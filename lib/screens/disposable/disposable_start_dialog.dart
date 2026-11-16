import 'package:flutter/material.dart';

import '../../core/database/tables.dart';
import '../../l10n/app_localizations.dart';
import '../../roll/disposable.dart';
import '../../ui/theme/carrete_tokens.dart';
import '../roll/roll_parts.dart';

/// Asks how long the disposable camera waits to develop and warns that the
/// screen will be locked. Resolves to the delay, or null when cancelled.
///
/// It opens over the camera of design A, so it is in the style of the plates
/// of the roll sheet.
Future<DevelopDelay?> showDisposableStart(BuildContext context) {
  return showDialog<DevelopDelay>(
    context: context,
    builder: (context) => const _DisposableStart(),
  );
}

class _DisposableStart extends StatefulWidget {
  const _DisposableStart();

  @override
  State<_DisposableStart> createState() => _DisposableStartState();
}

class _DisposableStartState extends State<_DisposableStart> {
  DevelopDelay _delay = kDisposableDefaultDelay;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    const tone = RollTone(null);
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.all(CarreteRoll.dialogInset),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: CarreteRoll.dialogMaxWidth),
        child: Semantics(
          container: true,
          explicitChildNodes: true,
          scopesRoute: true,
          namesRoute: true,
          label: l10n.disposableStartTitle,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: tone.plate,
              borderRadius: BorderRadius.circular(CarreteRadii.panel),
              border: Border.all(color: tone.edge),
              boxShadow: const [CarreteRelief.panel],
            ),
            child: SingleChildScrollView(
              padding: CarreteRoll.sheetPadding,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Semantics(
                    header: true,
                    child: Text(l10n.disposableStartTitle, style: tone.title),
                  ),
                  const SizedBox(height: CarreteSpacing.s),
                  Text(l10n.disposableStartBody, style: tone.note),
                  const SizedBox(height: CarreteSpacing.xs),
                  Text(l10n.rollLossWarning, style: tone.note),
                  const SizedBox(height: CarreteSpacing.l),
                  Semantics(
                    container: true,
                    child: Text(l10n.rollDelayLabel, style: CarreteText.row),
                  ),
                  const SizedBox(height: CarreteSpacing.s),
                  RollChoiceKeys<DevelopDelay>(
                    columns: 2,
                    selected: _delay,
                    onSelected: (v) => setState(() => _delay = v),
                    options: [
                      for (final d in DevelopDelay.values)
                        RollChoice(d, delayName(l10n, d)),
                    ],
                  ),
                  const SizedBox(height: CarreteSpacing.l),
                  Row(
                    children: [
                      Expanded(
                        child: RollWideKey(
                          label: l10n.dialogCancel,
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ),
                      const SizedBox(width: CarreteSpacing.s),
                      Expanded(
                        child: RollWideKey(
                          label: l10n.disposableStartAction,
                          color: tone.warn,
                          onPressed: () => Navigator.of(context).pop(_delay),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
