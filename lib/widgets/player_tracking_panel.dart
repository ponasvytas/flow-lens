import 'dart:async';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import '../controllers/tracking_controller.dart';
import '../models/tracking_models.dart';
import '../models/sport_taxonomy.dart';
import 'dockable_panel.dart';
import 'tracking_hotkey_dialog.dart';

/// Player tracking panel — shows subject cards with counter/timer rows.
///
/// Adapts layout based on [dockEdge]:
/// - Floating / left / right → vertical stack of subject cards
/// - Top / bottom → horizontal row of subject cards
class PlayerTrackingPanel extends StatefulWidget {
  final TrackingController controller;
  final Player player;
  final SportTaxonomy? taxonomy;
  final PanelDockEdge dockEdge;
  final VoidCallback? onSave;
  final VoidCallback? onLoad;
  final VoidCallback? onExportCsv;

  const PlayerTrackingPanel({
    required this.controller,
    required this.player,
    this.taxonomy,
    this.dockEdge = PanelDockEdge.floating,
    this.onSave,
    this.onLoad,
    this.onExportCsv,
    super.key,
  });

  @override
  State<PlayerTrackingPanel> createState() => _PlayerTrackingPanelState();
}

class _PlayerTrackingPanelState extends State<PlayerTrackingPanel> {
  final Set<String> _collapsedSubjects = {};
  final _nameController = TextEditingController();
  final _numberController = TextEditingController();
  bool _showAddForm = false;

  // Flash feedback
  ({String subjectId, String trackerId})? _flashKey;
  Timer? _flashTimer;

  // Live timer tick
  StreamSubscription<Duration>? _positionSub;
  Duration _videoPosition = Duration.zero;
  DateTime? _lastTimerPaint;
  late int _structureFingerprint;

  @override
  void initState() {
    super.initState();
    _videoPosition = widget.player.state.position;
    _structureFingerprint = _controllerStructureFingerprint();
    widget.controller.addListener(_onControllerChange);
    _updateTimerSubscription();
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _flashTimer?.cancel();
    _nameController.dispose();
    _numberController.dispose();
    widget.controller.removeListener(_onControllerChange);
    super.dispose();
  }

  void _onControllerChange() {
    if (!mounted) return;
    _updateTimerSubscription();
    // Check for feedback flash
    final fb = widget.controller.lastFeedback;
    if (fb != null) {
      _flashTimer?.cancel();
      setState(() => _flashKey = fb);
      widget.controller.clearFeedback();
      _flashTimer = Timer(const Duration(milliseconds: 400), () {
        if (mounted) setState(() => _flashKey = null);
      });
      return;
    }
    final nextFingerprint = _controllerStructureFingerprint();
    if (nextFingerprint != _structureFingerprint) {
      _structureFingerprint = nextFingerprint;
      setState(() {});
    }
  }

  int _controllerStructureFingerprint() => Object.hash(
    Object.hashAll(
      widget.controller.subjects.map(
        (subject) => Object.hash(
          subject.id,
          subject.label,
          subject.number,
          subject.colorValue,
        ),
      ),
    ),
    Object.hashAll(
      widget.controller.trackers.map(
        (tracker) => Object.hash(
          tracker.id,
          tracker.label,
          tracker.kind,
          tracker.timerMode,
        ),
      ),
    ),
    Object.hashAll(
      widget.controller.hotkeys.entries.map(
        (entry) => Object.hash(entry.key, entry.value),
      ),
    ),
    widget.controller.activeSubjectId,
  );

  void _updateTimerSubscription() {
    if (widget.controller.activeTimerKeys.isEmpty) {
      _positionSub?.cancel();
      _positionSub = null;
      return;
    }
    _positionSub ??= widget.player.stream.position.listen((position) {
      final now = DateTime.now();
      if (_lastTimerPaint != null &&
          now.difference(_lastTimerPaint!) <
              const Duration(milliseconds: 100)) {
        return;
      }
      _lastTimerPaint = now;
      if (mounted) setState(() => _videoPosition = position);
    });
  }

  bool get _isHorizontal =>
      widget.dockEdge == PanelDockEdge.top ||
      widget.dockEdge == PanelDockEdge.bottom;

