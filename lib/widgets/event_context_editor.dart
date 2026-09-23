import 'package:flutter/material.dart';
import '../models/sport_taxonomy.dart';

class EventContextEditor extends StatelessWidget {
  const EventContextEditor({
    super.key,
    required this.taxonomy,
    required this.categoryId,
    required this.values,
    required this.onChanged,
  });
  final SportTaxonomy taxonomy;
  final String categoryId;
  final Map<String, String> values;
  final ValueChanged<Map<String, String>> onChanged;

  @override
  Widget build(BuildContext context) {
    final fields = taxonomy.fieldsFor(categoryId);
    if (fields.isEmpty) return const SizedBox.shrink();
    void update(String id, String value) {
      final next = Map<String, String>.of(values);
      if (value.trim().isEmpty) {
        next.remove(id);
      } else {
        next[id] = value;
      }
      onChanged(next);
    }

    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: const Text('Event context (optional)'),
      subtitle: Text(
        values.isEmpty
            ? 'Team, player, outcome and coaching notes'
            : '${values.length} details recorded',
      ),
      children: [
        for (final field in fields)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: field.options.isEmpty
                ? TextFormField(
                    key: ValueKey('$categoryId:${field.id}'),
                    initialValue: values[field.id] ?? '',
                    decoration: InputDecoration(
                      labelText: field.name,
                      helperText: field.description.isEmpty
                          ? null
                          : field.description,
                      helperMaxLines: 4,
                    ),
                    onChanged: (value) => update(field.id, value),
                  )
                : DropdownButtonFormField<String>(
                    key: ValueKey('${field.id}:${values[field.id]}'),
                    initialValue: values[field.id] ?? '',
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: field.name,
                      helperText: field.description.isEmpty
                          ? null
                          : field.description,
                      helperMaxLines: 4,
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: '',
                        child: Text('Not recorded'),
                      ),
                      for (final option in {
                        ...field.options,
                        if (values[field.id] != null) values[field.id]!,
                      })
                        DropdownMenuItem(
                          value: option,
                          child: Text(option, overflow: TextOverflow.ellipsis),
                        ),
                    ],
                    onChanged: (value) => update(field.id, value ?? ''),
                  ),
          ),
        for (final entry in values.entries.where(
          (e) => !fields.any((f) => f.id == e.key),
        ))
          ListTile(
            title: Text(entry.key),
            subtitle: Text(entry.value),
            trailing: IconButton(
              tooltip: 'Remove detail',
              onPressed: () => update(entry.key, ''),
              icon: const Icon(Icons.clear),
            ),
          ),
      ],
    );
  }
}
