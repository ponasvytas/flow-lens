import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../controllers/challenges_controller.dart';
import '../models/challenge.dart';
import '../models/game_event.dart';
import '../services/challenge_repository.dart';
import '../utils/player_config.dart';
import '../utils/video_loader.dart';
import 'adaptive_dialog.dart';
import 'challenge_create_page.dart';

class ChallengePlayPage extends StatefulWidget {
  const ChallengePlayPage({
    super.key,
    required this.repository,
    required this.initial,
  });
  final ChallengeRepository repository;
  final ChallengeDetail initial;
  @override
  State<ChallengePlayPage> createState() => _ChallengePlayPageState();
}

class _ChallengePlayPageState extends State<ChallengePlayPage> {
  late final ChallengesController _controller;
  Player? _player;
  VideoController? _videoController;
  StreamSubscription<Duration>? _durationSub;
  StreamSubscription<String>? _errorSub;
  String? _ownedSource;
  String? _videoError;
  String? _loadedName;
  bool _loadingVideo = false;
  bool _loaded = false;
  bool _confirmed = false;
  bool _leaving = false;
  Duration _duration = Duration.zero;
  final _answers = <ChallengeMoment>[];
  final _name = TextEditingController();
  final _submissionForm = GlobalKey<FormState>();
  int _answerSequence = 0;
  Timer? _deadlineTimer;
  late final Stopwatch _elapsed;

  ChallengeDetail get _detail => _controller.detail!;
  VideoChallenge get _challenge => _detail.challenge;
  bool get _matchesDuration =>
      _loaded &&
      _duration.inMilliseconds > 0 &&
      (_duration.inMilliseconds - (_challenge.video.durationMs ?? 0)).abs() <=
          2000;
  bool get _canAnswer =>
      !_challenge.summary.isOwner &&
      _detail.submission == null &&
      !_detail.closed &&
      !_deadlinePassed;
  bool get _deadlinePassed =>
      _challenge.revealAtMs != null &&
      widget.initial.serverNowMs + _elapsed.elapsedMilliseconds >=
          _challenge.revealAtMs!;

  @override
  void initState() {
    super.initState();
    _elapsed = Stopwatch()..start();
    _controller = ChallengesController(widget.repository)
      ..detail = widget.initial;
    final deadline = _challenge.revealAtMs;
    if (deadline != null) {
      final wait = deadline - _detail.serverNowMs;
      if (wait > 0) {
        _deadlineTimer = Timer(Duration(milliseconds: wait + 250), () {
          if (mounted) _controller.open(_challenge.summary.id);
        });
      }
    }
  }

  @override
  void dispose() {
    _deadlineTimer?.cancel();
    _elapsed.stop();
    _durationSub?.cancel();
    _errorSub?.cancel();
    _player?.dispose();
    releaseVideoUrl(_ownedSource);
    _controller.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _pickVideo() async {
    if (_loadingVideo) return;
    try {
      if (kIsWeb) {
        final source = await pickVideoFileWeb();
        if (source == null) return;
        if (!mounted) {
          releaseVideoUrl(source);
          return;
        }
        final identity = videoFileIdentity(source);
        final name = identity == null
            ? 'Selected video'
            : identity.substring(0, identity.lastIndexOf(':'));
        await _loadVideo(source, name: name, owned: true);
      } else {
        final file = await FilePicker.pickFile(type: FileType.video);
        if (!mounted || file == null || file.path == null) return;
        await _loadVideo(file.path!, name: file.name);
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _videoError =
              'Could not open that video. Please choose the file again.',
        );
      }
    }
  }

