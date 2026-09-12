import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import '../models/transport_models.dart';
import '../protocol/marauder_protocol.dart';
import '../transport/serial_transport.dart';

class MarauderSessionEvent {
  const MarauderSessionEvent.log(this.text, {this.isError = false})
      : type = MarauderSessionEventType.log,
        payload = null,
        state = null;
  const MarauderSessionEvent.protocol(this.payload)
      : type = MarauderSessionEventType.protocol,
        text = null,
        isError = false,
        state = null;
  const MarauderSessionEvent.state(this.state)
      : type = MarauderSessionEventType.state,
        text = null,
        payload = null,
        isError = false;

  final MarauderSessionEventType type;
  final String? text;
  final bool isError;
  final MarauderEvent? payload;
  final MarauderSessionState? state;
}

enum MarauderSessionEventType { log, protocol, state }
enum MarauderSessionState { disconnected, connecting, connected, error }

class MarauderSession {
  MarauderSession(this.transport) {
    _protocol = MarauderProtocol(onEvent: _onProtocolEvent);
    _transportSubscription = transport.events.listen(_onTransportEvent);
  }

  final SerialTransport transport;
  late final MarauderProtocol _protocol;
  late final StreamSubscription<TransportEvent> _transportSubscription;
  final StreamController<MarauderSessionEvent> _events = StreamController.broadcast();
  final List<_QueuedCommand> _queue = <_QueuedCommand>[];
  _QueuedCommand? _active;
  Timer? _timeout;
  MarauderSessionState _state = MarauderSessionState.disconnected;
  String? _activeOperation;

  Stream<MarauderSessionEvent> get events => _events.stream;
  MarauderSessionState get state => _state;
  String? get activeOperation => _activeOperation;
  bool get locked => _activeOperation != null;
  bool get stopAllowed => _activeOperation == 'wifiScan' || _activeOperation == 'bluetoothScan';

  Future<void> connect(String deviceId) async {
    _setState(MarauderSessionState.connecting);
    try {
      await transport.connect(deviceId);
    } catch (error) {
      _emitLog('连接失败：$error', isError: true);
      _setState(MarauderSessionState.error);
    }
  }

  Future<void> disconnect() async {
    await transport.disconnect();
    _clearQueue();
    _setState(MarauderSessionState.disconnected);
  }

  Future<void> dispose() async {
    _clearQueue();
    _timeout?.cancel();
    await _transportSubscription.cancel();
    await _events.close();
  }

  Future<void> send(String command, {bool? waitForPrompt, String? operation}) {
    final normalized = command.trim();
    if (normalized.isEmpty || _state != MarauderSessionState.connected) return Future<void>.value();
    if (MarauderCommandCatalog.dangerous.any(normalized.startsWith)) {
      _emitLog('危险命令已被会话层拦截：$normalized', isError: true);
      return Future<void>.value();
    }
    if (locked && normalized != 'stopscan') {
      _emitLog('当前操作进行中，已忽略命令：$normalized');
      return Future<void>.value();
    }
    if (normalized == 'stopscan' && _active != null && !_active!.expectsPrompt) {
      _activeOperation = 'stopping';
      _emitLog('> stopscan');
      return transport.write(Uint8List.fromList(utf8.encode('stopscan\r\n'))).whenComplete(() {
        _finish();
      });
    }
    final commandName = normalized.split(RegExp(r'\s+')).first;
    final expectsPrompt = waitForPrompt ?? !_streamingCommands.contains(commandName);
    if (operation != null) _activeOperation = operation;
    if (normalized == 'stopscan') _activeOperation = 'stopping';
    final queued = _QueuedCommand(normalized, expectsPrompt);
    _queue.add(queued);
    _pump();
    return queued.completer.future;
  }

  static const _streamingCommands = <String>{
    'scanall', 'sniffraw', 'sniffbeacon', 'sniffprobe', 'sniffpwn', 'sniffdeauth',
    'sniffpmkid', 'pingscan', 'portscan', 'arpscan', 'mactrack', 'sniffbt',
  };

  void _pump() {
    if (_active != null || _queue.isEmpty || _state != MarauderSessionState.connected) return;
    final queued = _queue.removeAt(0);
    _active = queued;
    _emitLog('> ${queued.command}');
    transport.write(Uint8List.fromList(utf8.encode('${queued.command}\r\n'))).catchError((error) {
      _emitLog('命令发送失败：$error', isError: true);
      _finish();
    });
    if (!queued.expectsPrompt) {
      return;
    }
    _timeout?.cancel();
    _timeout = Timer(const Duration(seconds: 8), () {
      _emitLog('命令超时：${queued.command}', isError: true);
      _finish();
    });
  }

  void _finish() {
    _timeout?.cancel();
    _timeout = null;
    final completed = _active;
    _active = null;
    if (completed != null && !completed.completer.isCompleted) completed.completer.complete();
    if (_activeOperation == 'command' || _activeOperation == 'stopping') _activeOperation = null;
    _pump();
  }

  void _onProtocolEvent(MarauderEvent event) {
    _events.add(MarauderSessionEvent.protocol(event));
    if (event case MachineEvent(:final payload)) {
      if (payload['status'] == 'success' || payload['status'] == 'error') _finish();
    }
    if (event case PromptEvent()) _finish();
  }

  void _onTransportEvent(TransportEvent event) {
    switch (event.type) {
      case 'connected':
        _setState(MarauderSessionState.connected);
      case 'disconnected':
        _clearQueue();
        _setState(MarauderSessionState.disconnected);
      case 'data':
        if (event.data != null) _protocol.addBytes(event.data!);
      case 'error':
        _emitLog(event.message ?? '串口错误', isError: true);
        _setState(MarauderSessionState.error);
    }
  }

  void _clearQueue() {
    _timeout?.cancel();
    _timeout = null;
    _active?.completer.complete();
    _active = null;
    for (final item in _queue) {
      if (!item.completer.isCompleted) item.completer.complete();
    }
    _queue.clear();
    _activeOperation = null;
  }

  void _setState(MarauderSessionState state) {
    _state = state;
    _events.add(MarauderSessionEvent.state(state));
  }

  void _emitLog(String text, {bool isError = false}) {
    _events.add(MarauderSessionEvent.log(text, isError: isError));
  }
}

class _QueuedCommand {
  _QueuedCommand(this.command, this.expectsPrompt);

  final String command;
  final bool expectsPrompt;
  final Completer<void> completer = Completer<void>();
}
