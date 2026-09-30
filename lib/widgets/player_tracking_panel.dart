import 'dart:async';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import '../controllers/tracking_controller.dart';
import '../models/tracking_models.dart';
import '../models/sport_taxonomy.dart';
import '../theme/flow_theme.dart';
import 'adaptive_dialog.dart';
import 'add_player_dialog.dart';
import 'dockable_panel.dart';
import 'tool_action_grid.dart';
import 'tracking_hotkey_dialog.dart';

enum _TrackingSessionAction { save, load, export }

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
  final _nameFocusNode = FocusNode();
  bool _showAddForm = false;
  bool _nameError = false;

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
    _nameFocusNode.dispose();
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
    widget.controller.events.length,
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
                style: TextStyle(color: FlowTheme.muted, fontSize: 14),
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

  Widget _buildToolbar(TrackingController ctrl) => LayoutBuilder(
    builder: (context, constraints) {
      final compact = constraints.maxWidth < 320;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (compact)
                _SmallIconBtn(
                  icon: Icons.person_add_rounded,
                  tooltip: 'Add player',
                  onTap: () => _openAddPlayer(ctrl),
                )
              else
                FilledButton.tonalIcon(
                  onPressed: () => _openAddPlayer(ctrl),
                  icon: const Icon(Icons.person_add_rounded),
                  label: const Text('Add player'),
                ),
              if (compact)
                _SmallIconBtn(
                  icon: Icons.tune_rounded,
                  tooltip: 'Configure trackers',
                  onTap: () => _showTrackerPicker(ctrl),
                )
              else
                OutlinedButton.icon(
                  onPressed: () => _showTrackerPicker(ctrl),
                  icon: const Icon(Icons.tune_rounded),
                  label: const Text('Trackers'),
                ),
              PopupMenuButton<_TrackingSessionAction>(
                tooltip: 'Session actions',
                icon: const Icon(Icons.more_horiz_rounded),
                onSelected: (action) {
                  switch (action) {
                    case _TrackingSessionAction.save:
                      widget.onSave?.call();
                    case _TrackingSessionAction.load:
                      widget.onLoad?.call();
                    case _TrackingSessionAction.export:
                      widget.onExportCsv?.call();
                  }
                },
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: _TrackingSessionAction.save,
                    enabled: widget.onSave != null,
                    child: const Text('Save session'),
                  ),
                  PopupMenuItem(
                    value: _TrackingSessionAction.load,
                    enabled: widget.onLoad != null,
                    child: const Text('Load session'),
                  ),
                  PopupMenuItem(
                    value: _TrackingSessionAction.export,
                    enabled:
                        ctrl.events.isNotEmpty && widget.onExportCsv != null,
                    child: const Text('Export CSV'),
                  ),
                ],
              ),
              _SmallIconBtn(
                icon: Icons.undo_rounded,
                tooltip: 'Undo last tracking event',
                onTap: ctrl.events.isNotEmpty
                    ? () => ctrl.undoLastEvent()
                    : null,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${ctrl.events.length} tracking ${ctrl.events.length == 1 ? 'event' : 'events'}',
            style: const TextStyle(color: FlowTheme.muted, fontSize: 12),
          ),
        ],
      );
    },
  );

  void _openAddPlayer(TrackingController ctrl) {
    if (Theme.of(context).platform == TargetPlatform.iOS) {
      _showAddPlayerDialog(ctrl);
    } else {
      _toggleAddForm();
    }
  }

  // -------------------------------------------------------------------------
  // Inline add player form
  // -------------------------------------------------------------------------

  void _addPlayer(TrackingController ctrl, String name, String number) {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) return;
    final trimmedNumber = number.trim();
    ctrl.addSubjectWithSameTrackers(
      TrackingSubject(
        id: 'subj_${DateTime.now().microsecondsSinceEpoch}',
        label: trimmedName,
        number: trimmedNumber.isEmpty ? null : trimmedNumber,
      ),
      ctrl.subjects.isNotEmpty ? ctrl.subjects.first.id : null,
    );
  }

  void _showAddPlayerDialog(TrackingController ctrl) {
    showDialog<void>(
      context: context,
      builder: (context) => AddPlayerDialog(
        onAdd: (name, number) => _addPlayer(ctrl, name, number),
      ),
    );
  }

  void _toggleAddForm() {
    if (_showAddForm) {
      _closeAddForm();
      return;
    }
    setState(() => _showAddForm = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _showAddForm) {
        _nameFocusNode.requestFocus();
      }
    });
  }

  void _closeAddForm() {
    _nameFocusNode.unfocus();
    setState(() {
      _showAddForm = false;
      _nameError = false;
    });
  }

  Widget _buildAddForm(TrackingController ctrl) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _MiniTextField(
            controller: _nameController,
            label: 'Name',
            focusNode: _nameFocusNode,
            errorText: _nameError ? 'Enter a player name' : null,
            onChanged: (_) {
              if (_nameError) setState(() => _nameError = false);
            },
          ),
          const SizedBox(height: 8),
          _MiniTextField(
            controller: _numberController,
            label: 'Number',
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton(
                onPressed: () {
                  final name = _nameController.text.trim();
                  if (name.isEmpty) {
                    setState(() => _nameError = true);
                    _nameFocusNode.requestFocus();
                    return;
                  }
                  _addPlayer(ctrl, name, _numberController.text);
                  _nameController.clear();
                  _numberController.clear();
                  _closeAddForm();
                },
                child: const Text('Add player'),
              ),
              TextButton(onPressed: _closeAddForm, child: const Text('Cancel')),
            ],
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
          _buildSubjectHeader(subject, ctrl, isCollapsed, subjectColor),

          // Tracker rows
          if (!isCollapsed)
            ...trackers.map(
              (tracker) => _buildTrackerRow(subject, tracker, ctrl),
            ),
        ],
      ),
    );
  }

  Widget _buildSubjectHeader(
    TrackingSubject subject,
    TrackingController ctrl,
    bool isCollapsed,
    Color subjectColor,
  ) => LayoutBuilder(
    builder: (context, constraints) {
      final narrow = constraints.maxWidth < 200;
      final collapse = IconButton(
        tooltip: '${isCollapsed ? 'Expand' : 'Collapse'} ${subject.label}',
        onPressed: () => setState(() {
          isCollapsed
              ? _collapsedSubjects.remove(subject.id)
              : _collapsedSubjects.add(subject.id);
        }),
        icon: Icon(
          isCollapsed ? Icons.expand_more_rounded : Icons.expand_less_rounded,
          size: ToolsetLayout.glyph,
        ),
      );
      final remove = IconButton(
        tooltip: 'Remove ${subject.label}',
        onPressed: () => _confirmRemoveSubject(ctrl, subject),
        icon: const Icon(Icons.close_rounded, size: ToolsetLayout.glyph),
      );
      return DecoratedBox(
        decoration: BoxDecoration(
          color: subjectColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(5),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                collapse,
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: subjectColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Tooltip(
                    message: subject.label,
                    child: Text(
                      '${subject.number == null ? '' : '#${subject.number} '}${subject.label}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: FlowTheme.text,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                if (!narrow) remove,
              ],
            ),
            if (narrow) Align(alignment: Alignment.centerRight, child: remove),
          ],
        ),
      );
    },
  );

  Future<void> _confirmRemoveSubject(
    TrackingController ctrl,
    TrackingSubject subject,
  ) async {
    final remove = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove player?'),
        content: Text('Remove ${subject.label} from this tracking session?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (remove == true && mounted) ctrl.removeSubject(subject.id);
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
    final keyButton = _HotkeyBadge(
      label: hotkey,
      trackerLabel: tracker.label,
      subjectLabel: subject.label,
      onTap: () => _promptHotkey(ctrl, subject.id, tracker.id),
    );
    final add = _TinyBtn(
      icon: Icons.add_rounded,
      tooltip: 'Add ${tracker.label} for ${subject.label}',
      onTap: () => ctrl.incrementCounter(
        subjectId: subject.id,
        trackerId: tracker.id,
        timestamp: widget.player.state.position,
      ),
    );
    final subtract = _TinyBtn(
      icon: Icons.remove_rounded,
      tooltip: 'Subtract ${tracker.label} for ${subject.label}',
      onTap: value > 0
          ? () => ctrl.decrementCounter(
              subjectId: subject.id,
              trackerId: tracker.id,
              timestamp: widget.player.state.position,
            )
          : null,
    );
    final label = Tooltip(
      message: tracker.label,
      child: Text(
        tracker.label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: FlowTheme.text, fontSize: 14),
      ),
    );
    final count = Text(
      '$value',
      style: const TextStyle(
        color: FlowTheme.text,
        fontSize: 14,
        fontWeight: FontWeight.bold,
      ),
    );
    return LayoutBuilder(
      builder: (context, constraints) => constraints.maxWidth < 280
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(child: label),
                    count,
                  ],
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [keyButton, add, subtract],
                ),
              ],
            )
          : Row(
              children: [
                keyButton,
                const SizedBox(width: 8),
                Expanded(child: label),
                count,
                const SizedBox(width: 8),
                add,
                subtract,
              ],
            ),
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

    final keyButton = _HotkeyBadge(
      label: hotkey,
      trackerLabel: tracker.label,
      subjectLabel: subject.label,
      onTap: () => _promptHotkey(ctrl, subject.id, tracker.id),
    );
    final toggle = _TinyBtn(
      icon: running ? Icons.stop_rounded : Icons.play_arrow_rounded,
      tooltip:
          '${running ? 'Stop' : 'Start'} ${tracker.label} for ${subject.label}',
      color: running ? FlowTheme.negative : FlowTheme.positive,
      onTap: () => ctrl.toggleTimer(
        subjectId: subject.id,
        trackerId: tracker.id,
        timestamp: widget.player.state.position,
      ),
    );
    final label = Tooltip(
      message: tracker.label,
      child: Text(
        '${tracker.label} · ${tracker.timerMode == TimerMode.hold ? 'Hold' : 'Toggle'}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: FlowTheme.text, fontSize: 14),
      ),
    );
    final duration = Text(
      _formatDuration(display),
      style: TextStyle(
        color: running ? FlowTheme.positive : FlowTheme.text,
        fontSize: 14,
        fontWeight: FontWeight.bold,
        fontFamily: 'monospace',
      ),
    );
    return LayoutBuilder(
      builder: (context, constraints) => constraints.maxWidth < 260
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (constraints.maxWidth < 160) ...[
                  label,
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FittedBox(fit: BoxFit.scaleDown, child: duration),
                  ),
                ] else
                  Row(
                    children: [
                      Expanded(child: label),
                      duration,
                    ],
                  ),
                Wrap(spacing: 8, runSpacing: 4, children: [keyButton, toggle]),
              ],
            )
          : Row(
              children: [
                keyButton,
                const SizedBox(width: 8),
                Expanded(child: label),
                duration,
                const SizedBox(width: 8),
                toggle,
              ],
            ),
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

  const _SmallIconBtn({required this.icon, required this.tooltip, this.onTap});

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: tooltip,
    onPressed: onTap,
    icon: Icon(icon, size: ToolsetLayout.glyph),
  );
}

