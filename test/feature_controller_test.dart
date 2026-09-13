import 'package:flutter_test/flutter_test.dart';
import 'package:marauder_control/src/core/models/radio_models.dart';
import 'package:marauder_control/src/core/models/storage_models.dart';
import 'package:marauder_control/src/core/models/wifi_models.dart';
import 'package:marauder_control/src/core/models/device_models.dart';
import 'package:marauder_control/src/features/bluetooth/bluetooth_controller.dart';
import 'package:marauder_control/src/features/storage/storage_controller.dart';
import 'package:marauder_control/src/features/wifi/wifi_controller.dart';
import 'package:marauder_control/src/core/protocol/marauder_protocol.dart';
import 'package:marauder_control/src/features/dashboard/probe_controller.dart';

void main() {
  test('filters and sorts WiFi access points', () {
    const points = [
      WifiAccessPoint(index: 0, ssid: 'Cafe', channel: 11, rssi: -70),
      WifiAccessPoint(index: 1, ssid: 'Home', channel: 1, rssi: -40),
    ];
    const controller = WifiController();
    expect(controller.filterAndSortAccessPoints(points).first.ssid, 'Home');
    expect(controller.filterAndSortAccessPoints(points, query: 'caf').single.ssid, 'Cafe');
    expect(controller.filterAndSortAccessPoints(points, sort: WifiSort.channel).first.channel, 1);
  });

  test('sorts Bluetooth devices by signal strength', () {
    const devices = [
      BluetoothDeviceInfo(index: 0, name: 'Weak', rssi: -80),
      BluetoothDeviceInfo(index: 1, name: 'Strong', rssi: -30),
    ];
    expect(const BluetoothController().sortByRssi(devices).first.name, 'Strong');
  });

  test('calculates SD size and parent path', () {
    const files = [SdFileEntry(path: '/a', size: 10), SdFileEntry(path: '/b', size: 20)];
    const controller = StorageController();
    expect(controller.totalBytes(files), 30);
    expect(controller.parentPath('/logs/run'), '/logs');
    expect(controller.parentPath('/logs'), '/');
  });

  test('extracts Marauder banner and machine capabilities', () {
    const controller = ProbeController();
    final banner = controller.applyBanner(DeviceCapabilities(), 'ESP32 Marauder v1.16.0');
    expect(banner.firmwareVersion, 'v1.16.0');
    expect(banner.boardName, 'ESP32 Marauder');
    final machine = controller.applyMachine(banner, {
      'firmware': 'v1.16.0',
      'capabilities': ['spiffs-backup'],
    });
    expect(machine.supports(MarauderCapability.gps), isFalse);
  });

  test('parses firmware banner and machine capabilities', () {
    const probe = ProbeController();
    var capabilities = MarauderCommandCatalog.inferCapabilities();
    capabilities = probe.applyBanner(capabilities, 'ESP32 Marauder v1.16.0');
    expect(capabilities.firmwareVersion, 'v1.16.0');
    capabilities = probe.applyMachine(capabilities, {
      'firmware': 'v1.16.0',
      'capabilities': ['gps'],
    });
    expect(capabilities.supports(MarauderCapability.gps), isTrue);
    expect(capabilities.supports(MarauderCapability.directUpload), isFalse);
  });
}
