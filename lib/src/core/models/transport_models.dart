import 'dart:typed_data';

class UsbDeviceInfo {
  const UsbDeviceInfo({
    required this.id,
    required this.name,
    required this.vendorId,
    required this.productId,
    this.manufacturer,
    this.product,
    this.serialNumber,
  });

  final String id;
  final String name;
  final int vendorId;
  final int productId;
  final String? manufacturer;
  final String? product;
  final String? serialNumber;

  factory UsbDeviceInfo.fromMap(Map<Object?, Object?> map) {
    return UsbDeviceInfo(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? 'USB serial device',
      vendorId: (map['vendorId'] as num?)?.toInt() ?? 0,
      productId: (map['productId'] as num?)?.toInt() ?? 0,
      manufacturer: map['manufacturer'] as String?,
      product: map['product'] as String?,
      serialNumber: map['serialNumber'] as String?,
    );
  }
}

enum SerialConnectionState { disconnected, connecting, connected, error }

class TransportEvent {
  const TransportEvent.connected([this.info])
      : type = 'connected',
        data = null,
        message = null;
  const TransportEvent.disconnected([this.message])
      : type = 'disconnected',
        data = null,
        info = null;
  const TransportEvent.data(this.data)
      : type = 'data',
        message = null,
        info = null;
  const TransportEvent.error(this.message)
      : type = 'error',
        data = null,
        info = null;
  const TransportEvent.connectionInfo(this.info)
      : type = 'connectionInfo',
        data = null,
        message = null;

  final String type;
  final Uint8List? data;
  final String? message;
  final Map<String, Object?>? info;
}
