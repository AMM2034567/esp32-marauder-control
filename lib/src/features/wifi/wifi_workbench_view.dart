import 'package:material_ui/material_ui.dart';
import 'package:material_3_expressive/material_3_expressive.dart';

import '../../core/models/wifi_models.dart';
import '../../core/models/radio_models.dart';
import 'wifi_controller.dart';

class WifiWorkbenchView extends StatelessWidget {
  const WifiWorkbenchView({
    super.key,
    required this.connected,
    required this.running,
    required this.status,
    required this.selectedTab,
    required this.accessPoints,
    required this.stations,
    required this.ssids,
    required this.detailApIndex,
    required this.apDetails,
    required this.onTabChanged,
    required this.onScan,
    required this.onRefresh,
    required this.onStop,
    required this.onApTap,
    this.query = '',
    this.sort = WifiSort.rssi,
    this.onQueryChanged = _noopString,
    this.onSortChanged = _noopSort,
  });

  final bool connected;
  final bool running;
  final String status;
  final int selectedTab;
  final List<WifiAccessPoint> accessPoints;
  final List<WifiStation> stations;
  final List<WifiSsid> ssids;
  final int? detailApIndex;
  final List<String> apDetails;
  final ValueChanged<int> onTabChanged;
  final VoidCallback onScan;
  final VoidCallback onRefresh;
  final VoidCallback onStop;
  final ValueChanged<WifiAccessPoint> onApTap;
  final String query;
  final WifiSort sort;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<WifiSort> onSortChanged;

  static void _noopString(String _) {}
  static void _noopSort(WifiSort _) {}

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (running) const Padding(padding: EdgeInsets.only(bottom: 12), child: M3EProgressIndicator.linearWavy()),
        Row(children: [
          Expanded(child: Text('WiFi 数据工作台', style: Theme.of(context).textTheme.headlineSmall)),
          Chip(label: Text(status)),
        ]),
        const SizedBox(height: 8),
        SegmentedButton<int>(
          segments: const [
            ButtonSegment(value: 0, label: Text('AP'), icon: Icon(Icons.wifi)),
            ButtonSegment(value: 1, label: Text('Station'), icon: Icon(Icons.devices)),
            ButtonSegment(value: 2, label: Text('SSID'), icon: Icon(Icons.text_fields)),
          ],
          selected: {selectedTab},
          onSelectionChanged: connected ? (selection) => onTabChanged(selection.first) : null,
        ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(spacing: 8, runSpacing: 8, children: [
              FilledButton.icon(onPressed: connected && !running ? onScan : null, icon: const Icon(Icons.play_arrow), label: const Text('扫描 AP 和设备')),
              FilledButton.tonalIcon(onPressed: connected && !running ? onRefresh : null, icon: const Icon(Icons.list), label: const Text('刷新列表')),
              OutlinedButton.icon(onPressed: connected && running ? onStop : null, icon: const Icon(Icons.stop_circle_outlined), label: const Text('停止扫描')),
            ]),
          ),
        ),
        const SizedBox(height: 12),
        TextField(decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: '搜索 SSID'), onChanged: onQueryChanged),
        if (selectedTab == 0) DropdownButtonFormField<WifiSort>(
          initialValue: sort,
          decoration: const InputDecoration(labelText: '排序'),
          items: const [
            DropdownMenuItem(value: WifiSort.rssi, child: Text('RSSI')),
            DropdownMenuItem(value: WifiSort.channel, child: Text('信道')),
            DropdownMenuItem(value: WifiSort.name, child: Text('名称')),
          ],
          onChanged: (value) { if (value != null) onSortChanged(value); },
        ),
        const SizedBox(height: 8),
        if (selectedTab == 0) ..._apList(context),
        if (selectedTab == 1) ..._stationList(),
        if (selectedTab == 2) ..._ssidList(),
        if (selectedTab == 0 && detailApIndex != null && apDetails.isNotEmpty)
          Card(child: ExpansionTile(initiallyExpanded: true, title: Text('AP $detailApIndex 详情'), children: apDetails.map((line) => ListTile(dense: true, title: Text(line))).toList())),
      ],
    );
  }

  List<Widget> _apList(BuildContext context) {
    final visible = const WifiController().filterAndSortAccessPoints(accessPoints, query: query, sort: sort);
    return [
      Text('${visible.length} 个 AP', style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 8),
      if (visible.isEmpty)
        const Card(child: Padding(padding: EdgeInsets.all(24), child: Center(child: Text('暂无 AP 数据，请先启动扫描或刷新列表。'))))
      else
        ...visible.map((ap) => Card(child: ListTile(
              leading: CircleAvatar(child: Text('${ap.channel}')),
              title: Text(ap.ssid.isEmpty ? '<隐藏 SSID>' : ap.ssid),
              subtitle: Text('索引 ${ap.index}${ap.selected ? ' · 已选择' : ''}'),
              trailing: Text('${ap.rssi} dBm'),
              onTap: connected ? () => onApTap(ap) : null,
            ))),
    ];
  }

  List<Widget> _stationList() => [
        Text('${stations.length} 个 Station'),
        const SizedBox(height: 8),
        ...stations.map((station) => Card(child: ListTile(
              leading: const Icon(Icons.devices),
              title: Text(station.mac),
              subtitle: Text('索引 ${station.index}${station.apSsid == null ? '' : ' · ${station.apSsid}'}'),
              trailing: station.selected ? const Icon(Icons.check_circle, color: Colors.greenAccent) : null,
            ))),
      ];

  List<Widget> _ssidList() => [
        Text('${ssids.length} 个 SSID'),
        const SizedBox(height: 8),
        ...ssids.map((ssid) => Card(child: ListTile(
              leading: const Icon(Icons.text_fields),
              title: Text(ssid.ssid),
              subtitle: Text('索引 ${ssid.index}'),
              trailing: ssid.selected ? const Icon(Icons.check_circle, color: Colors.greenAccent) : null,
            ))),
      ];
}
