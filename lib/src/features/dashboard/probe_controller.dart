import '../../core/models/device_models.dart';

class ProbeController {
  const ProbeController();

  DeviceCapabilities applyBanner(DeviceCapabilities current, String text) {
    final version = RegExp(r'\bv?([0-9]+\.[0-9]+(?:\.[0-9]+)?)\b').firstMatch(text)?.group(1);
    final isMarauder = text.toLowerCase().contains('marauder');
    return current.copyWith(
      boardName: isMarauder ? 'ESP32 Marauder' : null,
      firmwareVersion: version == null ? null : 'v$version',
    );
  }

  DeviceCapabilities applyMachine(DeviceCapabilities current, Map<String, dynamic> payload) {
    final firmware = (payload['firmware'] ?? payload['version']) as String?;
    final board = payload['board'] as String?;
    final supported = (payload['capabilities'] as List<dynamic>?)?.cast<String>();
    if (firmware == null && board == null && supported == null) return current;
    final capabilities = {...current.capabilities};
    if (supported != null) {
      if (supported.contains('gps')) {
        capabilities.add(MarauderCapability.gps);
      } else {
        capabilities.remove(MarauderCapability.gps);
      }
      if (supported.contains('direct-upload')) {
        capabilities.add(MarauderCapability.directUpload);
      } else {
        capabilities.remove(MarauderCapability.directUpload);
      }
    }
    return current.copyWith(
      firmwareVersion: firmware,
      boardName: board,
      capabilities: capabilities,
    );
  }
}
