import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ca.dart';
import 'app_localizations_en.dart';
import 'app_localizations_es.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ca'),
    Locale('en'),
    Locale('es'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In es, this message translates to:
  /// **'Diapo'**
  String get appTitle;

  /// No description provided for @galleryTitle.
  ///
  /// In es, this message translates to:
  /// **'Galería'**
  String get galleryTitle;

  /// No description provided for @settingsTitle.
  ///
  /// In es, this message translates to:
  /// **'Ajustes'**
  String get settingsTitle;

  /// No description provided for @rollTitle.
  ///
  /// In es, this message translates to:
  /// **'Carrete'**
  String get rollTitle;

  /// No description provided for @settingCameraSounds.
  ///
  /// In es, this message translates to:
  /// **'Sonidos de la cámara'**
  String get settingCameraSounds;

  /// No description provided for @settingSaveOriginal.
  ///
  /// In es, this message translates to:
  /// **'Guardar también el original'**
  String get settingSaveOriginal;

  /// No description provided for @settingSaveOriginalHint.
  ///
  /// In es, this message translates to:
  /// **'Si se puede, también guarda la foto sin película.'**
  String get settingSaveOriginalHint;

  /// No description provided for @settingSaveLocation.
  ///
  /// In es, this message translates to:
  /// **'Guardar la ubicación'**
  String get settingSaveLocation;

  /// No description provided for @settingGrid.
  ///
  /// In es, this message translates to:
  /// **'Cuadrícula'**
  String get settingGrid;

  /// No description provided for @settingLevel.
  ///
  /// In es, this message translates to:
  /// **'Nivel'**
  String get settingLevel;

  /// No description provided for @settingDateStamp.
  ///
  /// In es, this message translates to:
  /// **'Fecha en la foto'**
  String get settingDateStamp;

  /// No description provided for @settingDefaultFilm.
  ///
  /// In es, this message translates to:
  /// **'Película por defecto'**
  String get settingDefaultFilm;

  /// No description provided for @settingTheme.
  ///
  /// In es, this message translates to:
  /// **'Tema'**
  String get settingTheme;

  /// No description provided for @settingLanguage.
  ///
  /// In es, this message translates to:
  /// **'Idioma'**
  String get settingLanguage;

  /// Setting: how the date is stamped on the photo (year first or day first).
  ///
  /// In es, this message translates to:
  /// **'Estilo de la fecha'**
  String get settingDateStyle;

  /// Date style 'yy m d, shown under its sample.
  ///
  /// In es, this message translates to:
  /// **'Año primero'**
  String get dateStyleYearFirst;

  /// Date style d m 'yy, shown under its sample.
  ///
  /// In es, this message translates to:
  /// **'Día primero'**
  String get dateStyleDayFirst;

  /// Screen reader text of a date style option. style: its name; date: today's date in that style.
  ///
  /// In es, this message translates to:
  /// **'{style}: {date}'**
  String dateStyleSemantics(String style, String date);

  /// Title of the section of the settings about the camera.
  ///
  /// In es, this message translates to:
  /// **'Cámara'**
  String get settingsSectionCamera;

  /// Title of the section of the settings about the theme and the language.
  ///
  /// In es, this message translates to:
  /// **'Aspecto'**
  String get settingsSectionLook;

  /// Title of the last section of the settings, collapsed: the export and import of the settings.
  ///
  /// In es, this message translates to:
  /// **'Avanzado'**
  String get settingsSectionAdvanced;

  /// Title of the section of the settings about the app.
  ///
  /// In es, this message translates to:
  /// **'Acerca de'**
  String get settingsSectionAbout;

  /// Theme option: follow the system.
  ///
  /// In es, this message translates to:
  /// **'Sistema'**
  String get themeSystem;

  /// Theme option: light.
  ///
  /// In es, this message translates to:
  /// **'Claro'**
  String get themeLight;

  /// Theme option: dark.
  ///
  /// In es, this message translates to:
  /// **'Oscuro'**
  String get themeDark;

  /// Language option: the language of the device.
  ///
  /// In es, this message translates to:
  /// **'Sistema'**
  String get languageSystem;

  /// Language option. Every language writes its own name the same in all translations, so a user can always find theirs.
  ///
  /// In es, this message translates to:
  /// **'Español'**
  String get languageSpanish;

  /// Language option. Same in all translations.
  ///
  /// In es, this message translates to:
  /// **'Català'**
  String get languageCatalan;

  /// Language option. Same in all translations.
  ///
  /// In es, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// Label of the version of the app.
  ///
  /// In es, this message translates to:
  /// **'Versión'**
  String get settingsVersion;

  /// Sentence in the about section: privacy promise of the app.
  ///
  /// In es, this message translates to:
  /// **'Funciona sin conexión, sin cuentas y sin anuncios. Tus fotos nunca salen del móvil.'**
  String get settingsOfflineNote;

  /// Sentence in the about section: the app is free software under GPL-3.0-only, with the address of its source code (shown as plain text, never opened: the app has no network).
  ///
  /// In es, this message translates to:
  /// **'Diapo es software libre bajo la licencia GPL-3.0-only. Código fuente: https://github.com/dferrandizmont/diapo'**
  String get settingsFreeSoftwareNote;

  /// Entry that opens the list of open source licences.
  ///
  /// In es, this message translates to:
  /// **'Licencias'**
  String get settingsLicences;

  /// Entry that opens the privacy policy, bundled with the app and readable offline.
  ///
  /// In es, this message translates to:
  /// **'Política de privacidad'**
  String get settingsPrivacyPolicy;

  /// Entry that opens the legal notice (aviso legal), bundled with the app and readable offline.
  ///
  /// In es, this message translates to:
  /// **'Aviso legal'**
  String get settingsLegalNotice;

  /// Small label under the LCD of the viewfinder while no roll is loaded: the photos are saved one by one to the gallery.
  ///
  /// In es, this message translates to:
  /// **'Fotos sueltas'**
  String get cameraCounterLabel;

  /// Screen reader text of the LCD of the viewfinder while no roll is loaded. film: the name of the selected film.
  ///
  /// In es, this message translates to:
  /// **'{film}, fotos sueltas'**
  String cameraCounterSemantics(String film);

  /// Flash mode: never fires.
  ///
  /// In es, this message translates to:
  /// **'Apagado'**
  String get flashOff;

  /// Flash mode: fires when it is dark.
  ///
  /// In es, this message translates to:
  /// **'Automático'**
  String get flashAuto;

  /// Flash mode: always fires.
  ///
  /// In es, this message translates to:
  /// **'Encendido'**
  String get flashOn;

  /// Flash mode: always fires and burns the highlights a little on purpose.
  ///
  /// In es, this message translates to:
  /// **'Fiesta'**
  String get flashParty;

  /// Screen reader label of a flash key. mode: the name of the mode.
  ///
  /// In es, this message translates to:
  /// **'Flash: {mode}'**
  String flashKeyLabel(String mode);

  /// Screen reader hint of the flash key, which cycles off, auto, on and party.
  ///
  /// In es, this message translates to:
  /// **'Toca para pasar al siguiente modo'**
  String get flashKeyHint;

  /// Key that switches between the back and the front camera.
  ///
  /// In es, this message translates to:
  /// **'Cambiar de cámara'**
  String get switchCameraLabel;

  /// The shutter button.
  ///
  /// In es, this message translates to:
  /// **'Disparar'**
  String get shutterLabel;

  /// Label of the key that cycles the frame format. format: for example 3:2.
  ///
  /// In es, this message translates to:
  /// **'Formato {format}'**
  String formatKeyLabel(String format);

  /// Hint of the format key.
  ///
  /// In es, this message translates to:
  /// **'Cambia el formato del encuadre'**
  String get formatKeyHint;

  /// Label of the live preview.
  ///
  /// In es, this message translates to:
  /// **'Visor de la cámara'**
  String get viewfinderLabel;

  /// Hint shown once over the camera of a new user, above the carousel of films.
  ///
  /// In es, this message translates to:
  /// **'Desliza los cartuchos para cambiar de película'**
  String get viewfinderSwipeHint;

  /// Screen reader label of the key that closes the hint about swiping the films.
  ///
  /// In es, this message translates to:
  /// **'Cerrar consejo'**
  String get swipeHintClose;

  /// Title of the offer shown once, after the second loose photo, to load a roll of 12 frames.
  ///
  /// In es, this message translates to:
  /// **'Prueba un carrete de 12'**
  String get rollOfferTitle;

  /// Body of the offer of a roll of 12. film: the name of the selected film.
  ///
  /// In es, this message translates to:
  /// **'Con {film}. Las fotos quedan ocultas hasta que cierres el carrete. Entonces las revelas al momento, sin espera.'**
  String rollOfferBody(String film);

  /// Key of the offer that loads a roll of 12 frames with no wait to develop.
  ///
  /// In es, this message translates to:
  /// **'Cargar carrete de 12'**
  String get rollOfferAction;

  /// Key of the offer of a roll of 12 that closes it.
  ///
  /// In es, this message translates to:
  /// **'Ahora no'**
  String get rollOfferDismiss;

  /// Label of the carousel of films.
  ///
  /// In es, this message translates to:
  /// **'Películas'**
  String get filmCarouselLabel;

  /// Hint of a film cartridge.
  ///
  /// In es, this message translates to:
  /// **'Mantén pulsado para los ajustes finos'**
  String get filmCartridgeHint;

  /// Label of the fine-tuning panel. film: name of the film.
  ///
  /// In es, this message translates to:
  /// **'Ajustes finos de {film}'**
  String tunePanelLabel(String film);

  /// Subtitle of the fine-tuning panel, under the name of the film.
  ///
  /// In es, this message translates to:
  /// **'Ajustes finos'**
  String get tuneSubtitle;

  /// Closes the fine-tuning panel.
  ///
  /// In es, this message translates to:
  /// **'Cerrar'**
  String get tuneClose;

  /// Slider of the fine-tuning panel.
  ///
  /// In es, this message translates to:
  /// **'Grano'**
  String get tuneGrain;

  /// Slider of the fine-tuning panel.
  ///
  /// In es, this message translates to:
  /// **'Halos'**
  String get tuneHalation;

  /// Slider of the fine-tuning panel.
  ///
  /// In es, this message translates to:
  /// **'Fuga de luz'**
  String get tuneLeak;

  /// Slider of the fine-tuning panel.
  ///
  /// In es, this message translates to:
  /// **'Viñeta'**
  String get tuneVignette;

  /// Switch of the fine-tuning panel.
  ///
  /// In es, this message translates to:
  /// **'Fecha impresa'**
  String get tuneDateStamp;

  /// Switch of the fine-tuning panel, shown only for the 16:9 format.
  ///
  /// In es, this message translates to:
  /// **'Bandas de cine'**
  String get tuneCinemaBands;

  /// Row of the fine-tuning panel with the frame formats.
  ///
  /// In es, this message translates to:
  /// **'Formato'**
  String get tuneFormat;

  /// Hint over the viewfinder in the square format of an instant film.
  ///
  /// In es, this message translates to:
  /// **'Marco blanco al guardar'**
  String get whiteFrameHint;

  /// Screen reader text of the lock indicator.
  ///
  /// In es, this message translates to:
  /// **'Enfoque y exposición bloqueados. Toca para soltar'**
  String get focusLockedLabel;

  /// Zoom shown while pinching. zoom: for example 1.4.
  ///
  /// In es, this message translates to:
  /// **'{zoom}x'**
  String zoomLabel(String zoom);

  /// Shown when the user refused the camera permission.
  ///
  /// In es, this message translates to:
  /// **'Hace falta el permiso de la cámara para hacer fotos. Puedes concederlo en los ajustes del sistema.'**
  String get cameraPermissionDenied;

  /// Key under the camera permission message that opens the settings of the app in the system.
  ///
  /// In es, this message translates to:
  /// **'Abrir los ajustes'**
  String get cameraOpenSettings;

  /// Shown when the camera fails to open.
  ///
  /// In es, this message translates to:
  /// **'No se puede abrir la cámara.'**
  String get cameraUnavailable;

  /// Retries opening the camera.
  ///
  /// In es, this message translates to:
  /// **'Reintentar'**
  String get cameraRetry;

  /// Announced to screen readers when a photo is saved.
  ///
  /// In es, this message translates to:
  /// **'Foto guardada'**
  String get shotSaved;

  /// Shown when processing or saving a photo fails.
  ///
  /// In es, this message translates to:
  /// **'No se pudo guardar la foto.'**
  String get shotSaveFailed;

  /// Shown when the book of films fails to load.
  ///
  /// In es, this message translates to:
  /// **'No se pudieron cargar las películas.'**
  String get filmsLoadFailed;

  /// Screen reader text while the book of films loads.
  ///
  /// In es, this message translates to:
  /// **'Cargando las películas'**
  String get filmsLoading;

  /// No description provided for @rollReadyTitle.
  ///
  /// In es, this message translates to:
  /// **'Ya puedes revelar tu carrete'**
  String get rollReadyTitle;

  /// Notification when the wait of a roll is over. count: the photos taken, fewer than the roll length when it was closed early. The photos are developed by the app, only while it is open.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{Abre la app para revelar tu foto. Mantenla abierta hasta terminar.} other{Abre la app para revelar tus {count} fotos. Mantenla abierta hasta terminar.}}'**
  String rollReadyBody(int count);

  /// Label of the roll control of the camera while no roll is loaded. It opens the sheet to load a roll.
  ///
  /// In es, this message translates to:
  /// **'Cargar carrete'**
  String get rollKeyLoad;

  /// Screen reader label of the roll key while a roll is loaded. count: frames left.
  ///
  /// In es, this message translates to:
  /// **'Carrete cargado, {count, plural, =1{queda una foto} other{quedan {count} fotos}}'**
  String rollKeyOpen(int count);

  /// Second line of the roll control while a roll or a disposable is loaded. count: the frames left, with two digits (08).
  ///
  /// In es, this message translates to:
  /// **'Quedan {count}'**
  String rollKeyLeft(String count);

  /// Screen reader label of the roll control while a disposable camera is set aside. count: frames left.
  ///
  /// In es, this message translates to:
  /// **'Cámara desechable en pausa, {count, plural, =1{queda una foto} other{quedan {count} fotos}}'**
  String rollKeyPaused(int count);

  /// First line of the roll control while a disposable camera is set aside. The camera shoots loose photos meanwhile.
  ///
  /// In es, this message translates to:
  /// **'Desechable en pausa'**
  String get rollKeyPausedTitle;

  /// Small print under the LCD while a roll is loaded.
  ///
  /// In es, this message translates to:
  /// **'Quedan'**
  String get rollCounterLabel;

  /// Screen reader text of the LCD counter while a roll is loaded. count: frames left.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =0{No quedan fotos} =1{Queda una foto} other{Quedan {count} fotos}}'**
  String rollCounterSemantics(int count);

  /// Hint of a film cartridge that cannot be chosen now.
  ///
  /// In es, this message translates to:
  /// **'La película queda fijada mientras haya un carrete cargado'**
  String get rollFilmLocked;

  /// Notice over the viewfinder when the roll closes by itself.
  ///
  /// In es, this message translates to:
  /// **'Carrete terminado'**
  String get rollClosedNotice;

  /// Notice when an action on a roll fails.
  ///
  /// In es, this message translates to:
  /// **'No se ha podido completar. Inténtalo de nuevo.'**
  String get rollActionFailed;

  /// Title of the sheet that loads a roll.
  ///
  /// In es, this message translates to:
  /// **'Cargar un carrete'**
  String get rollLoadTitle;

  /// One-line explanation at the top of the sheet that loads a roll.
  ///
  /// In es, this message translates to:
  /// **'Una película para todo el carrete. Las fotos quedan ocultas hasta que lo reveles.'**
  String get rollSheetIntro;

  /// Name of the row that shows the film of the roll.
  ///
  /// In es, this message translates to:
  /// **'Película'**
  String get rollFilmRow;

  /// Name of the row that picks the number of frames.
  ///
  /// In es, this message translates to:
  /// **'Fotos'**
  String get rollLengthLabel;

  /// Label of the choice of how long to wait before the roll can be developed, in the sheet that loads a roll.
  ///
  /// In es, this message translates to:
  /// **'Espera para revelar'**
  String get rollDelayLabel;

  /// Note under the choice of the wait: it counts from the moment the roll is closed, not loaded.
  ///
  /// In es, this message translates to:
  /// **'La espera empieza cuando cierras el carrete.'**
  String get rollDelayNote;

  /// Develop delay: as soon as the roll is closed.
  ///
  /// In es, this message translates to:
  /// **'Al momento'**
  String get delayInstant;

  /// Develop delay.
  ///
  /// In es, this message translates to:
  /// **'1 hora'**
  String get delayOneHour;

  /// Develop delay: the next morning.
  ///
  /// In es, this message translates to:
  /// **'Mañana temprano'**
  String get delayNextMorning;

  /// Develop delay.
  ///
  /// In es, this message translates to:
  /// **'3 días'**
  String get delayThreeDays;

  /// Key that loads the roll.
  ///
  /// In es, this message translates to:
  /// **'Cargar carrete'**
  String get rollLoadAction;

  /// Note under the sheet that loads a roll.
  ///
  /// In es, this message translates to:
  /// **'Mientras haya un carrete cargado no verás tus fotos, solo cuántas quedan.'**
  String get rollLoadNote;

  /// Warning in the sheet that loads a roll: where the undeveloped photos live and what loses them.
  ///
  /// In es, this message translates to:
  /// **'Las fotos de un carrete sin revelar solo existen en este móvil. Si desinstalas la app, borras sus datos o cambias de móvil, se pierden.'**
  String get rollLossWarning;

  /// Compact reminder in the details of a roll that is not developed yet (the sheet of the camera and the waiting screen).
  ///
  /// In es, this message translates to:
  /// **'Solo existen en este móvil: se pierden si desinstalas, borras los datos o cambias de móvil.'**
  String get rollLossNote;

  /// Key of the roll sheet that starts the disposable camera.
  ///
  /// In es, this message translates to:
  /// **'Cámara desechable'**
  String get disposableOption;

  /// Second line of the secondary option of the roll sheet that starts the disposable camera.
  ///
  /// In es, this message translates to:
  /// **'27 fotos para compartir la cámara'**
  String get disposableOptionNote;

  /// Screen reader label of the secondary option that starts the disposable camera. title and detail: its two lines.
  ///
  /// In es, this message translates to:
  /// **'{title} · {detail}'**
  String disposableOptionSemantics(String title, String detail);

  /// Title of the dialog that starts the disposable camera.
  ///
  /// In es, this message translates to:
  /// **'Cámara desechable'**
  String get disposableStartTitle;

  /// Body of the dialog that starts the disposable camera.
  ///
  /// In es, this message translates to:
  /// **'Tiene 27 fotos y una película fija. Nadie ve las fotos ni toca ajustes: para salir hay que mantener pulsado el sello de salir unos segundos. Al acabar, la revelas como un carrete.'**
  String get disposableStartBody;

  /// Key that starts the disposable camera.
  ///
  /// In es, this message translates to:
  /// **'Empezar'**
  String get disposableStartAction;

  /// Small text on the sticker that counts the photos left.
  ///
  /// In es, this message translates to:
  /// **'Fotos que quedan'**
  String get disposableCounterCaption;

  /// Name of the flash switch of the disposable camera (on or off).
  ///
  /// In es, this message translates to:
  /// **'Flash'**
  String get disposableFlashLabel;

  /// Word on the exit stamp.
  ///
  /// In es, this message translates to:
  /// **'Salir'**
  String get disposableExitWord;

  /// Small text on the exit stamp.
  ///
  /// In es, this message translates to:
  /// **'Mantén pulsado'**
  String get disposableExitHint;

  /// What a screen reader says for the exit stamp.
  ///
  /// In es, this message translates to:
  /// **'Salir de la cámara desechable. Mantén pulsado durante dos segundos.'**
  String get disposableExitSemantics;

  /// Title of the confirmation to leave the disposable camera.
  ///
  /// In es, this message translates to:
  /// **'¿Salir de la cámara desechable?'**
  String get disposableExitTitle;

  /// Body of the confirmation to leave the disposable camera.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =0{No quedan fotos.} =1{Queda 1 foto, que se guarda para más tarde.} other{Quedan {count} fotos, que se guardan para más tarde.}} Podrás seguir desde la llave del carrete.'**
  String disposableExitBody(int count);

  /// Key that leaves the disposable camera.
  ///
  /// In es, this message translates to:
  /// **'Salir'**
  String get disposableExitConfirm;

  /// Key that stays in the disposable camera.
  ///
  /// In es, this message translates to:
  /// **'Seguir'**
  String get disposableExitStay;

  /// Label on the cardboard of the disposable camera.
  ///
  /// In es, this message translates to:
  /// **'{count} fotos · usar y tirar'**
  String disposableStrip(int count);

  /// Notice when the last photo of the disposable camera is taken.
  ///
  /// In es, this message translates to:
  /// **'Se acabó la desechable'**
  String get disposableDone;

  /// Key of the roll sheet that returns to a disposable camera that was set aside.
  ///
  /// In es, this message translates to:
  /// **'Seguir con la desechable'**
  String get disposableResume;

  /// Word above the thumb wheel of the disposable camera.
  ///
  /// In es, this message translates to:
  /// **'Avanza'**
  String get disposableAdvanceLabel;

  /// Key of the roll sheet that finishes a disposable camera that was set aside and shows how it develops.
  ///
  /// In es, this message translates to:
  /// **'Terminar carrete'**
  String get disposableFinishAction;

  /// Shown when finishing a paused disposable whose wait is instant.
  ///
  /// In es, this message translates to:
  /// **'Esta desechable se revela al momento, en cuanto la termines.'**
  String get disposableFinishInstantNote;

  /// Shown when finishing a paused disposable: it cannot be resumed.
  ///
  /// In es, this message translates to:
  /// **'Una vez terminada, ya no se pueden hacer más fotos con ella.'**
  String get disposableFinishWarning;

  /// Key that finishes a paused disposable and keeps its scheduled wait to develop.
  ///
  /// In es, this message translates to:
  /// **'Mantener la espera'**
  String get disposableFinishKeepWait;

  /// Note in the roll sheet while a disposable camera is set aside.
  ///
  /// In es, this message translates to:
  /// **'La desechable está a medias: la cámara no la usa. Para cargar otro carrete, sigue con ella, termínala o tírala.'**
  String get disposablePausedNote;

  /// Second line of a recent roll: its date and its frame count.
  ///
  /// In es, this message translates to:
  /// **'{date} · {count}'**
  String rollRowSubtitle(String date, String count);

  /// Title of the list of the last rolls.
  ///
  /// In es, this message translates to:
  /// **'Últimos carretes'**
  String get rollRecentTitle;

  /// State of a closed roll that is waiting for its time.
  ///
  /// In es, this message translates to:
  /// **'Esperando'**
  String get rollStateWaiting;

  /// State of a roll that is being developed.
  ///
  /// In es, this message translates to:
  /// **'Revelando'**
  String get rollStateDeveloping;

  /// State of a developed roll.
  ///
  /// In es, this message translates to:
  /// **'Revelado'**
  String get rollStateDeveloped;

  /// State of a roll whose key is lost.
  ///
  /// In es, this message translates to:
  /// **'Perdido'**
  String get rollStateLost;

  /// Number of frames of a roll.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{1 foto} other{{count} fotos}}'**
  String rollFramesCount(int count);

  /// Screen reader text of a roll in the list. frames: for example 24 frames.
  ///
  /// In es, this message translates to:
  /// **'{film}, {frames}, {state}, {date}'**
  String rollRowSemantics(
    String film,
    String frames,
    String state,
    String date,
  );

  /// Title of the sheet while a roll is loaded.
  ///
  /// In es, this message translates to:
  /// **'Carrete en la cámara'**
  String get rollOpenTitle;

  /// Film and length of the loaded roll.
  ///
  /// In es, this message translates to:
  /// **'{film} · {length} fotos'**
  String rollOpenSummary(String film, int length);

  /// How long the loaded roll waits once closed. delay: the name of the delay.
  ///
  /// In es, this message translates to:
  /// **'Espera para revelar: {delay}'**
  String rollDevelopsLine(String delay);

  /// Key that closes the roll and develops it after its delay.
  ///
  /// In es, this message translates to:
  /// **'Cerrar carrete'**
  String get rollCloseAction;

  /// Key that develops the roll right away.
  ///
  /// In es, this message translates to:
  /// **'Revelar ahora'**
  String get rollDevelopNowAction;

  /// Key that throws the roll away.
  ///
  /// In es, this message translates to:
  /// **'Tirar el carrete'**
  String get rollDiscardAction;

  /// Title of the warning before developing early.
  ///
  /// In es, this message translates to:
  /// **'¿Revelar ahora?'**
  String get rollDevelopNowTitle;

  /// Body of the confirmation of developing a roll before its wait is over. count: the photos taken on the roll.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =0{Este carrete no tiene fotos.} =1{Se revelará la foto de este carrete ahora.} other{Se revelarán las {count} fotos de este carrete ahora.}} La espera termina ya y no se puede deshacer.'**
  String rollDevelopNowBody(int count);

  /// Button that cancels the early developing.
  ///
  /// In es, this message translates to:
  /// **'Seguir esperando'**
  String get rollDevelopKeepWaiting;

  /// Title of the confirmation before throwing a roll away.
  ///
  /// In es, this message translates to:
  /// **'¿Tirar el carrete?'**
  String get rollDiscardTitle;

  /// Confirmation before throwing a roll away.
  ///
  /// In es, this message translates to:
  /// **'Las fotos de este carrete se perderán para siempre. No se puede deshacer.'**
  String get rollDiscardBody;

  /// Button that confirms throwing a roll away.
  ///
  /// In es, this message translates to:
  /// **'Tirar'**
  String get rollDiscardConfirm;

  /// Button that closes a dialog without doing anything.
  ///
  /// In es, this message translates to:
  /// **'Cancelar'**
  String get dialogCancel;

  /// Screen reader label and tooltip of the key of a roll screen that opens the dialog to name the roll.
  ///
  /// In es, this message translates to:
  /// **'Editar nombre del carrete'**
  String get rollNameEdit;

  /// Title of the dialog that names a roll.
  ///
  /// In es, this message translates to:
  /// **'Nombre del carrete'**
  String get rollNameTitle;

  /// Label of the text field of the dialog that names a roll.
  ///
  /// In es, this message translates to:
  /// **'Nombre'**
  String get rollNameLabel;

  /// Note of the dialog that names a roll. fallback: the name the roll has while it has no name of its own, for example Carrete 07.
  ///
  /// In es, this message translates to:
  /// **'Es opcional. Sin nombre, el carrete se llama \"{fallback}\".'**
  String rollNameNote(String fallback);

  /// Key of the dialog that names a roll that saves the name.
  ///
  /// In es, this message translates to:
  /// **'Guardar'**
  String get rollNameSave;

  /// Screen reader text of the counter of the field that names a roll. count: the characters written. max: the most allowed.
  ///
  /// In es, this message translates to:
  /// **'{count} de {max} caracteres'**
  String rollNameCounter(int count, int max);

  /// Title of a closed roll that is waiting.
  ///
  /// In es, this message translates to:
  /// **'Carrete en espera'**
  String get rollWaitingTitle;

  /// When a closed roll will be ready.
  ///
  /// In es, this message translates to:
  /// **'Puedes revelar a partir del {date} a las {time}'**
  String rollReadyOn(String date, String time);

  /// Note under the date a closed roll will be ready.
  ///
  /// In es, this message translates to:
  /// **'Hasta entonces tus fotos siguen guardadas y cifradas en el móvil.'**
  String get rollWaitingNote;

  /// Title of a roll that is being developed.
  ///
  /// In es, this message translates to:
  /// **'Revelando'**
  String get rollDevelopingTitle;

  /// Screen reader text of the progress of the developing.
  ///
  /// In es, this message translates to:
  /// **'{done} de {total} fotos reveladas'**
  String rollDevelopProgressSemantics(int done, int total);

  /// Note on the developing screen.
  ///
  /// In es, this message translates to:
  /// **'Mantén la app abierta hasta que termine.'**
  String get rollKeepOpen;

  /// Shown when the screen of a roll is opened while the roll is loaded.
  ///
  /// In es, this message translates to:
  /// **'Este carrete sigue en la cámara'**
  String get rollStillOpenTitle;

  /// Title of a roll whose key is lost.
  ///
  /// In es, this message translates to:
  /// **'Este carrete no se puede revelar'**
  String get rollLostTitle;

  /// Explanation for a roll whose key is lost.
  ///
  /// In es, this message translates to:
  /// **'Se perdió la clave que protegía sus fotos, así que no se pueden recuperar.'**
  String get rollLostBody;

  /// Shown when the roll was thrown away.
  ///
  /// In es, this message translates to:
  /// **'Este carrete se tiró'**
  String get rollDiscardedTitle;

  /// Shown when there is no such roll.
  ///
  /// In es, this message translates to:
  /// **'No encuentro este carrete'**
  String get rollMissingTitle;

  /// Key of a developed roll that previews its contact sheet as one image and shares it. Also the title of the preview.
  ///
  /// In es, this message translates to:
  /// **'Compartir hoja'**
  String get rollShareSheetAction;

  /// Shown in the preview while the contact sheet image is painted.
  ///
  /// In es, this message translates to:
  /// **'Preparando la hoja'**
  String get rollShareSheetRendering;

  /// Shown in the preview when the contact sheet image could not be made.
  ///
  /// In es, this message translates to:
  /// **'No se pudo preparar la hoja. Inténtalo de nuevo.'**
  String get rollShareSheetError;

  /// Shown under the preview when the share sheet of the system did not open.
  ///
  /// In es, this message translates to:
  /// **'No se pudo abrir el menú de compartir.'**
  String get rollShareSheetFailed;

  /// Screen reader label of the preview image. number: the number of the roll.
  ///
  /// In es, this message translates to:
  /// **'Vista previa de la hoja de contactos del carrete {number}'**
  String rollShareSheetPreview(String number);

  /// Title of the sheet of thumbnails of a developed roll.
  ///
  /// In es, this message translates to:
  /// **'Hoja de contactos'**
  String get contactSheetTitle;

  /// When a roll was developed.
  ///
  /// In es, this message translates to:
  /// **'Revelado el {date}'**
  String rollDevelopedOn(String date);

  /// Short label inside a frame that could not be developed.
  ///
  /// In es, this message translates to:
  /// **'Fallo'**
  String get rollFrameFailed;

  /// Short label inside a frame whose photo was deleted from the gallery.
  ///
  /// In es, this message translates to:
  /// **'Borrada'**
  String get rollFrameMissing;

  /// Screen reader text of a frame of the contact sheet.
  ///
  /// In es, this message translates to:
  /// **'Fotograma {number}'**
  String frameSemantics(int number);

  /// Screen reader text of a frame that failed.
  ///
  /// In es, this message translates to:
  /// **'Fotograma {number}, no se pudo revelar'**
  String frameFailedSemantics(int number);

  /// Screen reader text of a frame whose photo is not saved yet while the roll is being developed.
  ///
  /// In es, this message translates to:
  /// **'Fotograma {number}, revelando'**
  String frameDevelopingSemantics(int number);

  /// Screen reader text of a frame whose photo was deleted.
  ///
  /// In es, this message translates to:
  /// **'Fotograma {number}, ya no está en la galería'**
  String frameMissingSemantics(int number);

  /// Hint of a frame of the contact sheet.
  ///
  /// In es, this message translates to:
  /// **'Abre la foto'**
  String get frameOpenHint;

  /// Position of the photo in the viewer.
  ///
  /// In es, this message translates to:
  /// **'{index} de {total}'**
  String viewerPosition(int index, int total);

  /// Screen reader text of the photo in the viewer.
  ///
  /// In es, this message translates to:
  /// **'Foto {index} de {total}'**
  String viewerSemantics(int index, int total);

  /// Shown when a photo cannot be read.
  ///
  /// In es, this message translates to:
  /// **'No se puede mostrar la foto.'**
  String get viewerUnavailable;

  /// Title of the screen of a roll. number: its number, for example 07.
  ///
  /// In es, this message translates to:
  /// **'Carrete {number}'**
  String rollNumberTitle(String number);

  /// Title of the gallery when it has no photos.
  ///
  /// In es, this message translates to:
  /// **'Aún no hay fotos'**
  String get galleryEmptyTitle;

  /// Explanation under the title of the empty gallery.
  ///
  /// In es, this message translates to:
  /// **'Las fotos que hagas aparecerán aquí. Las de un carrete, cuando las reveles.'**
  String get galleryEmptyBody;

  /// Title of the group of rolls that are not developed yet, in the gallery.
  ///
  /// In es, this message translates to:
  /// **'En revelado'**
  String get galleryDevelopingLabel;

  /// Name of the photos taken with no roll in the camera. It is the title of the contact sheet of a day.
  ///
  /// In es, this message translates to:
  /// **'Fotos sueltas'**
  String get galleryLooseLabel;

  /// The day of today, over a group of photos.
  ///
  /// In es, this message translates to:
  /// **'Hoy'**
  String get galleryToday;

  /// The day before today, over a group of photos.
  ///
  /// In es, this message translates to:
  /// **'Ayer'**
  String get galleryYesterday;

  /// Hint of a card of the gallery.
  ///
  /// In es, this message translates to:
  /// **'Abre las fotos'**
  String get galleryCardHint;

  /// Shown when the gallery cannot be read.
  ///
  /// In es, this message translates to:
  /// **'No se ha podido cargar la galería.'**
  String get galleryLoadFailed;

  /// Row of the gallery that opens the photo picker to develop photos already taken.
  ///
  /// In es, this message translates to:
  /// **'Revelar fotos del móvil'**
  String get galleryImportRow;

  /// Second line of the row of the gallery that develops photos of the phone.
  ///
  /// In es, this message translates to:
  /// **'Elige fotos de tu galería y dales una película'**
  String get galleryImportHint;

  /// Title of the screen that develops photos of the gallery.
  ///
  /// In es, this message translates to:
  /// **'Revelar fotos'**
  String get importTitle;

  /// Shown when the photo picker of the system could not open.
  ///
  /// In es, this message translates to:
  /// **'No se han podido abrir tus fotos.'**
  String get importPickFailed;

  /// Shown when more photos were chosen than can be developed at once. count: the limit.
  ///
  /// In es, this message translates to:
  /// **'Solo se pueden revelar {count} fotos a la vez. Se han cogido las primeras.'**
  String importPickLimit(int count);

  /// Screen reader text of the key that leaves the import screen without developing anything.
  ///
  /// In es, this message translates to:
  /// **'Salir sin revelar'**
  String get importCloseLabel;

  /// Position of the photo shown, for example 2 of 5. Printed on the top bar.
  ///
  /// In es, this message translates to:
  /// **'{current} de {total}'**
  String importCounter(int current, int total);

  /// Screen reader text of the photo being developed.
  ///
  /// In es, this message translates to:
  /// **'Foto {current} de {total}, con la película {film}'**
  String importPhotoSemantics(int current, int total, String film);

  /// Hint of the photo: holding it shows the photo without the film.
  ///
  /// In es, this message translates to:
  /// **'Mantén pulsada la foto para ver el original'**
  String get importCompareHint;

  /// Label shown over the photo while it is held, to say it is the original without the film.
  ///
  /// In es, this message translates to:
  /// **'Original'**
  String get importOriginalPill;

  /// Screen reader text of the key that opens the fine tuning of the film.
  ///
  /// In es, this message translates to:
  /// **'Ajuste fino'**
  String get importTuneLabel;

  /// Screen reader text of the strip of chosen photos.
  ///
  /// In es, this message translates to:
  /// **'Fotos para revelar'**
  String get importStripLabel;

  /// Screen reader text of a photo of the strip.
  ///
  /// In es, this message translates to:
  /// **'Foto {current} de {total}'**
  String importStripItem(int current, int total);

  /// Key that develops the chosen photos. count: how many.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{Revelar la foto} other{Revelar las {count} fotos}}'**
  String importDevelopAction(int count);

  /// Title of the panel shown while the photos are developed.
  ///
  /// In es, this message translates to:
  /// **'Revelando {current} de {total}'**
  String importProgress(int current, int total);

  /// Shown while a cancelled export finishes the photo in progress and undoes the rest.
  ///
  /// In es, this message translates to:
  /// **'Cancelando'**
  String get importCancelling;

  /// Title when some photos were developed and others not.
  ///
  /// In es, this message translates to:
  /// **'Revelado a medias'**
  String get importPartialTitle;

  /// Explains how many photos were developed. done: developed; total: chosen.
  ///
  /// In es, this message translates to:
  /// **'Se han revelado {done} de {total} fotos. Las demás no se han podido leer o guardar.'**
  String importPartialBody(int done, int total);

  /// Title when no photo could be developed.
  ///
  /// In es, this message translates to:
  /// **'No se ha podido revelar'**
  String get importFailedTitle;

  /// Explains that nothing was saved.
  ///
  /// In es, this message translates to:
  /// **'No se ha guardado ninguna foto. Prueba con otras o inténtalo de nuevo.'**
  String get importFailedBody;

  /// Key that leaves the import screen to the gallery once the export has ended with problems.
  ///
  /// In es, this message translates to:
  /// **'Ir a la galería'**
  String get importOpenGallery;

  /// Shown in place of a photo that cannot be read.
  ///
  /// In es, this message translates to:
  /// **'No se puede leer esta foto'**
  String get importUnreadable;

  /// Shown when photos were left out of the import for being too big to open. count: how many.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{Una foto es demasiado grande y se ha dejado fuera.} other{{count} fotos son demasiado grandes y se han dejado fuera.}}'**
  String importRejected(int count);

  /// Shown over a photo that has no date when the film asks for the date imprint.
  ///
  /// In es, this message translates to:
  /// **'Sin fecha: no se imprimirá'**
  String get importNoDate;

  /// Title when photos that had to be removed after a cancel or a failure are still in the gallery of the phone.
  ///
  /// In es, this message translates to:
  /// **'Algunas fotos se han quedado'**
  String get importLeftoverTitle;

  /// Explains how many photos could not be removed. count: how many.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{Una foto no se ha podido quitar de la galería del móvil. Está en la carpeta Diapo y puedes borrarla desde ahí.} other{{count} fotos no se han podido quitar de la galería del móvil. Están en la carpeta Diapo y puedes borrarlas desde ahí.}}'**
  String importLeftoverBody(int count);

  /// Shown when there are no loose photos of the day that was asked for.
  ///
  /// In es, this message translates to:
  /// **'No encuentro este día'**
  String get galleryDayMissingTitle;

  /// Key of the viewer that shares the photo.
  ///
  /// In es, this message translates to:
  /// **'Compartir'**
  String get viewerShare;

  /// Key of the viewer that deletes the photo.
  ///
  /// In es, this message translates to:
  /// **'Borrar'**
  String get viewerDelete;

  /// Title of the confirmation before deleting a photo.
  ///
  /// In es, this message translates to:
  /// **'¿Borrar esta foto?'**
  String get viewerDeleteTitle;

  /// Confirmation before deleting a photo.
  ///
  /// In es, this message translates to:
  /// **'Se borrará de Diapo y de la galería del móvil. No se puede deshacer.'**
  String get viewerDeleteBody;

  /// Button that confirms deleting a photo.
  ///
  /// In es, this message translates to:
  /// **'Borrar'**
  String get viewerDeleteConfirm;

  /// Notice when sharing or deleting a photo fails.
  ///
  /// In es, this message translates to:
  /// **'No se ha podido completar. Inténtalo de nuevo.'**
  String get viewerActionFailed;

  /// Notice after deleting a photo whose untouched original could not be deleted with it.
  ///
  /// In es, this message translates to:
  /// **'Foto eliminada, pero su original sigue en Pictures/Diapo/Originales.'**
  String get viewerOriginalKept;

  /// No description provided for @galleryPlaceholder.
  ///
  /// In es, this message translates to:
  /// **'La galería todavía no está aquí.'**
  String get galleryPlaceholder;

  /// Title of the first screen of the first-use flow.
  ///
  /// In es, this message translates to:
  /// **'Una cámara, no un filtro.'**
  String get onboardingTitle1;

  /// Text of the first screen of the first-use flow.
  ///
  /// In es, this message translates to:
  /// **'Eliges la película antes de disparar y la ves en directo en el visor. Tus fotos no salen del móvil.'**
  String get onboardingBody1;

  /// Title of the second screen of the first-use flow.
  ///
  /// In es, this message translates to:
  /// **'Elige la película.'**
  String get onboardingTitle2;

  /// Text of the second screen of the first-use flow.
  ///
  /// In es, this message translates to:
  /// **'Desliza los cartuchos para cambiar de película y mira el resultado en directo en el visor.'**
  String get onboardingBody2;

  /// Title of the third screen of the first-use flow.
  ///
  /// In es, this message translates to:
  /// **'Un carrete: fotos sin mirar.'**
  String get onboardingTitle3;

  /// Text of the third screen of the first-use flow.
  ///
  /// In es, this message translates to:
  /// **'Con un carrete las fotos quedan ocultas hasta que lo reveles. Cuando pase la espera que elijas, te avisamos y abres la app para revelarlas.'**
  String get onboardingBody3;

  /// Key that leaves the first-use flow.
  ///
  /// In es, this message translates to:
  /// **'Saltar'**
  String get onboardingSkip;

  /// Label of the shutter of the first-use flow: goes to the next screen.
  ///
  /// In es, this message translates to:
  /// **'Siguiente'**
  String get onboardingNext;

  /// Label of the shutter on the last screen of the first-use flow: opens the camera.
  ///
  /// In es, this message translates to:
  /// **'Empezar a disparar'**
  String get onboardingStart;

  /// Small label over the picture of the first screen of the first-use flow.
  ///
  /// In es, this message translates to:
  /// **'Sin cuenta'**
  String get onboardingChipNoAccount;

  /// Small label over the picture of the first screen of the first-use flow.
  ///
  /// In es, this message translates to:
  /// **'Sin marca de agua'**
  String get onboardingChipNoWatermark;

  /// Small label over the picture of the first screen of the first-use flow.
  ///
  /// In es, this message translates to:
  /// **'En tu móvil'**
  String get onboardingChipOnDevice;

  /// Screen reader text of the picture of the first screen.
  ///
  /// In es, this message translates to:
  /// **'Un visor con una escena en película. Sin cuenta, sin marca de agua, todo en tu móvil.'**
  String get onboardingArtCamera;

  /// Screen reader text of the picture of the second screen.
  ///
  /// In es, this message translates to:
  /// **'Un visor con una escena en película y, debajo, cinco cartuchos de película.'**
  String get onboardingArtFilm;

  /// Small label under the counter in the picture of the third screen.
  ///
  /// In es, this message translates to:
  /// **'Hechas · ocultas hasta revelar'**
  String get onboardingRollHidden;

  /// Label of the reminder switch in the picture of the third screen.
  ///
  /// In es, this message translates to:
  /// **'Aviso cuando puedas revelar'**
  String get onboardingReminder;

  /// Screen reader text of the picture of the third screen.
  ///
  /// In es, this message translates to:
  /// **'El contador de un carrete con 9 de 24 fotos hechas y ocultas, la espera para revelar a elegir y un aviso opcional.'**
  String get onboardingArtRoll;

  /// Entry of the settings that shows the first-use flow again.
  ///
  /// In es, this message translates to:
  /// **'Cómo funciona'**
  String get settingsHowItWorks;

  /// Row of the settings that opens the store page of the app to leave a review.
  ///
  /// In es, this message translates to:
  /// **'Valorar Diapo'**
  String get settingsRateTitle;

  /// Sentence under the rate row of the settings.
  ///
  /// In es, this message translates to:
  /// **'Una reseña ayuda a que otros la encuentren'**
  String get settingsRateSubtitle;

  /// Row of the settings that opens the Ko-fi page of the developer in the browser to leave a tip.
  ///
  /// In es, this message translates to:
  /// **'Invítame a un café'**
  String get settingsKofiTitle;

  /// Sentence under the Ko-fi row of the settings; says the page opens outside the app.
  ///
  /// In es, this message translates to:
  /// **'Ko-fi, se abre en el navegador'**
  String get settingsKofiSubtitle;

  /// Shown when the browser of the system could not open the Ko-fi page.
  ///
  /// In es, this message translates to:
  /// **'No se ha podido abrir el navegador'**
  String get settingsKofiFailed;

  /// Screen reader text of the step counter of the first-use flow.
  ///
  /// In es, this message translates to:
  /// **'Paso {step} de {total}'**
  String onboardingStepSemantics(int step, int total);

  /// Description of the save location setting: where it goes, when, and that it stays on the phone.
  ///
  /// In es, this message translates to:
  /// **'El lugar se guarda en los datos de la foto (EXIF), solo con la cámara abierta, y no se envía a ningún sitio. Desactivado por defecto.'**
  String get settingSaveLocationHint;

  /// Extra line under the save location setting when only approximate location is granted.
  ///
  /// In es, this message translates to:
  /// **'Solo tienes permiso para la ubicación aproximada, así que el lugar será aproximado.'**
  String get settingSaveLocationApproximate;

  /// Warning under the save location setting when it is on but the permission was removed.
  ///
  /// In es, this message translates to:
  /// **'No se está guardando la ubicación porque se quitó el permiso.'**
  String get settingSaveLocationRevoked;

  /// Action under the save location setting that opens the system settings of the app.
  ///
  /// In es, this message translates to:
  /// **'Abrir los ajustes del sistema'**
  String get settingSaveLocationOpenSettings;

  /// Shown when the user refuses the location permission after turning the setting on.
  ///
  /// In es, this message translates to:
  /// **'Hace falta el permiso de ubicación para guardar el lugar de las fotos.'**
  String get locationPermissionNeeded;

  /// Shown when the location permission is blocked and only the system settings can grant it.
  ///
  /// In es, this message translates to:
  /// **'El permiso de ubicación está bloqueado. Actívalo en los ajustes del sistema.'**
  String get locationPermissionBlocked;

  /// Button of the message that opens the system settings.
  ///
  /// In es, this message translates to:
  /// **'Ajustes'**
  String get locationPermissionBlockedAction;

  /// Row of the Advanced section that opens the export and import of the settings (settings only, not photos).
  ///
  /// In es, this message translates to:
  /// **'Tus ajustes, sin fotos'**
  String get settingsSectionBackup;

  /// Row that saves the settings and the film tuning to a file.
  ///
  /// In es, this message translates to:
  /// **'Exportar ajustes'**
  String get settingsExport;

  /// Explains the export row.
  ///
  /// In es, this message translates to:
  /// **'Guarda un archivo con tus ajustes y el afinado de cada película. No guarda tus fotos: no es una copia de seguridad.'**
  String get settingsExportHint;

  /// Row that restores the settings and the film tuning from a file.
  ///
  /// In es, this message translates to:
  /// **'Importar ajustes'**
  String get settingsImport;

  /// Explains the import row.
  ///
  /// In es, this message translates to:
  /// **'Lee un archivo exportado antes y lo aplica. No recupera fotos.'**
  String get settingsImportHint;

  /// Title of the confirmation before importing settings.
  ///
  /// In es, this message translates to:
  /// **'¿Importar ajustes?'**
  String get settingsImportConfirmTitle;

  /// Body of the confirmation before importing settings.
  ///
  /// In es, this message translates to:
  /// **'Se reemplazarán tus ajustes actuales y el afinado de las películas por los del archivo.'**
  String get settingsImportConfirmBody;

  /// Button that confirms importing settings.
  ///
  /// In es, this message translates to:
  /// **'Importar'**
  String get settingsImportConfirmAction;

  /// Shown after the settings file was saved.
  ///
  /// In es, this message translates to:
  /// **'Ajustes exportados.'**
  String get settingsExportDone;

  /// Shown after the settings were imported.
  ///
  /// In es, this message translates to:
  /// **'Ajustes importados.'**
  String get settingsImportDone;

  /// Added to the import message when the file had films this version does not know. count: how many.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{Se ha dejado fuera una película que esta versión no conoce.} other{Se han dejado fuera {count} películas que esta versión no conoce.}}'**
  String settingsImportSkippedFilms(int count);

  /// Added to the import message: an import never turns location on.
  ///
  /// In es, this message translates to:
  /// **'La ubicación sigue desactivada; actívala aquí si la quieres.'**
  String get settingsImportLocationStaysOff;

  /// Added to the import message: an import never turns saving originals on.
  ///
  /// In es, this message translates to:
  /// **'Guardar también el original sigue desactivado; actívalo aquí si lo quieres.'**
  String get settingsImportOriginalStaysOff;

  /// Import error: the file is too big.
  ///
  /// In es, this message translates to:
  /// **'El archivo es demasiado grande para ser una copia de ajustes de Diapo.'**
  String get settingsBackupTooLarge;

  /// Import error: the file is not readable JSON.
  ///
  /// In es, this message translates to:
  /// **'No se puede leer el archivo: no tiene un formato válido.'**
  String get settingsBackupInvalidJson;

  /// Import error: the file is not a Carrete settings backup.
  ///
  /// In es, this message translates to:
  /// **'Este archivo no es una copia de ajustes de Diapo.'**
  String get settingsBackupWrongFormat;

  /// Import error: the file comes from a newer version.
  ///
  /// In es, this message translates to:
  /// **'Este archivo viene de una versión más nueva de Diapo. Actualiza la app para importarlo.'**
  String get settingsBackupUnsupportedVersion;

  /// Import error: the file has values that are not valid.
  ///
  /// In es, this message translates to:
  /// **'El archivo tiene valores no válidos y no se ha importado nada.'**
  String get settingsBackupInvalidValue;

  /// Error: another export or import is still running.
  ///
  /// In es, this message translates to:
  /// **'Ya hay una exportación o una importación en curso.'**
  String get settingsBackupBusy;

  /// Error: the file or the storage could not be used.
  ///
  /// In es, this message translates to:
  /// **'No se ha podido leer o guardar. Inténtalo de nuevo.'**
  String get settingsBackupStorage;

  /// Error: the operation was interrupted.
  ///
  /// In es, this message translates to:
  /// **'Se interrumpió la operación. Inténtalo de nuevo.'**
  String get settingsBackupInterrupted;

  /// Setting that turns the small vibrations of the camera on or off (shutter, cartridge, roll loaded, roll finished). Not played on silent.
  ///
  /// In es, this message translates to:
  /// **'Vibración'**
  String get settingHaptics;

  /// What the camera says while photos are being saved. count: how many.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{Guardando 1 foto} other{Guardando {count} fotos}}'**
  String saveStatusSaving(int count);

  /// The chip of the camera while some photos could not be saved yet. Tapping it opens the explanation.
  ///
  /// In es, this message translates to:
  /// **'Hay fotos pendientes de guardar'**
  String get saveStatusPending;

  /// Title of the sheet that explains the photos waiting to be saved.
  ///
  /// In es, this message translates to:
  /// **'Fotos pendientes'**
  String get saveSheetTitle;

  /// First line of the sheet. count: the photos waiting.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{1 foto está esperando a guardarse.} other{{count} fotos están esperando a guardarse.}}'**
  String saveSheetCount(int count);

  /// The sheet: the reason is that the storage is full.
  ///
  /// In es, this message translates to:
  /// **'El teléfono se ha quedado sin espacio. Libera espacio y vuelve a intentarlo.'**
  String get saveSheetStorageFull;

  /// The sheet: the reason is a missing permission.
  ///
  /// In es, this message translates to:
  /// **'Diapo no tiene permiso para guardar en la galería. Revisa los permisos del sistema y vuelve a intentarlo.'**
  String get saveSheetPermission;

  /// The sheet: the reason is not known (for example after restarting the app).
  ///
  /// In es, this message translates to:
  /// **'No se han podido guardar ahora. Puedes volver a intentarlo.'**
  String get saveSheetUnknown;

  /// The sheet: where the photos are meanwhile, and what not to do.
  ///
  /// In es, this message translates to:
  /// **'Mientras tanto se conservan de forma provisional dentro de la app. No borres los datos de la app.'**
  String get saveSheetKept;

  /// Key of the sheet that tries to save the photos again.
  ///
  /// In es, this message translates to:
  /// **'Reintentar'**
  String get saveSheetRetry;

  /// Key of the sheet that closes it without doing anything.
  ///
  /// In es, this message translates to:
  /// **'Más tarde'**
  String get saveSheetLater;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ca', 'en', 'es'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ca':
      return AppLocalizationsCa();
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
