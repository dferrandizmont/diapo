import 'package:flutter/material.dart';

import '../../ui/theme/carrete_tokens.dart';

/// Shows [text] in a snack bar styled like the plates of the settings. Pass
/// the [messenger] and the [palette] read before an `await`, so no context is
/// used after a gap.
void showSettingsSnack(
  ScaffoldMessengerState messenger,
  CarretePalette palette,
  String text, {
  SnackBarAction? action,
  Duration duration = CarreteDurations.snack,
}) {
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        backgroundColor: palette.plate,
        duration: duration,
        action: action,
        content: Text(text, style: CarreteText.note(palette.ink)),
      ),
    );
}
