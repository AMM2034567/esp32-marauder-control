import '../../core/models/device_models.dart';
import '../../core/models/transport_models.dart';
import '../../core/session/marauder_session.dart';
import '../../core/protocol/marauder_protocol.dart';

class DeviceController {
  DeviceController({required this.session});

  final MarauderSession session;
  final List<UsbDeviceInfo> devices = <UsbDeviceInfo>[];
  DeviceCapabilities capabilities = MarauderCommandCatalog.inferCapabilities();
  bool probing = false;
  String? probeError;
  DeviceProbeState probeState = DeviceProbeState.pending;
  String? driverName;
  int? vendorId;
  int? productId;

  Future<void> refreshDevices() async {
    devices
      ..clear()
      ..addAll(await session.transport.listDevices());
  }

  Future<bool> connect() async {
    if (devices.isEmpty) await refreshDevices();
    if (devices.isEmpty) return false;
    await session.connect(devices.first.id);
    return true;
  }

  void applyConnectionInfo(Map<String, Object?> info) {
    driverName = info['driver'] as String?;
    vendorId = (info['vendorId'] as num?)?.toInt();
    productId = (info['productId'] as num?)?.toInt();
    probeState = DeviceProbeState.probing;
    capabilities = capabilities.copyWith(
      driverName: driverName,
      vendorId: vendorId,
      productId: productId,
      probeState: probeState,
    );
  }

  Future<void> probe(Future<void> Function(String command) send) async {
    if (probing) return;
    probing = true;
    probeError = null;
    capabilities = capabilities.copyWith(probeState: DeviceProbeState.probing);
    probeState = DeviceProbeState.probing;
    try {
      await send('protocolinfo --machine app_probe');
      await send('help');
      await Future<void>.delayed(const Duration(milliseconds: 1500));
      if (capabilities.firmwareVersion == null) {
        probeError = '未从串口输出中识别固件版本';
        probeState = DeviceProbeState.failed;
        capabilities = capabilities.copyWith(probeState: DeviceProbeState.failed);
      } else {
        capabilities = capabilities.copyWith(probeState: DeviceProbeState.ready);
        probeState = DeviceProbeState.ready;
      }
    } catch (error) {
      probeError = '固件探测失败：$error';
      capabilities = capabilities.copyWith(probeState: DeviceProbeState.failed);
      probeState = DeviceProbeState.failed;
    } finally {
      probing = false;
    }
  }
}
