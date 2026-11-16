import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/backup/settings_backup_codec.dart';
import '../../core/backup/settings_backup_service.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/theme/carrete_tokens.dart';
import '../roll/roll_parts.dart';
import 'settings_parts.dart';
import 'settings_snack.dart';

enum _Operation { export, import }

/// The "Advanced" section, at the end of the settings: collapsed, with one row
/// that opens the two rows that save the settings to a file and read them back
/// (settings only, never the photos). One operation at a time: both rows are
/// disabled while it runs.
class SettingsBackupSection extends ConsumerStatefulWidget {
  const SettingsBackupSection({super.key});

  @override
  ConsumerState<SettingsBackupSection> createState() =>
      _SettingsBackupSectionState();
}

class _SettingsBackupSectionState extends ConsumerState<SettingsBackupSection> {
  _Operation? _running;
  bool _open = false;

  static String _errorText(AppLocalizations l10n, BackupErrorCode code) =>
      switch (code) {
        BackupErrorCode.tooLarge => l10n.settingsBackupTooLarge,
        BackupErrorCode.invalidJson => l10n.settingsBackupInvalidJson,
        BackupErrorCode.wrongFormat => l10n.settingsBackupWrongFormat,
        BackupErrorCode.unsupportedVersion =>
          l10n.settingsBackupUnsupportedVersion,
        BackupErrorCode.invalidValue => l10n.settingsBackupInvalidValue,
        BackupErrorCode.busy => l10n.settingsBackupBusy,
        BackupErrorCode.storage => l10n.settingsBackupStorage,
        BackupErrorCode.interrupted => l10n.settingsBackupInterrupted,
      };

  Future<void> _export() async {
    if (_running != null) return;
    final l10n = AppLocalizations.of(context);
    final palette = CarretePalette.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _running = _Operation.export);
    String? message;
    try {
      final saved = await ref.read(settingsBackupProvider).exportSettings();
      // The user closed the system dialog: nothing to say.
      if (saved) message = l10n.settingsExportDone;
    } on SettingsBackupException catch (error) {
      message = _errorText(l10n, error.code);
    } on Object {
      message = l10n.settingsBackupStorage;
    } finally {
      if (mounted) setState(() => _running = null);
    }
    if (message != null) showSettingsSnack(messenger, palette, message);
  }

  Future<void> _import() async {
    if (_running != null) return;
    final l10n = AppLocalizations.of(context);
    final palette = CarretePalette.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await confirmRollAction(
      context,
      palette: palette,
      title: l10n.settingsImportConfirmTitle,
      body: l10n.settingsImportConfirmBody,
      confirmLabel: l10n.settingsImportConfirmAction,
      cancelLabel: l10n.dialogCancel,
    );
    if (!confirmed || !mounted || _running != null) return;
    setState(() => _running = _Operation.import);
    String? message;
    try {
      final result = await ref.read(settingsBackupProvider).importSettings();
      // The user closed the system picker: nothing to say.
      if (result != null) {
        message = [
          l10n.settingsImportDone,
          if (result.skippedFilmIds.isNotEmpty)
            l10n.settingsImportSkippedFilms(result.skippedFilmIds.length),
          // An import never turns these on: say so, and where to do it.
          if (result.needsUserSettings.contains('saveLocation'))
            l10n.settingsImportLocationStaysOff,
          if (result.needsUserSettings.contains('saveOriginal'))
            l10n.settingsImportOriginalStaysOff,
        ].join(' ');
      }
    } on SettingsBackupException catch (error) {
      message = _errorText(l10n, error.code);
    } on Object {
      message = l10n.settingsBackupStorage;
    } finally {
      if (mounted) setState(() => _running = null);
    }
    if (message != null) {
      showSettingsSnack(
        messenger,
        palette,
        message,
        duration: CarreteDurations.longNotice,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final idle = _running == null;
    return SettingsSection(
      title: l10n.settingsSectionAdvanced,
      children: [
        SettingsExpanderRow(
          label: l10n.settingsSectionBackup,
          expanded: _open,
          onTap: () => setState(() => _open = !_open),
        ),
        if (_open) ...[
          SettingsActionRow(
            label: l10n.settingsExport,
            hint: l10n.settingsExportHint,
            busy: _running == _Operation.export,
            onTap: idle ? _export : null,
          ),
          SettingsActionRow(
            label: l10n.settingsImport,
            hint: l10n.settingsImportHint,
            busy: _running == _Operation.import,
            onTap: idle ? _import : null,
          ),
        ],
      ],
    );
  }
}
