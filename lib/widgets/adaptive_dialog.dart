import 'package:flutter/material.dart';
import '../utils/responsive_layout.dart';

/// Phone editors keep their title and actions reachable above the keyboard.
class AdaptiveDialog extends StatelessWidget {
  const AdaptiveDialog({
    super.key,
    required this.title,
    required this.content,
    this.actions = const [],
  });

  final Widget title;
  final Widget content;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    if (!usesPhoneLayout(context)) {
      return AlertDialog(title: title, content: content, actions: actions);
    }
    return Dialog.fullscreen(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 56,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: DefaultTextStyle(
                    style: Theme.of(context).textTheme.titleLarge!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    child: title,
                  ),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: content,
              ),
            ),
            if (actions.isNotEmpty)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                reverse: true,
                padding: const EdgeInsets.all(8),
                child: Row(spacing: 8, children: actions),
              ),
          ],
        ),
      ),
    );
  }
}
