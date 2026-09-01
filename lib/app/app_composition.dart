import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../controllers/account_controller.dart';
import '../controllers/events_controller.dart';
import '../controllers/settings_controller.dart';
import '../controllers/tracking_controller.dart';
import '../controllers/ui_controller.dart';
import '../services/auth_repository.dart';
import '../services/cloud_settings_store.dart';
import '../services/dock_layout_repository.dart';
import '../services/entitlements_repository.dart';
import '../services/event_import_export_service.dart';
import '../services/event_session_repository.dart';
import '../services/firebase_auth_repository.dart';
import '../services/firestore_entitlements_repository.dart';
import '../services/hybrid_settings_repository.dart';
import '../services/settings_repository.dart';
import '../services/taxonomy_repository.dart';
import '../services/tracking_import_export_service.dart';
import '../services/tracking_session_repository.dart';
import 'app_capabilities.dart';

/// Selects the implementations used by the application.
///
/// The local factory preserves the original anonymous behavior. Later phases
/// can add authenticated compositions without spreading environment checks
/// through widgets and controllers.
class AppComposition {
  AppComposition({
    required this.authRepository,
    required this.entitlementsRepository,
    required this.settingsRepository,
    this.cloudSettingsStore,
    required this.dockLayoutRepository,
    required this.taxonomyRepository,
    required this.eventImportExportService,
    required this.trackingImportExportService,
    this.firestore,
  });

  factory AppComposition.local() => AppComposition(
    authRepository: AnonymousAuthRepository(),
    entitlementsRepository: FreeEntitlementsRepository(),
    settingsRepository: SharedPreferencesSettingsRepository(),
    dockLayoutRepository: SharedPreferencesDockLayoutRepository(),
    taxonomyRepository: BundledTaxonomyRepository(),
    eventImportExportService: EventImportExportService(),
    trackingImportExportService: TrackingImportExportService(),
  );

  factory AppComposition.firebase({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  }) {
    final database = firestore ?? FirebaseFirestore.instance;
    return AppComposition(
      authRepository: FirebaseAuthRepository(auth ?? FirebaseAuth.instance),
      entitlementsRepository: FirestoreEntitlementsRepository(database),
      settingsRepository: SharedPreferencesSettingsRepository(),
      cloudSettingsStore: FirestoreCloudSettingsStore(database),
      dockLayoutRepository: SharedPreferencesDockLayoutRepository(),
      taxonomyRepository: BundledTaxonomyRepository(),
      eventImportExportService: EventImportExportService(),
      trackingImportExportService: TrackingImportExportService(),
      firestore: database,
    );
  }

  final AuthRepository authRepository;
  final EntitlementsRepository entitlementsRepository;
  final SettingsRepository settingsRepository;
  final CloudSettingsStore? cloudSettingsStore;
  final DockLayoutRepository dockLayoutRepository;
  final TaxonomyRepository taxonomyRepository;
  final EventImportExportService eventImportExportService;
  final TrackingImportExportService trackingImportExportService;
  final FirebaseFirestore? firestore;

  AppRuntime createRuntime() {
    final accountController = AccountController(
      authRepository,
      entitlementsRepository,
    );
    final cloudStore = cloudSettingsStore;
    final effectiveSettingsRepository = cloudStore == null
        ? settingsRepository
        : HybridSettingsRepository(
            localRepository: settingsRepository,
            cloudStore: cloudStore,
            userId: () => accountController.user?.id,
            canSync: () => accountController.capabilities.canSyncSettings,
          );
    final database = firestore;
    final eventSessionRepository = database == null
        ? null
        : FirestoreEventSessionRepository(
            firestore: database,
            userId: () => accountController.user?.id,
            canSave: () => accountController.capabilities.canSaveCloudSessions,
          );
    final trackingSessionRepository = database == null
        ? null
        : FirestoreTrackingSessionRepository(
            firestore: database,
            userId: () => accountController.user?.id,
            canSave: () => accountController.capabilities.canSaveCloudSessions,
          );

    return AppRuntime(
      accountController: accountController,
      eventsController: EventsController(),
      settingsController: SettingsController(
        effectiveSettingsRepository,
        accountController: accountController,
      ),
      uiController: UIController(dockLayoutRepository),
      trackingController: TrackingController(),
      taxonomyRepository: taxonomyRepository,
      eventImportExportService: eventImportExportService,
      trackingImportExportService: trackingImportExportService,
      eventSessionRepository: eventSessionRepository,
      trackingSessionRepository: trackingSessionRepository,
    );
  }
}

/// App-scoped objects owned by the root screen.
class AppRuntime {
  AppRuntime({
    required this.accountController,
    required this.eventsController,
    required this.settingsController,
    required this.uiController,
    required this.trackingController,
    required this.taxonomyRepository,
    required this.eventImportExportService,
    required this.trackingImportExportService,
    required this.eventSessionRepository,
    required this.trackingSessionRepository,
  });

  final AccountController accountController;
  final EventsController eventsController;
  final SettingsController settingsController;
  final UIController uiController;
  final TrackingController trackingController;
  final TaxonomyRepository taxonomyRepository;
  final EventImportExportService eventImportExportService;
  final TrackingImportExportService trackingImportExportService;
  final EventSessionRepository? eventSessionRepository;
  final TrackingSessionRepository? trackingSessionRepository;

  AppCapabilities get capabilities => accountController.capabilities;

  void dispose() {
    accountController.dispose();
    eventsController.dispose();
    settingsController.dispose();
    trackingController.dispose();
    uiController.dispose();
  }
}
