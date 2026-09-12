enum WifiScanState { idle, running, stopping, stopped, error }

class WifiAccessPoint {
  const WifiAccessPoint({
    required this.index,
    required this.ssid,
    required this.channel,
    required this.rssi,
    this.selected = false,
    this.bssid,
  });

  final int index;
  final String ssid;
  final int channel;
  final int rssi;
  final bool selected;
  final String? bssid;

  WifiAccessPoint copyWith({
    String? ssid,
    int? channel,
    int? rssi,
    bool? selected,
    String? bssid,
  }) {
    return WifiAccessPoint(
      index: index,
      ssid: ssid ?? this.ssid,
      channel: channel ?? this.channel,
      rssi: rssi ?? this.rssi,
      selected: selected ?? this.selected,
      bssid: bssid ?? this.bssid,
    );
  }
}
