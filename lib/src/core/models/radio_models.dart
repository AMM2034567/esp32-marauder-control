class WifiStation {
  const WifiStation({required this.index, required this.mac, this.selected = false, this.apIndex, this.apSsid});

  final int index;
  final String mac;
  final bool selected;
  final int? apIndex;
  final String? apSsid;
}

class WifiSsid {
  const WifiSsid({required this.index, required this.ssid, this.selected = false});

  final int index;
  final String ssid;
  final bool selected;
}

class BluetoothDeviceInfo {
  const BluetoothDeviceInfo({required this.index, required this.name, required this.rssi});

  final int index;
  final String name;
  final int rssi;
}

class FlipperDeviceInfo {
  const FlipperDeviceInfo({required this.index, required this.mac, required this.name});

  final int index;
  final String mac;
  final String name;
}
