import 'package:flutter/widgets.dart';

/// Use the full window so opening the keyboard does not switch layout families.
bool usesPhoneLayout(BuildContext context) =>
    MediaQuery.sizeOf(context).shortestSide < 600;

bool usesDialogLayout(BuildContext context, {double minWidth = 600}) {
  final media = MediaQuery.of(context);
  return media.size.width > minWidth &&
      media.size.height - media.padding.vertical - media.viewInsets.vertical >=
          500;
}
