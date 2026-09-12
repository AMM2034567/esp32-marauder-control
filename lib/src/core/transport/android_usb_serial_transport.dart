import 'dart:async';

import 'package:flutter/services.dart';

import '../models/transport_models.dart';
import 'serial_transport.dart';

class AndroidUsbSerialTransport implements SerialTransport {
  AndroidUsbSerialTransport({MethodChannel? methodChannel, EventChannel? eventChannel})
      : _methods = methodChannel ?? const MethodChannel('marauder/usb_serial'),
        _eventChannel = eventChannel ?? const EventChannel('marauder/usb_serial_events') {
    _subscription = _eventChannel.receiveBroadcastStream().listen(_onNativeEvent);
  }

  final MethodChannel _methods;
  final EventChannel _eventChannel;
  final StreamController<TransportEvent> _events = StreamController.broadcast();
  StreamSubscription<dynamic>? _subscription;

  @override
  Stream<TransportEvent> get events => _events.stream;

  @override
  Future<List<UsbDeviceInfo>> listDevices() async {
    final result = await _methods.invokeMethod<List<dynamic>>('listDevices') ?? const [];
    return result
        .whereType<Map<dynamic, dynamic>>()
        .map((item) => UsbDeviceInfo.fromMap(item))
        .toList();
  }

  @override
  Future<void> connect(String deviceId, {int baudRate = 115200}) async {
    await _methods.invokeMethod<void>('connect', {'deviceId': deviceId, 'baudRate': baudRate});
  }

  @override
  Future<void> disconnect() => _methods.invokeMethod<void>('disconnect');

  @override
  Future<void> write(Uint8List bytes) => _methods.invokeMethod<void>('write', bytes);

  void _onNativeEvent(dynamic event) {
    if (event is Uint8List) {
      _events.add(TransportEvent.data(event));
      return;
    }
    if (event is List) {
      _events.add(TransportEvent.data(Uint8List.fromList(event.cast<int>())));
      return;
    }
    if (event is Map) {
      switch (event['type']) {
        case 'connected':
          _events.add(TransportEvent.connected(Map<String, Object?>.from(event.cast<String, Object?>())));
        case 'disconnected':
          _events.add(TransportEvent.disconnected(event['message'] as String?));
        case 'error':
          _events.add(TransportEvent.error(event['message'] as String? ?? 'USB 串口错误'));
      }
    }
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    await _events.close();
  }
}
