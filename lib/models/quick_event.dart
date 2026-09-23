import 'game_event.dart';

class QuickEvent {
  final String categoryId;
  final String eventTypeId;
  final EventGrade? grade;
  final String? slotId;
  final String? taxonomyRevision;
  final String? categoryLabel;
  final String? eventLabel;
  final String? definition;
  final Map<String, String> context;
  final String? hotkey;

  QuickEvent({
    required this.categoryId,
    required this.eventTypeId,
    required this.grade,
    this.hotkey,
    this.slotId,
    this.taxonomyRevision,
    this.categoryLabel,
    this.eventLabel,
    this.definition,
    Map<String, String> context = const {},
  }) : context = Map.unmodifiable(context);

  String get id => slotId ?? '$categoryId/$eventTypeId';

  QuickEvent copyWith({
    EventGrade? grade,
    String? hotkey,
    bool clearHotkey = false,
    bool clearGrade = false,
    Map<String, String>? context,
  }) => QuickEvent(
    categoryId: categoryId,
    eventTypeId: eventTypeId,
    grade: clearGrade ? null : grade ?? this.grade,
    slotId: slotId,
    taxonomyRevision: taxonomyRevision,
    categoryLabel: categoryLabel,
    eventLabel: eventLabel,
    definition: definition,
    context: context ?? this.context,
    hotkey: clearHotkey ? null : hotkey ?? this.hotkey,
  );

  Map<String, Object?> toJson() => {
    'categoryId': categoryId,
    'eventTypeId': eventTypeId,
    'grade': grade?.name,
    if (slotId != null) 'slotId': slotId,
    if (taxonomyRevision != null) 'taxonomyRevision': taxonomyRevision,
    if (categoryLabel != null) 'categoryLabel': categoryLabel,
    if (eventLabel != null) 'eventLabel': eventLabel,
    if (definition != null) 'definition': definition,
    if (context.isNotEmpty) 'context': context,
    if (hotkey != null) 'hotkey': hotkey,
  };

  factory QuickEvent.fromJson(Map<String, dynamic> json) => QuickEvent(
    categoryId: json['categoryId'] as String,
    eventTypeId: json['eventTypeId'] as String,
    grade: json['grade'] == null
        ? null
        : EventGrade.values.byName(json['grade'] as String),
    slotId: json['slotId'] as String?,
    taxonomyRevision: json['taxonomyRevision'] as String?,
    categoryLabel: json['categoryLabel'] as String?,
    eventLabel: json['eventLabel'] as String?,
    definition: json['definition'] as String?,
    context: Map<String, String>.from(json['context'] as Map? ?? {}),
    hotkey: json['hotkey'] as String?,
  );
}

class QuickEventPreset {
  final String id;
  final String sportId;
  final String name;
  final List<QuickEvent> items;

  QuickEventPreset({
    required this.id,
    required this.sportId,
    required this.name,
    required Iterable<QuickEvent> items,
  }) : items = List.unmodifiable(items);

  Map<String, Object?> toJson() => {
    'id': id,
    'sportId': sportId,
    'name': name,
    'items': items.map((item) => item.toJson()).toList(),
  };

  factory QuickEventPreset.fromJson(Map<String, dynamic> json) =>
      QuickEventPreset(
        id: json['id'] as String,
        sportId: json['sportId'] as String,
        name: json['name'] as String,
        items: (json['items'] as List).map(
          (item) => QuickEvent.fromJson(Map<String, dynamic>.from(item as Map)),
        ),
      );
}
