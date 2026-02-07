class AppSettings {
  final int schemaVersion;
  final double fastPlaySpeed;
  final double slowPlaybackSpeed;
  final double defaultPlaybackSpeed;
  final Duration leadIn;
  final Duration leadOut;

  static const int currentSchemaVersion = 1;
  static const double defaultFastPlaySpeed = 3.0;
  static const double defaultSlowPlaybackSpeed = 0.5;
  static const double defaultDefaultPlaybackSpeed = 1.0;
  static const Duration defaultLeadIn = Duration(seconds: 10);
  static const Duration defaultLeadOut = Duration(seconds: 10);

  const AppSettings({
    this.schemaVersion = currentSchemaVersion,
    this.fastPlaySpeed = defaultFastPlaySpeed,
    this.slowPlaybackSpeed = defaultSlowPlaybackSpeed,
    this.defaultPlaybackSpeed = defaultDefaultPlaybackSpeed,
    this.leadIn = defaultLeadIn,
    this.leadOut = defaultLeadOut,
  });

  factory AppSettings.defaults() {
    return const AppSettings();
  }

  Map<String, dynamic> toMap() {
    return {
      'schemaVersion': schemaVersion,
      'fastPlaySpeed': fastPlaySpeed,
      'slowPlaybackSpeed': slowPlaybackSpeed,
      'defaultPlaybackSpeed': defaultPlaybackSpeed,
      'leadInSeconds': leadIn.inSeconds,
      'leadOutSeconds': leadOut.inSeconds,
    };
  }

  factory AppSettings.fromMap(Map<String, dynamic> map) {
    return AppSettings(
      schemaVersion: map['schemaVersion'] as int? ?? currentSchemaVersion,
      fastPlaySpeed: map['fastPlaySpeed'] as double? ?? defaultFastPlaySpeed,
      slowPlaybackSpeed: map['slowPlaybackSpeed'] as double? ?? defaultSlowPlaybackSpeed,
      defaultPlaybackSpeed: map['defaultPlaybackSpeed'] as double? ?? defaultDefaultPlaybackSpeed,
      leadIn: Duration(seconds: map['leadInSeconds'] as int? ?? defaultLeadIn.inSeconds),
      leadOut: Duration(seconds: map['leadOutSeconds'] as int? ?? defaultLeadOut.inSeconds),
    );
  }

  AppSettings copyWith({
    int? schemaVersion,
    double? fastPlaySpeed,
    double? slowPlaybackSpeed,
    double? defaultPlaybackSpeed,
    Duration? leadIn,
    Duration? leadOut,
  }) {
    return AppSettings(
      schemaVersion: schemaVersion ?? this.schemaVersion,
      fastPlaySpeed: fastPlaySpeed ?? this.fastPlaySpeed,
      slowPlaybackSpeed: slowPlaybackSpeed ?? this.slowPlaybackSpeed,
      defaultPlaybackSpeed: defaultPlaybackSpeed ?? this.defaultPlaybackSpeed,
      leadIn: leadIn ?? this.leadIn,
      leadOut: leadOut ?? this.leadOut,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AppSettings &&
        other.schemaVersion == schemaVersion &&
        other.fastPlaySpeed == fastPlaySpeed &&
        other.slowPlaybackSpeed == slowPlaybackSpeed &&
        other.defaultPlaybackSpeed == defaultPlaybackSpeed &&
        other.leadIn == leadIn &&
        other.leadOut == leadOut;
  }

  @override
  int get hashCode {
    return Object.hash(schemaVersion, fastPlaySpeed, slowPlaybackSpeed, defaultPlaybackSpeed, leadIn, leadOut);
  }
}
