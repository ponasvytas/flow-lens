import 'dart:math' as math;
import 'package:flutter/material.dart';

/// The dock and its contents measure the same contract. Placement never changes
/// target sizes, and labels are measured with the user's actual text scale.
class ToolsetLayout {
  static const target = 48.0;
  static const glyph = 24.0;
  static const gap = 4.0;
  static const padding = 8.0;
  static const labelStyle = TextStyle(
    fontFamily: 'Roboto',
    fontSize: 12,
    height: 1.15,
    fontWeight: FontWeight.w500,
    letterSpacing: 0,
  );

  final List<String>? labels;
  final double tileWidth;
  final double minimumTileWidth;
  final double preferredWidth;
  final double preferredHeight;

  const ToolsetLayout.widget({
    this.preferredWidth = 320,
    this.preferredHeight = 180,
  }) : labels = null,
       tileWidth = target,
       minimumTileWidth = target;

  const ToolsetLayout.actions(
    this.labels, {
    this.tileWidth = target,
    double? minimumTileWidth,
  }) : minimumTileWidth = minimumTileWidth ?? tileWidth,
       preferredWidth = 0,
       preferredHeight = 0;

  bool get isActionSet => labels != null;

  double get idealWidth => labels == null
      ? preferredWidth
      : labels!.length * (tileWidth + gap) - gap + padding * 2;

  ActionGridGeometry measure(double width, TextScaler scaler) {
    final items = labels ?? const <String>[];
    final available = math.max(target, width - padding * 2);
    final columns = math.max(
      1,
      math.min(
        items.length,
        ((available + gap) / (minimumTileWidth + gap)).floor(),
      ),
    );
    final cellWidth = math.max(
      target,
      math.min(tileWidth, (available - (columns - 1) * gap) / columns),
    );
    var height = target;
    for (final label in items) {
      if (label.isEmpty) continue;
      final painter = TextPainter(
        text: TextSpan(text: label, style: labelStyle),
        textDirection: TextDirection.ltr,
        textScaler: scaler,
      )..layout(maxWidth: cellWidth - 8);
      height = math.max(
        height,
        glyph + gap + painter.height.ceilToDouble() + 16,
      );
      painter.dispose();
    }
    final rows = (items.length / columns).ceil();
    return ActionGridGeometry(
      columns,
      cellWidth,
      height,
      rows * (height + gap) - (rows > 0 ? gap : 0) + padding * 2,
    );
  }

  double heightFor(double width, TextScaler scaler) =>
      isActionSet ? measure(width, scaler).height : preferredHeight;
}

class ActionGridGeometry {
  final int columns;
  final double cellWidth;
  final double cellHeight;
  final double height;
  const ActionGridGeometry(
    this.columns,
    this.cellWidth,
    this.cellHeight,
    this.height,
  );
}

class ToolActionGrid extends StatefulWidget {
  final String title;
  final ToolsetLayout layout;
  final List<Widget> children;
  final bool scrollOnOverflow;
  const ToolActionGrid({
    super.key,
    required this.title,
    required this.layout,
    required this.children,
    this.scrollOnOverflow = false,
  });

  @override
  State<ToolActionGrid> createState() => _ToolActionGridState();
}

class _ToolActionGridState extends State<ToolActionGrid> {
  ValueNotifier<ToolActionGrid>? _palette;

  @override
  void didUpdateWidget(ToolActionGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    final palette = _palette;
    if (palette != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && identical(_palette, palette)) palette.value = widget;
      });
    }
  }

  void _expand() {
    final palette = ValueNotifier(widget);
    _palette = palette;
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(widget.title),
        content: SizedBox(
          width: 640,
          child: SingleChildScrollView(
            child: _ExpandedActionPalette(
              child: ValueListenableBuilder<ToolActionGrid>(
                valueListenable: palette,
                builder: (context, grid, _) => ToolActionGrid(
                  title: grid.title,
                  layout: grid.layout,
                  children: grid.children,
                ),
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    ).whenComplete(() {
      if (identical(_palette, palette)) _palette = null;
      palette.dispose();
    });
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final layout = widget.layout;
      final children = widget.children;
      final title = widget.title;
      assert(layout.labels?.length == children.length);
      final geometry = layout.measure(
        constraints.maxWidth,
        MediaQuery.textScalerOf(context),
      );
      // A physically small viewport gets an explicit palette, never half a target.
      if ((!widget.scrollOnOverflow &&
              constraints.hasBoundedHeight &&
              geometry.height > constraints.maxHeight + 0.5) ||
          constraints.maxWidth <
              ToolsetLayout.target + ToolsetLayout.padding * 2) {
        return Center(
          child: Tooltip(
            message: 'Show all $title',
            child: TextButton.icon(
              key: ValueKey('expand-actions-$title'),
              style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
              onPressed: _expand,
              icon: const Icon(Icons.apps, size: ToolsetLayout.glyph),
              label: Text('Show all (${children.length})'),
            ),
          ),
        );
      }
      final content = Align(
        alignment: Alignment.topLeft,
        child: Padding(
          padding: const EdgeInsets.all(ToolsetLayout.padding),
          child: Wrap(
            spacing: ToolsetLayout.gap,
            runSpacing: ToolsetLayout.gap,
            children: [
              for (final child in children)
                SizedBox(
                  width: geometry.cellWidth,
                  height: geometry.cellHeight,
                  child: child,
                ),
            ],
          ),
        ),
      );
      return widget.scrollOnOverflow
          ? SingleChildScrollView(child: content)
          : content;
    },
  );
}

class _ExpandedActionPalette extends InheritedWidget {
  const _ExpandedActionPalette({required super.child});
  @override
  bool updateShouldNotify(_ExpandedActionPalette oldWidget) => false;
}

class ToolActionButton extends StatelessWidget {
  final String label;
  final String? tooltip;
  final IconData icon;
  final Color? color;
  final VoidCallback? onPressed;
  final bool selected;
  final bool dismissPalette;
  const ToolActionButton({
    super.key,
    required this.label,
    required this.icon,
    this.tooltip,
    this.color,
    this.onPressed,
    this.selected = false,
    this.dismissPalette = false,
  });

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip ?? label,
    child: Semantics(
      selected: selected,
      child: OutlinedButton(
        onPressed: onPressed == null
            ? null
            : () {
                if (dismissPalette &&
                    context
                            .getInheritedWidgetOfExactType<
                              _ExpandedActionPalette
                            >() !=
                        null) {
                  Navigator.pop(context);
                }
                onPressed!();
              },
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          foregroundColor: Theme.of(context).colorScheme.onSurface,
          backgroundColor: selected
              ? Theme.of(context).colorScheme.primaryContainer
              : null,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: ToolsetLayout.labelStyle,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: ToolsetLayout.glyph,
              color: onPressed == null ? null : color,
            ),
            if (label.isNotEmpty) ...[
              const SizedBox(height: ToolsetLayout.gap),
              Text(
                label,
                textAlign: TextAlign.center,
                style: ToolsetLayout.labelStyle,
              ),
            ],
          ],
        ),
      ),
    ),
  );
}