class _TinyBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final Color? color;

  const _TinyBtn({
    required this.icon,
    required this.tooltip,
    this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: tooltip,
    onPressed: onTap,
    icon: Icon(
      icon,
      size: ToolsetLayout.glyph,
      color: onTap == null ? Theme.of(context).disabledColor : color,
    ),
  );
}

class _MiniTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final FocusNode? focusNode;
  final String? errorText;
  final ValueChanged<String>? onChanged;
  final TextInputType? keyboardType;

  const _MiniTextField({
    required this.controller,
    required this.label,
    this.focusNode,
    this.errorText,
    this.onChanged,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      keyboardType: keyboardType,
      onChanged: onChanged,
      style: const TextStyle(color: FlowTheme.text, fontSize: 16),
      decoration: InputDecoration(
        labelText: label,
        errorText: errorText,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 14,
        ),
      ),
    );
  }
}

class _HotkeyBadge extends StatelessWidget {
  final String? label;
  final String trackerLabel;
  final String subjectLabel;
  final VoidCallback? onTap;

  const _HotkeyBadge({
    required this.trackerLabel,
    required this.subjectLabel,
    this.label,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: 48,
    child: Tooltip(
      message: label == null
          ? 'Assign hotkey for $trackerLabel, $subjectLabel'
          : 'Change hotkey $label for $trackerLabel, $subjectLabel',
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          padding: EdgeInsets.zero,
          minimumSize: const Size(48, 48),
        ),
        child: Text(
          label?.toUpperCase() ?? 'Key',
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        ),
      ),
    ),
  );
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
    return AdaptiveDialog(
      title: const Text('Select trackers'),
      content: SizedBox(
        width: 420,
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
        TextButton(onPressed: widget.onCancel, child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            final selected = widget.presets
                .where((t) => _selected.contains(t.id))
                .toList();
            widget.onConfirm(selected);
          },
          child: const Text('Apply'),
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
          color: FlowTheme.muted,
          fontSize: 14,
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
      child: CheckboxListTile(
        value: checked,
        onChanged: (value) => setState(() {
          if (value ?? false) {
            _selected.add(t.id);
          } else {
            _selected.remove(t.id);
          }
        }),
        controlAffinity: ListTileControlAffinity.leading,
        contentPadding: const EdgeInsets.symmetric(horizontal: 4),
        title: Text(t.label),
        subtitle: t.kind == TrackerKind.timer
            ? Text(
                t.timerMode == TimerMode.hold ? 'Hold timer' : 'Toggle timer',
              )
            : null,
      ),
    );
  }
}
