import 'package:material_ui/material_ui.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;

class MarauderTerminalView extends StatelessWidget {
  const MarauderTerminalView({
    super.key,
    required this.logs,
    required this.scrollController,
    required this.inputController,
    required this.connected,
    required this.operationLocked,
    required this.stopAllowed,
    required this.autoScroll,
    required this.onAutoScrollChanged,
    required this.onClear,
    required this.onSubmitted,
    required this.onSend,
    required this.onPreviousCommand,
    required this.onNextCommand,
  });

  final List<({String text, bool isError})> logs;
  final ScrollController scrollController;
  final TextEditingController inputController;
  final bool connected;
  final bool operationLocked;
  final bool stopAllowed;
  final bool autoScroll;
  final ValueChanged<bool> onAutoScrollChanged;
  final VoidCallback onClear;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onSend;
  final VoidCallback onPreviousCommand;
  final VoidCallback onNextCommand;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xff050807),
      child: Column(children: [
        if (operationLocked) const M3EProgressIndicator.linearWavy(),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 8, 0),
          child: Row(children: [
            const Expanded(child: Text('MARAUDER TERMINAL', style: TextStyle(color: Colors.greenAccent, fontFamily: 'monospace', fontWeight: FontWeight.bold))),
            M3EIconButton(icon: const Icon(Icons.delete_sweep), variant: M3EIconButtonVariant.standard, onPressed: onClear, tooltip: '清屏'),
            M3EIconButton(
              icon: Icon(autoScroll ? Icons.vertical_align_bottom : Icons.pause),
              variant: M3EIconButtonVariant.standard,
              onPressed: () => onAutoScrollChanged(!autoScroll),
              tooltip: autoScroll ? '暂停自动滚动' : '恢复自动滚动',
            ),
          ]),
        ),
        Expanded(
          child: logs.isEmpty
              ? const Center(child: Text('MARAUDER TERMINAL\n等待串口输出…', textAlign: TextAlign.center, style: TextStyle(color: Colors.greenAccent, fontFamily: 'monospace')))
              : ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
                  itemCount: logs.length,
                  itemBuilder: (context, index) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: SelectableText(
                      logs[index].text,
                      style: TextStyle(
                        color: logs[index].isError ? Colors.redAccent : (logs[index].text.startsWith('>') ? Colors.cyanAccent : Colors.greenAccent),
                        fontFamily: 'monospace',
                        fontSize: 13,
                        height: 1.25,
                      ),
                    ),
                  ),
                ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(children: [
              const Text('> ', style: TextStyle(color: Colors.greenAccent, fontFamily: 'monospace', fontSize: 16)),
              Expanded(child: Shortcuts(
                shortcuts: <ShortcutActivator, Intent>{
                  SingleActivator(LogicalKeyboardKey.arrowUp): const _HistoryUpIntent(),
                  SingleActivator(LogicalKeyboardKey.arrowDown): const _HistoryDownIntent(),
                },
                child: Actions(
                  actions: <Type, Action<Intent>>{
                    _HistoryUpIntent: CallbackAction<_HistoryUpIntent>(onInvoke: (_) { onPreviousCommand(); return null; }),
                    _HistoryDownIntent: CallbackAction<_HistoryDownIntent>(onInvoke: (_) { onNextCommand(); return null; }),
                  },
                  child: TextField(
                controller: inputController,
                enabled: connected && !operationLocked,
                onSubmitted: onSubmitted,
                style: const TextStyle(color: Colors.greenAccent, fontFamily: 'monospace'),
                cursorColor: Colors.greenAccent,
                decoration: const InputDecoration.collapsed(hintText: '输入命令…', hintStyle: TextStyle(color: Colors.white38, fontFamily: 'monospace')),
                  ),
                ),
              )),
              IconButton(
                onPressed: connected && (!operationLocked || stopAllowed) ? onSend : null,
                icon: Icon(stopAllowed ? Icons.stop_circle : Icons.send, color: stopAllowed ? Colors.orangeAccent : Colors.greenAccent),
                tooltip: stopAllowed ? '停止操作' : '发送命令',
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}

class _HistoryUpIntent extends Intent {
  const _HistoryUpIntent();
}

class _HistoryDownIntent extends Intent {
  const _HistoryDownIntent();
}