  Future<void> _loadVideo(
    String source, {
    required String name,
    bool owned = false,
  }) async {
    if (_loadingVideo) {
      if (owned) releaseVideoUrl(source);
      return;
    }
    setState(() {
      _loadingVideo = true;
      _loaded = false;
      _confirmed = false;
      _videoError = null;
    });
    try {
      if (_player == null) {
        final player = Player(
          configuration: PlayerConfiguration(
            title: 'Flow Lens Challenge',
            vo: kIsWeb ? null : 'gpu',
            logLevel: MPVLogLevel.warn,
          ),
        );
        _player = player;
        configureNativePlayer(player);
        _videoController = VideoController(player);
        _durationSub = player.stream.duration.listen((duration) {
          if (mounted) setState(() => _duration = duration);
        });
        _errorSub = player.stream.error.listen((_) {
          if (mounted) {
            setState(() {
              _videoError =
                  'This video could not be played. Check access to the direct video URL, or open a local copy.';
              _loaded = false;
              _confirmed = false;
            });
          }
        });
      }
      final oldSource = _ownedSource;
      _ownedSource = owned ? source : null;
      try {
        await _player!
            .open(Media(source), play: false)
            .timeout(const Duration(seconds: 30));
      } finally {
        if (oldSource != source) releaseVideoUrl(oldSource);
      }
      if (!mounted || _videoError != null) return;
      setState(() {
        _loaded = true;
        _loadedName = name;
        _duration = _player!.state.duration;
      });
      if (_challenge.startMs > 0) await _seek(_challenge.startMs);
    } catch (_) {
      if (owned && _ownedSource != source) releaseVideoUrl(source);
      if (mounted) {
        setState(
          () => _videoError =
              'Could not load the video. Try a direct media URL or a local copy.',
        );
      }
    } finally {
      if (mounted) setState(() => _loadingVideo = false);
    }
  }

  Future<void> _seek(int milliseconds) async {
    if (_player == null || !_loaded) return;
    try {
      await _player!.seek(Duration(milliseconds: milliseconds));
    } catch (_) {
      if (mounted) {
        setState(() => _videoError = 'Could not seek to that moment.');
      }
    }
  }

