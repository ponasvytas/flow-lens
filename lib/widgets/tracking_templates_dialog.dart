import 'package:flutter/material.dart';
import '../controllers/tracking_controller.dart';
import '../controllers/tracking_templates_controller.dart';
import '../models/sport_taxonomy.dart';
import '../models/tracking_models.dart';
import '../models/tracking_template.dart';
import '../services/tracking_template_import_export_service.dart';
import 'adaptive_dialog.dart';

class TrackingTemplatesDialog extends StatefulWidget {
  const TrackingTemplatesDialog({
    super.key,
    required this.tracking,
    required this.library,
    required this.taxonomy,
    required this.position,
  });
  final TrackingController tracking;
  final TrackingTemplatesController library;
  final SportTaxonomy taxonomy;
  final Duration Function() position;

  @override
  State<TrackingTemplatesDialog> createState() =>
      _TrackingTemplatesDialogState();
}

class _TrackingTemplatesDialogState extends State<TrackingTemplatesDialog> {
  final _files = TrackingTemplateImportExportService();
  String? _error;
  bool _busy = false;

  Future<String?> _name(String title, String initial) => showDialog<String>(
    context: context,
    builder: (_) => _TemplateNameDialog(title: title, initial: initial),
  );

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _saveCurrent() async {
    final tracking = widget.tracking;
    final selected = tracking.activeSubjectId;
    final definitions = selected == null
        ? tracking.trackers
        : tracking.trackersForSubject(selected);
    if (definitions.isEmpty) {
      throw StateError('Choose trackers before saving a template.');
    }
    final name = await _name(
      'Save current trackers',
      'My ${widget.taxonomy.name} template',
    );
    if (name == null || !mounted) return;
    final subject = tracking.subjects
        .where((s) => s.id == selected)
        .firstOrNull;
    widget.library.saveCopy(
      TrackingTemplate(
        id: 'current',
        sportId: widget.taxonomy.sportId,
        name: name,
        subjectKind: subject?.kind ?? TrackingSubjectKind.player,
        trackers: definitions,
        sourceTemplateId: tracking.session.templateId,
      ),
      name,
    );
  }

  Future<void> _import() async {
    final template = await _files.importTemplate();
    if (template == null || !mounted) return;
    if (template.sportId != widget.taxonomy.sportId) {
      throw StateError(
        'This template is for ${template.sportId}. Open that sport to import it.',
      );
    }
    widget.library.saveCopy(template, template.name);
  }

