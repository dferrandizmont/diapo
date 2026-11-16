import 'dart:async';

import 'package:film_recipes/film_recipes.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../capture/date_stamp.dart';
import '../../core/app_info.dart';
import '../../core/l10n/localized_text.dart';
import '../../core/router.dart';
import '../../core/settings/app_settings.dart';
import '../../core/settings/settings_provider.dart';
import '../../l10n/app_localizations.dart';
import '../../legal/legal_document.dart';
import '../../render/film_resources.dart';
import '../../review/review_service.dart';
import '../../ui/theme/carrete_licence_theme.dart';
import '../../ui/theme/carrete_tokens.dart';
import '../../ui/widgets/carrete_icon.dart';
import '../../ui/widgets/plastic_key.dart';
import '../../ui/widgets/seven_segment.dart';
import '../legal/legal_page.dart';
import '../viewfinder/viewfinder_state.dart';
import 'settings_backup_section.dart';
import 'settings_location_row.dart';
import 'settings_parts.dart';

/// The settings of the app, in the style of proposal A on a screen that
/// follows the theme of the system. It lists only the settings that work:
/// the grid, the level, the camera sounds, the place of the photos, the date
/// style, the default film, the theme, the language and the backup of the
/// settings.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({this.today, super.key});

  /// The date the samples of the date styles show; today when null.
  final DateTime? today;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final palette = CarretePalette.of(context);
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final book = ref.watch(recipeBookProvider);
    final date = today ?? DateTime.now();

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: palette.brightness == Brightness.dark
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: palette.background,
        body: SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: CarreteSizes.settingsMaxWidth,
              ),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  CarreteSpacing.margin,
                  CarreteSpacing.s,
                  CarreteSpacing.margin,
                  CarreteSpacing.xxl,
                ),
                children: [
                  _Header(title: l10n.settingsTitle),
                  const SizedBox(height: CarreteSpacing.l),
                  SettingsSection(
                    title: l10n.settingsSectionCamera,
                    children: [
                      SettingsSwitchRow(
                        label: l10n.settingGrid,
                        value: settings.grid,
                        onChanged: notifier.setGrid,
                      ),
                      SettingsSwitchRow(
                        label: l10n.settingLevel,
                        value: settings.level,
                        onChanged: notifier.setLevel,
                      ),
                      SettingsSwitchRow(
                        label: l10n.settingCameraSounds,
                        value: settings.cameraSounds,
                        onChanged: notifier.setCameraSounds,
                      ),
                      SettingsSwitchRow(
                        label: l10n.settingHaptics,
                        value: settings.haptics,
                        onChanged: notifier.setHaptics,
                      ),
                      SettingsSwitchRow(
                        label: l10n.settingSaveOriginal,
                        hint: l10n.settingSaveOriginalHint,
                        value: settings.saveOriginal,
                        onChanged: notifier.setSaveOriginal,
                      ),
                      const SettingsLocationRow(),
                      SettingsBlock(
                        label: l10n.settingDateStyle,
                        child: _DateStyleTiles(
                          date: date,
                          selected: settings.dateStampStyle,
                          onSelected: notifier.setDateStampStyle,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: CarreteSpacing.xl),
                  SettingsSection(
                    title: l10n.settingDefaultFilm,
                    children: book.when(
                      data: (book) => _filmRows(book, settings, notifier),
                      loading: () => const [
                        SizedBox(height: CarreteSizes.filmRow),
                      ],
                      error: (_, _) => [
                        SettingsNote(text: l10n.filmsLoadFailed),
                      ],
                    ),
                  ),
                  const SizedBox(height: CarreteSpacing.xl),
                  SettingsSection(
                    title: l10n.settingsSectionLook,
                    children: [
                      SettingsBlock(
                        label: l10n.settingTheme,
                        child: SettingsChoiceKeys<ThemeMode>(
                          selected: settings.themeMode,
                          onSelected: notifier.setThemeMode,
                          options: [
                            SettingsChoice(ThemeMode.system, l10n.themeSystem),
                            SettingsChoice(ThemeMode.light, l10n.themeLight),
                            SettingsChoice(ThemeMode.dark, l10n.themeDark),
                          ],
                        ),
                      ),
                      SettingsBlock(
                        label: l10n.settingLanguage,
                        child: SettingsChoiceKeys<Locale?>(
                          columns: 2,
                          selected: settings.localeOverride,
                          onSelected: notifier.setLocaleOverride,
                          options: [
                            SettingsChoice(null, l10n.languageSystem),
                            SettingsChoice(
                              const Locale('es'),
                              l10n.languageSpanish,
                            ),
                            SettingsChoice(
                              const Locale('ca'),
                              l10n.languageCatalan,
                            ),
                            SettingsChoice(
                              const Locale('en'),
                              l10n.languageEnglish,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: CarreteSpacing.xl),
                  SettingsSection(
                    title: l10n.settingsSectionAbout,
                    children: [
                      SettingsValueRow(
                        label: l10n.settingsVersion,
                        value: kAppVersion,
                      ),
                      SettingsNote(text: l10n.settingsOfflineNote),
                      SettingsNote(
                        text: l10n.settingsFreeSoftwareNote,
                        selectable: true,
                      ),
                      SettingsLinkRow(
                        label: l10n.settingsHowItWorks,
                        onTap: () => context.push(AppRoutes.onboarding),
                      ),
                      SettingsLinkRow(
                        label: l10n.settingsPrivacyPolicy,
                        onTap: () =>
                            openLegalPage(context, LegalDocument.privacyPolicy),
                      ),
                      SettingsLinkRow(
                        label: l10n.settingsLegalNotice,
                        onTap: () =>
                            openLegalPage(context, LegalDocument.legalNotice),
                      ),
                      SettingsLinkRow(
                        label: l10n.settingsLicences,
                        onTap: () => _openLicences(context, l10n.appTitle),
                      ),
                      if (_showsRateRow(ref.watch(reviewAppStoreIdProvider)))
                        SettingsActionRow(
                          key: const ValueKey('settings-rate'),
                          label: l10n.settingsRateTitle,
                          hint: l10n.settingsRateSubtitle,
                          onTap: () => unawaited(
                            ref.read(reviewServiceProvider).openStoreListing(),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: CarreteSpacing.xl),
                  const SettingsBackupSection(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// The row that opens the store page shows on Android, and on iOS only once
  /// the app has an App Store id (it has none yet).
  bool _showsRateRow(String? appStoreId) => switch (defaultTargetPlatform) {
    TargetPlatform.android => true,
    TargetPlatform.iOS => appStoreId != null,
    _ => false,
  };

  /// Opens the page of licences of Flutter with the look of the settings. The
  /// theme wraps the page itself, so its list and the detail of a package
  /// (which it opens in a navigator of its own) are themed too.
  void _openLicences(BuildContext context, String appName) {
    final theme = CarreteLicenceTheme.of(CarretePalette.of(context));
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Theme(
          data: theme,
          child: LicensePage(
            applicationName: appName,
            applicationVersion: kAppVersion,
          ),
        ),
      ),
    );
  }

  /// One row per film of the recipe book, so a film added to the JSON is
  /// listed without touching this screen.
  List<Widget> _filmRows(
    RecipeBook book,
    AppSettings settings,
    SettingsNotifier notifier,
  ) {
    // The camera falls back to the first film when the saved one is gone;
    // the list shows the same one as selected.
    final selectedId = selectedRecipe(book, settings.defaultFilmId).id;
    return [
      for (final recipe in book.recipes)
        Builder(
          builder: (context) => SettingsChoiceRow(
            label: recipe.name.of(context),
            swatch: filmBandColor(recipe),
            selected: recipe.id == selectedId,
            onTap: () => notifier.setDefaultFilmId(recipe.id),
          ),
        ),
    ];
  }
}

/// The back key and the title of the page.
class _Header extends StatelessWidget {
  const _Header({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final palette = CarretePalette.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: CarreteSizes.settingsHeader),
      child: Row(
        children: [
          PlasticKey(
            palette: palette,
            semanticLabel: MaterialLocalizations.of(context).backButtonTooltip,
            onPressed: () => Navigator.of(context).maybePop(),
            child: const CarreteIconView(
              icon: CarreteIcon.back,
              size: CarreteSizes.settingsIcon,
            ),
          ),
          const SizedBox(width: CarreteSpacing.l),
          Expanded(
            child: Semantics(
              header: true,
              container: true,
              child: Text(title, style: CarreteText.pageTitle(palette.ink)),
            ),
          ),
        ],
      ),
    );
  }
}

/// The two ways to stamp the date, each shown as the LCD digits it makes
/// with the date of today.
class _DateStyleTiles extends StatelessWidget {
  const _DateStyleTiles({
    required this.date,
    required this.selected,
    required this.onSelected,
  });

  final DateTime date;
  final DateStampStyle selected;
  final ValueChanged<DateStampStyle> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    String nameOf(DateStampStyle style) => switch (style) {
      DateStampStyle.yearFirst => l10n.dateStyleYearFirst,
      DateStampStyle.dayFirst => l10n.dateStyleDayFirst,
    };
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final style in DateStampStyle.values) ...[
          if (style != DateStampStyle.values.first)
            const SizedBox(width: CarreteSpacing.s),
          Expanded(
            child: _DateStyleTile(
              name: nameOf(style),
              sample: DateStamp.format(date, style),
              selected: style == selected,
              onTap: () => onSelected(style),
            ),
          ),
        ],
      ],
    );
  }
}

class _DateStyleTile extends StatelessWidget {
  const _DateStyleTile({
    required this.name,
    required this.sample,
    required this.selected,
    required this.onTap,
  });

  final String name;
  final String sample;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = CarretePalette.of(context);
    final locale = Localizations.localeOf(context);
    return Semantics(
      container: true,
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      label: l10n.dateStyleSemantics(name, sample),
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: CarreteSizes.dateTile,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: CarreteColors.black,
                  borderRadius: BorderRadius.circular(CarreteRadii.key),
                  border: Border.all(
                    color: selected ? palette.accent : CarreteColors.black,
                    width: CarreteSizes.cartridgeBorder,
                  ),
                ),
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: CarreteSpacing.s,
                      ),
                      child: SevenSegmentText(
                        text: sample,
                        height: CarreteSizes.dateTileDigits,
                        color: CarreteColors.date,
                        glow: true,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: CarreteSpacing.xs),
            Text(
              CarreteText.upper(name, locale),
              textAlign: TextAlign.center,
              style: CarreteText.sectionLabel(
                selected ? palette.ink : palette.inkSoft,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
