import 'package:flutter/material.dart';
import 'game_event.dart';
import 'tracking_models.dart';

class SportTaxonomy {
  final int schemaVersion;
  final String revision;
  final int contentVersion;
  final List<TaxonomyContextField> contextFields;
  final List<TrackingDefinition> trackingPresets;
  final List<TaxonomyQuickPreset> quickPresets;
  final String sportId;
  final String name;
  final List<CategoryTaxonomy> categories;
  final Map<String, CategoryTaxonomy> _categoriesById;
  final Map<String, EventTypeTaxonomy> _eventTypesById;

  SportTaxonomy({
    required this.schemaVersion,
    this.revision = 'legacy-v1',
    this.contentVersion = 1,
    List<TaxonomyContextField> contextFields = const [],
    List<TrackingDefinition> trackingPresets = const [],
    List<TaxonomyQuickPreset> quickPresets = const [],
    required this.sportId,
    required this.name,
    required List<CategoryTaxonomy> categories,
  }) : contextFields = List.unmodifiable(contextFields),
       trackingPresets = List.unmodifiable(trackingPresets),
       quickPresets = List.unmodifiable(quickPresets),
       categories = List<CategoryTaxonomy>.unmodifiable(categories),
       _categoriesById = Map<String, CategoryTaxonomy>.unmodifiable(
         <String, CategoryTaxonomy>{
           for (final category in categories) category.categoryId: category,
         },
       ),
       _eventTypesById = Map<String, EventTypeTaxonomy>.unmodifiable(
         <String, EventTypeTaxonomy>{
           for (final category in categories)
             for (final eventType in category.eventTypes)
               eventType.eventTypeId: eventType,
         },
       );

