import '../../core/models/wifi_models.dart';

class WifiController {
  const WifiController();

  List<WifiAccessPoint> filterAndSortAccessPoints(
    List<WifiAccessPoint> source, {
    String query = '',
    WifiSort sort = WifiSort.rssi,
  }) {
    final normalized = query.trim().toLowerCase();
    final result = source.where((ap) => normalized.isEmpty || ap.ssid.toLowerCase().contains(normalized)).toList();
    result.sort((a, b) {
      return switch (sort) {
        WifiSort.rssi => b.rssi.compareTo(a.rssi),
        WifiSort.channel => a.channel.compareTo(b.channel),
        WifiSort.name => a.ssid.toLowerCase().compareTo(b.ssid.toLowerCase()),
      };
    });
    return result;
  }
}

enum WifiSort { rssi, channel, name }
