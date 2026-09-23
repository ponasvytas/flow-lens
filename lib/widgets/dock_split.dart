import 'dart:math' as math;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Shares one axis while reserving minimums and leaving collapsed items fixed.
List<double> allocateDockSplit({
  required double available,
  required List<double> preferred,
  required List<double> minimums,
  required List<bool> fixed,
  List<double>? fractions,
}) {
  assert(
    preferred.length == minimums.length && fixed.length == preferred.length,
  );
  final sizes = List<double>.filled(preferred.length, 0);
  final flexible = <int>[];
  var remaining = available;
  for (var i = 0; i < sizes.length; i++) {
    if (fixed[i]) {
      sizes[i] = preferred[i];
      remaining -= sizes[i];
    } else {
      flexible.add(i);
    }
  }
  if (flexible.isEmpty) return sizes;
  remaining = math.max(0, remaining);
  final minimumTotal = flexible.fold(0.0, (sum, i) => sum + minimums[i]);
  if (remaining <= minimumTotal) {
    for (final i in flexible) {
      sizes[i] = minimumTotal == 0 ? 0 : minimums[i] * remaining / minimumTotal;
    }
    return sizes;
  }
  final custom =
      fractions != null &&
      fractions.length == sizes.length &&
      fractions.every((v) => v.isFinite && v > 0);
  if (!custom) {
    final total = flexible.fold(0.0, (sum, i) => sum + preferred[i]);
    for (final i in flexible) {
      sizes[i] = total <= remaining
          ? preferred[i] + (remaining - total) / flexible.length
          : minimums[i] +
                (preferred[i] - minimums[i]) *
                    (remaining - minimumTotal) /
                    math.max(1, total - minimumTotal);
    }
    return sizes;
  }
  final pending = [...flexible];
  while (pending.isNotEmpty) {
    final weight = pending.fold(0.0, (sum, i) => sum + fractions[i]);
    final constrained = pending
        .where((i) => remaining * fractions[i] / weight < minimums[i])
        .toList();
    if (constrained.isEmpty) {
      for (final i in pending) {
        sizes[i] = remaining * fractions[i] / weight;
      }
      break;
    }
    for (final i in constrained) {
      sizes[i] = minimums[i];
      remaining -= sizes[i];
      pending.remove(i);
    }
  }
  return sizes;
}

class DockSplit extends StatefulWidget {
  final Axis axis;
  final List<Widget> children;
  final List<String> labels;
  final List<double> preferred;
  final List<double> minimums;
  final List<bool> fixed;
  final List<double>? fractions;
  final ValueChanged<List<double>?> onChanged;
  const DockSplit({
    super.key,
    required this.axis,
    required this.children,
    required this.labels,
    required this.preferred,
    required this.minimums,
    required this.fixed,
    required this.onChanged,
    this.fractions,
  });

  @override
  State<DockSplit> createState() => _DockSplitState();
}

class _DockSplitState extends State<DockSplit> {
  List<double>? _dragSizes;
  List<double>? _startSizes;
  double _startPointer = 0;
  double? _dragAvailable;

  double _coordinate(Offset point) =>
      widget.axis == Axis.horizontal ? point.dx : point.dy;

  void _move(int first, int second, double delta, List<double> sizes) {
    final change = delta.clamp(
      widget.minimums[first] - sizes[first],
      sizes[second] - widget.minimums[second],
    );
    setState(() {
      _dragSizes = [...sizes];
      _dragSizes![first] += change;
      _dragSizes![second] -= change;
    });
  }

  void _finish() {
    final sizes = _dragSizes;
    setState(() {
      _dragSizes = null;
      _startSizes = null;
      _dragAvailable = null;
    });
    if (sizes != null) widget.onChanged(sizes);
  }

  void _cancel() => setState(() {
    _dragSizes = null;
    _startSizes = null;
    _dragAvailable = null;
  });

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final horizontal = widget.axis == Axis.horizontal;
      final available = horizontal
          ? constraints.maxWidth
          : constraints.maxHeight;
      if (_dragAvailable != null && (_dragAvailable! - available).abs() > .5) {
        _dragSizes = null;
        _startSizes = null;
        _dragAvailable = null;
      }
      final sizes =
          _dragSizes ??
          allocateDockSplit(
            available: available,
            preferred: widget.preferred,
            minimums: widget.minimums,
            fixed: widget.fixed,
            fractions: widget.fractions,
          );
      final starts = <double>[];
      var offset = 0.0;
      for (final size in sizes) {
        starts.add(offset);
        offset += size;
      }
      final flexible = [
        for (var i = 0; i < sizes.length; i++)
          if (!widget.fixed[i]) i,
      ];
      return Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          for (var i = 0; i < sizes.length; i++)
            Positioned(
              left: horizontal ? starts[i] : 0,
              top: horizontal ? 0 : starts[i],
              width: horizontal ? sizes[i] : constraints.maxWidth,
              height: horizontal ? constraints.maxHeight : sizes[i],
              child: widget.children[i],
            ),
          for (var pair = 0; pair < flexible.length - 1; pair++)
            () {
              final first = flexible[pair];
              final second = flexible[pair + 1];
              final canResize =
                  sizes[first] + sizes[second] >
                      widget.minimums[first] + widget.minimums[second] + 1 &&
                  sizes[first] >= widget.minimums[first] &&
                  sizes[second] >= widget.minimums[second];
              if (!canResize) return const SizedBox.shrink();
              final position = starts[first] + sizes[first] - 4;
              final label =
                  'Resize ${widget.labels[first]} / ${widget.labels[second]}';
              return Positioned(
                left: horizontal ? position : 4,
                top: horizontal ? 4 : position,
                width: horizontal ? 8 : math.max(0, constraints.maxWidth - 8),
                height: horizontal ? math.max(0, constraints.maxHeight - 8) : 8,
                child: Semantics(
                  label: label,
                  onIncrease: () {
                    _move(first, second, 16, sizes);
                    _finish();
                  },
                  onDecrease: () {
                    _move(first, second, -16, sizes);
                    _finish();
                  },
                  child: Tooltip(
                    message: '$label\nDouble-click to reset sharing',
                    child: MouseRegion(
                      cursor: horizontal
                          ? SystemMouseCursors.resizeColumn
                          : SystemMouseCursors.resizeRow,
                      child: GestureDetector(
                        dragStartBehavior: DragStartBehavior.down,
                        key: ValueKey(
                          'divider-${widget.labels[first]}-${widget.labels[second]}',
                        ),
                        behavior: HitTestBehavior.opaque,
                        onDoubleTap: () => widget.onChanged(null),
                        onPanStart: (details) {
                          _startSizes = [...sizes];
                          _startPointer = _coordinate(details.globalPosition);
                          _dragAvailable = available;
                        },
                        onPanUpdate: (details) {
                          if (_startSizes == null) return;
                          _move(
                            first,
                            second,
                            _coordinate(details.globalPosition) - _startPointer,
                            _startSizes!,
                          );
                        },
                        onPanEnd: (_) => _finish(),
                        onPanCancel: _cancel,
                        child: Listener(
                          behavior: HitTestBehavior.opaque,
                          // An accepted pan may end on pointer cancellation.
                          onPointerCancel: (_) => _cancel(),
                          child: Center(
                            child: Container(
                              width: horizontal ? 2 : 32,
                              height: horizontal ? 32 : 2,
                              decoration: BoxDecoration(
                                color: Colors.white30,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }(),
        ],
      );
    },
  );
}
