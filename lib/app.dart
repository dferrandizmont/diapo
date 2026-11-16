import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/l10n/app_locales.dart';
import 'core/router.dart';
import 'core/settings/settings_provider.dart';
import 'l10n/app_localizations.dart';
import 'review/review_host.dart';

/// The app: the shell that holds the screens and the language of the app.
class CarreteApp extends ConsumerWidget {
  const CarreteApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      // The whole app follows the setting of the theme, the camera too
      // (only the disposable camera keeps its own look).
      theme: ThemeData(useMaterial3: true),
      darkTheme: ThemeData.dark(useMaterial3: true),
      themeMode: settings.themeMode,
      routerConfig: ref.watch(routerProvider),
      builder: (context, child) =>
          ReviewHost(child: child ?? const SizedBox.shrink()),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: appSupportedLocales,
      locale: settings.localeOverride,
    );
  }
}
