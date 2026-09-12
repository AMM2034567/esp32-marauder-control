import 'dart:async';
import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:material_3_expressive/material_3_expressive.dart';

import 'src/core/models/device_models.dart';
import 'src/core/models/transport_models.dart';
import 'src/core/models/wifi_models.dart';
import 'src/core/models/storage_models.dart';
import 'src/core/models/radio_models.dart';
import 'src/core/protocol/marauder_protocol.dart';
import 'src/core/session/marauder_session.dart';
import 'src/core/transport/serial_transport.dart';
import 'src/core/transport/android_usb_serial_transport.dart';
import 'src/features/terminal/marauder_terminal_view.dart';
import 'src/features/wifi/wifi_workbench_view.dart';
import 'src/features/bluetooth/bluetooth_workbench_view.dart';
import 'src/features/storage/storage_browser_view.dart';

void main() => runApp(const MarauderApp());

class MarauderApp extends StatelessWidget {
  const MarauderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return M3EMaterialApp(
      title: 'Marauder Control',
      debugShowCheckedModeBanner: false,
      data: M3EThemeData.dark(seedColor: const Color(0xff4ed9a4)),
      autoTheming: false,
      dynamicColoring: false,
      drawUnderSystemBars: true,
      home: const MarauderHomePage(),
    );
  }
}

class MarauderHomePage extends StatefulWidget {
  const MarauderHomePage({super.key});

  @override
  State<MarauderHomePage> createState() => _MarauderHomePageState();
}

class _MarauderHomePageState extends State<MarauderHomePage> {
  late final SerialTransport _transport;
  late final MarauderSession _session;
  final List<MarauderLogEntry> _logs = <MarauderLogEntry>[];
  final List<UsbDeviceInfo> _devices = <UsbDeviceInfo>[];
  StreamSubscription<MarauderSessionEvent>? _sessionSubscription;
  SerialConnectionState _connectionState = SerialConnectionState.disconnected;
  DeviceCapabilities _capabilities = MarauderCommandCatalog.inferCapabilities();
  int _tabIndex = 0;
  final List<WifiAccessPoint> _accessPoints = <WifiAccessPoint>[];
  WifiScanState _wifiScanState = WifiScanState.idle;
  final List<SdFileEntry> _sdFiles = <SdFileEntry>[];
  String _sdPath = '/';
  final List<WifiStation> _stations = <WifiStation>[];
  final List<WifiSsid> _ssids = <WifiSsid>[];
  final List<BluetoothDeviceInfo> _bluetoothDevices = <BluetoothDeviceInfo>[];
  final List<FlipperDeviceInfo> _flipperDevices = <FlipperDeviceInfo>[];
  int _radioSubtab = 0;
  bool _bluetoothScanning = false;
  final List<String> _apDetails = <String>[];
  int _wifiSubtab = 0;
  int? _detailApIndex;
  int? _stationApIndex;
  String? _stationApSsid;
  String? _lastProbeError;
  bool _probeInProgress = false;
  final ScrollController _terminalScrollController = ScrollController();
  final TextEditingController _terminalInputController = TextEditingController();
  final List<String> _commandHistory = <String>[];
  int _historyIndex = -1;
  bool _terminalAutoScroll = true;
  String? _activeOperation;

  bool get _operationLocked => _activeOperation != null;
  bool get _stopAllowed => _activeOperation == 'wifiScan' || _activeOperation == 'bluetoothScan';

  void _beginOperation(String operation) {
    if (_operationLocked && !_stopAllowed) return;
    setState(() {
      _activeOperation = operation;
    });
  }

  void _endOperation() {
    if (!mounted) return;
    setState(() {
      _activeOperation = null;
    });
  }

  @override
  void initState() {
    super.initState();
    _transport = AndroidUsbSerialTransport();
    _session = MarauderSession(_transport);
    _sessionSubscription = _session.events.listen(_handleSessionEvent);
    _refreshDevices();
  }

  @override
  void dispose() {
    _sessionSubscription?.cancel();
    unawaited(_session.dispose());
    _terminalScrollController.dispose();
    _terminalInputController.dispose();
    if (_transport is AndroidUsbSerialTransport) {
      unawaited(_transport.dispose());
    }
    super.dispose();
  }

  Future<void> _refreshDevices() async {
    final devices = await _transport.listDevices();
    if (mounted) setState(() => _devices..clear()..addAll(devices));
  }

