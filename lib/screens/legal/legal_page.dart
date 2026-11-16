import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../legal/legal_document.dart';
import '../../legal/legal_markdown.dart';
import '../../ui/theme/carrete_licence_theme.dart';
import '../../ui/theme/carrete_tokens.dart';

/// Opens [document] on a page with the look of the settings (the theme of the
/// page of licences), so the colours, the app bar and the back key match.
void openLegalPage(BuildContext context, LegalDocument document) {
  final theme = CarreteLicenceTheme.of(CarretePalette.of(context));
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => Theme(
        data: theme,
        child: LegalPage(document: document),
      ),
    ),
  );
}

/// A legal text, read from the bundle for the language of the app. Nothing
/// here touches the network.
class LegalPage extends StatefulWidget {
  const LegalPage({required this.document, super.key});

  final LegalDocument document;

  @override
  State<LegalPage> createState() => _LegalPageState();
}

class _LegalPageState extends State<LegalPage> {
  Future<List<MdBlock>>? _blocks;
  String? _asset;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final asset = widget.document.assetFor(Localizations.localeOf(context));
    if (asset != _asset) {
      _asset = asset;
      _blocks = DefaultAssetBundle.of(context)
          .loadString(asset, cache: false)
          .then(parseLegalMarkdown);
    }
  }

  @override
  void didUpdateWidget(LegalPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.document != widget.document) {
      _asset = null;
      didChangeDependencies();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final title = switch (widget.document) {
      LegalDocument.privacyPolicy => l10n.settingsPrivacyPolicy,
      LegalDocument.legalNotice => l10n.settingsLegalNotice,
    };
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        top: false,
        child: FutureBuilder<List<MdBlock>>(
          future: _blocks,
          builder: (context, snapshot) {
            final blocks = snapshot.data;
            if (blocks == null) return const SizedBox.shrink();
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                CarreteSpacing.margin,
                CarreteSpacing.s,
                CarreteSpacing.margin,
                CarreteSpacing.xxl,
              ),
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: CarreteSizes.settingsMaxWidth,
                  ),
                  child: SelectionArea(
                    child: LegalMarkdownView(
                      blocks: blocks,
                      onOpenDocument: (document) =>
                          openLegalPage(context, document),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Draws parsed Markdown blocks with the tokens of the settings.
///
/// Tables are drawn as one small card per row, with the header as the label
/// of each value, so they read on a phone without scrolling sideways. A link
/// to another bundled text calls [onOpenDocument]; any other link shows only
/// its text and is never opened.
class LegalMarkdownView extends StatefulWidget {
  const LegalMarkdownView({
    required this.blocks,
    this.onOpenDocument,
    super.key,
  });

  final List<MdBlock> blocks;
  final ValueChanged<LegalDocument>? onOpenDocument;

  @override
  State<LegalMarkdownView> createState() => _LegalMarkdownViewState();
}

class _LegalMarkdownViewState extends State<LegalMarkdownView> {
  final List<TapGestureRecognizer> _recognizers = [];

  void _disposeRecognizers() {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    _recognizers.clear();
  }

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _disposeRecognizers();
    final palette = CarretePalette.of(context);
    final children = <Widget>[];
    for (final block in widget.blocks) {
      children.add(_block(block, palette));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }

  Widget _block(MdBlock block, CarretePalette palette) {
    switch (block) {
      case MdHeading(:final level, :final spans):
        final style = switch (level) {
          1 => CarreteText.pageTitle(palette.ink),
          2 => CarreteText.setting(palette.ink),
          _ => CarreteText.legalBody(
            palette.ink,
          ).copyWith(fontWeight: FontWeight.w700),
        };
        return Semantics(
          header: true,
          child: Padding(
            padding: EdgeInsets.only(
              top: level == 1 ? CarreteSpacing.s : CarreteSpacing.xl,
              bottom: CarreteSpacing.s,
            ),
            child: Text.rich(_rich(spans, style, palette)),
          ),
        );
      case MdParagraph(:final spans):
        return Padding(
          padding: const EdgeInsets.only(bottom: CarreteSpacing.m),
          child: Text.rich(
            _rich(spans, CarreteText.legalBody(palette.ink), palette),
          ),
        );
      case MdBulletList(:final items):
        return Padding(
          padding: const EdgeInsets.only(bottom: CarreteSpacing.m),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final item in items)
                Padding(
                  padding: const EdgeInsets.only(bottom: CarreteSpacing.s),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: CarreteSpacing.l,
                        child: Text(
                          '•',
                          style: CarreteText.legalBody(palette.inkSoft),
                        ),
                      ),
                      Expanded(
                        child: Text.rich(
                          _rich(
                            item,
                            CarreteText.legalBody(palette.ink),
                            palette,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      case MdTable():
        return Padding(
          padding: const EdgeInsets.only(bottom: CarreteSpacing.m),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final row in block.rows)
                _tableCard(block.header, row, palette),
            ],
          ),
        );
    }
  }

  /// One row of a table: the first cell as the title of the card and each of
  /// the others under the name of its column.
  Widget _tableCard(
    List<List<MdSpan>> header,
    List<List<MdSpan>> row,
    CarretePalette palette,
  ) {
    final body = CarreteText.legalBody(palette.ink);
    return Padding(
      padding: const EdgeInsets.only(bottom: CarreteSpacing.s),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: palette.plate,
          borderRadius: BorderRadius.circular(CarreteRadii.panel),
          border: Border.all(
            color: palette.hairline,
            width: CarreteSizes.hairlineWidth,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(CarreteSizes.plateInset),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text.rich(
                _rich(
                  row.first,
                  body.copyWith(fontWeight: FontWeight.w700),
                  palette,
                ),
              ),
              for (var c = 1; c < row.length; c++)
                if (row[c].isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: CarreteSpacing.s),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text.rich(
                          _rich(
                            header[c],
                            CarreteText.sectionLabel(palette.inkSoft),
                            palette,
                          ),
                        ),
                        const SizedBox(height: CarreteSpacing.xs),
                        Text.rich(_rich(row[c], body, palette)),
                      ],
                    ),
                  ),
            ],
          ),
        ),
      ),
    );
  }

  TextSpan _rich(List<MdSpan> spans, TextStyle base, CarretePalette palette) {
    return TextSpan(
      style: base,
      children: [
        for (final span in spans)
          if (span.code)
            TextSpan(
              text: span.text,
              style: TextStyle(
                fontFamily: CarreteFonts.display,
                fontFamilyFallback: const [CarreteFonts.text],
                fontWeight: span.bold ? FontWeight.w700 : FontWeight.w500,
                fontStyle: span.italic ? FontStyle.italic : null,
                fontSize: (base.fontSize ?? 15) - 1,
                backgroundColor: palette.hairline,
              ),
            )
          else
            _textSpan(span, palette),
      ],
    );
  }

  TextSpan _textSpan(MdSpan span, CarretePalette palette) {
    final document = span.link == null
        ? null
        : LegalDocument.fromLink(span.link!);
    final open = widget.onOpenDocument;
    TapGestureRecognizer? recognizer;
    if (document != null && open != null) {
      recognizer = TapGestureRecognizer()..onTap = () => open(document);
      _recognizers.add(recognizer);
    }
    return TextSpan(
      text: span.text,
      recognizer: recognizer,
      style: TextStyle(
        fontWeight: span.bold ? FontWeight.w700 : null,
        fontStyle: span.italic ? FontStyle.italic : null,
        color: recognizer == null ? null : palette.accent,
        decoration: recognizer == null ? null : TextDecoration.underline,
        decorationColor: recognizer == null ? null : palette.accent,
      ),
    );
  }
}
