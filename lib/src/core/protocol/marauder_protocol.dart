import 'dart:convert';
import 'dart:typed_data';

import '../models/device_models.dart';
import '../models/wifi_models.dart';
import '../models/storage_models.dart';
import '../models/radio_models.dart';

sealed class MarauderEvent {
  const MarauderEvent();
}

class TextEvent extends MarauderEvent {
  const TextEvent(this.text);
  final String text;
}

class PromptEvent extends MarauderEvent {
  const PromptEvent();
}

class MachineEvent extends MarauderEvent {
  const MachineEvent(this.payload);
  final Map<String, dynamic> payload;
}

class MarauderProtocol {
  MarauderProtocol({this.onEvent});

  final void Function(MarauderEvent event)? onEvent;
  final List<int> _buffer = <int>[];
  String _pendingLine = '';

  void addBytes(Uint8List bytes) {
    _buffer.addAll(bytes);
    while (_buffer.isNotEmpty) {
      final newline = _buffer.indexOf(0x0A);
      if (newline < 0) break;
      final lineBytes = _buffer.sublist(0, newline);
      _buffer.removeRange(0, newline + 1);
      final line = utf8.decode(lineBytes, allowMalformed: true).replaceAll('\r', '');
      _consumeLine(line);
    }
  }

  void flush() {
    if (_buffer.isNotEmpty) {
      _pendingLine += utf8.decode(_buffer, allowMalformed: true);
      _buffer.clear();
    }
    if (_pendingLine.isNotEmpty) {
      _consumeLine(_pendingLine);
      _pendingLine = '';
    }
  }

  void _consumeLine(String rawLine) {
    final line = rawLine.trimRight();
    if (line == '>') {
      onEvent?.call(const PromptEvent());
      return;
    }
    if (line.startsWith('@MARAUDER:')) {
      final jsonText = line.substring('@MARAUDER:'.length);
      try {
        final decoded = jsonDecode(jsonText);
        if (decoded is Map<String, dynamic>) {
          onEvent?.call(MachineEvent(decoded));
          return;
        }
      } on FormatException {
        // Preserve malformed machine output as normal text for diagnostics.
      }
    }
    onEvent?.call(TextEvent(line));
  }

  static String command(String name, [List<String> arguments = const []]) {
    final parts = <String>[name, ...arguments]
        .where((part) => part.trim().isNotEmpty)
        .map(_quoteIfNeeded)
        .toList();
    return '${parts.join(' ')}\r\n';
  }

  static String _quoteIfNeeded(String value) {
    if (!value.contains(RegExp(r'[\s"]'))) return value;
    return '"${value.replaceAll('"', '\\"')}"';
  }

  static String? extractFirmwareVersion(String text) {
    final match = RegExp(r'\bv?([0-9]+\.[0-9]+(?:\.[0-9]+)?)\b', caseSensitive: false).firstMatch(text);
    return match == null ? null : 'v${match.group(1)}';
  }

  static bool isCommandEcho(String text) => text.startsWith('#');

  static bool isMarauderBanner(String text) =>
      text.toLowerCase().contains('esp32 marauder') || text.toLowerCase().contains('marauder');

  static WifiAccessPoint? parseAccessPointLine(String text) {
    final match = RegExp(r'^\[(\d+)\]\[CH:(\d+)\]\s(.*)\s(-?\d+)(?:\s\(selected\))?$').firstMatch(text.trim());
    if (match == null) return null;
    final ssid = match.group(3)?.trim();
    final index = int.tryParse(match.group(1) ?? '');
    final channel = int.tryParse(match.group(2) ?? '');
    final rssi = int.tryParse(match.group(4) ?? '');
    if (ssid == null || index == null || channel == null || rssi == null) return null;
    return WifiAccessPoint(
      index: index,
      ssid: ssid,
      channel: channel,
      rssi: rssi,
      selected: text.trim().endsWith('(selected)'),
    );
  }

  static bool isScanStarted(String text) => text.toLowerCase().contains('scanning for aps') || text.toLowerCase().contains('starting');

  static bool isScanStopped(String text) => text.toLowerCase().contains('stopping wifi') || text.toLowerCase().contains('scan stopped');