  // -------------------------------------------------------------------------
  // Build
  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final ctrl = widget.controller;
    final subjects = ctrl.subjects;
    final trackers = ctrl.trackers;

    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Toolbar row
          _buildToolbar(ctrl),
          const SizedBox(height: 6),

          // Subject cards
          if (subjects.isEmpty && !_showAddForm)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'No players added.\nTap + to add a player.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white38, fontSize: 11),
              ),
            ),

          if (_isHorizontal)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (int i = 0; i < subjects.length; i++) ...[
                    if (i > 0) const SizedBox(width: 6),
                    SizedBox(
                      width: 220,
                      child: _buildSubjectCard(subjects[i], trackers, ctrl),
                    ),
                  ],
                ],
              ),
            )
          else
            for (int i = 0; i < subjects.length; i++) ...[
              if (i > 0) const SizedBox(height: 4),
              _buildSubjectCard(subjects[i], trackers, ctrl),
            ],

          // Inline add form
          if (_showAddForm) ...[const SizedBox(height: 6), _buildAddForm(ctrl)],
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Toolbar
  // -------------------------------------------------------------------------

  Widget _buildToolbar(TrackingController ctrl) {
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        // Add player button
        _SmallIconBtn(
          icon: Icons.person_add,
          tooltip: 'Add player',
          onTap: () => setState(() => _showAddForm = !_showAddForm),
        ),
        // Config / add trackers
        _SmallIconBtn(
          icon: Icons.tune,
          tooltip: 'Configure trackers',
          onTap: () => _showTrackerPicker(ctrl),
        ),
        // Save
        _SmallIconBtn(
          icon: Icons.save_alt,
          tooltip: 'Save session',
          onTap: widget.onSave,
        ),
        // Load
        _SmallIconBtn(
          icon: Icons.upload_file,
          tooltip: 'Load session',
          onTap: widget.onLoad,
        ),
        // Export CSV
        _SmallIconBtn(
          icon: Icons.table_chart,
          tooltip: 'Export CSV',
          onTap: ctrl.events.isNotEmpty ? widget.onExportCsv : null,
        ),
        // Event count
        Text(
          '${ctrl.events.length} events',
          style: const TextStyle(color: Colors.white30, fontSize: 10),
        ),
        // Undo
        _SmallIconBtn(
          icon: Icons.undo,
          tooltip: 'Undo last',
          onTap: ctrl.events.isNotEmpty ? () => ctrl.undoLastEvent() : null,
        ),
      ],
    );
  }

  // -------------------------------------------------------------------------
  // Inline add player form
  // -------------------------------------------------------------------------

  Widget _buildAddForm(TrackingController ctrl) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: _MiniTextField(
              controller: _nameController,
              hint: 'Name',
              autofocus: true,
            ),
          ),
          const SizedBox(width: 4),
          SizedBox(
            width: 44,
            child: _MiniTextField(controller: _numberController, hint: '#'),
          ),
          const SizedBox(width: 4),
          _SmallIconBtn(
            icon: Icons.check,
            tooltip: 'Add',
            color: Colors.greenAccent,
            onTap: () {
              final name = _nameController.text.trim();
              if (name.isEmpty) return;
              final number = _numberController.text.trim();
              final id = 'subj_${DateTime.now().millisecondsSinceEpoch}';
              ctrl.addSubjectWithSameTrackers(
                TrackingSubject(
                  id: id,
                  label: name,
                  number: number.isEmpty ? null : number,
                ),
                ctrl.subjects.isNotEmpty ? ctrl.subjects.first.id : null,
              );
              _nameController.clear();
              _numberController.clear();
              setState(() => _showAddForm = false);
            },
          ),
          _SmallIconBtn(
            icon: Icons.close,
            tooltip: 'Cancel',
            onTap: () => setState(() => _showAddForm = false),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Subject card
  // -------------------------------------------------------------------------

  Widget _buildSubjectCard(
    TrackingSubject subject,
    List<TrackingDefinition> trackers,
    TrackingController ctrl,
  ) {
    final isCollapsed = _collapsedSubjects.contains(subject.id);
    final subjectColor = Color(subject.colorValue);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: subjectColor.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Card header
          GestureDetector(
            onTap: () => setState(() {
              isCollapsed
                  ? _collapsedSubjects.remove(subject.id)
                  : _collapsedSubjects.add(subject.id);
            }),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              decoration: BoxDecoration(
                color: subjectColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(5),
                  topRight: const Radius.circular(5),
                  bottomLeft: isCollapsed
                      ? const Radius.circular(5)
                      : Radius.zero,
                  bottomRight: isCollapsed
                      ? const Radius.circular(5)
                      : Radius.zero,
                ),
              ),
              child: Row(
                children: [
                  // Color dot
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: subjectColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  // Number
                  if (subject.number != null)
                    Text(
                      '#${subject.number} ',
                      style: TextStyle(
                        color: subjectColor.withValues(alpha: 0.8),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  // Name
                  Expanded(
                    child: Text(
                      subject.label,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // Remove subject
                  GestureDetector(
                    onTap: () => ctrl.removeSubject(subject.id),
                    child: const Padding(
                      padding: EdgeInsets.all(2),
                      child: Icon(Icons.close, size: 12, color: Colors.white30),
                    ),
                  ),
                  // Collapse toggle
                  Icon(
                    isCollapsed
                        ? Icons.keyboard_arrow_down
                        : Icons.keyboard_arrow_up,
                    size: 14,
                    color: Colors.white38,
                  ),
                ],
              ),
            ),
          ),

          // Tracker rows
          if (!isCollapsed)
            ...trackers.map(
              (tracker) => _buildTrackerRow(subject, tracker, ctrl),
            ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Tracker row (counter or timer)
  // -------------------------------------------------------------------------

  Widget _buildTrackerRow(
    TrackingSubject subject,
    TrackingDefinition tracker,
    TrackingController ctrl,
  ) {
    final isFlashing =
        _flashKey != null &&
        _flashKey!.subjectId == subject.id &&
        _flashKey!.trackerId == tracker.id;
    final hotkey = ctrl.getHotkey(subject.id, tracker.id);

    return ValueListenableBuilder<TrackingCellStats>(
      valueListenable: ctrl.cellStatsListenable(subject.id, tracker.id),
      builder: (context, stats, child) => AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        color: isFlashing
            ? Colors.amber.withValues(alpha: 0.25)
            : Colors.transparent,
        child: tracker.kind == TrackerKind.counter
            ? _buildCounterContent(subject, tracker, ctrl, hotkey)
            : _buildTimerContent(subject, tracker, ctrl, hotkey),
      ),
    );
  }

  Widget _buildCounterContent(
    TrackingSubject subject,
    TrackingDefinition tracker,
    TrackingController ctrl,
    String? hotkey,
  ) {
    final value = ctrl.getCounterValue(subject.id, tracker.id);
    return Row(
      children: [
        _HotkeyBadge(
          label: hotkey,
          onTap: () => _promptHotkey(ctrl, subject.id, tracker.id),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            tracker.label,
            style: const TextStyle(color: Colors.white60, fontSize: 10),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Text(
          '$value',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(width: 2),
        _TinyBtn(
          icon: Icons.add,
          onTap: () => ctrl.incrementCounter(
            subjectId: subject.id,
            trackerId: tracker.id,
            timestamp: widget.player.state.position,
          ),
        ),
        _TinyBtn(
          icon: Icons.remove,
          onTap: value > 0
              ? () => ctrl.decrementCounter(
                  subjectId: subject.id,
                  trackerId: tracker.id,
                  timestamp: widget.player.state.position,
                )
              : null,
        ),
      ],
    );
  }

  Widget _buildTimerContent(
    TrackingSubject subject,
    TrackingDefinition tracker,
    TrackingController ctrl,
    String? hotkey,
  ) {
    final running = ctrl.isTimerRunning(subject.id, tracker.id);
    final accumulated = ctrl.getTimerDuration(subject.id, tracker.id);
    final startTs = ctrl.timerStartTimestamp(subject.id, tracker.id);

    // Live duration = accumulated + current running interval
    Duration display = accumulated;
    if (running && startTs != null) {
      final currentInterval = _videoPosition - startTs;
      if (!currentInterval.isNegative) {
        display = accumulated + currentInterval;
      }
    }

    final modeIcon = tracker.timerMode == TimerMode.hold
        ? Icons.touch_app
        : Icons.toggle_on;

    return Row(
      children: [
        _HotkeyBadge(
          label: hotkey,
          onTap: () => _promptHotkey(ctrl, subject.id, tracker.id),
        ),
        const SizedBox(width: 4),
        Icon(modeIcon, size: 10, color: Colors.white24),
        const SizedBox(width: 2),
        Expanded(
          child: Text(
            tracker.label,
            style: const TextStyle(color: Colors.white60, fontSize: 10),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        // Duration display
        Text(
          _formatDuration(display),
          style: TextStyle(
            color: running ? Colors.greenAccent : Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.bold,
            fontFamily: 'monospace',
          ),
        ),
        if (running)
          const Padding(
            padding: EdgeInsets.only(left: 3),
            child: _PulsingDot(),
          ),
        const SizedBox(width: 2),
        // Toggle button (for toggle-mode timers via click)
        _TinyBtn(
          icon: running ? Icons.stop : Icons.play_arrow,
          color: running ? Colors.redAccent : Colors.greenAccent,
          onTap: () => ctrl.toggleTimer(
            subjectId: subject.id,
            trackerId: tracker.id,
            timestamp: widget.player.state.position,
          ),
        ),
      ],
    );
  }

  // -------------------------------------------------------------------------
  // Hotkey prompt
  // -------------------------------------------------------------------------

  void _promptHotkey(
    TrackingController ctrl,
    String subjectId,
    String trackerId,
  ) {
    showTrackingHotkeyDialog(
      context: context,
      controller: ctrl,
      subjectId: subjectId,
      trackerId: trackerId,
    );
  }

  // -------------------------------------------------------------------------
  // Tracker picker dialog
  // -------------------------------------------------------------------------

  void _showTrackerPicker(TrackingController ctrl) {
    showDialog(
      context: context,
      builder: (ctx) => _TrackerPickerDialog(
        presets: widget.taxonomy?.trackingPresets ?? const [],
        currentTrackerIds: ctrl.trackers.map((t) => t.id).toSet(),
        onConfirm: (selected) {
          // Add newly selected, remove deselected
          final currentIds = ctrl.trackers.map((t) => t.id).toSet();
          for (final def in selected) {
            if (!currentIds.contains(def.id)) {
              ctrl.addTracker(def);
            }
          }
          for (final id in currentIds) {
            if ((widget.taxonomy?.trackingPresets.any((t) => t.id == id) ??
                    false) &&
                !selected.any((d) => d.id == id)) {
              ctrl.removeTracker(id);
            }
          }
          Navigator.of(ctx).pop();
        },
        onCancel: () => Navigator.of(ctx).pop(),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Helpers
  // -------------------------------------------------------------------------

  String _formatDuration(Duration d) {
    final mins = d.inMinutes.toString().padLeft(2, '0');
    final secs = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }
}

// ===========================================================================
// Small helper widgets
// ===========================================================================

class _SmallIconBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final Color? color;

  const _SmallIconBtn({
    required this.icon,
    required this.tooltip,
    this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: SizedBox.square(
          dimension: 44,
          child: Icon(
            icon,
            size: 16,
            color: onTap != null ? (color ?? Colors.white54) : Colors.white12,
          ),
        ),
      ),
    );
  }
}

class _TinyBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final Color? color;

  const _TinyBtn({required this.icon, this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: icon == Icons.add
          ? 'Increment'
          : icon == Icons.remove
          ? 'Decrement'
          : icon == Icons.stop
          ? 'Stop timer'
          : 'Start timer',
      child: Semantics(
        button: true,
        enabled: onTap != null,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: SizedBox.square(
            dimension: 44,
            child: Icon(
              icon,
              size: 14,
              color: onTap != null ? (color ?? Colors.white54) : Colors.white12,
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final bool autofocus;

  const _MiniTextField({
    required this.controller,
    required this.hint,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      autofocus: autofocus,
      style: const TextStyle(color: Colors.white, fontSize: 11),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white24, fontSize: 11),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: Colors.white12),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: Colors.white12),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: Colors.blueAccent),
        ),
      ),
    );
  }
}

class _HotkeyBadge extends StatelessWidget {
  final String? label;
  final VoidCallback? onTap;

  const _HotkeyBadge({this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label == null ? 'Assign hotkey' : 'Change hotkey $label',
      child: Semantics(
        button: true,
        label: label == null ? 'Assign hotkey' : 'Hotkey $label',
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: SizedBox.square(
            dimension: 44,
            child: Center(
              child: Container(
                constraints: const BoxConstraints(minWidth: 20),
                padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                decoration: BoxDecoration(
                  color: label != null
                      ? Colors.blueGrey.withValues(alpha: 0.4)
                      : Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(3),
                  border: Border.all(
                    color: label != null ? Colors.white24 : Colors.white10,
                    width: 1,
                  ),
                ),
                child: Text(
                  label?.toUpperCase() ?? '·',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: label != null ? Colors.white70 : Colors.white12,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Green pulsing dot for active timers.
class _PulsingDot extends StatefulWidget {
  const _PulsingDot();

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _anim,
      child: Container(
        width: 6,
        height: 6,
        decoration: const BoxDecoration(
          color: Colors.greenAccent,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

// ===========================================================================
// Tracker picker dialog (select from presets)
// ===========================================================================

class _TrackerPickerDialog extends StatefulWidget {
  final Set<String> currentTrackerIds;
  final List<TrackingDefinition> presets;
  final void Function(List<TrackingDefinition> selected) onConfirm;
  final VoidCallback onCancel;

  const _TrackerPickerDialog({
    required this.currentTrackerIds,
    required this.presets,
    required this.onConfirm,
    required this.onCancel,
  });

  @override
  State<_TrackerPickerDialog> createState() => _TrackerPickerDialogState();
}

class _TrackerPickerDialogState extends State<_TrackerPickerDialog> {
  String _query = '';
  bool _matches(TrackingDefinition t) =>
      t.label.toLowerCase().contains(_query) ||
      (t.definition?.toLowerCase().contains(_query) ?? false);
  late final Set<String> _selected;

  @override
  void initState() {
    super.initState();
    _selected = Set.from(widget.currentTrackerIds);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E1E2E),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Colors.white12),
      ),
      title: const Text(
        'Select Trackers',
        style: TextStyle(color: Colors.white, fontSize: 14),
      ),
      content: SizedBox(
        width: 300,
        height: 400,
        child: ListView(
          children: [
            TextField(
              decoration: const InputDecoration(
                labelText: 'Find tracker',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) =>
                  setState(() => _query = value.toLowerCase()),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Manual counts are separate from Record events. Record all opportunities before using rates.',
              ),
            ),
            _sectionHeader('Counters'),
            for (final t in widget.presets.where(
              (t) => t.kind == TrackerKind.counter && _matches(t),
            ))
              _trackerTile(t),
            const SizedBox(height: 8),
            _sectionHeader('Timers'),
            for (final t in widget.presets.where(
              (t) => t.kind == TrackerKind.timer && _matches(t),
            ))
              _trackerTile(t),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: widget.onCancel,
          child: const Text(
            'Cancel',
            style: TextStyle(color: Colors.white38, fontSize: 12),
          ),
        ),
        TextButton(
          onPressed: () {
            final selected = widget.presets
                .where((t) => _selected.contains(t.id))
                .toList();
            widget.onConfirm(selected);
          },
          child: const Text('Apply', style: TextStyle(fontSize: 12)),
        ),
      ],
    );
  }

  Widget _sectionHeader(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4, top: 4),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white54,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _trackerTile(TrackingDefinition t) {
    final checked = _selected.contains(t.id);
    return Tooltip(
      message: t.definition ?? t.label,
      child: InkWell(
        onTap: () => setState(() {
          checked ? _selected.remove(t.id) : _selected.add(t.id);
        }),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            children: [
              Icon(
                checked ? Icons.check_box : Icons.check_box_outline_blank,
                size: 16,
                color: checked ? Colors.blueAccent : Colors.white24,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  t.label,
                  style: TextStyle(
                    color: checked ? Colors.white : Colors.white54,
                    fontSize: 12,
                  ),
                ),
              ),
              if (t.kind == TrackerKind.timer)
                Icon(
                  t.timerMode == TimerMode.hold
                      ? Icons.touch_app
                      : Icons.toggle_on,
                  size: 12,
                  color: Colors.white24,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
