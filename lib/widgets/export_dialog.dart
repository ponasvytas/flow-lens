import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import '../models/game_event.dart';
import '../models/sport_taxonomy.dart';
import '../services/export/export_models.dart';
import '../services/export/export_service.dart';
import '../services/export/export_config_store.dart';

class ExportDialog extends StatefulWidget {
  final List<GameEvent> selectedEvents;
  final String sourceVideoPath;
  final Duration videoDuration;
  final SportTaxonomy? taxonomy;

  const ExportDialog({
    required this.selectedEvents,
    required this.sourceVideoPath,
    required this.videoDuration,
    this.taxonomy,
    super.key,
  });

  @override
  State<ExportDialog> createState() => _ExportDialogState();
}

class _ExportDialogState extends State<ExportDialog> {
  var _config = const ExportConfig();
  final Map<String, bool> _perEventSlowReplay = {};
  final Map<String, bool> _perEventLabels = {};
  ExportProgress? _progress;
  ExportService? _exportService;
  StreamSubscription<ExportProgress>? _exportSub;
  bool _ffmpegAvailable = true;
  bool _showLog = false;
  final _logScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Initialize per-event toggles
    for (final event in widget.selectedEvents) {
      _perEventSlowReplay[event.id] = false;
      _perEventLabels[event.id] = false;
    }
    _loadSavedConfig();
    _checkFfmpeg();
  }

  /// Restore the last-used export parameters so the user doesn't have to
  /// re-enter ease-in/out, slow-mo, label and format settings each time.
  Future<void> _loadSavedConfig() async {
    final saved = await ExportConfigStore.load();
    if (mounted) {
      setState(() => _config = saved);
    }
  }

  Future<void> _checkFfmpeg() async {
    if (kIsWeb) {
      setState(() => _ffmpegAvailable = false);
      return;
    }
    final service = ExportService();
    final available = await service.isFfmpegAvailable();
    if (mounted) {
      setState(() => _ffmpegAvailable = available);
    }
  }

  @override
  void dispose() {
    _exportSub?.cancel();
    _logScrollController.dispose();
    // Persist the latest parameters so they're remembered next time.
    ExportConfigStore.save(_config);
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    final h = d.inHours;
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  List<ExportClip> _buildClips() {
    final sorted = List<GameEvent>.from(widget.selectedEvents)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    return sorted.map((event) {
      final easeIn = Duration(
          milliseconds: (_config.easeInSeconds * 1000).round());
      final easeOut = Duration(
          milliseconds: (_config.easeOutSeconds * 1000).round());

      var start = event.timestamp - easeIn;
      if (start < Duration.zero) start = Duration.zero;

      var end = event.timestamp + easeOut;
      if (end > widget.videoDuration) end = widget.videoDuration;

      final appendSlow = _config.includeSlowReplay ||
          (_perEventSlowReplay[event.id] ?? false);

      // Slow-motion replays use their own (typically tighter) window.
      final slowEaseIn = Duration(
          milliseconds: (_config.slowMoEaseInSeconds * 1000).round());
      final slowEaseOut = Duration(
          milliseconds: (_config.slowMoEaseOutSeconds * 1000).round());

      var slowStart = event.timestamp - slowEaseIn;
      if (slowStart < Duration.zero) slowStart = Duration.zero;

      var slowEnd = event.timestamp + slowEaseOut;
      if (slowEnd > widget.videoDuration) slowEnd = widget.videoDuration;

      final showLabel =
          _config.includeLabels || (_perEventLabels[event.id] ?? false);

      return ExportClip(
        event: event,
        startTime: start,
        endTime: end,
        appendSlowReplay: appendSlow,
        slowStartTime: slowStart,
        slowEndTime: slowEnd,
        labelText: showLabel ? _buildLabelText(event) : null,
        labelColor: showLabel ? _impactColor(event.grade) : 'white',
      );
    }).toList();
  }

  String _categoryName(GameEvent event) {
    final cat = widget.taxonomy?.getCategoryById(event.categoryId);
    return cat?.name ?? event.categoryId;
  }

  /// Resolve the specific event-type name (e.g. "Lost", "Goal Against").
  ///
  /// Mirrors EventsTableView: prefer the taxonomy event-type name, then fall
  /// back to the free-text detail, then the raw label.
  String _eventTypeName(GameEvent event) {
    if (event.eventTypeId != null) {
      final eventType = widget.taxonomy?.getEventTypeById(event.eventTypeId!);
      if (eventType != null) return eventType.name;
    }
    return event.detail ?? event.label;
  }

  /// The impact marker appended to the label, depending on the chosen style.
  String _impactSuffix(EventGrade? grade) {
    switch (_config.labelImpactStyle) {
      case LabelImpactStyle.ascii:
        switch (grade) {
          case EventGrade.positive:
            return ' [+]';
          case EventGrade.negative:
            return ' [-]';
          case EventGrade.neutral:
            return ' [=]';
          case null:
            return '';
        }
      case LabelImpactStyle.word:
        switch (grade) {
          case EventGrade.positive:
            return ' (Positive)';
          case EventGrade.negative:
            return ' (Negative)';
          case EventGrade.neutral:
            return ' (Neutral)';
          case null:
            return '';
        }
      case LabelImpactStyle.color:
      case LabelImpactStyle.none:
        return '';
    }
  }

  /// FFmpeg color name for the label text (only varies in `color` style).
  String _impactColor(EventGrade? grade) {
    if (_config.labelImpactStyle != LabelImpactStyle.color) return 'white';
    switch (grade) {
      case EventGrade.positive:
        return 'green';
      case EventGrade.negative:
        return 'red';
      case EventGrade.neutral:
      case null:
        return 'white';
    }
  }

  String _buildLabelText(GameEvent event) {
    return '${_categoryName(event)} - ${_eventTypeName(event)}'
        '${_impactSuffix(event.grade)}';
  }

  /// Human-readable impact/grade word for display in lists.
  String _gradeLabel(EventGrade? grade) {
    switch (grade) {
      case EventGrade.positive:
        return 'Positive';
      case EventGrade.negative:
        return 'Negative';
      case EventGrade.neutral:
        return 'Neutral';
      case null:
        return 'No impact';
    }
  }

  String _positionLabel(LabelPosition p) {
    switch (p) {
      case LabelPosition.topLeft:
        return 'Top Left';
      case LabelPosition.topCenter:
        return 'Top Center';
      case LabelPosition.topRight:
        return 'Top Right';
      case LabelPosition.bottomLeft:
        return 'Bottom Left';
      case LabelPosition.bottomCenter:
        return 'Bottom Center';
      case LabelPosition.bottomRight:
        return 'Bottom Right';
    }
  }

  Future<void> _startExport() async {
    // Persist the chosen parameters immediately so they're remembered even
    // if the app is closed before the dialog is dismissed.
    ExportConfigStore.save(_config);

    // Pick output location
    String? outputPath;
    if (!kIsWeb) {
      outputPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Exported Video',
        fileName:
            'export_${DateTime.now().millisecondsSinceEpoch}.${_config.outputFormat}',
        type: FileType.custom,
        allowedExtensions: [_config.outputFormat],
      );
      if (outputPath == null) return;
      if (!outputPath.endsWith('.${_config.outputFormat}')) {
        outputPath += '.${_config.outputFormat}';
      }
    } else {
      outputPath = 'export.${_config.outputFormat}';
    }

    final clips = _buildClips();
    final job = ExportJob(
      sourceVideoPath: widget.sourceVideoPath,
      clips: clips,
      config: _config,
      outputPath: outputPath,
    );

    _exportService = ExportService();
    _exportSub = _exportService!.export(job).listen(
      (progress) {
        if (mounted) setState(() => _progress = progress);
      },
      onDone: () {
        // done
      },
      onError: (e) {
        if (mounted) {
          setState(() {
            _progress = ExportProgress(
              status: ExportStatus.failed,
              errorMessage: e.toString(),
            );
          });
        }
      },
    );
  }

  void _cancelExport() {
    _exportService?.cancel();
    _exportSub?.cancel();
    setState(() {
      _progress = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isExporting = _progress != null &&
        _progress!.status != ExportStatus.done &&
        _progress!.status != ExportStatus.failed &&
        _progress!.status != ExportStatus.cancelled;

    return Dialog(
      child: SizedBox(
        width: 560,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFF753b8f),
                borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.movie_creation, color: Colors.white),
                  const SizedBox(width: 8),
                  Text(
                    'Export ${widget.selectedEvents.length} Event(s)',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70),
                    onPressed:
                        isExporting ? null : () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            if (!_ffmpegAvailable && !kIsWeb)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                color: Colors.orange.shade100,
                child: const Row(
                  children: [
                    Icon(Icons.warning_amber, color: Colors.orange),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'FFmpeg not found on your system PATH. '
                        'Install FFmpeg to enable video export.',
                        style: TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),

            // Settings body
            if (_progress == null) ...[
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Ease In / Out
                      const Text('Clip Timing',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15)),
                      const SizedBox(height: 8),
                      _buildSlider(
                        label: 'Ease-in (before event)',
                        value: _config.easeInSeconds,
                        min: 0,
                        max: 10,
                        suffix: 's',
                        onChanged: (v) => setState(() {
                          _config = _config.copyWith(
                              easeInSeconds: double.parse(v.toStringAsFixed(1)));
                        }),
                      ),
                      _buildSlider(
                        label: 'Ease-out (after event)',
                        value: _config.easeOutSeconds,
                        min: 0,
                        max: 10,
                        suffix: 's',
                        onChanged: (v) => setState(() {
                          _config = _config.copyWith(
                              easeOutSeconds:
                                  double.parse(v.toStringAsFixed(1)));
                        }),
                      ),

                      const Divider(height: 24),

                      // Slow Replay
                      const Text('Slow-Motion Replay',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15)),
                      const SizedBox(height: 8),
                      SwitchListTile(
                        title: const Text('Enable slow-mo for all clips'),
                        subtitle: const Text(
                            'Append a slow-motion replay after each clip'),
                        value: _config.includeSlowReplay,
                        contentPadding: EdgeInsets.zero,
                        onChanged: (v) => setState(() {
                          _config =
                              _config.copyWith(includeSlowReplay: v);
                        }),
                      ),

                      if (_config.includeSlowReplay ||
                          _perEventSlowReplay.values.any((v) => v)) ...[
                        _buildSlider(
                          label: 'Replay speed',
                          value: _config.slowReplaySpeed,
                          min: 0.1,
                          max: 0.75,
                          suffix: 'x',
                          divisions: 13,
                          onChanged: (v) => setState(() {
                            _config = _config.copyWith(
                                slowReplaySpeed:
                                    double.parse(v.toStringAsFixed(2)));
                          }),
                        ),
                        _buildSlider(
                          label: 'Replay lead-in (before event)',
                          value: _config.slowMoEaseInSeconds,
                          min: 0,
                          max: 10,
                          suffix: 's',
                          onChanged: (v) => setState(() {
                            _config = _config.copyWith(
                                slowMoEaseInSeconds:
                                    double.parse(v.toStringAsFixed(1)));
                          }),
                        ),
                        _buildSlider(
                          label: 'Replay lead-out (after event)',
                          value: _config.slowMoEaseOutSeconds,
                          min: 0,
                          max: 10,
                          suffix: 's',
                          onChanged: (v) => setState(() {
                            _config = _config.copyWith(
                                slowMoEaseOutSeconds:
                                    double.parse(v.toStringAsFixed(1)));
                          }),
                        ),
                        SwitchListTile(
                          title: const Text('Mute slow-mo replays'),
                          subtitle: const Text(
                              'Silence audio on slowed-down replay clips'),
                          value: _config.muteSlowReplay,
                          contentPadding: EdgeInsets.zero,
                          onChanged: (v) => setState(() {
                            _config = _config.copyWith(muteSlowReplay: v);
                          }),
                        ),
                      ],

                      if (!_config.includeSlowReplay) ...[
                        const SizedBox(height: 8),
                        const Text('Or enable per-event:',
                            style: TextStyle(
                                fontSize: 13, color: Colors.grey)),
                        const SizedBox(height: 4),
                        ...widget.selectedEvents.map((event) {
                          return CheckboxListTile(
                            title: Text(
                              '${event.label} @ ${_formatDuration(event.timestamp)}',
                              style: const TextStyle(fontSize: 13),
                            ),
                            subtitle: Text(
                              event.detail != null
                                  ? '${event.detail!}  •  ${_gradeLabel(event.grade)}'
                                  : 'Impact: ${_gradeLabel(event.grade)}',
                              style: const TextStyle(fontSize: 12),
                            ),
                            value: _perEventSlowReplay[event.id] ?? false,
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            onChanged: (v) => setState(() {
                              _perEventSlowReplay[event.id] = v ?? false;
                            }),
                          );
                        }),
                      ],

                      const Divider(height: 24),

                      // Event Labels
                      const Text('Event Labels',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15)),
                      const SizedBox(height: 8),
                      SwitchListTile(
                        title: const Text('Burn labels onto all clips'),
                        subtitle: const Text(
                            'Show "Category - Event" text on each clip'),
                        value: _config.includeLabels,
                        contentPadding: EdgeInsets.zero,
                        onChanged: (v) => setState(() {
                          _config = _config.copyWith(includeLabels: v);
                        }),
                      ),

                      if (_config.includeLabels ||
                          _perEventLabels.values.any((v) => v)) ...[
                        const SizedBox(height: 4),
                        // Impact encoding
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const SizedBox(
                              width: 90,
                              child: Text('Impact',
                                  style: TextStyle(fontSize: 13)),
                            ),
                            Expanded(
                              child: SegmentedButton<LabelImpactStyle>(
                                showSelectedIcon: false,
                                style: const ButtonStyle(
                                  visualDensity: VisualDensity.compact,
                                ),
                                segments: const [
                                  ButtonSegment(
                                      value: LabelImpactStyle.ascii,
                                      label: Text('+/-')),
                                  ButtonSegment(
                                      value: LabelImpactStyle.word,
                                      label: Text('Word')),
                                  ButtonSegment(
                                      value: LabelImpactStyle.color,
                                      label: Text('Color')),
                                  ButtonSegment(
                                      value: LabelImpactStyle.none,
                                      label: Text('None')),
                                ],
                                selected: {_config.labelImpactStyle},
                                onSelectionChanged: (v) => setState(() {
                                  _config = _config.copyWith(
                                      labelImpactStyle: v.first);
                                }),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // Text size
                        Row(
                          children: [
                            const SizedBox(
                              width: 90,
                              child: Text('Text size',
                                  style: TextStyle(fontSize: 13)),
                            ),
                            Expanded(
                              child: SegmentedButton<LabelSize>(
                                showSelectedIcon: false,
                                style: const ButtonStyle(
                                  visualDensity: VisualDensity.compact,
                                ),
                                segments: const [
                                  ButtonSegment(
                                      value: LabelSize.small,
                                      label: Text('Small')),
                                  ButtonSegment(
                                      value: LabelSize.medium,
                                      label: Text('Medium')),
                                  ButtonSegment(
                                      value: LabelSize.large,
                                      label: Text('Large')),
                                ],
                                selected: {_config.labelSize},
                                onSelectionChanged: (v) => setState(() {
                                  _config =
                                      _config.copyWith(labelSize: v.first);
                                }),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // Placement
                        Row(
                          children: [
                            const SizedBox(
                              width: 90,
                              child: Text('Placement',
                                  style: TextStyle(fontSize: 13)),
                            ),
                            Expanded(
                              child: DropdownButton<LabelPosition>(
                                isExpanded: true,
                                value: _config.labelPosition,
                                items: LabelPosition.values
                                    .map((p) => DropdownMenuItem(
                                          value: p,
                                          child: Text(_positionLabel(p),
                                              style:
                                                  const TextStyle(fontSize: 13)),
                                        ))
                                    .toList(),
                                onChanged: (v) => setState(() {
                                  if (v != null) {
                                    _config =
                                        _config.copyWith(labelPosition: v);
                                  }
                                }),
                              ),
                            ),
                          ],
                        ),
                      ],

                      if (!_config.includeLabels) ...[
                        const SizedBox(height: 8),
                        const Text('Or enable per-event:',
                            style: TextStyle(
                                fontSize: 13, color: Colors.grey)),
                        const SizedBox(height: 4),
                        ...widget.selectedEvents.map((event) {
                          return CheckboxListTile(
                            title: Text(
                              '${_buildLabelText(event)} @ ${_formatDuration(event.timestamp)}',
                              style: const TextStyle(fontSize: 13),
                            ),
                            value: _perEventLabels[event.id] ?? false,
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            onChanged: (v) => setState(() {
                              _perEventLabels[event.id] = v ?? false;
                            }),
                          );
                        }),
                      ],

                      const Divider(height: 24),

                      // Transitions
                      _buildSlider(
                        label: 'Fade duration',
                        value: _config.fadeDurationSeconds,
                        min: 0,
                        max: 2,
                        suffix: 's',
                        onChanged: (v) => setState(() {
                          _config = _config.copyWith(
                              fadeDurationSeconds:
                                  double.parse(v.toStringAsFixed(1)));
                        }),
                      ),

                      const SizedBox(height: 8),

                      // Format
                      Row(
                        children: [
                          const Text('Format: ',
                              style: TextStyle(fontWeight: FontWeight.w500)),
                          const SizedBox(width: 8),
                          SegmentedButton<String>(
                            segments: const [
                              ButtonSegment(value: 'mp4', label: Text('MP4')),
                              ButtonSegment(value: 'mov', label: Text('MOV')),
                            ],
                            selected: {_config.outputFormat},
                            onSelectionChanged: (v) => setState(() {
                              _config =
                                  _config.copyWith(outputFormat: v.first);
                            }),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Action buttons
              Container(
                padding: const EdgeInsets.all(12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: _ffmpegAvailable ? _startExport : null,
                      icon: const Icon(Icons.file_download),
                      label: const Text('Export Video'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF753b8f),
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Progress view
            if (_progress != null)
              Padding(
                padding: const EdgeInsets.all(24),
                child: _buildProgressView(),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _copyLog() async {
    final p = _progress;
    if (p == null) return;
    final buffer = StringBuffer();
    if (p.message.isNotEmpty) buffer.writeln(p.message);
    if (p.errorMessage != null) buffer.writeln('ERROR: ${p.errorMessage}');
    if (p.logLines.isNotEmpty) {
      buffer.writeln('--- FFmpeg log ---');
      buffer.writeln(p.logLines.join('\n'));
    }
    await Clipboard.setData(ClipboardData(text: buffer.toString()));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Export log copied to clipboard'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Widget _buildProgressView() {
    final p = _progress!;
    final isDone = p.status == ExportStatus.done;
    final isFailed = p.status == ExportStatus.failed;
    final isCancelled = p.status == ExportStatus.cancelled;
    final isRunning = !isDone && !isFailed && !isCancelled;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isRunning) ...[
          LinearProgressIndicator(
            value: p.overallProgress > 0 ? p.overallProgress : null,
            backgroundColor: Colors.grey[300],
            valueColor:
                const AlwaysStoppedAnimation<Color>(Color(0xFF753b8f)),
          ),
          const SizedBox(height: 16),
        ],
        Icon(
          isDone
              ? Icons.check_circle
              : isFailed
                  ? Icons.error
                  : isCancelled
                      ? Icons.cancel
                      : Icons.movie_creation,
          size: 48,
          color: isDone
              ? Colors.green
              : isFailed
                  ? Colors.red
                  : isCancelled
                      ? Colors.orange
                      : const Color(0xFF753b8f),
        ),
        const SizedBox(height: 12),
        Text(
          p.message,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            color: isFailed ? Colors.red : null,
          ),
        ),
        if (p.errorMessage != null) ...[
          const SizedBox(height: 8),
          SelectableText(
            p.errorMessage!,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: Colors.red),
          ),
        ],
        const SizedBox(height: 16),
        if (isRunning)
          TextButton(
            onPressed: _cancelExport,
            child: const Text('Cancel Export'),
          ),
        if (!isRunning)
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        const SizedBox(height: 8),
        // Collapsible log viewer
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            InkWell(
              onTap: () => setState(() => _showLog = !_showLog),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _showLog ? Icons.expand_less : Icons.expand_more,
                    size: 18,
                    color: Colors.grey,
                  ),
                  Text(
                    _showLog
                        ? 'Hide Log'
                        : 'Show Log (${p.logLines.length} lines)',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
            if (p.logLines.isNotEmpty || p.errorMessage != null) ...[
              const SizedBox(width: 16),
              TextButton.icon(
                onPressed: _copyLog,
                icon: const Icon(Icons.copy, size: 16),
                label: const Text('Copy Log',
                    style: TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  foregroundColor: Colors.grey,
                ),
              ),
            ],
          ],
        ),
        if (_showLog && p.logLines.isNotEmpty)
          Container(
            height: 180,
            margin: const EdgeInsets.only(top: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(6),
            ),
            child: ListView.builder(
              controller: _logScrollController,
              reverse: true,
              itemCount: p.logLines.length,
              padding: const EdgeInsets.all(8),
              itemBuilder: (context, index) {
                final line = p.logLines[p.logLines.length - 1 - index];
                return SelectableText(
                  line,
                  style: const TextStyle(
                    fontSize: 11,
                    fontFamily: 'monospace',
                    color: Color(0xFFCCCCCC),
                    height: 1.4,
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildSlider({
    required String label,
    required double value,
    required double min,
    required double max,
    required String suffix,
    int? divisions,
    required ValueChanged<double> onChanged,
  }) {
    return Row(
      children: [
        SizedBox(
          width: 160,
          child: Text(label, style: const TextStyle(fontSize: 13)),
        ),
        Expanded(
          child: Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions ?? ((max - min) * 10).round(),
            onChanged: onChanged,
          ),
        ),
        SizedBox(
          width: 48,
          child: Text(
            '${value.toStringAsFixed(1)}$suffix',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }
}