  Future<void> _connect() async {
    if (_devices.isEmpty) await _refreshDevices();
    if (_devices.isEmpty) {
      _addLog('未发现 USB 串口设备。请确认 OTG、供电和 USB-UART 芯片。', isError: true);
      return;
    }
    setState(() => _connectionState = SerialConnectionState.connecting);
    try {
      await _session.connect(_devices.first.id);
      _addLog('已发起连接，等待 USB 权限或串口事件');
    } catch (error) {
      setState(() => _connectionState = SerialConnectionState.error);
      _addLog('连接失败：$error', isError: true);
    }
  }

  Future<void> _disconnect() async {
    await _session.disconnect();
    if (mounted) setState(() => _connectionState = SerialConnectionState.disconnected);
    _addLog('已断开连接');
  }

  Future<void> _sendCommand(String command, {bool? waitForPrompt}) {
    if (_connectionState != SerialConnectionState.connected) {
      _addLog('未连接，无法发送命令', isError: true);
      return Future<void>.value();
    }
    final normalized = command.trim();
    final operation = normalized == 'scanall' ? 'wifiScan' : normalized == 'sniffbt' ? 'bluetoothScan' : null;
    final future = _session.send(normalized, waitForPrompt: waitForPrompt, operation: operation);
    if (normalized == 'scanall') {
      _beginOperation('wifiScan');
      setState(() => _wifiScanState = WifiScanState.running);
    } else if (normalized == 'sniffbt') {
      _beginOperation('bluetoothScan');
    } else if (normalized == 'stopscan') {
      setState(() => _wifiScanState = WifiScanState.stopping);
    } else if (!_operationLocked) {
      _beginOperation('command');
      future.whenComplete(() {
        if (mounted && _activeOperation == 'command') _endOperation();
      });
    }
    return future;
  }

  Future<void> _refreshAccessPoints() async {
    if (_operationLocked) return;
    _accessPoints.clear();
    await _sendCommand('list -a');
  }

  Future<void> _stopWifiScan() async {
    if (!_stopAllowed) return;
    try {
      await _sendCommand('stopscan', waitForPrompt: false);
    } finally {
      _endOperation();
      if (mounted) setState(() => _bluetoothScanning = false);
    }
  }

  Future<void> _probeDevice() async {
    if (_connectionState != SerialConnectionState.connected || _probeInProgress) return;
    setState(() {
      _probeInProgress = true;
      _lastProbeError = null;
      _capabilities = _capabilities.copyWith(probeState: DeviceProbeState.probing);
    });
    try {
      _addLog('开始探测 Marauder 固件和命令能力');
      await _sendCommand('protocolinfo --machine app_probe');
      await _sendCommand('help');
      await Future<void>.delayed(const Duration(milliseconds: 1500));
      if (mounted) {
        setState(() {
          if (_capabilities.firmwareVersion == null) {
            _lastProbeError = '未从串口输出中识别固件版本';
            _capabilities = _capabilities.copyWith(probeState: DeviceProbeState.failed);
          } else {
            _capabilities = _capabilities.copyWith(probeState: DeviceProbeState.ready);
          }
        });
      }
    } catch (error) {
      _addLog('固件探测失败：$error', isError: true);
      if (mounted) {
        setState(() => _capabilities = _capabilities.copyWith(probeState: DeviceProbeState.failed));
      }
    } finally {
      if (mounted) {
        setState(() => _probeInProgress = false);
        _endOperation();
      }
    }
  }

  void _handleSessionEvent(MarauderSessionEvent event) {
    switch (event.type) {
      case MarauderSessionEventType.log:
        _addLog(event.text ?? '', isError: event.isError);
      case MarauderSessionEventType.state:
        final state = event.state!;
        setState(() => _connectionState = switch (state) {
          MarauderSessionState.connected => SerialConnectionState.connected,
          MarauderSessionState.connecting => SerialConnectionState.connecting,
          MarauderSessionState.error => SerialConnectionState.error,
          MarauderSessionState.disconnected => SerialConnectionState.disconnected,
        });
        if (state == MarauderSessionState.connected) unawaited(_probeDevice());
        if (state == MarauderSessionState.disconnected) _endOperation();
      case MarauderSessionEventType.protocol:
        _handleProtocolEvent(event.payload!);
    }
  }

