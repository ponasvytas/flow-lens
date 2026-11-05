import 'package:flutter/material.dart';
import '../controllers/challenges_controller.dart';
import '../models/challenge.dart';
import '../models/cloud_sessions.dart';
import '../services/challenge_repository.dart';
import 'adaptive_dialog.dart';

class ChallengeCreatePage extends StatefulWidget {
  const ChallengeCreatePage({
    super.key,
    required this.repository,
    required this.video,
    required this.moments,
    required this.sportId,
  });
  final ChallengeRepository repository;
  final VideoSourceMetadata video;
  final List<ChallengeMoment> moments;
  final String sportId;

  @override
  State<ChallengeCreatePage> createState() => _ChallengeCreatePageState();
}

class _ChallengeCreatePageState extends State<ChallengeCreatePage> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _prompt = TextEditingController();
  late final TextEditingController _videoName;
  late final TextEditingController _start;
  late final TextEditingController _end;
  late final Map<String, TextEditingController> _explanations;
  late final Set<String> _selected;
  late final ChallengesController _controller;
  final _requestId = newChallengeRequestId();
  bool _scoreGrades = false;
  int _tolerance = 5;
  DateTime? _deadline;
  String? _validationError;

  @override
  void initState() {
    super.initState();
    _controller = ChallengesController(widget.repository);
    _videoName = TextEditingController(
      text: widget.video.displayName ?? 'Game video',
    );
    _start = TextEditingController(text: '0:00');
    _end = TextEditingController(
      text: challengeTime(widget.video.durationMs ?? 0),
    );
    _explanations = {
      for (final m in widget.moments.take(12))
        m.id: TextEditingController(text: m.explanation),
    };
    _selected = widget.moments.take(12).map((m) => m.id).toSet();
    _scoreGrades = widget.moments
        .where((m) => _selected.contains(m.id))
        .every((m) => m.grade != null);
  }

  @override
  void dispose() {
    _controller.dispose();
    for (final c in [
      _title,
      _prompt,
      _videoName,
      _start,
      _end,
      ..._explanations.values,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _chooseDeadline() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _deadline ?? now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 89)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_deadline ?? now),
    );
    if (time != null && mounted) {
      setState(
        () => _deadline = DateTime(
          date.year,
          date.month,
          date.day,
          time.hour,
          time.minute,
        ),
      );
    }
  }

  Future<void> _create() async {
    final invalid = _form.currentState!.validateGranularly();
    if (invalid.isNotEmpty) {
      setState(() => _validationError = 'Complete the highlighted fields.');
      await Scrollable.ensureVisible(
        invalid.first.context,
        duration: const Duration(milliseconds: 200),
        alignment: 0.1,
      );
      return;
    }
    final start = parseChallengeTime(_start.text)!;
    final duration = widget.video.durationMs!;
    final end = _end.text == challengeTime(duration)
        ? duration
        : parseChallengeTime(_end.text)!;
    final refs = widget.moments
        .where((m) => _selected.contains(m.id))
        .map((m) => m.copyWith(explanation: _explanations[m.id]!.text.trim()))
        .toList();
    String? error;
    if (refs.isEmpty || refs.length > 12) {
      error = 'Choose between 1 and 12 hidden moments.';
    } else if (start >= end || end > duration) {
      error =
          'The search range must fit inside the video, with the end after the start.';
    } else if (refs.any((m) => m.timestampMs < start || m.timestampMs > end)) {
      error = 'Every selected moment must be inside the search range.';
    } else if (_scoreGrades && refs.any((m) => m.grade == null)) {
      error =
          'Classify every selected event first, or turn off classification scoring.';
    } else if (_deadline != null &&
        !_deadline!.isAfter(DateTime.now().add(const Duration(minutes: 1)))) {
      error = 'Choose a deadline at least one minute in the future.';
    }
    setState(() => _validationError = error);
    if (error != null) return;
    final draft = ChallengeDraft(
      title: _title.text.trim(),
      prompt: _prompt.text.trim(),
      sportId: widget.sportId,
      references: refs,
      startMs: start,
      endMs: end,
      video: VideoSourceMetadata(
        kind: widget.video.kind,
        displayName: _videoName.text.trim(),
        externalUrl: widget.video.externalUrl,
        durationMs: duration,
      ),
      scoreGrades: _scoreGrades,
      toleranceMs: _tolerance * 1000,
      revealAtMs: _deadline?.millisecondsSinceEpoch,
    );
    final ok = await _controller.execute({
      'action': 'create',
      'requestId': _requestId,
      'draft': draft.toJson(),
    });
    if (ok && mounted) Navigator.of(context).pop(_controller.detail);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _controller,
    builder: (context, _) => Scaffold(
      appBar: AppBar(title: const Text('Create a challenge')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Form(
              key: _form,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Find the play',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Choose your hidden moments and explain what makes each play worth noticing. '
                      'Participants see the prompt first and your explanations after submitting.',
                    ),
                    const SizedBox(height: 24),
                    _field(
                      _title,
                      'Challenge title',
                      120,
                      hint: 'Read the breakout',
                    ),
                    _field(
                      _prompt,
                      'What should players find?',
                      2000,
                      lines: 3,
                      hint:
                          'Find my two good and two bad breakouts in the second period.',
                    ),
                    _field(_videoName, 'Video name', 200),
                    Text(
                      widget.video.kind == VideoSourceKind.externalUrl
                          ? 'The direct video link will be shared with invited participants.'
                          : 'Participants will need their own copy of this recording, with the same cut.',
                    ),
                    const SizedBox(height: 20),
                    Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      children: [
                        SizedBox(
                          width: 200,
                          child: _timeField(_start, 'Search from (m:ss)'),
                        ),
                        SizedBox(
                          width: 200,
                          child: _timeField(_end, 'Search until (m:ss)'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Hidden moments (${_selected.length}/12)',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const Text(
                      'These are saved as a snapshot. Later edits to your analysis will not change this challenge.',
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: _controller.busy ? null : _chooseMoments,
                      icon: const Icon(Icons.checklist),
                      label: const Text('Choose hidden moments'),
                    ),
                    for (final moment in widget.moments.where(
                      (m) => _selected.contains(m.id),
                    ))
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            children: [
                              CheckboxListTile(
                                contentPadding: EdgeInsets.zero,
                                value: _selected.contains(moment.id),
                                title: Text(
                                  '${challengeTime(moment.timestampMs)} · ${moment.label}',
                                ),
                                subtitle: Text(challengeGrade(moment.grade)),
                                onChanged: _controller.busy
                                    ? null
                                    : (value) => setState(() {
                                        if (value == true) {
                                          _selected.add(moment.id);
                                        } else {
                                          _selected.remove(moment.id);
                                        }
                                      }),
                              ),
                              if (_selected.contains(moment.id))
                                TextFormField(
                                  controller: _explanations[moment.id],
                                  enabled: !_controller.busy,
                                  maxLength: 1000,
                                  minLines: 2,
                                  maxLines: 4,
                                  decoration: const InputDecoration(
                                    labelText: 'What should the player learn?',
                                    border: OutlineInputBorder(),
                                  ),
                                  validator: (v) =>
                                      v == null || v.trim().isEmpty
                                      ? 'Add an explanation for the reveal.'
                                      : null,
                                ),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(height: 20),
                    Text(
                      'Scoring and feedback',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'Score good / bad / neutral classification',
                      ),
                      subtitle: const Text(
                        'One point for finding a moment, plus one for its classification.',
                      ),
                      value: _scoreGrades,
                      onChanged: _controller.busy
                          ? null
                          : (v) => setState(() => _scoreGrades = v),
                    ),
                    DropdownButtonFormField<int>(
                      isExpanded: true,
                      itemHeight: null,
                      initialValue: _tolerance,
                      decoration: const InputDecoration(
                        labelText: 'Timing tolerance',
                      ),
                      items: [
                        for (final seconds in [3, 5, 10, 15, 30])
                          DropdownMenuItem(
                            value: seconds,
                            child: Text('Within $seconds seconds'),
                          ),
                      ],
                      onChanged: _controller.busy
                          ? null
                          : (v) => setState(() => _tolerance = v!),
                    ),
                    const SizedBox(height: 16),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Reveal after a deadline'),
                      subtitle: const Text(
                        'When off, each participant gets feedback immediately after submission.',
                      ),
                      value: _deadline != null,
                      onChanged: _controller.busy
                          ? null
                          : (v) => setState(
                              () => _deadline = v
                                  ? DateTime.now().add(const Duration(days: 1))
                                  : null,
                            ),
                    ),
                    if (_deadline != null)
                      OutlinedButton.icon(
                        onPressed: _controller.busy ? null : _chooseDeadline,
                        icon: const Icon(Icons.schedule),
                        label: Text(
                          'Deadline: ${MaterialLocalizations.of(context).formatMediumDate(_deadline!)} '
                          '${TimeOfDay.fromDateTime(_deadline!).format(context)} (your local time)',
                        ),
                      ),
                    if (_validationError ?? _controller.error case final error?)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Text(
                          error,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: _controller.busy ? null : _create,
                      icon: _controller.busy
                          ? const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.flag_outlined),
                      label: Text(
                        _controller.busy ? 'Creating…' : 'Create challenge',
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );

  Future<void> _chooseMoments() async {
    final selection = Set<String>.from(_selected);
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => AdaptiveDialog(
          title: Text('Choose moments (${selection.length}/12)'),
          content: SizedBox(
            width: 600,
            height: 420,
            child: ListView.builder(
              itemCount: widget.moments.length,
              itemBuilder: (context, index) {
                final moment = widget.moments[index];
                final checked = selection.contains(moment.id);
                return CheckboxListTile(
                  value: checked,
                  title: Text(
                    '${challengeTime(moment.timestampMs)} · ${moment.label}',
                  ),
                  subtitle: Text(challengeGrade(moment.grade)),
                  onChanged: !checked && selection.length >= 12
                      ? null
                      : (value) => update(() {
                          if (value == true) {
                            selection.add(moment.id);
                          } else {
                            selection.remove(moment.id);
                          }
                        }),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: selection.isEmpty
                  ? null
                  : () => Navigator.pop(context, true),
              child: const Text('Use selected moments'),
            ),
          ],
        ),
      ),
    );
    if (accepted == true && mounted) {
      setState(() {
        _selected
          ..clear()
          ..addAll(selection);
        for (final m in widget.moments.where((m) => selection.contains(m.id))) {
          _explanations.putIfAbsent(
            m.id,
            () => TextEditingController(text: m.explanation),
          );
        }
      });
    }
  }

  Widget _field(
    TextEditingController controller,
    String label,
    int max, {
    int lines = 1,
    String? hint,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: TextFormField(
      controller: controller,
      enabled: !_controller.busy,
      maxLength: max,
      minLines: lines,
      maxLines: lines + 1,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: const OutlineInputBorder(),
      ),
      validator: (v) => v == null || v.trim().isEmpty
          ? 'Enter ${label.toLowerCase()}.'
          : null,
    ),
  );

  Widget _timeField(TextEditingController controller, String label) =>
      TextFormField(
        controller: controller,
        enabled: !_controller.busy,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        validator: (v) => parseChallengeTime(v ?? '') == null
            ? 'Use minutes:seconds, such as 20:00.'
            : null,
      );
}
