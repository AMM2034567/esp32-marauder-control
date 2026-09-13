import '../core/models/radio_models.dart';
import '../core/models/storage_models.dart';
import '../core/models/wifi_models.dart';

class RadioDataController {
  final List<WifiAccessPoint> accessPoints = <WifiAccessPoint>[];
  final List<WifiStation> stations = <WifiStation>[];
  final List<WifiSsid> ssids = <WifiSsid>[];
  final List<BluetoothDeviceInfo> bluetoothDevices = <BluetoothDeviceInfo>[];
  final List<FlipperDeviceInfo> flipperDevices = <FlipperDeviceInfo>[];
  final List<String> apDetails = <String>[];
  int? detailApIndex;
  int? stationApIndex;
  String? stationApSsid;

  void clearWifiLists() {
    stations.clear();
    ssids.clear();
  }

  void upsertStation(WifiStation value) {
    final index = stations.indexWhere((item) => item.index == value.index);
    if (index >= 0) {
      stations[index] = value;
    } else {
      stations.add(value);
    }
  }

  void upsertSsid(WifiSsid value) {
    final index = ssids.indexWhere((item) => item.index == value.index);
    if (index >= 0) {
      ssids[index] = value;
    } else {
      ssids.add(value);
    }
  }

  void upsertBluetooth(BluetoothDeviceInfo value) {
    final index = bluetoothDevices.indexWhere((item) => item.index == value.index);
    if (index >= 0) {
      bluetoothDevices[index] = value;
    } else {
      bluetoothDevices.add(value);
    }
  }

  void upsertFlipper(FlipperDeviceInfo value) {
    final index = flipperDevices.indexWhere((item) => item.index == value.index);
    if (index >= 0) {
      flipperDevices[index] = value;
    } else {
      flipperDevices.add(value);
    }
  }

  void upsertAccessPoint(WifiAccessPoint value) {
    final index = accessPoints.indexWhere((item) => item.index == value.index);
    if (index >= 0) {
      accessPoints[index] = value;
    } else {
      accessPoints.add(value);
    }
  }
}

class StorageDataController {
  final List<SdFileEntry> files = <SdFileEntry>[];
  String path = '/';

  void clear() => files.clear();

  void upsert(SdFileEntry value) {
    final index = files.indexWhere((item) => item.path == value.path);
    if (index >= 0) {
      files[index] = value;
    } else {
      files.add(value);
    }
  }
}
