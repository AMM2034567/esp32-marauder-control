import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:marauder_control/src/core/models/transport_models.dart';
import 'package:marauder_control/src/core/session/marauder_session.dart';
import 'package:marauder_control/src/core/transport/serial_transport.dart';

class _FakeTransport implements SerialTransport {
  final StreamController<TransportEvent> controller = StreamController.broadcast();
  final List<Uint8List> writes = <Uint8List>[];

  @override
  Stream<TransportEvent> get events => controller.stream;

  @override
  Future<void> connect(String deviceId, {int baudRate = 115200}) async {
    controller.add(const TransportEvent.connected());
  }

  @override
  Future<void> disconnect() async {
    controller.add(const TransportEvent.disconnected());
  }

  @override
  Future<List<UsbDeviceInfo>> listDevices() async => const [];

  @override
  Future<void> write(Uint8List bytes) async {
    writes.add(bytes);
  }

  Future<void> close() => controller.close();
}

void main() {
  late _FakeTransport transport;
  late MarauderSession session;

  setUp(() async {
    transport = _FakeTransport();
    session = MarauderSession(transport);
    await session.connect('mock');
    await Future<void>.delayed(Duration.zero);
  });

  tearDown(() async {
    await session.dispose();
    await transport.close();
  });

  test('serializes commands and writes CRLF', () async {
    final first = session.send('help');
    final second = session.send('channel');

    await Future<void>.delayed(Duration.zero);
    expect(transport.writes, hasLength(1));
    expect(String.fromCharCodes(transport.writes.single), 'help\r\n');

    transport.controller.add(TransportEvent.data(Uint8List.fromList([62, 10])));
    await first;
    await Future<void>.delayed(Duration.zero);
    expect(transport.writes, hasLength(2));
    expect(String.fromCharCodes(transport.writes[1]), 'channel\r\n');
    transport.controller.add(TransportEvent.data(Uint8List.fromList([62, 10])));
    await second;
  });

  test('allows stopscan while a streaming scan is active', () async {
    final scan = session.send('scanall', operation: 'wifiScan');
    await Future<void>.delayed(Duration.zero);
    expect(session.locked, isTrue);

    final stop = session.send('stopscan', waitForPrompt: false);
    await stop;
    expect(String.fromCharCodes(transport.writes.last), 'stopscan\r\n');
    expect(session.locked, isFalse);
    expect(scan, completes);
  });

  test('blocks dangerous commands before writing', () async {
    final events = <MarauderSessionEvent>[];
    final subscription = session.events.listen(events.add);
    await session.send('blespam -t all');
    expect(transport.writes, isEmpty);
    expect(events.any((event) => event.isError), isTrue);
    await subscription.cancel();
  });

  test('clears pending commands on disconnect', () async {
    final command = session.send('help');
    transport.controller.add(const TransportEvent.disconnected());
    await command;
    expect(session.state, MarauderSessionState.disconnected);
    expect(session.locked, isFalse);
  });
}