  factory SportTaxonomy.fromJson(Map<String, dynamic> json) {
    return SportTaxonomy(
      schemaVersion: json['schemaVersion'] as int,
      revision: json['revision'] as String? ?? 'legacy-v1',
      contentVersion: json['contentVersion'] as int? ?? 1,
      contextFields: (json['contextFields'] as List? ?? [])
          .map(
            (e) => TaxonomyContextField.fromJson(Map<String, dynamic>.from(e)),
          )
          .toList(),
      trackingPresets: (json['trackingPresets'] as List? ?? [])
          .map((e) => TrackingDefinition.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      quickPresets: (json['quickPresets'] as List? ?? [])
          .map(
            (e) => TaxonomyQuickPreset.fromJson(Map<String, dynamic>.from(e)),
          )
          .toList(),
      sportId: json['sportId'] as String,
      name: json['name'] as String,
      categories: (json['categories'] as List<dynamic>)
          .map((c) => CategoryTaxonomy.fromJson(c as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'schemaVersion': schemaVersion,
      'revision': revision,
      'contentVersion': contentVersion,
      'contextFields': contextFields.map((e) => e.toJson()).toList(),
      'trackingPresets': trackingPresets.map((e) => e.toJson()).toList(),
      'quickPresets': quickPresets.map((e) => e.toJson()).toList(),
      'sportId': sportId,
      'name': name,
      'categories': categories.map((c) => c.toJson()).toList(),
    };
  }

  CategoryTaxonomy? getCategoryById(String categoryId) {
    return _categoriesById[categoryId];
  }

  EventTypeTaxonomy? getEventTypeById(String eventTypeId) {
    return _eventTypesById[eventTypeId];
  }

  List<CategoryTaxonomy> get captureCategories => categories
      .where((c) => c.captureEventTypes.isNotEmpty)
      .toList(growable: false);

  List<TaxonomyContextField> fieldsFor(String categoryId) {
    final ids =
        getCategoryById(categoryId)?.contextFieldIds ?? const <String>[];
    return contextFields
        .where((f) => f.common || ids.contains(f.id))
        .toList(growable: false);
  }

  CategoryTaxonomy? categoryForType(String id) =>
      categories.where((c) => c.getEventTypeById(id) != null).firstOrNull;

  void validate() {
    final categoryIds = <String>{};
    final eventTypeIds = <String>{};

    for (final category in categories) {
      if (categoryIds.contains(category.categoryId)) {
        throw Exception(
          'Duplicate categoryId: ${category.categoryId} in sport: $sportId',
        );
      }
      categoryIds.add(category.categoryId);

      for (final eventType in category.eventTypes) {
        if (eventTypeIds.contains(eventType.eventTypeId)) {
          throw Exception(
            'Duplicate eventTypeId: ${eventType.eventTypeId} in sport: $sportId',
          );
        }
        eventTypeIds.add(eventType.eventTypeId);
      }
    }
    final fieldIds = contextFields.map((f) => f.id).toSet();
    if (fieldIds.length != contextFields.length) {
      throw FormatException('Duplicate context field ID');
    }
    for (final category in categories) {
      if (!fieldIds.containsAll(category.contextFieldIds)) {
        throw FormatException(
          'Unknown context field in ${category.categoryId}',
        );
      }
      for (final type in category.eventTypes) {
        if (schemaVersion >= 2 && type.definition.isEmpty) {
          throw FormatException('Missing definition: ${type.eventTypeId}');
        }
        for (final entry in type.contextDefaults.entries) {
          final field = contextFields
              .where((f) => f.id == entry.key)
              .firstOrNull;
          if (field == null ||
              (field.options.isNotEmpty &&
                  !field.options.contains(entry.value))) {
            throw FormatException(
              'Invalid context default: ${type.eventTypeId}',
            );
          }
        }
      }
    }
    for (final preset in quickPresets) {
      for (final id in preset.eventTypeIds) {
        if (getEventTypeById(id) == null || getEventTypeById(id)!.archived) {
          throw FormatException('Invalid quick preset type: $id');
        }
      }
    }
    if (trackingPresets.map((t) => t.id).toSet().length !=
        trackingPresets.length) {
      throw FormatException('Duplicate tracking preset ID');
    }
    for (final tracker in trackingPresets) {
      if (tracker.categoryId != null &&
          getCategoryById(tracker.categoryId!) == null) {
        throw FormatException('Unknown tracker category: ${tracker.id}');
      }
      if (tracker.eventTypeId != null &&
          getCategoryById(
                tracker.categoryId ?? '',
              )?.getEventTypeById(tracker.eventTypeId!) ==
              null) {
        throw FormatException('Unknown tracker event: ${tracker.id}');
      }
    }
  }
}

class CategoryTaxonomy {
  final String categoryId;
  final String name;
  final String iconKey;
  final String colorKey;
  final String description;
  final List<String> contextFieldIds;
  final List<EventTypeTaxonomy> eventTypes;
  final Map<String, EventTypeTaxonomy> _eventTypesById;

  // Static map of available icons - add any Material Icons here
  static const Map<String, IconData> _iconMap = {
    'sports_hockey': Icons.sports_hockey,
    'compare_arrows': Icons.compare_arrows,
    'logout': Icons.logout,
    'login': Icons.login,
    'touch_app': Icons.touch_app,
    'pause_circle_outline': Icons.pause_circle_outline,
    'sports': Icons.sports,
    'sync_alt': Icons.sync_alt,
    'close': Icons.close,
    'shield': Icons.shield,
    'groups': Icons.groups,
    'gavel': Icons.gavel,
    'security': Icons.security,
    'sports_baseball': Icons.sports_baseball,
    'sports_soccer': Icons.sports_soccer,
    'sports_basketball': Icons.sports_basketball,
    'sports_football': Icons.sports_football,
    'sports_tennis': Icons.sports_tennis,
    'block': Icons.block,
    'person': Icons.person,
    'flag': Icons.flag,
    'timer': Icons.timer,
    'warning': Icons.warning,
    'check_circle': Icons.check_circle,
    'cancel': Icons.cancel,
    'verified_user': Icons.verified_user,
    'admin_panel_settings': Icons.admin_panel_settings,
  };

  // Static map of available colors - add any Material Colors here
  static const Map<String, Color> _colorMap = {
    'orange': Colors.orange,
    'cyan': Colors.cyan,
    'redAccent': Colors.redAccent,
    'blue': Colors.blue,
    'teal': Colors.teal,
    'purple': Colors.purple,
    'amber': Colors.amber,
    'red': Colors.red,
    'green': Colors.green,
    'yellow': Colors.yellow,
    'pink': Colors.pink,
    'indigo': Colors.indigo,
    'lime': Colors.lime,
    'brown': Colors.brown,
    'grey': Colors.grey,
    'blueGrey': Colors.blueGrey,
    'deepOrange': Colors.deepOrange,
    'deepPurple': Colors.deepPurple,
    'lightBlue': Colors.lightBlue,
    'lightGreen': Colors.lightGreen,
  };

  CategoryTaxonomy({
    required this.categoryId,
    required this.name,
    required this.iconKey,
    required this.colorKey,
    this.description = '',
    List<String> contextFieldIds = const [],
    required List<EventTypeTaxonomy> eventTypes,
  }) : contextFieldIds = List.unmodifiable(contextFieldIds),
       eventTypes = List<EventTypeTaxonomy>.unmodifiable(eventTypes),
       _eventTypesById = Map<String, EventTypeTaxonomy>.unmodifiable(
         <String, EventTypeTaxonomy>{
           for (final eventType in eventTypes) eventType.eventTypeId: eventType,
         },
       );

  factory CategoryTaxonomy.fromJson(Map<String, dynamic> json) {
    return CategoryTaxonomy(
      categoryId: json['categoryId'] as String,
      name: json['name'] as String,
      iconKey: json['iconKey'] as String,
      colorKey: json['colorKey'] as String,
      description: json['description'] as String? ?? '',
      contextFieldIds: List<String>.from(
        json['contextFieldIds'] as List? ?? [],
      ),
      eventTypes: (json['eventTypes'] as List<dynamic>)
          .map((e) => EventTypeTaxonomy.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'categoryId': categoryId,
      'name': name,
      'iconKey': iconKey,
      'colorKey': colorKey,
      'description': description,
      'contextFieldIds': contextFieldIds,
      'eventTypes': eventTypes.map((e) => e.toJson()).toList(),
    };
  }

  List<EventTypeTaxonomy> get captureEventTypes =>
      eventTypes.where((e) => !e.archived).toList(growable: false);
  bool matches(String query) =>
      name.toLowerCase().contains(query.toLowerCase()) ||
      captureEventTypes.any((e) => e.matches(query));

  EventTypeTaxonomy? getEventTypeById(String eventTypeId) {
    return _eventTypesById[eventTypeId];
  }

  IconData getIcon() {
    return _iconMap[iconKey] ?? Icons.circle;
  }

  Color getColor() {
    return _colorMap[colorKey] ?? Colors.grey;
  }
}

class EventTypeTaxonomy {
  final String eventTypeId;
  final String name;
  final EventGrade? defaultImpact;
  final String definition;
  final bool archived;
  final List<String> aliases;
  final Map<String, String> contextDefaults;

  EventTypeTaxonomy({
    required this.eventTypeId,
    required this.name,
    this.defaultImpact,
    this.definition = '',
    this.archived = false,
    List<String> aliases = const [],
    Map<String, String> contextDefaults = const {},
  }) : aliases = List.unmodifiable(aliases),
       contextDefaults = Map.unmodifiable(contextDefaults);

  bool matches(String query) => [
    name,
    ...aliases,
  ].any((s) => s.toLowerCase().contains(query.toLowerCase()));

  factory EventTypeTaxonomy.fromJson(Map<String, dynamic> json) {
    EventGrade? impact;
    if (json['defaultImpact'] != null) {
      final impactStr = json['defaultImpact'] as String;
      impact = EventGrade.values.firstWhere(
        (e) => e.name == impactStr,
        orElse: () => EventGrade.neutral,
      );
    }

    return EventTypeTaxonomy(
      eventTypeId: json['eventTypeId'] as String,
      name: json['name'] as String,
      defaultImpact: impact,
      definition: json['definition'] as String? ?? '',
      archived: json['archived'] as bool? ?? false,
      aliases: List<String>.from(json['aliases'] as List? ?? []),
      contextDefaults: Map<String, String>.from(
        json['contextDefaults'] as Map? ?? {},
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'eventTypeId': eventTypeId,
      'name': name,
      if (defaultImpact != null) 'defaultImpact': defaultImpact!.name,
      'definition': definition,
      'archived': archived,
      'aliases': aliases,
      'contextDefaults': contextDefaults,
    };
  }
}

class TaxonomyContextField {
  final String id;
  final String name;
  final String description;
  final bool common;
  final List<String> options;
  TaxonomyContextField({
    required this.id,
    required this.name,
    this.description = '',
    this.common = false,
    List<String> options = const [],
  }) : options = List.unmodifiable(options);
  factory TaxonomyContextField.fromJson(Map<String, dynamic> json) =>
      TaxonomyContextField(
        id: json['id'] as String,
        name: json['name'] as String,
        description: json['description'] as String? ?? '',
        common: json['common'] == true,
        options: List<String>.from(json['options'] as List? ?? []),
      );
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'common': common,
    'options': options,
  };
}

class TaxonomyQuickPreset {
  final String name;
  final List<String> eventTypeIds;
  TaxonomyQuickPreset({required this.name, required List<String> eventTypeIds})
    : eventTypeIds = List.unmodifiable(eventTypeIds);
  factory TaxonomyQuickPreset.fromJson(Map<String, dynamic> json) =>
      TaxonomyQuickPreset(
        name: json['name'] as String,
        eventTypeIds: List<String>.from(json['eventTypeIds'] as List),
      );
  Map<String, dynamic> toJson() => {'name': name, 'eventTypeIds': eventTypeIds};
}
