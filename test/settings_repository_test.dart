import 'package:flow_lens/models/app_settings.dart';
import 'package:flow_lens/services/settings_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('fresh settings default to 7x and hold on touch', () async {
    SharedPreferences.setMockInitialValues({});
    final settings = await SharedPreferencesSettingsRepository().load();
    expect(settings.fastPlaySpeed, 7);
    expect(settings.stickyFastPlayOnTouch, isFalse);
  });

  test('older settings retain speed and default to hold on touch', () async {
    SharedPreferences.setMockInitialValues({
      'settings_schemaVersion': 1,
      'settings_fastPlaySpeed': 4.0,
    });
    final settings = await SharedPreferencesSettingsRepository().load();
    expect(settings.fastPlaySpeed, 4);
    expect(settings.stickyFastPlayOnTouch, isFalse);
  });

  test('sticky preference survives reload and resetting defaults', () async {
    SharedPreferences.setMockInitialValues({});
    await SharedPreferencesSettingsRepository().save(
      const AppSettings(stickyFastPlayOnTouch: true),
    );
    expect(
      (await SharedPreferencesSettingsRepository().load())
          .stickyFastPlayOnTouch,
      isTrue,
    );
    await SharedPreferencesSettingsRepository().save(AppSettings.defaults());
    final settings = await SharedPreferencesSettingsRepository().load();
    expect(settings.stickyFastPlayOnTouch, isFalse);
    expect(settings.fastPlaySpeed, 7);
  });
}
