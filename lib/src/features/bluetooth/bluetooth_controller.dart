import '../../core/models/radio_models.dart';

class BluetoothController {
  const BluetoothController();

  List<BluetoothDeviceInfo> sortByRssi(List<BluetoothDeviceInfo> devices) {
    final result = List<BluetoothDeviceInfo>.of(devices);
    result.sort((a, b) => b.rssi.compareTo(a.rssi));
    return result;
  }
}
