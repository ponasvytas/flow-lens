import 'package:flow_lens/app/app_capabilities.dart';
import 'package:flow_lens/app/app_composition.dart';
import 'package:flow_lens/services/event_import_export_service.dart';
import 'package:flow_lens/services/auth_repository.dart';
import 'package:flow_lens/services/settings_repository.dart';
import 'package:flow_lens/services/taxonomy_repository.dart';
import 'package:flow_lens/services/tracking_import_export_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('anonymous capabilities keep all cloud writes disabled', () {
    const capabilities = AppCapabilities.anonymousFree;

    expect(capabilities.canUseBundledTaxonomies, isTrue);
    expect(capabilities.canPersistLocalSettings, isTrue);
    expect(capabilities.canImportExportFiles, isTrue);
    expect(capabilities.canSyncSettings, isFalse);
    expect(capabilities.canSaveCloudSessions, isFalse);
    expect(capabilities.canEditCustomTaxonomy, isFalse);
    expect(capabilities.canCreateReviewLinks, isFalse);
    expect(capabilities.canUploadVideo, isFalse);
    expect(capabilities.canRunServerExport, isFalse);
  });

  test('premium launch excludes deferred high-cost capabilities', () {
    const capabilities = AppCapabilities.premiumLaunch;

    expect(capabilities.canSyncSettings, isTrue);
    expect(capabilities.canSaveCloudSessions, isTrue);
    expect(capabilities.canEditCustomTaxonomy, isTrue);
    expect(capabilities.canCreateReviewLinks, isTrue);
    expect(capabilities.canUploadVideo, isFalse);
    expect(capabilities.canRunServerExport, isFalse);
  });

  test('local composition selects existing local implementations', () {
    final composition = AppComposition.local();

    expect(composition.authRepository, isA<AnonymousAuthRepository>());
    expect(
      composition.settingsRepository,
      isA<SharedPreferencesSettingsRepository>(),
    );
    expect(composition.taxonomyRepository, isA<BundledTaxonomyRepository>());
    expect(
      composition.eventImportExportService,
      isA<EventImportExportService>(),
    );
    expect(
      composition.trackingImportExportService,
      isA<TrackingImportExportService>(),
    );

    final runtime = composition.createRuntime();
    expect(runtime.capabilities, same(AppCapabilities.anonymousFree));
    expect(runtime.taxonomyRepository, same(composition.taxonomyRepository));
    runtime.dispose();
  });
}