  static SdFileEntry? parseSdFileLine(String text) {
    final match = RegExp(r'^(.+?)\t(\d+)$').firstMatch(text.trimRight());
    if (match == null) return null;
    final path = match.group(1)?.trim();
    final size = int.tryParse(match.group(2) ?? '');
    if (path == null || path.isEmpty || size == null) return null;
    return SdFileEntry(path: path, size: size);
  }

  static WifiSsid? parseSsidLine(String text) {
    final match = RegExp(r'^\[(\d+)\]\s(.+?)(?:\s\(selected\))?$').firstMatch(text.trim());
    if (match == null) return null;
    final index = int.tryParse(match.group(1) ?? '');
    final ssid = match.group(2)?.trim();
    if (index == null || ssid == null || ssid.isEmpty) return null;
    return WifiSsid(index: index, ssid: ssid, selected: text.trim().endsWith('(selected)'));
  }

  static BluetoothDeviceInfo? parseBluetoothLine(String text) {
    final match = RegExp(r'^\[(\d+)\]\[RSSI:(-?\d+)\]\s(.*)$').firstMatch(text.trim());
    if (match == null) return null;
    final index = int.tryParse(match.group(1) ?? '');
    final rssi = int.tryParse(match.group(2) ?? '');
    final name = match.group(3)?.trim();
    if (index == null || rssi == null || name == null) return null;
    return BluetoothDeviceInfo(index: index, name: name, rssi: rssi);
  }

  static FlipperDeviceInfo? parseFlipperLine(String text) {
    final match = RegExp(r'^\[(\d+)\]MAC:\s([^\s]+)\s?(.*)$').firstMatch(text.trim());
    if (match == null) return null;
    final index = int.tryParse(match.group(1) ?? '');
    final mac = match.group(2)?.trim();
    final name = match.group(3)?.trim() ?? '';
    if (index == null || mac == null) return null;
    return FlipperDeviceInfo(index: index, mac: mac, name: name);
  }

  static WifiStation? parseStationLine(String text, {int? apIndex, String? apSsid}) {
    final match = RegExp(r'^\s*\[(\d+)\]\s([0-9A-Fa-f:]{17})(?:\s\(selected\))?$').firstMatch(text);
    if (match == null) return null;
    final index = int.tryParse(match.group(1) ?? '');
    final mac = match.group(2)?.toUpperCase();
    if (index == null || mac == null) return null;
    return WifiStation(
      index: index,
      mac: mac,
      selected: text.trim().endsWith('(selected)'),
      apIndex: apIndex,
      apSsid: apSsid,
    );
  }

  static ({int index, String ssid})? parseStationGroupHeader(String text) {
    final match = RegExp(r'^\[(\d+)\]\s?(.*)\s-?\d+:$').firstMatch(text.trim());
    if (match == null) return null;
    final index = int.tryParse(match.group(1) ?? '');
    final ssid = match.group(2)?.trim();
    if (index == null || ssid == null) return null;
    return (index: index, ssid: ssid);
  }
}

class MarauderCommandCatalog {
  static const readOnly = <String>[
    'help',
    'protocolinfo',
    'channel',
    'settings',
    'list',
    'info',
    'clearlist',
  ];

  static const scan = <String>[
    'scanall',
    'sniffraw',
    'sniffbeacon',
    'sniffprobe',
    'sniffpwn',
    'sniffdeauth',
    'sniffpmkid',
    'pingscan',
    'portscan',
    'arpscan',
    'mactrack',
  ];

  static const dangerous = <String>[
    'attack',
    'evilportal',
    'karma',
    'blespam',
    'spoofat',
  ];

  static DeviceCapabilities inferCapabilities({String? boardName, String? version}) {
    return DeviceCapabilities(
      boardName: boardName ?? 'ESP32 Marauder',
      firmwareVersion: version,
      capabilities: {
        MarauderCapability.wifiScan,
        MarauderCapability.wifiData,
        MarauderCapability.bluetooth,
        MarauderCapability.sdStorage,
      },
      probeState: DeviceProbeState.pending,
    );
  }
}
