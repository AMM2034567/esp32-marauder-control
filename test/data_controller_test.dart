import 'package:flutter_test/flutter_test.dart';
import 'package:marauder_control/src/features/terminal/terminal_controller.dart';
import 'package:marauder_control/src/features/radio_data_controller.dart';
import 'package:marauder_control/src/core/models/radio_models.dart';

void main() {
  test('terminal controller tracks command history', () {
    final controller = TerminalController();
    controller.recordCommand('help');
    controller.recordCommand('help');
    controller.recordCommand('list -a');
    expect(controller.previous(), 'list -a');
    expect(controller.previous(), 'help');
    expect(controller.next(), 'list -a');
  });

  test('radio data controller upserts by index', () {
    final controller = RadioDataController();
    controller.upsertSsid(const WifiSsid(index: 1, ssid: 'old'));
    controller.upsertSsid(const WifiSsid(index: 1, ssid: 'new'));
    expect(controller.ssids, hasLength(1));
    expect(controller.ssids.single.ssid, 'new');
  });
}
