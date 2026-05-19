import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../models/game_event.dart';
import '../services/export/export_models.dart';
import '../services/export/export_service.dart';

class ExportDialog extends StatefulWidget {
  final List<GameEvent> selectedEvents;
  final String sourceVideoPath;
  final Duration videoDuration;

  const ExportDialog({
    required this.selectedEvents,
    required this.sourceVideoPath,
    required this.videoDuration,
    super.key,
  });

  @override
  State<ExportDialog> createState() => _ExportDialogState();
}

class _ExportDialogState extends State<ExportDialog> {
  var _config = const ExportConfig();
  final Map<String, bool> _perEventSlowReplay = {};
  ExportProgress? _progress;
  ExportService? _exportService;
  StreamSubscription<ExportProgress>? _exportSub;
  bool _ffmpegAvailable = true;
  bool _showLog = false;
  final _logScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Initialize per-event slow replay toggles
    for (final event in widget.selectedEvents) {
      _perEventSlowReplay[event.id] = false;
    }
    _checkFfmpeg();
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

      return ExportClip(
        event: event,
        startTime: start,
        endTime: end,
        appendSlowReplay: _config.includeSlowReplay ||
            (_perEventSlowReplay[event.id] ?? false),
      );
    }).toList();
  }

  Future<void> _startExport() async {
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
                          _perEventSlowReplay.values.any((v) => v))
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
                            subtitle: event.detail != null
                                ? Text(event.detail!,
                                    style: const TextStyle(fontSize: 12))
                                : null,
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
          Text(
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
        InkWell(
          onTap: () => setState(() => _showLog = !_showLog),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _showLog ? Icons.expand_less : Icons.expand_more,
                size: 18,
                color: Colors.grey,
              ),
              Text(
                _showLog ? 'Hide Log' : 'Show Log (${p.logLines.length} lines)',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
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
                return Text(
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
