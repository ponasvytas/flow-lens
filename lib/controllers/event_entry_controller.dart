import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import '../models/game_event.dart';
import 'events_controller.dart';

enum EventEntryStage { none, categories, labels, grades }

class EventEntryController extends ChangeNotifier {
  final categorySearch = TextEditingController();
  GameEvent? _draft;
  GameEvent? get draft => _draft;

  bool beginDraft(GameEvent event) {
    if (_draft != null) return false;
    _draft = event;
    notifyListeners();
    return true;
  }

  void updateDraft(GameEvent event) {
    if (_draft?.id != event.id) return;
    _draft = event;
    notifyListeners();
  }

  void cancelDraft() {
    if (_draft == null) return;
    _draft = null;
    notifyListeners();
  }

  GameEvent? commitDraft(EventsController events) {
    final event = _draft;
    if (event == null || !event.isComplete) return null;
    events.upsertEvent(event);
    cancelDraft();
    if (isEntryActive) setStage(EventEntryStage.categories);
    return event;
  }

  @override
  void dispose() {
    categorySearch.dispose();
    super.dispose();
  }

  static const pageSize = 9;
  bool isEntryActive = false;
  EventEntryStage stage = EventEntryStage.none;
  int page = 0;
  bool get showCategoryNumbers =>
      isEntryActive && stage == EventEntryStage.categories;
  bool get showLabelNumbers => isEntryActive && stage == EventEntryStage.labels;
  bool get showGradeNumbers => isEntryActive && stage == EventEntryStage.grades;

  void toggle() {
    if (isEntryActive) {
      exit();
    } else {
      isEntryActive = true;
      setStage(
        _draft == null
            ? EventEntryStage.categories
            : _draft!.isComplete
            ? EventEntryStage.grades
            : EventEntryStage.labels,
      );
    }
  }

  void exit() {
    isEntryActive = false;
    stage = EventEntryStage.none;
    page = 0;
    notifyListeners();
  }

  void setStage(EventEntryStage value) {
    stage = value;
    page = 0;
    notifyListeners();
  }

  void setPage(int value, int count) {
    final lastPage = count == 0 ? 0 : (count - 1) ~/ pageSize;
    final next = value.clamp(0, lastPage);
    if (next == page) return;
    page = next;
    notifyListeners();
  }

  int? selectionIndex(LogicalKeyboardKey key, int count) {
    final digit = digitFor(key);
    if (digit == null || digit == 0) return null;
    final index = page * pageSize + digit - 1;
    return index < count ? index : null;
  }

  static int? digitFor(LogicalKeyboardKey key) {
    const digits = [
      LogicalKeyboardKey.digit0,
      LogicalKeyboardKey.digit1,
      LogicalKeyboardKey.digit2,
      LogicalKeyboardKey.digit3,
      LogicalKeyboardKey.digit4,
      LogicalKeyboardKey.digit5,
      LogicalKeyboardKey.digit6,
      LogicalKeyboardKey.digit7,
      LogicalKeyboardKey.digit8,
      LogicalKeyboardKey.digit9,
    ];
    const numpad = [
      LogicalKeyboardKey.numpad0,
      LogicalKeyboardKey.numpad1,
      LogicalKeyboardKey.numpad2,
      LogicalKeyboardKey.numpad3,
      LogicalKeyboardKey.numpad4,
      LogicalKeyboardKey.numpad5,
      LogicalKeyboardKey.numpad6,
      LogicalKeyboardKey.numpad7,
      LogicalKeyboardKey.numpad8,
      LogicalKeyboardKey.numpad9,
    ];
    final index = digits.indexOf(key);
    final result = index >= 0 ? index : numpad.indexOf(key);
    return result < 0 ? null : result;
  }
}