  Future<void> _capture({int? editIndex}) async {
    final existing = editIndex == null ? null : _answers[editIndex];
    final timestamp =
        existing?.timestampMs ?? _player!.state.position.inMilliseconds;
    if (timestamp < _challenge.startMs || timestamp > _challenge.endMs) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Choose a moment inside the challenge search range.'),
        ),
      );
      return;
    }
    await _player?.pause();
    if (!mounted) return;
    final answer = await showDialog<ChallengeMoment>(
      context: context,
      builder: (_) => _AnswerDialog(
        timestampMs: timestamp,
        existing: existing,
        scoreGrades: _challenge.scoreGrades,
        id: existing?.id ?? 'draft-${++_answerSequence}',
      ),
    );
    if (answer != null && mounted && _canAnswer) {
      setState(() {
        if (editIndex == null) {
          _answers.add(answer);
        } else {
          _answers[editIndex] = answer;
        }
      });
    }
  }

  Future<void> _submit() async {
    if (!_submissionForm.currentState!.validate()) return;
    final confirmed = await _confirm(
      'Submit your answers?',
      'You have ${_answers.length} of ${_challenge.summary.referenceCount} answers. '
          'This is your only scored attempt; submitted answers cannot be changed.',
      'Submit answers',
    );
    if (!confirmed || !mounted) return;
    await _controller.execute({
      'action': 'submit',
      'id': _challenge.summary.id,
      'displayName': _name.text.trim(),
      'videoConfirmed': _confirmed && _matchesDuration,
      'answers': _answers.map((a) => a.toJson()).toList(),
    });
  }

  Future<bool> _confirm(String title, String message, String action) async =>
      await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(action),
            ),
          ],
        ),
      ) ??
      false;

  Future<void> _copyInvitation() async {
    final invitation = ChallengeInvitation(
      _challenge.summary.id,
      _challenge.inviteToken!,
    );
    try {
      await Clipboard.setData(
        ClipboardData(text: invitation.toUri().toString()),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invitation link copied.')),
        );
      }
    } catch (_) {
      if (mounted) {
        await showDialog<void>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Invitation link'),
            content: SelectableText(invitation.toUri().toString()),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      }
    }
  }

  Future<void> _revoke() async {
    if (await _confirm(
          'Revoke this challenge?',
          'The invitation and participant access will stop working. Your copy and submissions remain available to you.',
          'Revoke challenge',
        ) &&
        mounted) {
      await _controller.execute({
        'action': 'revoke',
        'id': _challenge.summary.id,
      });
    }
  }

  Future<void> _accept(
    ChallengeSubmission submission,
    ChallengeMoment answer,
  ) async {
    final reference = await showDialog<ChallengeMoment>(
      context: context,
      builder: (_) => SimpleDialog(
        title: const Text('Accept as an alternative to…'),
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'This answer receives full credit for the selected reference. '
              'Each reference can still count only once.',
            ),
          ),
          for (final r in _detail.references!)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, r),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  '${challengeTime(r.timestampMs)} · ${r.label} · ${challengeGrade(r.grade)}',
                ),
              ),
            ),
        ],
      ),
    );
    if (reference != null && mounted) {
      await _controller.execute({
        'action': 'review',
        'id': _challenge.summary.id,
        'userId': submission.userId,
        'answerId': answer.id,
        'referenceId': reference.id,
      });
    }
  }

  Future<void> _challengeBack() async {
    final moments = _detail.submission!.answers;
    final created = await Navigator.of(context).push<ChallengeDetail>(
      MaterialPageRoute(
        builder: (_) => ChallengeCreatePage(
          repository: widget.repository,
          video: _challenge.video,
          moments: moments
              .map(
                (m) => ChallengeMoment(
                  id: m.id,
                  timestampMs: m.timestampMs,
                  grade: m.grade,
                  label: 'Play',
                  explanation: m.explanation,
                ),
              )
              .toList(),
          sportId: _challenge.sportId,
        ),
      ),
    );
    if (created != null && mounted) {
      await _player?.pause();
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ChallengePlayPage(
            repository: widget.repository,
            initial: created,
          ),
        ),
      );
    }
  }

  Future<void> _leave() async {
    if (_controller.busy) return;
    if (await _confirm(
          'Leave this attempt?',
          'Your unsubmitted answers will be discarded.',
          'Leave',
        ) &&
        mounted) {
      setState(() => _leaving = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pop(context);
      });
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _controller,
    builder: (context, _) => PopScope(
      canPop:
          !_controller.busy &&
          (_leaving || _answers.isEmpty || _detail.submission != null),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_challenge.summary.title),
          actions: [
            IconButton(
              tooltip: 'Refresh challenge',
              onPressed: _controller.busy
                  ? null
                  : () => _controller.open(_challenge.summary.id),
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 960),
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Text(
                    _challenge.prompt,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Chip(
                        label: Text(
                          '${_challenge.summary.referenceCount} hidden moments',
                        ),
                      ),
                      Chip(
                        label: Text(
                          '${challengeTime(_challenge.startMs)}–${challengeTime(_challenge.endMs)}',
                        ),
                      ),
                      Chip(
                        label: Text(
                          'Within ${_challenge.toleranceMs ~/ 1000} seconds',
                        ),
                      ),
                      if (_challenge.summary.revoked)
                        const Chip(label: Text('Revoked')),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _challenge.scoreGrades
                        ? 'One point for finding a moment, plus one for the correct classification. Each moment counts once.'
                        : 'One point for each reference moment you find. Each moment counts once.',
                  ),
                  if (_challenge.revealAtMs case final deadline?)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'Answers close and feedback is released: '
                        '${DateTime.fromMillisecondsSinceEpoch(deadline).toLocal()}',
                      ),
                    ),
                  if (_controller.busy)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: LinearProgressIndicator(),
                    ),
                  if (_controller.error case final error?) _error(error),
                  if (_challenge.summary.isOwner) ...[
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        FilledButton.icon(
                          onPressed:
                              _controller.busy || _challenge.summary.revoked
                              ? null
                              : _copyInvitation,
                          icon: const Icon(Icons.link),
                          label: const Text('Copy invitation link'),
                        ),
                        OutlinedButton(
                          onPressed:
                              _controller.busy || _challenge.summary.revoked
                              ? null
                              : _revoke,
                          child: const Text('Revoke challenge'),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 24),
                  _videoSection(context),
                  const SizedBox(height: 24),
                  if (_canAnswer) _answerSection(context),
                  if (!_challenge.summary.isOwner &&
                      _detail.submission == null &&
                      !_canAnswer)
                    const Text(
                      'This challenge is closed. New answers can no longer be submitted.',
                    ),
                  if (_detail.submission case final submission?) ...[
                    if (submission.result == null)
                      const Card(
                        child: Padding(
                          padding: EdgeInsets.all(20),
                          child: Text(
                            'Answers submitted. Your score and the reference moments will appear after the deadline. '
                            'Use Refresh if they do not appear automatically.',
                          ),
                        ),
                      )
                    else
                      _submissionCard(context, submission),
                    if (submission.result != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: FilledButton.icon(
                          onPressed: _controller.busy ? null : _challengeBack,
                          icon: const Icon(Icons.reply),
                          label: const Text('Challenge back with your moments'),
                        ),
                      ),
                  ],
                  if (_detail.references case final references?) ...[
                    Text(
                      _challenge.summary.isOwner
                          ? 'Your hidden moments'
                          : 'The reference plays',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    for (final reference in references)
                      Card(
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(16),
                          title: Text(
                            '${challengeTime(reference.timestampMs)} · ${reference.label} · ${challengeGrade(reference.grade)}',
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(reference.explanation),
                          ),
                          trailing: _loaded
                              ? IconButton(
                                  tooltip: 'Jump to reference moment',
                                  onPressed: () => _seek(reference.timestampMs),
                                  icon: const Icon(Icons.play_circle_outline),
                                )
                              : null,
                        ),
                      ),
                  ],
                  if (_challenge.summary.isOwner) ...[
                    const SizedBox(height: 24),
                    Text(
                      'Player submissions (${_detail.submissions.length})',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    if (_detail.submissions.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Text(
                          'Share the invitation link. Submitted answers will appear here when you refresh.',
                        ),
                      ),
                    for (final submission in _detail.submissions)
                      _submissionCard(context, submission),
                  ],
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );

  Widget _videoSection(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        _challenge.video.displayName ?? 'Challenge video',
        style: Theme.of(context).textTheme.titleMedium,
      ),
      Text(
        'Expected duration: ${challengeTime(_challenge.video.durationMs ?? 0)}. Use the same recording and cut.',
      ),
      const SizedBox(height: 12),
      if (_videoController != null)
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 420),
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: RepaintBoundary(child: Video(controller: _videoController!)),
          ),
        ),
      if (_loadingVideo) const LinearProgressIndicator(),
      if (_videoError case final error?) _error(error),
      const SizedBox(height: 12),
      Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          if (_challenge.video.externalUrl case final url?)
            FilledButton.icon(
              onPressed: _loadingVideo
                  ? null
                  : () => _loadVideo(
                      url,
                      name: _challenge.video.displayName ?? 'Hosted video',
                    ),
              icon: const Icon(Icons.play_arrow),
              label: const Text('Open hosted video'),
            ),
          OutlinedButton.icon(
            onPressed: _loadingVideo ? null : _pickVideo,
            icon: const Icon(Icons.video_file_outlined),
            label: const Text('Open local video'),
          ),
          if (_loaded)
            TextButton(
              onPressed: () => _seek(_challenge.startMs),
              child: const Text('Go to search start'),
            ),
        ],
      ),
      if (_challenge.video.externalUrl != null)
        const Padding(
          padding: EdgeInsets.only(top: 8),
          child: Text(
            'Hosted playback needs a direct supported video URL. If it fails, download the shared recording and open it locally.',
          ),
        ),
      if (_loaded)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Text(
            'Loaded: $_loadedName · ${challengeTime(_duration.inMilliseconds)}',
          ),
        ),
      if (_loaded && !_matchesDuration)
        _error(
          _duration == Duration.zero
              ? 'Waiting for the video duration. If it stays unavailable, try a local copy.'
              : 'The duration does not match. Load the same recording and cut before answering.',
        ),
      if (_canAnswer)
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('I have the same recording and cut'),
          subtitle: const Text(
            'Check that the video starts at the same point; matching duration alone is not enough.',
          ),
          value: _confirmed,
          onChanged: _matchesDuration && !_controller.busy
              ? (v) => setState(() => _confirmed = v!)
              : null,
        ),
    ],
  );

  Widget _answerSection(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        'Your answers (${_answers.length}/${_challenge.summary.referenceCount})',
        style: Theme.of(context).textTheme.titleLarge,
      ),
      const SizedBox(height: 12),
      if (_player != null)
        StreamBuilder<Duration>(
          stream: _player!.stream.position,
          initialData: _player!.state.position,
          builder: (context, snapshot) => FilledButton.icon(
            onPressed:
                _confirmed &&
                    _matchesDuration &&
                    !_controller.busy &&
                    _answers.length < _challenge.summary.referenceCount
                ? () => _capture()
                : null,
            icon: const Icon(Icons.add_location_alt_outlined),
            label: Text(
              'Tag this moment · ${challengeTime((snapshot.data ?? Duration.zero).inMilliseconds)}',
            ),
          ),
        ),
      for (var i = 0; i < _answers.length; i++)
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '${challengeTime(_answers[i].timestampMs)} · ${challengeGrade(_answers[i].grade)}',
                ),
                if (_answers[i].explanation.isNotEmpty)
                  Text(_answers[i].explanation),
                Wrap(
                  spacing: 8,
                  children: [
                    TextButton(
                      onPressed: _loaded
                          ? () => _seek(_answers[i].timestampMs)
                          : null,
                      child: const Text('Jump to play'),
                    ),
                    TextButton(
                      onPressed: _controller.busy
                          ? null
                          : () => _capture(editIndex: i),
                      child: const Text('Edit'),
                    ),
                    TextButton(
                      onPressed: _controller.busy
                          ? null
                          : () => setState(() => _answers.removeAt(i)),
                      child: const Text('Remove'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      const SizedBox(height: 16),
      Form(
        key: _submissionForm,
        child: TextFormField(
          controller: _name,
          enabled: !_controller.busy,
          maxLength: 60,
          decoration: const InputDecoration(
            labelText: 'Your name for this challenge',
            border: OutlineInputBorder(),
          ),
          validator: (v) => v == null || v.trim().isEmpty
              ? 'Enter a name the creator will recognize.'
              : null,
        ),
      ),
      const SizedBox(height: 12),
      FilledButton(
        onPressed:
            _answers.isNotEmpty &&
                _confirmed &&
                _matchesDuration &&
                !_controller.busy
            ? _submit
            : null,
        child: const Text('Submit answers'),
      ),
      const SizedBox(height: 24),
    ],
  );

  Widget _submissionCard(BuildContext context, ChallengeSubmission submission) {
    final result = submission.result!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${submission.displayName} · ${result.score}/${result.maxScore} points',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              '${result.matches.length} of ${_challenge.summary.referenceCount} reference moments found.',
            ),
            for (final answer in submission.answers)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Builder(
                  builder: (context) {
                    final match = result.matches
                        .where((m) => m.answerId == answer.id)
                        .firstOrNull;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          '${challengeTime(answer.timestampMs)} · ${challengeGrade(answer.grade)} · '
                          '${match == null ? 'No reference match' : '${match.points} point(s)${match.acceptedByCreator ? ' · Accepted by creator' : ''}'}',
                        ),
                        if (answer.explanation.isNotEmpty)
                          Text(answer.explanation),
                        Wrap(
                          spacing: 8,
                          children: [
                            if (_loaded)
                              TextButton(
                                onPressed: () => _seek(answer.timestampMs),
                                child: const Text('Jump to answer'),
                              ),
                            if (_challenge.summary.isOwner)
                              TextButton(
                                onPressed: _controller.busy
                                    ? null
                                    : () => _accept(submission, answer),
                                child: const Text('Accept alternative'),
                              ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _error(String message) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Text(
      message,
      style: TextStyle(color: Theme.of(context).colorScheme.error),
    ),
  );
}

class _AnswerDialog extends StatefulWidget {
  const _AnswerDialog({
    required this.timestampMs,
    required this.id,
    required this.scoreGrades,
    this.existing,
  });
  final int timestampMs;
  final String id;
  final bool scoreGrades;
  final ChallengeMoment? existing;
  @override
  State<_AnswerDialog> createState() => _AnswerDialogState();
}

class _AnswerDialogState extends State<_AnswerDialog> {
  late final TextEditingController _explanation;
  EventGrade? _grade;
  final _form = GlobalKey<FormState>();
  @override
  void initState() {
    super.initState();
    _explanation = TextEditingController(
      text: widget.existing?.explanation ?? '',
    );
    _grade = widget.existing?.grade;
  }

  @override
  void dispose() {
    _explanation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AdaptiveDialog(
    title: Text('Your play at ${challengeTime(widget.timestampMs)}'),
    content: SingleChildScrollView(
      child: SizedBox(
        width: 460,
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<EventGrade>(
                isExpanded: true,
                itemHeight: null,
                initialValue: _grade,
                decoration: InputDecoration(
                  labelText: widget.scoreGrades
                      ? 'Classification'
                      : 'Classification (optional)',
                ),
                items: [
                  for (final g in EventGrade.values)
                    DropdownMenuItem(value: g, child: Text(challengeGrade(g))),
                ],
                onChanged: (value) => _grade = value,
                validator: (v) => widget.scoreGrades && v == null
                    ? 'Choose good, bad, or neutral.'
                    : null,
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _explanation,
                maxLength: 1000,
                minLines: 3,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Why did you choose this play? (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () {
          if (_form.currentState!.validate()) {
            Navigator.pop(
              context,
              ChallengeMoment(
                id: widget.id,
                timestampMs: widget.timestampMs,
                grade: _grade,
                explanation: _explanation.text.trim(),
              ),
            );
          }
        },
        child: const Text('Save answer'),
      ),
    ],
  );
}
