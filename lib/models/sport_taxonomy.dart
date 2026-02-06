import 'package:flutter/material.dart';
import 'game_event.dart';

class SportTaxonomy {
  final int schemaVersion;
  final String sportId;
  final String name;
  final List<CategoryTaxonomy> categories;

  SportTaxonomy({
    required this.schemaVersion,
    required this.sportId,
    required this.name,
    required this.categories,
  });

  factory SportTaxonomy.fromJson(Map<String, dynamic> json) {
    return SportTaxonomy(
      schemaVersion: json['schemaVersion'] as int,
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
      'sportId': sportId,
      'name': name,
      'categories': categories.map((c) => c.toJson()).toList(),
    };
  }

  CategoryTaxonomy? getCategoryById(String categoryId) {
    try {
      return categories.firstWhere((c) => c.categoryId == categoryId);
    } catch (e) {
      return null;
    }
  }

  EventTypeTaxonomy? getEventTypeById(String eventTypeId) {
    for (final category in categories) {
      final eventType = category.getEventTypeById(eventTypeId);
      if (eventType != null) return eventType;
    }
    return null;
  }

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
  }
}

class CategoryTaxonomy {
  final String categoryId;
  final String name;
  final String iconKey;
  final String colorKey;
  final List<EventTypeTaxonomy> eventTypes;

  // Static map of available icons - add any Material Icons here
  static const Map<String, IconData> _iconMap = {
    'sports_hockey': Icons.sports_hockey,
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
    required this.eventTypes,
  });

  factory CategoryTaxonomy.fromJson(Map<String, dynamic> json) {
    return CategoryTaxonomy(
      categoryId: json['categoryId'] as String,
      name: json['name'] as String,
      iconKey: json['iconKey'] as String,
      colorKey: json['colorKey'] as String,
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
      'eventTypes': eventTypes.map((e) => e.toJson()).toList(),
    };
  }

  EventTypeTaxonomy? getEventTypeById(String eventTypeId) {
    try {
      return eventTypes.firstWhere((e) => e.eventTypeId == eventTypeId);
    } catch (e) {
      return null;
    }
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

  EventTypeTaxonomy({
    required this.eventTypeId,
    required this.name,
    this.defaultImpact,
  });

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
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'eventTypeId': eventTypeId,
      'name': name,
      if (defaultImpact != null) 'defaultImpact': defaultImpact!.name,
    };
  }
}
