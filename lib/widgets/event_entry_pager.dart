import 'package:flutter/material.dart';
import '../controllers/event_entry_controller.dart';

class EventEntryPager extends StatelessWidget {
  const EventEntryPager({
    super.key,
    required this.page,
    required this.count,
    required this.onChanged,
  });
  final int page;
  final int count;
  final ValueChanged<int>? onChanged;
  @override
  Widget build(BuildContext context) {
    final pages = (count / EventEntryController.pageSize).ceil();
    if (pages <= 1) return const SizedBox.shrink();
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          tooltip: 'Previous choices (Page Up)',
          onPressed: page > 0 && onChanged != null
              ? () => onChanged!(page - 1)
              : null,
          icon: const Icon(Icons.chevron_left),
        ),
        Flexible(
          child: Text(
            '${page + 1} / $pages · PgUp / PgDn',
            textAlign: TextAlign.center,
          ),
        ),
        IconButton(
          tooltip: 'Next choices (Page Down)',
          onPressed: page + 1 < pages && onChanged != null
              ? () => onChanged!(page + 1)
              : null,
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }
}
