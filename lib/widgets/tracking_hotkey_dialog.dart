import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../controllers/tracking_controller.dart';

Future<void> showTrackingHotkeyDialog({
  required BuildContext context,
  required TrackingController controller,
  required String subjectId,
  required String trackerId,
}) async {
  final workspaceFocus = Focus.of(context);
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => _HotkeyDialog(
      currentKey: controller.getHotkey(subjectId, trackerId),
      validate: (key) => controller.hotkeyError(subjectId, trackerId, key),
      onSet: (key) {
        if (controller.setHotkey(subjectId, trackerId, key)) {
          Navigator.pop(dialogContext);
        }
      },
      onClear: () {
        controller.removeHotkey(subjectId, trackerId);
        Navigator.pop(dialogContext);
      },
      onCancel: () => Navigator.pop(dialogContext),
    ),
  );
  // A dismissed dialog can leave focus on the route scope or a text field.
  if (context.mounted) workspaceFocus.requestFocus();
}

// ===========================================================================
// Hotkey assignment dialog
// ===========================================================================

class _HotkeyDialog extends StatefulWidget {
  final String? currentKey;
  final String? Function(String) validate;
  final ValueChanged<String> onSet;
  final VoidCallback onClear;
  final VoidCallback onCancel;

  const _HotkeyDialog({
    this.currentKey,
    required this.validate,
    required this.onSet,
    required this.onClear,
    required this.onCancel,
  });

  @override
  State<_HotkeyDialog> createState() => _HotkeyDialogState();
}

class _HotkeyDialogState extends State<_HotkeyDialog> {
  String? _captured;
  String? _error;

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.escape) {
            widget.onCancel();
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.tab) {
            return KeyEventResult.ignored;
          }
          if (event.logicalKey == LogicalKeyboardKey.enter &&
              _captured != null) {
            widget.onSet(_captured!);
            return KeyEventResult.handled;
          }
          final keyboard = HardwareKeyboard.instance;
          final label = event.logicalKey.keyLabel.toLowerCase();
          final error =
              keyboard.isAltPressed ||
                  keyboard.isControlPressed ||
                  keyboard.isMetaPressed ||
                  keyboard.isShiftPressed
              ? 'Use a key without Shift, Ctrl, Alt, or Command.'
              : widget.validate(label);
          setState(() {
            _error = error;
            _captured = error == null ? label : null;
          });
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: AlertDialog(
        backgroundColor: const Color(0xFF1E1E2E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Colors.white12),
        ),
        title: const Text(
          'Assign Hotkey',
          style: TextStyle(color: Colors.white, fontSize: 14),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.currentKey != null)
                Text(
                  'Current: ${widget.currentKey!.toUpperCase()}',
                  style: const TextStyle(color: Colors.white38, fontSize: 12),
                ),
              const SizedBox(height: 12),
              Container(
                width: 60,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.black38,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _captured != null
                        ? Colors.blueAccent
                        : Colors.white24,
                    width: 2,
                  ),
                ),
                child: Center(
                  child: Text(
                    _captured?.toUpperCase() ?? '?',
                    style: TextStyle(
                      color: _captured != null ? Colors.white : Colors.white24,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Press a letter or number. Playback keys are reserved.',
                style: TextStyle(color: Colors.white38, fontSize: 11),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: const TextStyle(color: Colors.redAccent)),
              ],
            ],
          ),
        ),
        actionsAlignment: MainAxisAlignment.spaceBetween,
        actions: [
          TextButton(
            onPressed: widget.onClear,
            child: const Text(
              'Clear',
              style: TextStyle(color: Colors.redAccent, fontSize: 12),
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton(
                onPressed: widget.onCancel,
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Colors.white38, fontSize: 12),
                ),
              ),
              TextButton(
                onPressed: _captured != null
                    ? () => widget.onSet(_captured!)
                    : null,
                child: const Text('Assign', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