  void _handleProtocolEvent(MarauderEvent event) {
    switch (event) {
      case TextEvent(:final text):
        _addLog(text, isError: text.toLowerCase().contains('error'));
        final ssid = MarauderProtocol.parseSsidLine(text);
        final bluetooth = MarauderProtocol.parseBluetoothLine(text);
        final flipper = MarauderProtocol.parseFlipperLine(text);
        final station = MarauderProtocol.parseStationLine(text);
        final stationHeader = MarauderProtocol.parseStationGroupHeader(text);
        if (stationHeader != null) {
          _stationApIndex = stationHeader.index;
          _stationApSsid = stationHeader.ssid;
        }
        if (ssid != null) _upsertSsid(ssid);
        if (bluetooth != null) _upsertBluetooth(bluetooth);
        if (flipper != null) _upsertFlipper(flipper);
        if (station != null) {
          _upsertStation(MarauderProtocol.parseStationLine(text, apIndex: _stationApIndex, apSsid: _stationApSsid)!);
        }
        if (_detailApIndex != null && text.isNotEmpty && !MarauderProtocol.isCommandEcho(text)) {
          setState(() => _apDetails.add(text));
        }
        final file = MarauderProtocol.parseSdFileLine(text);
        if (file != null) {
          final existing = _sdFiles.indexWhere((item) => item.path == file.path);
          setState(() {
            if (existing >= 0) {
              _sdFiles[existing] = file;
            } else {
              _sdFiles.add(file);
            }
          });
        }
        final ap = MarauderProtocol.parseAccessPointLine(text);
        if (ap != null) {
          final existing = _accessPoints.indexWhere((item) => item.index == ap.index);
          setState(() {
            if (existing >= 0) {
              _accessPoints[existing] = ap;
            } else {
              _accessPoints.add(ap);
            }
          });
        }
        if (MarauderProtocol.isScanStarted(text)) setState(() => _wifiScanState = WifiScanState.running);
        if (MarauderProtocol.isScanStopped(text)) {
          setState(() {
            _wifiScanState = WifiScanState.stopped;
            _bluetoothScanning = false;
          });
          _endOperation();
          if (_wifiSubtab == 0) unawaited(_refreshAccessPoints());
        }
        final version = MarauderProtocol.extractFirmwareVersion(text);
        if (version != null || MarauderProtocol.isMarauderBanner(text)) {
          setState(() => _capabilities = _capabilities.copyWith(
                firmwareVersion: version ?? _capabilities.firmwareVersion,
                boardName: 'ESP32 Marauder',
              ));
        }
      case PromptEvent():
        _addLog('设备就绪');
      case MachineEvent(:final payload):
        _addLog('机器响应：${jsonEncode(payload)}');
        final version = (payload['firmware'] ?? payload['version']) as String?;
        final board = payload['board'] as String?;
        final supported = (payload['capabilities'] as List<dynamic>?)?.cast<String>();
        if (version != null || board != null || supported != null) {
          final capabilities = {..._capabilities.capabilities};
          if (supported != null) {
            if (supported.contains('bluetooth') || supported.contains('ble')) {
              capabilities.add(MarauderCapability.bluetooth);
            }
            if (supported.contains('sd') || supported.contains('spiffs-backup')) {
              capabilities.add(MarauderCapability.sdStorage);
            }
            if (supported.contains('gps')) {
              capabilities.add(MarauderCapability.gps);
            } else {
              capabilities.remove(MarauderCapability.gps);
            }
            if (supported.contains('direct-upload')) {
              capabilities.add(MarauderCapability.directUpload);
            } else {
              capabilities.remove(MarauderCapability.directUpload);
            }
          }
          setState(() => _capabilities = _capabilities.copyWith(
                firmwareVersion: version,
                boardName: board,
                capabilities: capabilities,
              ));
        }
    }
  }

  void _upsertStation(WifiStation value) {
    final index = _stations.indexWhere((item) => item.index == value.index);
    setState(() => index >= 0 ? _stations[index] = value : _stations.add(value));
  }

  void _upsertSsid(WifiSsid value) {
    final index = _ssids.indexWhere((item) => item.index == value.index);
    setState(() => index >= 0 ? _ssids[index] = value : _ssids.add(value));
  }

  void _upsertBluetooth(BluetoothDeviceInfo value) {
    final index = _bluetoothDevices.indexWhere((item) => item.index == value.index);
    setState(() => index >= 0 ? _bluetoothDevices[index] = value : _bluetoothDevices.add(value));
  }

  void _upsertFlipper(FlipperDeviceInfo value) {
    final index = _flipperDevices.indexWhere((item) => item.index == value.index);
    setState(() => index >= 0 ? _flipperDevices[index] = value : _flipperDevices.add(value));
  }

