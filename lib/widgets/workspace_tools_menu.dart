import 'package:flutter/material.dart';

import '../controllers/ui_controller.dart';
import '../models/app_mode.dart';
import '../models/dock_layout_state.dart';
import '../models/workspace_tool.dart';

Future<void> showWorkspaceTools(
  BuildContext context,
  UIController controller, {
  required VoidCallback onShortcuts,
}) => showDialog<void>(
  context: context,
  builder: (context) => Dialog(
    insetPadding: const EdgeInsets.all(16),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420, maxHeight: 720),
      child: ListenableBuilder(
        listenable: controller,
        builder: (context, _) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 8, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Tools',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Done',
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final tool in WorkspaceTool.forMode(
                      controller.currentMode,
                    ))
                      CheckboxListTile(
                        key: ValueKey('tool-visibility-${tool.id.name}'),
                        title: Text(tool.title),
                        secondary: Icon(tool.icon),
                        value: controller.panelVisible(tool.id),
                        onChanged: (show) => show == true
                            ? controller.showPanel(tool.id)
                            : controller.hidePanel(tool.id),
                      ),
                    const Divider(),
                    ExpansionTile(
                      title: const Text('Workspace layout'),
                      leading: const Icon(Icons.dashboard_customize_outlined),
                      children: [
                        SwitchListTile(
                          title: const Text('Fit video between panels'),
                          subtitle: const Text(
                            'Turn off to overlay panels on video.',
                          ),
                          value:
                              controller.dockPresentationMode ==
                              DockPresentationMode.squeeze,
                          onChanged: (fit) =>
                              controller.setDockPresentationMode(
                                fit
                                    ? DockPresentationMode.squeeze
                                    : DockPresentationMode.overlay,
                              ),
                        ),
                        if (controller.currentMode == AppMode.record) ...[
                          ListTile(
                            title: const Text('Quick tagging layout'),
                            onTap: () => controller.setFullTagging(false),
                          ),
                          ListTile(
                            title: const Text('Full tagging layout'),
                            onTap: () => controller.setFullTagging(true),
                          ),
                        ],
                        if (controller.currentMode == AppMode.review)
                          ListTile(
                            leading: const Icon(Icons.present_to_all),
                            title: Text(
                              controller.isPresenting
                                  ? 'Exit presentation'
                                  : 'Present',
                            ),
                            onTap: () {
                              controller.togglePresentation();
                              Navigator.pop(context);
                            },
                          ),
                        ListTile(
                          title: const Text('Reset this workflow'),
                          onTap: controller.resetLayout,
                        ),
                        if (controller.canUndoReset)
                          ListTile(
                            leading: const Icon(Icons.undo),
                            title: const Text('Undo layout reset'),
                            onTap: controller.undoReset,
                          ),
                      ],
                    ),
                    ListTile(
                      leading: const Icon(Icons.keyboard_outlined),
                      title: const Text('Keyboard shortcuts'),
                      onTap: () {
                        Navigator.pop(context);
                        onShortcuts();
                      },
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Done'),
              ),
            ),
          ],
        ),
      ),
    ),
  ),
);
