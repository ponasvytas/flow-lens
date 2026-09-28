import 'package:flutter/widgets.dart';

/// Use the full window so opening the keyboard does not switch layout families.
bool usesPhoneLayout(BuildContext context) {
  final size = MediaQuery.sizeOf(context);
  return size.width < 600 || (size.height < 600 && size.width < 1024);
}

bool usesDialogLayout(BuildContext context, {double minWidth = 600}) {
  final media = MediaQuery.of(context);
  return media.size.width > minWidth &&
      media.size.height - media.padding.vertical - media.viewInsets.vertical >=
          500;
}
