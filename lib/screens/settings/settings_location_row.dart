import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/settings/settings_provider.dart';
import '../../l10n/app_localizations.dart';
import '../../location/location_provider.dart';
import '../../platform/system_settings.dart';
import '../../ui/theme/carrete_tokens.dart';
import 'settings_parts.dart';
import 'settings_snack.dart';

/// The switch "Save location". Turning it on is the only place that asks for
/// the location permission (an explicit opt-in); turning it off never opens a
/// dialog. When the setting is on but the permission was removed afterwards,
/// the row says so and offers the system settings.
class SettingsLocationRow extends ConsumerStatefulWidget {
  const SettingsLocationRow({super.key});

  @override
  ConsumerState<SettingsLocationRow> createState() =>
      _SettingsLocationRowState();
}

class _SettingsLocationRowState extends ConsumerState<SettingsLocationRow>
    with WidgetsBindingObserver {
  bool _requesting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Back from the system settings: look at the permission again (this never
    // asks for it).
    if (state == AppLifecycleState.resumed &&
        ref.read(settingsProvider).saveLocation) {
      ref.read(locationControllerProvider).refreshPermission();
    }
  }

  Future<void> _onChanged(bool value) async {
    final notifier = ref.read(settingsProvider.notifier);
    if (!value) {
      notifier.setSaveLocation(false);
      return;
    }
    if (_requesting) return;
    _requesting = true;
    final l10n = AppLocalizations.of(context);
    final palette = CarretePalette.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final system = ref.read(systemSettingsProvider);
    try {
      final permission = await notifier.requestLocationPermission();
      if (!mounted) return;
      switch (permission) {
        case LocationPermission.granted || LocationPermission.coarseOnly:
          notifier.setSaveLocation(true);
        case LocationPermission.denied:
          showSettingsSnack(messenger, palette, l10n.locationPermissionNeeded);
        case LocationPermission.permanentlyDenied:
          showSettingsSnack(
            messenger,
            palette,
            l10n.locationPermissionBlocked,
            action: system.canOpen
                ? SnackBarAction(
                    label: l10n.locationPermissionBlockedAction,
                    textColor: palette.accent,
                    onPressed: system.open,
                  )
                : null,
          );
      }
    } finally {
      _requesting = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = CarretePalette.of(context);
    final on = ref.watch(settingsProvider.select((s) => s.saveLocation));
    final permission = ref.watch(locationPermissionProvider).value;
    final system = ref.watch(systemSettingsProvider);

    Widget? footer;
    if (on) {
      switch (permission) {
        case LocationPermission.denied || LocationPermission.permanentlyDenied:
          footer = SettingsWarning(
            text: l10n.settingSaveLocationRevoked,
            actionLabel: system.canOpen
                ? l10n.settingSaveLocationOpenSettings
                : null,
            onAction: system.open,
          );
        case LocationPermission.coarseOnly:
          footer = Text(
            l10n.settingSaveLocationApproximate,
            style: CarreteText.note(palette.inkSoft),
          );
        case LocationPermission.granted || null:
          break;
      }
    }
    return SettingsSwitchRow(
      label: l10n.settingSaveLocation,
      hint: l10n.settingSaveLocationHint,
      footer: footer,
      value: on,
      onChanged: _onChanged,
    );
  }
}
