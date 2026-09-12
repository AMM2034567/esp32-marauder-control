// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:marauder_control/src/core/protocol/marauder_protocol.dart';
import 'package:marauder_control/src/core/models/device_models.dart';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('builds commands with quoted arguments and CRLF', () {
    expect(MarauderProtocol.command('ssid', ['-n', 'test network']), 'ssid -n "test network"\r\n');
  });

  test('parses text, prompt, and machine events', () {
    final events = <MarauderEvent>[];
    final protocol = MarauderProtocol(onEvent: events.add);

    protocol.addBytes(Uint8List.fromList('hello\r\n>MISSING\n>\n@MARAUDER:{"status":"success"}\n'.codeUnits));

    expect(events.whereType<TextEvent>().map((event) => event.text), contains('hello'));
    expect(events.whereType<PromptEvent>(), hasLength(1));
    expect(events.whereType<MachineEvent>().single.payload['status'], 'success');
  });

  test('blocks dangerous commands in the catalog', () {
    expect(MarauderCommandCatalog.dangerous, contains('attack'));
    expect(MarauderCommandCatalog.dangerous, contains('evilportal'));
  });

  test('extracts firmware version and identifies Marauder banner', () {
    expect(MarauderProtocol.extractFirmwareVersion('ESP32 Marauder v1.16.0'), 'v1.16.0');
    expect(MarauderProtocol.isMarauderBanner('ESP32 Marauder'), isTrue);
  });

  test('keeps LDDB GPS and direct upload disabled until detected', () {
    final capabilities = MarauderCommandCatalog.inferCapabilities();
    expect(capabilities.probeState, DeviceProbeState.pending);
    expect(capabilities.supports(MarauderCapability.wifiScan), isTrue);
    expect(capabilities.supports(MarauderCapability.gps), isFalse);
    expect(capabilities.supports(MarauderCapability.directUpload), isFalse);
  });

  test('parses Marauder list -a access point output', () {
    final ap = MarauderProtocol.parseAccessPointLine('[3][CH:11] Cafe WiFi -67 (selected)');
    expect(ap, isNotNull);
    expect(ap!.index, 3);
    expect(ap.channel, 11);
    expect(ap.ssid, 'Cafe WiFi');
    expect(ap.rssi, -67);
    expect(ap.selected, isTrue);
  });

  test('recognizes scan lifecycle messages', () {
    expect(MarauderProtocol.isScanStarted('Scanning for APs and Stations. Stop with stopscan'), isTrue);
    expect(MarauderProtocol.isScanStopped('Stopping WiFi tran/recv'), isTrue);
  });

  test('parses SD listDir output', () {
    final file = MarauderProtocol.parseSdFileLine('/logs/scan.pcap\t2048');
    expect(file, isNotNull);
    expect(file!.path, '/logs/scan.pcap');
    expect(file.size, 2048);
  });

  test('parses station, SSID, Bluetooth and Flipper list output', () {
    final station = MarauderProtocol.parseStationLine('  [2] AA:BB:CC:DD:EE:FF (selected)');
    final ssid = MarauderProtocol.parseSsidLine('[1] Home WiFi (selected)');
    final bluetooth = MarauderProtocol.parseBluetoothLine('[4][RSSI:-72] Sensor');
    final flipper = MarauderProtocol.parseFlipperLine('[0]MAC: 11:22:33:44:55:66 Flipper');
    expect(station?.mac, 'AA:BB:CC:DD:EE:FF');
    expect(station?.selected, isTrue);
    expect(ssid?.ssid, 'Home WiFi');
    expect(bluetooth?.rssi, -72);
    expect(flipper?.mac, '11:22:33:44:55:66');
  });

  test('parses station group header', () {
    final header = MarauderProtocol.parseStationGroupHeader('[3]Cafe WiFi -67:');
    expect(header?.index, 3);
    expect(header?.ssid, 'Cafe WiFi');
  });

  test('Bluetooth dangerous commands remain outside the read-only catalog', () {
    expect(MarauderCommandCatalog.dangerous, contains('blespam'));
    expect(MarauderCommandCatalog.dangerous, contains('spoofat'));
    expect(MarauderCommandCatalog.readOnly, isNot(contains('blespam')));
    expect(MarauderCommandCatalog.readOnly, isNot(contains('spoofat')));
  });
}
