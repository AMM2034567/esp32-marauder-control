import 'dart:typed_data';

import '../models/transport_models.dart';

abstract interface class SerialTransport {
  Stream<TransportEvent> get events;
  Future<List<UsbDeviceInfo>> listDevices();
  Future<void> connect(String deviceId, {int baudRate = 115200});
  Future<void> disconnect();
  Future<void> write(Uint8List bytes);
}

class MockSerialTransport implements SerialTransport {
  final Stream<TransportEvent> _events = const Stream<TransportEvent>.empty();

  @override
  Stream<TransportEvent> get events => _events;

  @override
  Future<List<UsbDeviceInfo>> listDevices() async => const [
        UsbDeviceInfo(
          id: 'mock-esp32-lddb',
          name: '模拟 ESP32 LDDB',
          vendorId: 0x1A86,
          productId: 0x7523,
          manufacturer: 'Mock USB serial',
        ),
      ];

  @override
  Future<void> connect(String deviceId, {int baudRate = 115200}) async {}

  @override
  Future<void> disconnect() async {}

  @override
  Future<void> write(Uint8List bytes) async {}
}
