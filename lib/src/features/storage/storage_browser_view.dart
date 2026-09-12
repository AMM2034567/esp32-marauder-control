import 'package:material_ui/material_ui.dart';

import '../../core/models/storage_models.dart';

class StorageBrowserView extends StatelessWidget {
  const StorageBrowserView({
    super.key,
    required this.connected,
    required this.path,
    required this.files,
    required this.onRefresh,
    required this.onEnterDirectory,
    required this.onParent,
  });

  final bool connected;
  final String path;
  final List<SdFileEntry> files;
  final VoidCallback onRefresh;
  final ValueChanged<String> onEnterDirectory;
  final VoidCallback onParent;

  @override
  Widget build(BuildContext context) {
    final totalBytes = files.fold<int>(0, (sum, item) => sum + item.size);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(children: [
          Expanded(child: Text('SD 文件', style: Theme.of(context).textTheme.headlineSmall)),
          FilledButton.tonalIcon(onPressed: connected ? onRefresh : null, icon: const Icon(Icons.refresh), label: Text('刷新 $path')),
        ]),
        const SizedBox(height: 8),
        Card(child: ListTile(
          leading: const Icon(Icons.info_outline),
          title: Text('${files.length} 个文件 · $totalBytes bytes'),
          subtitle: const Text('当前为只读目录浏览。完整 PCAP/JSON 下载协议尚未确认。'),
        )),
        const SizedBox(height: 8),
        if (files.isEmpty)
          const Card(child: Padding(padding: EdgeInsets.all(24), child: Center(child: Text('暂无目录数据，请点击刷新。'))))
        else
          ...files.map((file) => Card(child: ListTile(
                leading: Icon(file.path.endsWith('/') ? Icons.folder_outlined : Icons.insert_drive_file_outlined),
                title: Text(file.path),
                trailing: Text('${file.size} B'),
                onTap: file.path.endsWith('/') ? () => onEnterDirectory(file.path) : null,
              ))),
        if (path != '/') TextButton.icon(onPressed: connected ? onParent : null, icon: const Icon(Icons.arrow_upward), label: const Text('返回上级目录')),
      ],
    );
  }
}
