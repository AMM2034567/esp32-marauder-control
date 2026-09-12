import 'package:flutter_test/flutter_test.dart';
import 'package:marauder_control/src/core/models/radio_models.dart';
import 'package:marauder_control/src/core/models/storage_models.dart';
import 'package:marauder_control/src/core/models/wifi_models.dart';
import 'package:marauder_control/src/features/bluetooth/bluetooth_controller.dart';
import 'package:marauder_control/src/features/storage/storage_controller.dart';
import 'package:marauder_control/src/features/wifi/wifi_controller.dart';

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
}
