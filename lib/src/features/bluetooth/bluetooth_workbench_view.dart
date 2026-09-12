import 'package:material_ui/material_ui.dart';
import 'package:material_3_expressive/material_3_expressive.dart';

import '../../core/models/radio_models.dart';

class BluetoothWorkbenchView extends StatelessWidget {
  const BluetoothWorkbenchView({
    super.key,
    required this.connected,
    required this.scanning,
    required this.selectedTab,
    required this.bluetoothDevices,
    required this.flipperDevices,
    required this.onTabChanged,
    required this.onScan,
    required this.onRefresh,
    required this.onStop,
  });

  final bool connected;
  final bool scanning;
  final int selectedTab;
  final List<BluetoothDeviceInfo> bluetoothDevices;
  final List<FlipperDeviceInfo> flipperDevices;
  final ValueChanged<int> onTabChanged;
  final VoidCallback onScan;
  final VoidCallback onRefresh;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final items = selectedTab == 0 ? bluetoothDevices : flipperDevices;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (scanning) const Padding(padding: EdgeInsets.only(bottom: 12), child: M3EProgressIndicator.linearWavy()),
        Row(children: [
          Expanded(child: Text('Bluetooth 数据', style: Theme.of(context).textTheme.headlineSmall)),
          Chip(label: Text(scanning ? '扫描中' : '只读')),
        ]),
        const SizedBox(height: 8),
        SegmentedButton<int>(
          segments: const [
            ButtonSegment(value: 0, label: Text('BLE'), icon: Icon(Icons.bluetooth)),
            ButtonSegment(value: 1, label: Text('Flipper'), icon: Icon(Icons.memory)),
          ],
          selected: {selectedTab},
          onSelectionChanged: connected ? (selection) => onTabChanged(selection.first) : null,
        ),
        const SizedBox(height: 8),
        Wrap(spacing: 8, children: [
          FilledButton.icon(onPressed: connected && !scanning ? onScan : null, icon: const Icon(Icons.play_arrow), label: const Text('开始扫描')),
          FilledButton.tonalIcon(onPressed: connected && !scanning ? onRefresh : null, icon: const Icon(Icons.refresh), label: const Text('刷新列表')),
          OutlinedButton.icon(onPressed: connected && scanning ? onStop : null, icon: const Icon(Icons.stop_circle_outlined), label: const Text('停止扫描')),
        ]),
        const SizedBox(height: 12),
        if (items.isEmpty)
          const Card(child: Padding(padding: EdgeInsets.all(24), child: Center(child: Text('暂无数据，请先开始扫描或刷新列表。'))))
        else if (selectedTab == 0)
          ...bluetoothDevices.map((device) => Card(child: ListTile(
                leading: const Icon(Icons.bluetooth),
                title: Text(device.name.isEmpty ? '<未命名设备>' : device.name),
                subtitle: Text('索引 ${device.index}'),
                trailing: Text('${device.rssi} dBm'),
              )))
        else
          ...flipperDevices.map((device) => Card(child: ListTile(
                leading: const Icon(Icons.memory),
                title: Text(device.name.isEmpty ? '<未命名 Flipper>' : device.name),
                subtitle: Text('索引 ${device.index}'),
                trailing: Text(device.mac),
              ))),
        const SizedBox(height: 12),
        const Card(child: ListTile(
          leading: Icon(Icons.shield_outlined),
          title: Text('只读安全模式'),
          subtitle: Text('blespam、spoofat 和其他 Bluetooth 攻击/欺骗命令未在应用中暴露。'),
        )),
      ],
    );
  }
}
