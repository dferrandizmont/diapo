import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/app_localizations.dart';
import '../../roll/roll_name.dart';
import '../../ui/theme/carrete_tokens.dart';
import 'roll_parts.dart';

/// The name a roll has while the user has not given it one: "Carrete 07".
String rollFallbackName(AppLocalizations l10n, int rollId) =>
    l10n.rollNumberTitle(rollId.toString().padLeft(2, '0'));

/// Asks for the name of a roll in a small dialog in the style of the plates:
/// a field written in the hand of the app, a counter, and two keys.
///
/// Resolves to what the user wrote (an empty text clears the name; the
/// caller cleans it with `normalizeRollName`), or to null when the dialog is
/// cancelled.
Future<String?> showRollNameDialog(
  BuildContext context, {
  required int rollId,
  String? current,
  CarretePalette? palette,
}) {
  final l10n = AppLocalizations.of(context);
  return showDialog<String>(
    context: context,
    builder: (context) => _RollNameDialog(
      tone: RollTone(palette),
      current: current ?? '',
      fallback: rollFallbackName(l10n, rollId),
    ),
  );
}

class _RollNameDialog extends StatefulWidget {
  const _RollNameDialog({
    required this.tone,
    required this.current,
    required this.fallback,
  });

  final RollTone tone;
  final String current;
  final String fallback;

  @override
  State<_RollNameDialog> createState() => _RollNameDialogState();
}

class _RollNameDialogState extends State<_RollNameDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.current,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() => Navigator.of(context).pop(_controller.text);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tone = widget.tone;
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(CarreteRadii.key),
      borderSide: BorderSide(color: tone.line),
    );
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
          label: l10n.rollNameTitle,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: tone.plate,
              borderRadius: BorderRadius.circular(CarreteRadii.panel),
              border: Border.all(color: tone.edge),
              boxShadow: tone.palette == null
                  ? const [CarreteRelief.panel]
                  : null,
            ),
            child: SingleChildScrollView(
              padding: CarreteRoll.sheetPadding,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Semantics(
                    header: true,
                    child: Text(l10n.rollNameTitle, style: tone.title),
                  ),
                  const SizedBox(height: CarreteSpacing.m),
                  TextField(
                    key: const ValueKey('roll-name-field'),
                    controller: _controller,
                    autofocus: true,
                    maxLength: kRollNameMaxLength,
                    maxLengthEnforcement: MaxLengthEnforcement.enforced,
                    // Not a one-line field: Flutter's own one-line filter would drop a pasted
                    // line break without a space; the formatter below turns it into one.
                    maxLines: null,
                    keyboardType: TextInputType.text,
                    textInputAction: TextInputAction.done,
                    textCapitalization: TextCapitalization.sentences,
                    inputFormatters: [
                      FilteringTextInputFormatter.deny(
                        RegExp(r'[\u0000-\u001F\u007F]+'),
                        replacementString: ' ',
                      ),
                    ],
                    cursorColor: tone.active,
                    style: CarreteText.handName(tone.ink),
                    onSubmitted: (_) => _save(),
                    buildCounter:
                        (
                          context, {
                          required currentLength,
                          required isFocused,
                          required maxLength,
                        }) {
                          // What the user sees: grapheme clusters, the unit
                          // of the limit.
                          final count = _controller.text.characters.length;
                          return Semantics(
                            label: l10n.rollNameCounter(count, maxLength!),
                            excludeSemantics: true,
                            child: Text(
                              '$count/$maxLength',
                              style: CarreteText.note(tone.soft),
                            ),
                          );
                        },
                    decoration: InputDecoration(
                      labelText: l10n.rollNameLabel,
                      labelStyle: CarreteText.note(tone.soft),
                      floatingLabelStyle: CarreteText.note(tone.soft),
                      hintText: widget.fallback,
                      hintStyle: CarreteText.handName(tone.soft),
                      border: border,
                      enabledBorder: border,
                      focusedBorder: border.copyWith(
                        borderSide: BorderSide(
                          color: tone.active,
                          width: CarreteSizes.handFieldFocusBorder,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: CarreteSpacing.xs),
                  Text(l10n.rollNameNote(widget.fallback), style: tone.note),
                  const SizedBox(height: CarreteSpacing.l),
                  Row(
                    children: [
                      Expanded(
                        child: RollWideKey(
                          palette: tone.palette,
                          label: l10n.dialogCancel,
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ),
                      const SizedBox(width: CarreteSpacing.s),
                      Expanded(
                        child: RollWideKey(
                          palette: tone.palette,
                          label: l10n.rollNameSave,
                          color: tone.active,
                          onPressed: _save,
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
