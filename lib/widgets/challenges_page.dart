import 'package:flutter/material.dart';
import '../controllers/account_controller.dart';
import '../controllers/challenges_controller.dart';
import '../models/challenge.dart';
import '../models/cloud_sessions.dart';
import '../services/challenge_repository.dart';
import 'account_view.dart';
import 'challenge_create_page.dart';
import 'challenge_play_page.dart';

class ChallengesPage extends StatelessWidget {
  const ChallengesPage({
    super.key,
    required this.account,
    required this.repository,
    required this.video,
    required this.moments,
    required this.sportId,
    this.invitation,
  });
  final AccountController account;
  final ChallengeRepository? repository;
  final VideoSourceMetadata video;
  final List<ChallengeMoment> moments;
  final String sportId;
  final ChallengeInvitation? invitation;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: account,
    builder: (context, _) {
      if (account.isSignedIn && repository != null) {
        return _ChallengeHub(
          key: ValueKey(account.user!.id),
          repository: repository!,
          video: video,
          moments: moments,
          sportId: sportId,
          invitation: invitation,
        );
      }
      return Scaffold(
        appBar: AppBar(title: const Text('Challenges')),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.flag_outlined, size: 48),
                    const SizedBox(height: 16),
                    Text(
                      'Watch. Find. Learn.',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      repository == null || !account.canAuthenticate
                          ? 'Challenges need a connection to the account service. Reopen the app when it is available.'
                          : 'Sign in with a free account to create challenges, find hidden plays, and challenge a teammate.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    if (repository != null && account.canAuthenticate)
                      FilledButton(
                        onPressed: () => showDialog<void>(
                          context: context,
                          builder: (_) => AccountView(controller: account),
                        ),
                        child: const Text('Sign in or create account'),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

class _ChallengeHub extends StatefulWidget {
  const _ChallengeHub({
    super.key,
    required this.repository,
    required this.video,
    required this.moments,
    required this.sportId,
    this.invitation,
  });
  final ChallengeRepository repository;
  final VideoSourceMetadata video;
  final List<ChallengeMoment> moments;
  final String sportId;
  final ChallengeInvitation? invitation;
  @override
  State<_ChallengeHub> createState() => _ChallengeHubState();
}

class _ChallengeHubState extends State<_ChallengeHub> {
  late final ChallengesController _controller;
  final _link = TextEditingController();
  final _form = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _controller = ChallengesController(widget.repository);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final invitation = widget.invitation;
      if (invitation == null) {
        _controller.refresh();
      } else {
        _link.text = invitation.toUri().toString();
        _join(invitation);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _link.dispose();
    super.dispose();
  }

  Future<void> _showDetail(ChallengeDetail detail) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            ChallengePlayPage(repository: widget.repository, initial: detail),
      ),
    );
    if (mounted) await _controller.refresh();
  }

  Future<void> _join(ChallengeInvitation invitation) async {
    if (await _controller.join(invitation) && mounted) {
      await _showDetail(_controller.detail!);
    }
  }

  Future<void> _open(String id) async {
    if (await _controller.open(id) && mounted) {
      await _showDetail(_controller.detail!);
    }
  }

  Future<void> _create() async {
    final detail = await Navigator.of(context).push<ChallengeDetail>(
      MaterialPageRoute(
        builder: (_) => ChallengeCreatePage(
          repository: widget.repository,
          video: widget.video,
          moments: widget.moments,
          sportId: widget.sportId,
        ),
      ),
    );
    if (detail != null && mounted) await _showDetail(detail);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _controller,
    builder: (context, _) => Scaffold(
      appBar: AppBar(
        title: const Text('Challenges'),
        actions: [
          IconButton(
            tooltip: 'Refresh challenges',
            onPressed: _controller.busy ? null : _controller.refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 860),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  'Watch. Find. Learn.',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Find the hidden plays, understand the decisions, then challenge a teammate.',
                ),
                const SizedBox(height: 24),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Your next challenge',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Tag moments in your video first, then turn selected events into a challenge. '
                          'Free accounts can have five active challenges, with up to 30 participants each.',
                        ),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed:
                              !_controller.busy &&
                                  widget.moments.isNotEmpty &&
                                  (widget.video.durationMs ?? 0) > 0
                              ? _create
                              : null,
                          icon: const Icon(Icons.add),
                          label: const Text('Create from current events'),
                        ),
                        if (widget.moments.isEmpty ||
                            (widget.video.durationMs ?? 0) <= 0)
                          const Padding(
                            padding: EdgeInsets.only(top: 8),
                            child: Text(
                              'Return to the video workspace to load a video and tag your moments.',
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Form(
                  key: _form,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        controller: _link,
                        enabled: !_controller.busy,
                        decoration: const InputDecoration(
                          labelText: 'Challenge invitation link',
                          hintText:
                              'Paste the link a coach or teammate sent you',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) =>
                            ChallengeInvitation.parse(v ?? '') == null
                            ? 'Paste a complete challenge invitation link.'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: _controller.busy
                            ? null
                            : () {
                                if (_form.currentState!.validate()) {
                                  _join(ChallengeInvitation.parse(_link.text)!);
                                }
                              },
                        icon: const Icon(Icons.link),
                        label: const Text('Open invitation'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                if (_controller.busy) const LinearProgressIndicator(),
                if (_controller.error case final error?)
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      error,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                Text(
                  'Your challenges',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                if (_controller.items.isEmpty &&
                    !_controller.busy &&
                    _controller.error == null)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Text(
                      'No challenges yet. Create one or open an invitation to get started.',
                    ),
                  ),
                for (final item in _controller.items)
                  Card(
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      leading: Icon(
                        item.isOwner ? Icons.flag_outlined : Icons.search,
                      ),
                      title: Text(item.title),
                      subtitle: Text(
                        '${item.isOwner ? 'Created by you' : 'Joined'}'
                        ' · ${item.referenceCount} moments${item.revoked ? ' · Revoked' : ''}',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _controller.busy ? null : () => _open(item.id),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