  Future<void> _preview(TrackingTemplate template) async {
    final applied = await showDialog<bool>(
      context: context,
      builder: (_) => _ApplyTrackingTemplateDialog(
        template: template,
        tracking: widget.tracking,
        position: widget.position,
      ),
    );
    if (applied != true || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    Navigator.pop(context);
    messenger.showSnackBar(
      SnackBar(
        content: Text('Applied ${template.name}'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () {
            if (!widget.tracking.undoTemplate()) {
              messenger.showSnackBar(
                const SnackBar(
                  content: Text(
                    'Tracking has changed since this template was applied. Recorded data has been kept.',
                  ),
                ),
              );
            }
          },
        ),
      ),
    );
  }

  Future<void> _manage(TrackingTemplate template, String action) async {
    switch (action) {
      case 'export':
        await _files.exportTemplate(template);
      case 'rename':
        final name = await _name('Rename template', template.name);
        if (name != null && mounted) widget.library.rename(template, name);
      case 'duplicate':
        final name = await _name('Duplicate template', '${template.name} copy');
        if (name != null && mounted) widget.library.saveCopy(template, name);
      case 'delete':
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete saved template?'),
            content: const Text(
              'Recorded sessions keep their trackers and observations.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete'),
              ),
            ],
          ),
        );
        if (confirmed == true && mounted) widget.library.delete(template.id);
    }
  }

  Widget _tile(TrackingTemplate template, {required bool saved}) => Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(template.name, style: Theme.of(context).textTheme.titleMedium),
          if (template.description.isNotEmpty) Text(template.description),
          const SizedBox(height: 4),
          Text(
            '${template.trackers.length} trackers · ${template.subjectKind.name}',
          ),
          Wrap(
            spacing: 8,
            children: [
              TextButton(
                onPressed: _busy ? null : () => _run(() => _preview(template)),
                child: const Text('Preview and apply'),
              ),
              PopupMenuButton<String>(
                tooltip: 'Template actions',
                enabled: !_busy,
                onSelected: (action) => _run(() => _manage(template, action)),
                itemBuilder: (_) => [
                  if (widget.library.ready)
                    const PopupMenuItem(
                      value: 'duplicate',
                      child: Text('Save a copy'),
                    ),
                  if (saved && widget.library.ready)
                    const PopupMenuItem(value: 'rename', child: Text('Rename')),
                  const PopupMenuItem(
                    value: 'export',
                    child: Text('Export template'),
                  ),
                  if (saved && widget.library.ready)
                    const PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              ),
            ],
          ),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.library,
    builder: (context, _) {
      final library = widget.library;
      final saved = library.forSport(widget.taxonomy.sportId);
      return AdaptiveDialog(
        title: Text('${widget.taxonomy.name} tracking templates'),
        content: SizedBox(
          width: 560,
          height: 460,
          child: ListView(
            children: [
              const Text(
                'Choose a small set of manual counts or timers. Record events remain separate.',
              ),
              Wrap(
                spacing: 8,
                children: [
                  TextButton.icon(
                    onPressed:
                        _busy ||
                            !library.ready ||
                            widget.tracking.trackers.isEmpty
                        ? null
                        : () => _run(_saveCurrent),
                    icon: const Icon(Icons.bookmark_add_outlined),
                    label: const Text('Save current'),
                  ),
                  TextButton.icon(
                    onPressed: _busy || !library.ready
                        ? null
                        : () => _run(_import),
                    icon: const Icon(Icons.file_open_outlined),
                    label: const Text('Import template'),
                  ),
                ],
              ),
              if (_busy) const Text('Working…'),
              if (_error != null)
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              if (library.error != null) ...[
                Text(
                  library.error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => _run(() async {
                          if (library.ready) {
                            library.retrySave();
                            await library.flushed;
                          } else {
                            await library.load();
                          }
                        }),
                  child: const Text('Retry'),
                ),
              ],
              const SizedBox(height: 8),
              Text('Starters', style: Theme.of(context).textTheme.titleSmall),
              if (widget.taxonomy.trackingTemplates.isEmpty)
                const Text(
                  'No bundled templates for this sport yet. Choose trackers and save your own.',
                ),
              for (final suggestion in widget.taxonomy.trackingTemplates)
                _tile(
                  suggestion.resolve(
                    widget.taxonomy.sportId,
                    widget.taxonomy.trackingPresets,
                  ),
                  saved: false,
                ),
              const SizedBox(height: 8),
              Text(
                'Saved on this device',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              if (!library.ready && library.error == null)
                const LinearProgressIndicator(),
              if (library.ready && saved.isEmpty)
                const Text(
                  'Save a starter copy or your current selection to reuse it.',
                ),
              for (final template in saved) _tile(template, saved: true),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      );
    },
  );
}

class _ApplyTrackingTemplateDialog extends StatefulWidget {
  const _ApplyTrackingTemplateDialog({
    required this.template,
    required this.tracking,
    required this.position,
  });
  final TrackingTemplate template;
  final TrackingController tracking;
  final Duration Function() position;
  @override
  State<_ApplyTrackingTemplateDialog> createState() =>
      _ApplyTrackingTemplateDialogState();
}

class _TemplateNameDialog extends StatefulWidget {
  const _TemplateNameDialog({required this.title, required this.initial});
  final String title;
  final String initial;
  @override
  State<_TemplateNameDialog> createState() => _TemplateNameDialogState();
}

class _TemplateNameDialogState extends State<_TemplateNameDialog> {
  late final _controller = TextEditingController(text: widget.initial);
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: TextField(
      controller: _controller,
      autofocus: true,
      maxLength: 120,
      decoration: const InputDecoration(labelText: 'Template name'),
      onChanged: (_) => setState(() {}),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: _controller.text.trim().isEmpty
            ? null
            : () => Navigator.pop(context, _controller.text.trim()),
        child: const Text('Save'),
      ),
    ],
  );
}

class _ApplyTrackingTemplateDialogState
    extends State<_ApplyTrackingTemplateDialog> {
  late final List<TrackingDefinition> _trackers = [...widget.template.trackers];
  final _name = TextEditingController();
  String? _subjectId;
  bool _replace = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _subjectId =
        widget.tracking.activeSubjectId ??
        widget.tracking.subjects
            .where((s) => s.kind == widget.template.subjectKind)
            .firstOrNull
            ?.id;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _apply() {
    if (_trackers.isEmpty) return;
    if (_subjectId == null && _name.text.trim().isEmpty) {
      setState(() => _error = 'Enter a name or choose an existing subject.');
      return;
    }
    try {
      final changed = !listEqualsById(_trackers, widget.template.trackers);
      final template = changed
          ? widget.template.copyWith(
              id: 'custom:${DateTime.now().microsecondsSinceEpoch}',
              revision: 1,
              trackers: _trackers,
              sourceTemplateId: widget.template.id,
            )
          : widget.template;
      final subject = _subjectId == null
          ? TrackingSubject(
              id: 'subj_${DateTime.now().microsecondsSinceEpoch}',
              label: _name.text.trim(),
              kind: template.subjectKind,
            )
          : null;
      widget.tracking.applyTemplateToSubject(
        template,
        subjectId: _subjectId,
        newSubject: subject,
        replaceVisible: _replace,
        timestamp: widget.position(),
      );
      Navigator.pop(context, true);
    } catch (error) {
      setState(() => _error = error.toString());
    }
  }

  @override
  Widget build(BuildContext context) => AdaptiveDialog(
    title: Text(widget.template.name),
    content: SizedBox(
      width: 520,
      height: 460,
      child: ListView(
        children: [
          Text(widget.template.description),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _subjectId ?? '',
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Track for'),
            items: [
              DropdownMenuItem(
                value: '',
                child: Text('New ${widget.template.subjectKind.name}'),
              ),
              for (final subject in widget.tracking.subjects)
                DropdownMenuItem(
                  value: subject.id,
                  child: Text(subject.label, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: (value) =>
                setState(() => _subjectId = value == '' ? null : value),
          ),
          if (_subjectId == null)
            TextField(
              controller: _name,
              maxLength: 120,
              decoration: InputDecoration(
                labelText: '${widget.template.subjectKind.name} name',
              ),
            ),
          const SizedBox(height: 12),
          const Text('Controls — remove or reorder before applying'),
          for (var index = 0; index < _trackers.length; index++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    _trackers[index].label,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  Text(
                    _trackers[index].definition ??
                        '${_trackers[index].kind.name} tracker',
                  ),
                  Wrap(
                    children: [
                      IconButton(
                        tooltip: 'Move ${_trackers[index].label} up',
                        onPressed: index == 0
                            ? null
                            : () => setState(() {
                                final item = _trackers.removeAt(index);
                                _trackers.insert(index - 1, item);
                              }),
                        icon: const Icon(Icons.arrow_upward),
                      ),
                      IconButton(
                        tooltip: 'Move ${_trackers[index].label} down',
                        onPressed: index == _trackers.length - 1
                            ? null
                            : () => setState(() {
                                final item = _trackers.removeAt(index);
                                _trackers.insert(index + 1, item);
                              }),
                        icon: const Icon(Icons.arrow_downward),
                      ),
                      IconButton(
                        tooltip: 'Remove ${_trackers[index].label}',
                        onPressed: _trackers.length == 1
                            ? null
                            : () => setState(() => _trackers.removeAt(index)),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Replace visible controls'),
            subtitle: const Text(
              'Recorded data stays in the session. Hidden timers stop at the current video position.',
            ),
            value: _replace,
            onChanged: (value) => setState(() => _replace = value),
          ),
          if (_error != null)
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(onPressed: _apply, child: const Text('Apply template')),
    ],
  );
}

bool listEqualsById(List<TrackingDefinition> a, List<TrackingDefinition> b) =>
    a.length == b.length &&
    Iterable<int>.generate(a.length).every((i) => a[i].id == b[i].id);
