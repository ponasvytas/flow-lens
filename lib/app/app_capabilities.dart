/// Product capabilities available to the current app session.
///
/// UI and repository selection should depend on these values instead of on
/// the operating system. Authentication and entitlement state will produce
/// this value when premium account support is added.
class AppCapabilities {
  const AppCapabilities({
    required this.canUseBundledTaxonomies,
    required this.canPersistLocalSettings,
    required this.canImportExportFiles,
    required this.canSyncSettings,
    required this.canSaveCloudSessions,
    required this.canEditCustomTaxonomy,
    required this.canCreateReviewLinks,
    required this.canUploadVideo,
    required this.canRunServerExport,
  });

  static const anonymousFree = AppCapabilities(
    canUseBundledTaxonomies: true,
    canPersistLocalSettings: true,
    canImportExportFiles: true,
    canSyncSettings: false,
    canSaveCloudSessions: false,
    canEditCustomTaxonomy: false,
    canCreateReviewLinks: false,
    canUploadVideo: false,
    canRunServerExport: false,
  );

  static const premiumLaunch = AppCapabilities(
    canUseBundledTaxonomies: true,
    canPersistLocalSettings: true,
    canImportExportFiles: true,
    canSyncSettings: true,
    canSaveCloudSessions: true,
    canEditCustomTaxonomy: true,
    canCreateReviewLinks: true,
    canUploadVideo: false,
    canRunServerExport: false,
  );

  final bool canUseBundledTaxonomies;
  final bool canPersistLocalSettings;
  final bool canImportExportFiles;
  final bool canSyncSettings;
  final bool canSaveCloudSessions;
  final bool canEditCustomTaxonomy;
  final bool canCreateReviewLinks;
  final bool canUploadVideo;
  final bool canRunServerExport;
}