  Future<void> _loadWifiData() async {
    if (_operationLocked) return;
    _stations.clear();
    _ssids.clear();
    if (_wifiSubtab == 0) {
      await _refreshAccessPoints();
    } else if (_wifiSubtab == 1) {
      await _sendCommand('list -c');
    } else {
      await _sendCommand('list -s');
    }
  }

  Future<void> _showApDetails(WifiAccessPoint ap) async {
    if (_operationLocked) return;
    setState(() {
      _detailApIndex = ap.index;
      _apDetails.clear();
    });
    // This command is queued before the lock is exposed to subsequent user taps.
    await _sendCommand('info -a ${ap.index}');
  }

  Future<void> _startBluetoothScan() async {
    if (_operationLocked) return;
    _bluetoothDevices.clear();
    _flipperDevices.clear();
    setState(() => _bluetoothScanning = true);
    await _sendCommand('sniffbt');
  }

  Future<void> _refreshBluetoothDevices() async {
    if (_operationLocked) return;
    _bluetoothDevices.clear();
    _flipperDevices.clear();
    await _sendCommand(_radioSubtab == 0 ? 'list -b' : 'list -f');
    _endOperation();
  }

  void _addLog(String text, {bool isError = false}) {
    if (!mounted) return;
    setState(() {
      _logs.add(MarauderLogEntry(text: text, timestamp: DateTime.now(), isError: isError));
      if (_logs.length > 300) _logs.removeAt(0);
    });
    if (_tabIndex == 2 && _terminalAutoScroll) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_terminalScrollController.hasClients) {
          _terminalScrollController.animateTo(
            _terminalScrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  void _clearTerminal() {
    setState(() => _logs.clear());
  }

  void _showPreviousCommand() {
    if (_commandHistory.isEmpty) return;
    setState(() {
      _historyIndex = _historyIndex < 0 ? _commandHistory.length - 1 : (_historyIndex - 1).clamp(0, _commandHistory.length - 1);
      _terminalInputController.text = _commandHistory[_historyIndex];
      _terminalInputController.selection = TextSelection.fromPosition(TextPosition(offset: _terminalInputController.text.length));
    });
  }

  void _showNextCommand() {
    if (_commandHistory.isEmpty || _historyIndex < 0) return;
    setState(() {
      _historyIndex++;
      if (_historyIndex >= _commandHistory.length) {
        _historyIndex = -1;
        _terminalInputController.clear();
      } else {
        _terminalInputController.text = _commandHistory[_historyIndex];
        _terminalInputController.selection = TextSelection.fromPosition(TextPosition(offset: _terminalInputController.text.length));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MARAUDER CONTROL'),
        actions: [
          IconButton(onPressed: _refreshDevices, icon: const Icon(Icons.refresh), tooltip: '刷新设备'),
          Padding(padding: const EdgeInsets.only(right: 16), child: Center(child: _ConnectionChip(state: _connectionState))),
        ],
      ),
      body: IndexedStack(index: _tabIndex, children: [_dashboard(), _wifiView(), _terminal(), _bluetoothView(), _storageView(), _logsPage()]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex <= 3 ? _tabIndex : 0,
        onDestinationSelected: (index) => setState(() => _tabIndex = index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.radar), label: '控制台'),
          NavigationDestination(icon: Icon(Icons.wifi_find), label: 'WiFi'),
          NavigationDestination(icon: Icon(Icons.terminal), label: '终端'),
          NavigationDestination(icon: Icon(Icons.bluetooth), label: 'Bluetooth'),
        ],
      ),
      floatingActionButton: FloatingActionButton.small(onPressed: _openMoreMenu, child: const Icon(Icons.more_horiz)),
    );
  }

  Widget _dashboard() {
    final connected = _connectionState == SerialConnectionState.connected;
    return RefreshIndicator(
      onRefresh: _refreshDevices,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _heroCard(connected),
          if (_capabilities.driverName != null) _diagnosticsCard(),
          const SizedBox(height: 16),
          _sectionTitle('设备能力'),
          _capabilityCard(),
          const SizedBox(height: 16),
          _sectionTitle('基础控制'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Wrap(spacing: 8, runSpacing: 8, children: [
                _commandButton('帮助', 'help', Icons.help_outline),
                _commandButton('扫描全部', 'scanall', Icons.wifi_find),
                _commandButton('列出 AP', 'list -a', Icons.list),
                _commandButton('停止扫描', 'stopscan', Icons.stop_circle_outlined),
                _commandButton('清空列表', 'clearlist -a', Icons.delete_outline),
              ]),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            color: Theme.of(context).colorScheme.errorContainer.withValues(alpha: .18),
            child: const ListTile(
              leading: Icon(Icons.shield_outlined),
              title: Text('安全模式已启用'),
              subtitle: Text('攻击、Evil Portal、BLE spam 等危险操作未在首期 UI 中暴露。仅在自有设备和授权实验室使用。'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _wifiView() => WifiWorkbenchView(
        connected: _connectionState == SerialConnectionState.connected,
        running: _wifiScanState == WifiScanState.running || _wifiScanState == WifiScanState.stopping,
        status: switch (_wifiScanState) {
          WifiScanState.idle => '等待开始',
          WifiScanState.running => '扫描中',
          WifiScanState.stopping => '正在停止',
          WifiScanState.stopped => '已停止',
          WifiScanState.error => '错误',
        },
        selectedTab: _wifiSubtab,
        accessPoints: _accessPoints,
        stations: _stations,
        ssids: _ssids,
        detailApIndex: _detailApIndex,
        apDetails: _apDetails,
        onTabChanged: (tab) { setState(() => _wifiSubtab = tab); _loadWifiData(); },
        onScan: () => _sendCommand('scanall'),
        onRefresh: _loadWifiData,
        onStop: _stopWifiScan,
        onApTap: _showApDetails,
      );

  Widget _bluetoothView() => BluetoothWorkbenchView(
        connected: _connectionState == SerialConnectionState.connected,
        scanning: _bluetoothScanning,
        selectedTab: _radioSubtab,
        bluetoothDevices: _bluetoothDevices,
        flipperDevices: _flipperDevices,
        onTabChanged: (tab) { setState(() => _radioSubtab = tab); _refreshBluetoothDevices(); },
        onScan: _startBluetoothScan,
        onRefresh: _refreshBluetoothDevices,
        onStop: _stopWifiScan,
      );

  Widget _storageView() => StorageBrowserView(
        connected: _connectionState == SerialConnectionState.connected,
        path: _sdPath,
        files: _sdFiles,
        onRefresh: () { setState(() => _sdFiles.clear()); _sendCommand('ls $_sdPath'); },
        onEnterDirectory: (path) { setState(() { _sdPath = path; _sdFiles.clear(); }); _sendCommand('ls $path'); },
        onParent: () {
          final parent = _sdPath.substring(0, _sdPath.lastIndexOf('/'));
          setState(() { _sdPath = parent.isEmpty ? '/' : parent; _sdFiles.clear(); });
          _sendCommand('ls $_sdPath');
        },
      );

  void _openMoreMenu() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          M3EListItem(
            leading: const Icon(Icons.sd_card),
            headline: 'SD 文件',
            onTap: () { Navigator.pop(context); setState(() => _tabIndex = 4); },
          ),
          M3EListItem(
            leading: const Icon(Icons.receipt_long),
            headline: '日志',
            onTap: () { Navigator.pop(context); setState(() => _tabIndex = 5); },
          ),
        ]),
      ),
    );
  }

  Widget _heroCard(bool connected) => Card(
        clipBehavior: Clip.antiAlias,
        child: Container(
          decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xff123b31), Color(0xff101917)])),
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('ESP32 MARAUDER', style: Theme.of(context).textTheme.labelLarge?.copyWith(letterSpacing: 2)),
            const SizedBox(height: 8),
            Text(_capabilities.boardName, style: Theme.of(context).textTheme.headlineSmall),
            Text('固件 ${_capabilities.firmwareVersion ?? '待探测'} · USB 串口 115200 8N1'),
            const SizedBox(height: 16),
            FilledButton.icon(onPressed: connected ? _disconnect : _connect, icon: Icon(connected ? Icons.usb_off : Icons.usb), label: Text(connected ? '断开设备' : '连接 USB 设备')),
          ]),
        ),
      );

  Widget _capabilityCard() {
    final items = <({String label, MarauderCapability capability, IconData icon})>[
      (label: 'WiFi 扫描', capability: MarauderCapability.wifiScan, icon: Icons.wifi_find),
      (label: 'WiFi 数据', capability: MarauderCapability.wifiData, icon: Icons.device_hub),
      (label: 'Bluetooth', capability: MarauderCapability.bluetooth, icon: Icons.bluetooth),
      (label: 'SD 存储', capability: MarauderCapability.sdStorage, icon: Icons.sd_card),
      (label: 'GPS', capability: MarauderCapability.gps, icon: Icons.gps_fixed),
      (label: '直接上传', capability: MarauderCapability.directUpload, icon: Icons.cloud_upload),
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Wrap(children: items.map((item) {
          final enabled = _capabilities.probeState == DeviceProbeState.ready && _capabilities.supports(item.capability);
          return SizedBox(width: 110, child: ListTile(
            dense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 8),
            leading: Icon(item.icon, color: enabled ? null : Colors.white24),
            title: Text(item.label, style: TextStyle(color: enabled ? null : Colors.white38, fontSize: 12)),
            subtitle: Text(
              enabled ? '可用' : (_capabilities.probeState == DeviceProbeState.probing ? '探测中' : '不可用'),
              style: TextStyle(color: enabled ? Colors.greenAccent : Colors.white24, fontSize: 11),
            ),
          ));
        }).toList()),
      ),
    );
  }

  Widget _commandButton(String label, String command, IconData icon) => FilledButton.tonalIcon(
      onPressed: _connectionState == SerialConnectionState.connected && (!_operationLocked || command == 'stopscan')
        ? () => _sendCommand(command)
        : null,
        icon: Icon(icon),
        label: Text(label),
      );

  Widget _diagnosticsCard() {
    final state = switch (_capabilities.probeState) {
      DeviceProbeState.pending => '等待探测',
      DeviceProbeState.probing => '探测中',
      DeviceProbeState.ready => '探测完成',
      DeviceProbeState.failed => '探测失败',
    };
    return Card(
      child: ListTile(
        leading: Icon(_capabilities.probeState == DeviceProbeState.failed ? Icons.warning_amber : Icons.usb),
        title: Text('连接诊断 · $state'),
        subtitle: Text(
          '驱动 ${_capabilities.driverName} · VID ${_capabilities.vendorId ?? '-'} / PID ${_capabilities.productId ?? '-'}'
          '${_lastProbeError == null ? '' : '\n$_lastProbeError'}',
        ),
        trailing: _connectionState == SerialConnectionState.connected
            ? IconButton(onPressed: _probeInProgress ? null : _probeDevice, icon: const Icon(Icons.sync), tooltip: '重新探测')
            : null,
      ),
    );
  }

  Widget _terminal() => MarauderTerminalView(
        logs: _logs.map((log) => (text: log.text, isError: log.isError)).toList(),
        scrollController: _terminalScrollController,
        inputController: _terminalInputController,
        connected: _connectionState == SerialConnectionState.connected,
        operationLocked: _operationLocked,
        stopAllowed: _stopAllowed,
        autoScroll: _terminalAutoScroll,
        onAutoScrollChanged: (value) => setState(() => _terminalAutoScroll = value),
        onClear: _clearTerminal,
        onSubmitted: (value) {
          _sendCommand(value);
          _terminalInputController.clear();
        },
        onSend: () => _sendCommand(_terminalInputController.text),
        onPreviousCommand: _showPreviousCommand,
        onNextCommand: _showNextCommand,
      );

  Widget _logsPage() => _logList(showEmptyHint: '暂无日志');

  Widget _logList({required String showEmptyHint}) {
    if (_logs.isEmpty) return Center(child: Text(showEmptyHint));
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _logs.length,
      itemBuilder: (context, index) {
        final log = _logs[_logs.length - index - 1];
        return ListTile(
          dense: true,
          leading: Icon(log.isError ? Icons.error_outline : Icons.chevron_right, color: log.isError ? Colors.redAccent : Colors.greenAccent),
          title: Text(log.text, style: TextStyle(color: log.isError ? Colors.redAccent : null)),
          subtitle: Text('${log.timestamp.hour.toString().padLeft(2, '0')}:${log.timestamp.minute.toString().padLeft(2, '0')}:${log.timestamp.second.toString().padLeft(2, '0')}'),
        );
      },
    );
  }

  Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.greenAccent)),
      );
}

class _ConnectionChip extends StatelessWidget {
  const _ConnectionChip({required this.state});
  final SerialConnectionState state;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (state) {
      SerialConnectionState.connected => ('已连接', Colors.greenAccent),
      SerialConnectionState.connecting => ('连接中', Colors.amber),
      SerialConnectionState.error => ('错误', Colors.redAccent),
      SerialConnectionState.disconnected => ('未连接', Colors.white54),
    };
    return Chip(label: Text(label, style: TextStyle(color: color)), avatar: Icon(Icons.circle, size: 10, color: color));
  }
}


