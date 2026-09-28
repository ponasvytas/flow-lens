import 'package:flutter/material.dart';
import '../utils/responsive_layout.dart';

import '../models/cloud_sessions.dart';
import '../services/event_session_repository.dart';
import '../services/tracking_session_repository.dart';

typedef SaveCloudSession = Future<void> Function(String title, bool asNew);

class CloudSessionsView extends StatefulWidget {
  const CloudSessionsView({
    required this.eventRepository,
    required this.trackingRepository,
    required this.onSaveEvents,
    required this.onSaveTracking,
    required this.onLoadEvents,
    required this.onLoadTracking,
    this.activeEventSessionId,
    this.activeEventTitle,
    this.activeTrackingSessionId,
    this.activeTrackingTitle,
    this.onEventArchived,
    this.onTrackingArchived,
    super.key,
  });

  final EventSessionRepository eventRepository;
  final TrackingSessionRepository trackingRepository;
  final SaveCloudSession? onSaveEvents;
  final SaveCloudSession? onSaveTracking;
  final ValueChanged<CloudEventSession> onLoadEvents;
  final ValueChanged<CloudTrackingSession> onLoadTracking;
  final String? activeEventSessionId;
  final String? activeEventTitle;
  final String? activeTrackingSessionId;
  final String? activeTrackingTitle;
  final ValueChanged<String>? onEventArchived;
  final ValueChanged<String>? onTrackingArchived;

  @override
  State<CloudSessionsView> createState() => _CloudSessionsViewState();
}

class _CloudSessionsViewState extends State<CloudSessionsView> {
  List<CloudEventSession> _eventSessions = const [];
  List<CloudTrackingSession> _trackingSessions = const [];
  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final content = Column(
      children: [
        _buildHeader(context),
        const Divider(height: 1),
        if (_error case final error?)
          MaterialBanner(
            content: Text(error),
            actions: [
              TextButton(onPressed: _refresh, child: const Text('Retry')),
            ],
          ),
        Expanded(
          child: DefaultTabController(
            length: 2,
            child: Column(
              children: [
                const TabBar(
                  tabs: [
                    Tab(text: 'Event timelines'),
                    Tab(text: 'Tracking'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [_buildEventTab(), _buildTrackingTab()],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );

    if (usesDialogLayout(context, minWidth: 700)) {
      return Dialog(child: SizedBox(width: 760, height: 640, child: content));
    }
    return Scaffold(body: SafeArea(child: content));
  }

  Widget _buildHeader(BuildContext context) => Padding(
    padding: const EdgeInsets.all(16),
    child: Row(
      children: [
        const Icon(Icons.cloud, size: 28),
        const SizedBox(width: 12),
        const Text(
          'Cloud sessions',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const Spacer(),
        IconButton(
          onPressed: _busy ? null : _refresh,
          tooltip: 'Refresh',
          icon: const Icon(Icons.refresh),
        ),
        IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close),
        ),
      ],
    ),
  );

  Widget _buildEventTab() => _buildTab<CloudEventSession>(
    onSave: widget.onSaveEvents,
    activeId: widget.activeEventSessionId,
    activeTitle: widget.activeEventTitle,
    emptyMessage: 'No cloud event timelines yet.',
    sessions: _eventSessions,
    title: (session) => session.title,
    subtitle: (session) =>
        '${session.events.length} events • ${_date(session.updatedAt)}',
    id: (session) => session.id,
    onLoad: (session) {
      widget.onLoadEvents(session);
      Navigator.of(context).pop();
    },
    onArchive: (session) async {
      await widget.eventRepository.archive(session.id);
      widget.onEventArchived?.call(session.id);
    },
    onDelete: (session) => widget.eventRepository.delete(session.id),
  );

  Widget _buildTrackingTab() => _buildTab<CloudTrackingSession>(
    onSave: widget.onSaveTracking,
    activeId: widget.activeTrackingSessionId,
    activeTitle: widget.activeTrackingTitle,
    emptyMessage: 'No cloud tracking sessions yet.',
    sessions: _trackingSessions,
    title: (session) => session.title,
    subtitle: (session) =>
        '${session.session.subjects.length} subjects, '
        '${session.session.events.length} events • ${_date(session.updatedAt)}',
    id: (session) => session.id,
    onLoad: (session) {
      widget.onLoadTracking(session);
      Navigator.of(context).pop();
    },
    onArchive: (session) async {
      await widget.trackingRepository.archive(session.id);
      widget.onTrackingArchived?.call(session.id);
    },
    onDelete: (session) => widget.trackingRepository.delete(session.id),
  );

  Widget _buildTab<T>({
    required SaveCloudSession? onSave,
    required String? activeId,
    required String? activeTitle,
    required String emptyMessage,
    required List<T> sessions,
    required String Function(T) title,
    required String Function(T) subtitle,
    required String Function(T) id,
    required ValueChanged<T> onLoad,
    required Future<void> Function(T) onArchive,
    required Future<void> Function(T) onDelete,
  }) {
    return Column(
      children: [
        if (onSave != null)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (activeId != null)
                  FilledButton.icon(
                    onPressed: _busy
                        ? null
                        : () => _save(onSave, activeTitle ?? 'Session', false),
                    icon: const Icon(Icons.cloud_upload),
                    label: const Text('Update loaded session'),
                  ),
                OutlinedButton.icon(
                  onPressed: _busy
                      ? null
                      : () => _promptAndSave(onSave, activeTitle),
                  icon: const Icon(Icons.add),
                  label: Text(
                    activeId == null ? 'Save current' : 'Save as new',
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : sessions.isEmpty
              ? Center(child: Text(emptyMessage))
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                  itemCount: sessions.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final session = sessions[index];
                    final isActive = id(session) == activeId;
                    return ListTile(
                      leading: Icon(
                        isActive ? Icons.cloud_done : Icons.cloud_outlined,
                      ),
                      title: Text(title(session)),
                      subtitle: Text(subtitle(session)),
                      onTap: () => onLoad(session),
                      trailing: PopupMenuButton<String>(
                        enabled: !_busy,
                        onSelected: (action) async {
                          if (action == 'archive') {
                            await _run(() => onArchive(session));
                          } else if (action == 'delete' &&
                              await _confirmDelete(title(session))) {
                            await _run(() => onDelete(session));
                          }
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(
                            value: 'archive',
                            child: Text('Archive'),
                          ),
                          PopupMenuItem(
                            value: 'delete',
                            child: Text('Delete permanently'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        widget.eventRepository.list(),
        widget.trackingRepository.list(),
      ]);
      if (!mounted) return;
      setState(() {
        _eventSessions = results[0] as List<CloudEventSession>;
        _trackingSessions = results[1] as List<CloudTrackingSession>;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load cloud sessions: $error';
      });
    }
  }

  Future<void> _promptAndSave(
    SaveCloudSession onSave,
    String? currentTitle,
  ) async {
    final controller = TextEditingController(text: currentTitle ?? 'Session');
    final title = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Session title'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 120,
          onSubmitted: (value) => Navigator.of(context).pop(value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (title == null || title.isEmpty) return;
    await _save(onSave, title, true);
  }

  Future<void> _save(SaveCloudSession onSave, String title, bool asNew) =>
      _run(() => onSave(title, asNew));

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      await _refresh();
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = 'Cloud session operation failed: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _confirmDelete(String title) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Delete cloud session?'),
          content: Text('“$title” will be permanently deleted.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete'),
            ),
          ],
        ),
      ) ??
      false;

  String _date(DateTime value) =>
      '${value.year}-${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}
