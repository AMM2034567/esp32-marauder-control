enum MarauderCapability {
  wifiScan,
  wifiData,
  bluetooth,
  sdStorage,
  gps,
  directUpload,
}

class DeviceCapabilities {
  const DeviceCapabilities({
    this.boardName = '未知设备',
    this.firmwareVersion,
    this.capabilities = const {},
    this.driverName,
    this.vendorId,
    this.productId,
    this.probeState = DeviceProbeState.pending,
  });

  final String boardName;
  final String? firmwareVersion;
  final Set<MarauderCapability> capabilities;
  final String? driverName;
  final int? vendorId;
  final int? productId;
  final DeviceProbeState probeState;

  bool supports(MarauderCapability capability) => capabilities.contains(capability);

  DeviceCapabilities copyWith({
    String? boardName,
    String? firmwareVersion,
    Set<MarauderCapability>? capabilities,
    String? driverName,
    int? vendorId,
    int? productId,
    DeviceProbeState? probeState,
  }) {
    return DeviceCapabilities(
      boardName: boardName ?? this.boardName,
      firmwareVersion: firmwareVersion ?? this.firmwareVersion,
      capabilities: capabilities ?? this.capabilities,
      driverName: driverName ?? this.driverName,
      vendorId: vendorId ?? this.vendorId,
      productId: productId ?? this.productId,
      probeState: probeState ?? this.probeState,
    );
  }
}

enum DeviceProbeState { pending, probing, ready, failed }

class MarauderLogEntry {
  MarauderLogEntry({required this.text, required this.timestamp, this.isError = false});

  final String text;
  final DateTime timestamp;
  final bool isError;
}
