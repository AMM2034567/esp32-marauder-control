class TerminalController {
  final List<String> history = <String>[];
  int historyIndex = -1;
  bool autoScroll = true;

  void recordCommand(String command) {
    final normalized = command.trim();
    if (normalized.isEmpty) return;
    if (history.isEmpty || history.last != normalized) {
      history.add(normalized);
      if (history.length > 50) history.removeAt(0);
    }
    historyIndex = -1;
  }

  String? previous() {
    if (history.isEmpty) return null;
    historyIndex = historyIndex < 0 ? history.length - 1 : (historyIndex - 1).clamp(0, history.length - 1);
    return history[historyIndex];
  }

  String? next() {
    if (history.isEmpty || historyIndex < 0) return null;
    historyIndex++;
    if (historyIndex >= history.length) {
      historyIndex = -1;
      return '';
    }
    return history[historyIndex];
  }
}
