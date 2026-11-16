// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Diapo';

  @override
  String get galleryTitle => 'Gallery';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get rollTitle => 'Roll';

  @override
  String get settingCameraSounds => 'Camera sounds';

  @override
  String get settingSaveOriginal => 'Also save the original';

  @override
  String get settingSaveOriginalHint =>
      'When possible, also keeps the photo without the film.';

  @override
  String get settingSaveLocation => 'Save location';

  @override
  String get settingGrid => 'Grid';

  @override
  String get settingLevel => 'Level';

  @override
  String get settingDateStamp => 'Date on the photo';

  @override
  String get settingDefaultFilm => 'Default film';

  @override
  String get settingTheme => 'Theme';

  @override
  String get settingLanguage => 'Language';

  @override
  String get settingDateStyle => 'Date style';

  @override
  String get dateStyleYearFirst => 'Year first';

  @override
  String get dateStyleDayFirst => 'Day first';

  @override
  String dateStyleSemantics(String style, String date) {
    return '$style: $date';
  }

  @override
  String get settingsSectionCamera => 'Camera';

  @override
  String get settingsSectionLook => 'Appearance';

  @override
  String get settingsSectionAdvanced => 'Advanced';

  @override
  String get settingsSectionAbout => 'About';

  @override
  String get themeSystem => 'System';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get languageSystem => 'System';

  @override
  String get languageSpanish => 'Español';

  @override
  String get languageCatalan => 'Català';

  @override
  String get languageEnglish => 'English';

  @override
  String get settingsVersion => 'Version';

  @override
  String get settingsOfflineNote =>
      'Works offline, with no accounts and no ads. Your photos never leave the phone.';

  @override
  String get settingsFreeSoftwareNote =>
      'Diapo is free software under the GPL-3.0-only licence. Source code: https://github.com/dferrandizmont/diapo';

  @override
  String get settingsLicences => 'Licenses';

  @override
  String get settingsPrivacyPolicy => 'Privacy policy';

  @override
  String get settingsLegalNotice => 'Legal notice';

  @override
  String get cameraCounterLabel => 'Loose photos';

  @override
  String cameraCounterSemantics(String film) {
    return '$film, loose photos';
  }

  @override
  String get flashOff => 'Off';

  @override
  String get flashAuto => 'Auto';

  @override
  String get flashOn => 'On';

  @override
  String get flashParty => 'Party';

  @override
  String flashKeyLabel(String mode) {
    return 'Flash: $mode';
  }

  @override
  String get flashKeyHint => 'Tap for the next mode';

  @override
  String get switchCameraLabel => 'Switch camera';

  @override
  String get shutterLabel => 'Take photo';

  @override
  String formatKeyLabel(String format) {
    return 'Format $format';
  }

  @override
  String get formatKeyHint => 'Changes the shape of the frame';

  @override
  String get viewfinderLabel => 'Camera viewfinder';

  @override
  String get viewfinderSwipeHint => 'Swipe the cartridges to change film';

  @override
  String get swipeHintClose => 'Dismiss tip';

  @override
  String get rollOfferTitle => 'Try a roll of 12';

  @override
  String rollOfferBody(String film) {
    return 'With $film. The photos stay hidden until you close the roll. Then you develop them right away, with no wait.';
  }

  @override
  String get rollOfferAction => 'Load a roll of 12';

  @override
  String get rollOfferDismiss => 'Not now';

  @override
  String get filmCarouselLabel => 'Films';

  @override
  String get filmCartridgeHint => 'Press and hold for fine tuning';

  @override
  String tunePanelLabel(String film) {
    return 'Fine tuning of $film';
  }

  @override
  String get tuneSubtitle => 'Fine tuning';

  @override
  String get tuneClose => 'Close';

  @override
  String get tuneGrain => 'Grain';

  @override
  String get tuneHalation => 'Halation';

  @override
  String get tuneLeak => 'Light leak';

  @override
  String get tuneVignette => 'Vignette';

  @override
  String get tuneDateStamp => 'Date imprint';

  @override
  String get tuneCinemaBands => 'Cinema bands';

  @override
  String get tuneFormat => 'Format';

  @override
  String get whiteFrameHint => 'White frame when saved';

  @override
  String get focusLockedLabel => 'Focus and exposure locked. Tap to release';

  @override
  String zoomLabel(String zoom) {
    return '${zoom}x';
  }

  @override
  String get cameraPermissionDenied =>
      'Camera permission is needed to take photos. You can grant it in the system settings.';

  @override
  String get cameraOpenSettings => 'Open settings';

  @override
  String get cameraUnavailable => 'The camera cannot be opened.';

  @override
  String get cameraRetry => 'Try again';

  @override
  String get shotSaved => 'Photo saved';

  @override
  String get shotSaveFailed => 'The photo could not be saved.';

  @override
  String get filmsLoadFailed => 'The films could not be loaded.';

  @override
  String get filmsLoading => 'Loading the films';

  @override
  String get rollReadyTitle => 'You can develop your roll now';

  @override
  String rollReadyBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Open the app to develop your $count photos. Keep it open until it finishes.',
      one:
          'Open the app to develop your photo. Keep it open until it finishes.',
    );
    return '$_temp0';
  }

  @override
  String get rollKeyLoad => 'Load roll';

  @override
  String rollKeyOpen(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count frames left',
      one: 'one frame left',
    );
    return 'Roll loaded, $_temp0';
  }

  @override
  String rollKeyLeft(String count) {
    return 'Left $count';
  }

  @override
  String rollKeyPaused(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count frames left',
      one: 'one frame left',
    );
    return 'Disposable camera paused, $_temp0';
  }

  @override
  String get rollKeyPausedTitle => 'Disposable paused';

  @override
  String get rollCounterLabel => 'Left';

  @override
  String rollCounterSemantics(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count frames left',
      one: 'One frame left',
      zero: 'No frames left',
    );
    return '$_temp0';
  }

  @override
  String get rollFilmLocked => 'The film is fixed while a roll is loaded';

  @override
  String get rollClosedNotice => 'Roll finished';

  @override
  String get rollActionFailed => 'That did not work. Try again.';

  @override
  String get rollLoadTitle => 'Load a roll';

  @override
  String get rollSheetIntro =>
      'One film for the whole roll. The photos stay hidden until you develop it.';

  @override
  String get rollFilmRow => 'Film';

  @override
  String get rollLengthLabel => 'Frames';

  @override
  String get rollDelayLabel => 'Wait to develop';

  @override
  String get rollDelayNote => 'The wait starts when you close the roll.';

  @override
  String get delayInstant => 'Now';

  @override
  String get delayOneHour => '1 hour';

  @override
  String get delayNextMorning => 'Next morning';

  @override
  String get delayThreeDays => '3 days';

  @override
  String get rollLoadAction => 'Load roll';

  @override
  String get rollLoadNote =>
      'While a roll is loaded you will not see your photos, only how many are left.';

  @override
  String get rollLossWarning =>
      'The photos of a roll you have not developed exist only on this phone. If you uninstall the app, clear its data or move to another phone, they are lost.';

  @override
  String get rollLossNote =>
      'They exist only on this phone: they are lost if you uninstall, clear the data or change phone.';

  @override
  String get disposableOption => 'Disposable camera';

  @override
  String get disposableOptionNote => '27 photos to share the camera';

  @override
  String disposableOptionSemantics(String title, String detail) {
    return '$title · $detail';
  }

  @override
  String get disposableStartTitle => 'Disposable camera';

  @override
  String get disposableStartBody =>
      'It has 27 photos and a fixed film. Nobody sees the photos or touches the settings: to leave, hold the exit stamp for a few seconds. When it is full, you develop it like a roll.';

  @override
  String get disposableStartAction => 'Start';

  @override
  String get disposableCounterCaption => 'Photos left';

  @override
  String get disposableFlashLabel => 'Flash';

  @override
  String get disposableExitWord => 'Exit';

  @override
  String get disposableExitHint => 'Hold down';

  @override
  String get disposableExitSemantics =>
      'Leave the disposable camera. Hold down for two seconds.';

  @override
  String get disposableExitTitle => 'Leave the disposable camera?';

  @override
  String disposableExitBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count photos are left and are kept for later.',
      one: '1 photo is left and is kept for later.',
      zero: 'No photos are left.',
    );
    return '$_temp0 You can carry on from the roll key.';
  }

  @override
  String get disposableExitConfirm => 'Leave';

  @override
  String get disposableExitStay => 'Stay';

  @override
  String disposableStrip(int count) {
    return '$count photos · use and throw away';
  }

  @override
  String get disposableDone => 'The disposable is finished';

  @override
  String get disposableResume => 'Back to the disposable camera';

  @override
  String get disposableAdvanceLabel => 'Advance';

  @override
  String get disposableFinishAction => 'Finish roll';

  @override
  String get disposableFinishInstantNote =>
      'This disposable develops right away once you finish it.';

  @override
  String get disposableFinishWarning =>
      'Once finished, you cannot take more photos with it.';

  @override
  String get disposableFinishKeepWait => 'Keep the wait';

  @override
  String get disposablePausedNote =>
      'The disposable is half used: the camera does not use it. To load another roll, go back to it, finish it or throw it away.';

  @override
  String rollRowSubtitle(String date, String count) {
    return '$date · $count';
  }

  @override
  String get rollRecentTitle => 'Recent rolls';

  @override
  String get rollStateWaiting => 'Waiting';

  @override
  String get rollStateDeveloping => 'Developing';

  @override
  String get rollStateDeveloped => 'Developed';

  @override
  String get rollStateLost => 'Lost';

  @override
  String rollFramesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count frames',
      one: '1 frame',
    );
    return '$_temp0';
  }

  @override
  String rollRowSemantics(
    String film,
    String frames,
    String state,
    String date,
  ) {
    return '$film, $frames, $state, $date';
  }

  @override
  String get rollOpenTitle => 'Roll in the camera';

  @override
  String rollOpenSummary(String film, int length) {
    return '$film · $length frames';
  }

  @override
  String rollDevelopsLine(String delay) {
    return 'Wait to develop: $delay';
  }

  @override
  String get rollCloseAction => 'Close roll';

  @override
  String get rollDevelopNowAction => 'Develop now';

  @override
  String get rollDiscardAction => 'Throw away the roll';

  @override
  String get rollDevelopNowTitle => 'Develop now?';

  @override
  String rollDevelopNowBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'The $count photos on this roll will be developed now.',
      one: 'The photo on this roll will be developed now.',
      zero: 'This roll has no photos.',
    );
    return '$_temp0 The wait ends now and this cannot be undone.';
  }

  @override
  String get rollDevelopKeepWaiting => 'Keep waiting';

  @override
  String get rollDiscardTitle => 'Throw away the roll?';

  @override
  String get rollDiscardBody =>
      'The photos of this roll will be lost for good. There is no undo.';

  @override
  String get rollDiscardConfirm => 'Throw away';

  @override
  String get dialogCancel => 'Cancel';

  @override
  String get rollNameEdit => 'Edit roll name';

  @override
  String get rollNameTitle => 'Roll name';

  @override
  String get rollNameLabel => 'Name';

  @override
  String rollNameNote(String fallback) {
    return 'It is optional. Without a name, the roll is called \"$fallback\".';
  }

  @override
  String get rollNameSave => 'Save';

  @override
  String rollNameCounter(int count, int max) {
    return '$count of $max characters';
  }

  @override
  String get rollWaitingTitle => 'Roll waiting';

  @override
  String rollReadyOn(String date, String time) {
    return 'You can develop from $date at $time';
  }

  @override
  String get rollWaitingNote =>
      'Until then your photos stay encrypted on this phone.';

  @override
  String get rollDevelopingTitle => 'Developing';

  @override
  String rollDevelopProgressSemantics(int done, int total) {
    return '$done of $total frames developed';
  }

  @override
  String get rollKeepOpen => 'Keep the app open until it finishes.';

  @override
  String get rollStillOpenTitle => 'This roll is still in the camera';

  @override
  String get rollLostTitle => 'This roll cannot be developed';

  @override
  String get rollLostBody =>
      'The key that protected its photos is gone, so they cannot be recovered.';

  @override
  String get rollDiscardedTitle => 'This roll was thrown away';

  @override
  String get rollMissingTitle => 'This roll cannot be found';

  @override
  String get rollShareSheetAction => 'Share contact sheet';

  @override
  String get rollShareSheetRendering => 'Preparing the sheet';

  @override
  String get rollShareSheetError =>
      'The sheet could not be prepared. Try again.';

  @override
  String get rollShareSheetFailed => 'The share menu could not be opened.';

  @override
  String rollShareSheetPreview(String number) {
    return 'Preview of the contact sheet of roll $number';
  }

  @override
  String get contactSheetTitle => 'Contact sheet';

  @override
  String rollDevelopedOn(String date) {
    return 'Developed on $date';
  }

  @override
  String get rollFrameFailed => 'Failed';

  @override
  String get rollFrameMissing => 'Deleted';

  @override
  String frameSemantics(int number) {
    return 'Frame $number';
  }

  @override
  String frameFailedSemantics(int number) {
    return 'Frame $number, could not be developed';
  }

  @override
  String frameDevelopingSemantics(int number) {
    return 'Frame $number, developing';
  }

  @override
  String frameMissingSemantics(int number) {
    return 'Frame $number, no longer in the gallery';
  }

  @override
  String get frameOpenHint => 'Opens the photo';

  @override
  String viewerPosition(int index, int total) {
    return '$index of $total';
  }

  @override
  String viewerSemantics(int index, int total) {
    return 'Photo $index of $total';
  }

  @override
  String get viewerUnavailable => 'The photo cannot be shown.';

  @override
  String rollNumberTitle(String number) {
    return 'Roll $number';
  }

  @override
  String get galleryEmptyTitle => 'No photos yet';

  @override
  String get galleryEmptyBody =>
      'The photos you take will show up here. Those from a roll, once you develop it.';

  @override
  String get galleryDevelopingLabel => 'Developing';

  @override
  String get galleryLooseLabel => 'Loose photos';

  @override
  String get galleryToday => 'Today';

  @override
  String get galleryYesterday => 'Yesterday';

  @override
  String get galleryCardHint => 'Opens the photos';

  @override
  String get galleryLoadFailed => 'The gallery could not be loaded.';

  @override
  String get galleryImportRow => 'Develop photos from your phone';

  @override
  String get galleryImportHint =>
      'Pick photos from your gallery and give them a film';

  @override
  String get importTitle => 'Develop photos';

  @override
  String get importPickFailed => 'Could not open your photos.';

  @override
  String importPickLimit(int count) {
    return 'Only $count photos can be developed at a time. The first ones were taken.';
  }

  @override
  String get importCloseLabel => 'Leave without developing';

  @override
  String importCounter(int current, int total) {
    return '$current of $total';
  }

  @override
  String importPhotoSemantics(int current, int total, String film) {
    return 'Photo $current of $total, with the film $film';
  }

  @override
  String get importCompareHint => 'Hold the photo to see the original';

  @override
  String get importOriginalPill => 'Original';

  @override
  String get importTuneLabel => 'Fine tuning';

  @override
  String get importStripLabel => 'Photos to develop';

  @override
  String importStripItem(int current, int total) {
    return 'Photo $current of $total';
  }

  @override
  String importDevelopAction(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Develop all $count photos',
      one: 'Develop the photo',
    );
    return '$_temp0';
  }

  @override
  String importProgress(int current, int total) {
    return 'Developing $current of $total';
  }

  @override
  String get importCancelling => 'Cancelling';

  @override
  String get importPartialTitle => 'Only partly developed';

  @override
  String importPartialBody(int done, int total) {
    return '$done of $total photos were developed. The others could not be read or saved.';
  }

  @override
  String get importFailedTitle => 'Could not develop';

  @override
  String get importFailedBody =>
      'No photo was saved. Try other photos or try again.';

  @override
  String get importOpenGallery => 'Go to the gallery';

  @override
  String get importUnreadable => 'This photo cannot be read';

  @override
  String importRejected(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count photos are too big and were left out.',
      one: 'One photo is too big and was left out.',
    );
    return '$_temp0';
  }

  @override
  String get importNoDate => 'No date: none will be printed';

  @override
  String get importLeftoverTitle => 'Some photos stayed';

  @override
  String importLeftoverBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count photos could not be removed from the gallery of the phone. They are in the Diapo folder and you can delete them from there.',
      one: 'One photo could not be removed from the gallery of the phone. It is in the Diapo folder and you can delete it from there.',
    );
    return '$_temp0';
  }

  @override
  String get galleryDayMissingTitle => 'This day cannot be found';

  @override
  String get viewerShare => 'Share';

  @override
  String get viewerDelete => 'Delete';

  @override
  String get viewerDeleteTitle => 'Delete this photo?';

  @override
  String get viewerDeleteBody =>
      'It will be deleted from Diapo and from your phone\'s gallery. This cannot be undone.';

  @override
  String get viewerDeleteConfirm => 'Delete';

  @override
  String get viewerActionFailed => 'That did not work. Try again.';

  @override
  String get viewerOriginalKept =>
      'Photo deleted, but its original is still in Pictures/Diapo/Originales.';

  @override
  String get galleryPlaceholder => 'The gallery is not here yet.';

  @override
  String get onboardingTitle1 => 'A camera, not a filter.';

  @override
  String get onboardingBody1 =>
      'You pick the film before you shoot and see it live in the viewfinder. Your photos never leave your phone.';

  @override
  String get onboardingTitle2 => 'Pick a film.';

  @override
  String get onboardingBody2 =>
      'Swipe the cartridges to change film and see the result live in the viewfinder.';

  @override
  String get onboardingTitle3 => 'A roll: photos you can\'t peek at.';

  @override
  String get onboardingBody3 =>
      'With a roll, photos stay hidden until you develop it. When the wait you chose is over, we let you know and you open the app to develop them.';

  @override
  String get onboardingSkip => 'Skip';

  @override
  String get onboardingNext => 'Next';

  @override
  String get onboardingStart => 'Start shooting';

  @override
  String get onboardingChipNoAccount => 'No account';

  @override
  String get onboardingChipNoWatermark => 'No watermark';

  @override
  String get onboardingChipOnDevice => 'On your phone';

  @override
  String get onboardingArtCamera =>
      'A viewfinder with a scene on film. No account, no watermark, all on your phone.';

  @override
  String get onboardingArtFilm =>
      'A viewfinder with a film-look scene and, below it, five film cartridges.';

  @override
  String get onboardingRollHidden => 'Taken · hidden until developed';

  @override
  String get onboardingReminder => 'Alert when you can develop';

  @override
  String get onboardingArtRoll =>
      'The counter of a roll with 9 of 24 photos taken and hidden, a choice of how long to wait, and an optional alert.';

  @override
  String get settingsHowItWorks => 'How it works';

  @override
  String get settingsRateTitle => 'Rate Diapo';

  @override
  String get settingsRateSubtitle => 'A review helps others find it';

  @override
  String get settingsKofiTitle => 'Buy me a coffee';

  @override
  String get settingsKofiSubtitle => 'Ko-fi, opens in your browser';

  @override
  String get settingsKofiFailed => 'Could not open the browser';

  @override
  String onboardingStepSemantics(int step, int total) {
    return 'Step $step of $total';
  }

  @override
  String get settingSaveLocationHint =>
      'The place is written into the photo\'s data (EXIF), only while the camera is open, and is never sent anywhere. Off by default.';

  @override
  String get settingSaveLocationApproximate =>
      'You only granted approximate location, so the place will be approximate.';

  @override
  String get settingSaveLocationRevoked =>
      'The location is not being saved because the permission was removed.';

  @override
  String get settingSaveLocationOpenSettings => 'Open system settings';

  @override
  String get locationPermissionNeeded =>
      'Location permission is needed to save where photos are taken.';

  @override
  String get locationPermissionBlocked =>
      'Location permission is blocked. Turn it on in the system settings.';

  @override
  String get locationPermissionBlockedAction => 'Settings';

  @override
  String get settingsSectionBackup => 'Your settings, no photos';

  @override
  String get settingsExport => 'Export settings';

  @override
  String get settingsExportHint =>
      'Saves a file with your settings and the tuning of each film. It does not save your photos: it is not a backup.';

  @override
  String get settingsImport => 'Import settings';

  @override
  String get settingsImportHint =>
      'Reads a file exported earlier and applies it. It does not bring photos back.';

  @override
  String get settingsImportConfirmTitle => 'Import settings?';

  @override
  String get settingsImportConfirmBody =>
      'Your current settings and film tuning will be replaced by the ones in the file.';

  @override
  String get settingsImportConfirmAction => 'Import';

  @override
  String get settingsExportDone => 'Settings exported.';

  @override
  String get settingsImportDone => 'Settings imported.';

  @override
  String settingsImportSkippedFilms(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count films this version does not know were left out.',
      one: 'One film this version does not know was left out.',
    );
    return '$_temp0';
  }

  @override
  String get settingsImportLocationStaysOff =>
      'Location is still off; turn it on here if you want it.';

  @override
  String get settingsImportOriginalStaysOff =>
      'Also save the original is still off; turn it on here if you want it.';

  @override
  String get settingsBackupTooLarge =>
      'The file is too big to be a Diapo settings backup.';

  @override
  String get settingsBackupInvalidJson =>
      'The file cannot be read: it is not in a valid format.';

  @override
  String get settingsBackupWrongFormat =>
      'This file is not a Diapo settings backup.';

  @override
  String get settingsBackupUnsupportedVersion =>
      'This file comes from a newer version of Diapo. Update the app to import it.';

  @override
  String get settingsBackupInvalidValue =>
      'The file has invalid values and nothing was imported.';

  @override
  String get settingsBackupBusy => 'An export or an import is already running.';

  @override
  String get settingsBackupStorage => 'Could not read or save. Try again.';

  @override
  String get settingsBackupInterrupted =>
      'The operation was interrupted. Try again.';

  @override
  String get settingHaptics => 'Vibration';

  @override
  String saveStatusSaving(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Saving $count photos',
      one: 'Saving 1 photo',
    );
    return '$_temp0';
  }

  @override
  String get saveStatusPending => 'Some photos are waiting to be saved';

  @override
  String get saveSheetTitle => 'Photos waiting';

  @override
  String saveSheetCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count photos are waiting to be saved.',
      one: '1 photo is waiting to be saved.',
    );
    return '$_temp0';
  }

  @override
  String get saveSheetStorageFull =>
      'The phone has run out of space. Free some space and try again.';

  @override
  String get saveSheetPermission =>
      'Diapo is not allowed to save to the gallery. Check the permissions of the system and try again.';

  @override
  String get saveSheetUnknown =>
      'They could not be saved just now. You can try again.';

  @override
  String get saveSheetKept =>
      'Meanwhile they are kept temporarily inside the app. Do not clear the data of the app.';

  @override
  String get saveSheetRetry => 'Try again';

  @override
  String get saveSheetLater => 'Later';
}
