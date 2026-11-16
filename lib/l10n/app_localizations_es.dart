// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appTitle => 'Diapo';

  @override
  String get galleryTitle => 'Galería';

  @override
  String get settingsTitle => 'Ajustes';

  @override
  String get rollTitle => 'Carrete';

  @override
  String get settingCameraSounds => 'Sonidos de la cámara';

  @override
  String get settingSaveOriginal => 'Guardar también el original';

  @override
  String get settingSaveOriginalHint =>
      'Si se puede, también guarda la foto sin película.';

  @override
  String get settingSaveLocation => 'Guardar la ubicación';

  @override
  String get settingGrid => 'Cuadrícula';

  @override
  String get settingLevel => 'Nivel';

  @override
  String get settingDateStamp => 'Fecha en la foto';

  @override
  String get settingDefaultFilm => 'Película por defecto';

  @override
  String get settingTheme => 'Tema';

  @override
  String get settingLanguage => 'Idioma';

  @override
  String get settingDateStyle => 'Estilo de la fecha';

  @override
  String get dateStyleYearFirst => 'Año primero';

  @override
  String get dateStyleDayFirst => 'Día primero';

  @override
  String dateStyleSemantics(String style, String date) {
    return '$style: $date';
  }

  @override
  String get settingsSectionCamera => 'Cámara';

  @override
  String get settingsSectionLook => 'Aspecto';

  @override
  String get settingsSectionAdvanced => 'Avanzado';

  @override
  String get settingsSectionAbout => 'Acerca de';

  @override
  String get themeSystem => 'Sistema';

  @override
  String get themeLight => 'Claro';

  @override
  String get themeDark => 'Oscuro';

  @override
  String get languageSystem => 'Sistema';

  @override
  String get languageSpanish => 'Español';

  @override
  String get languageCatalan => 'Català';

  @override
  String get languageEnglish => 'English';

  @override
  String get settingsVersion => 'Versión';

  @override
  String get settingsOfflineNote =>
      'Funciona sin conexión, sin cuentas y sin anuncios. Tus fotos nunca salen del móvil.';

  @override
  String get settingsFreeSoftwareNote =>
      'Diapo es software libre bajo la licencia GPL-3.0-only. Código fuente: https://github.com/dferrandizmont/diapo';

  @override
  String get settingsLicences => 'Licencias';

  @override
  String get settingsPrivacyPolicy => 'Política de privacidad';

  @override
  String get settingsLegalNotice => 'Aviso legal';

  @override
  String get cameraCounterLabel => 'Fotos sueltas';

  @override
  String cameraCounterSemantics(String film) {
    return '$film, fotos sueltas';
  }

  @override
  String get flashOff => 'Apagado';

  @override
  String get flashAuto => 'Automático';

  @override
  String get flashOn => 'Encendido';

  @override
  String get flashParty => 'Fiesta';

  @override
  String flashKeyLabel(String mode) {
    return 'Flash: $mode';
  }

  @override
  String get flashKeyHint => 'Toca para pasar al siguiente modo';

  @override
  String get switchCameraLabel => 'Cambiar de cámara';

  @override
  String get shutterLabel => 'Disparar';

  @override
  String formatKeyLabel(String format) {
    return 'Formato $format';
  }

  @override
  String get formatKeyHint => 'Cambia el formato del encuadre';

  @override
  String get viewfinderLabel => 'Visor de la cámara';

  @override
  String get viewfinderSwipeHint =>
      'Desliza los cartuchos para cambiar de película';

  @override
  String get swipeHintClose => 'Cerrar consejo';

  @override
  String get rollOfferTitle => 'Prueba un carrete de 12';

  @override
  String rollOfferBody(String film) {
    return 'Con $film. Las fotos quedan ocultas hasta que cierres el carrete. Entonces las revelas al momento, sin espera.';
  }

  @override
  String get rollOfferAction => 'Cargar carrete de 12';

  @override
  String get rollOfferDismiss => 'Ahora no';

  @override
  String get filmCarouselLabel => 'Películas';

  @override
  String get filmCartridgeHint => 'Mantén pulsado para los ajustes finos';

  @override
  String tunePanelLabel(String film) {
    return 'Ajustes finos de $film';
  }

  @override
  String get tuneSubtitle => 'Ajustes finos';

  @override
  String get tuneClose => 'Cerrar';

  @override
  String get tuneGrain => 'Grano';

  @override
  String get tuneHalation => 'Halos';

  @override
  String get tuneLeak => 'Fuga de luz';

  @override
  String get tuneVignette => 'Viñeta';

  @override
  String get tuneDateStamp => 'Fecha impresa';

  @override
  String get tuneCinemaBands => 'Bandas de cine';

  @override
  String get tuneFormat => 'Formato';

  @override
  String get whiteFrameHint => 'Marco blanco al guardar';

  @override
  String get focusLockedLabel =>
      'Enfoque y exposición bloqueados. Toca para soltar';

  @override
  String zoomLabel(String zoom) {
    return '${zoom}x';
  }

  @override
  String get cameraPermissionDenied =>
      'Hace falta el permiso de la cámara para hacer fotos. Puedes concederlo en los ajustes del sistema.';

  @override
  String get cameraOpenSettings => 'Abrir los ajustes';

  @override
  String get cameraUnavailable => 'No se puede abrir la cámara.';

  @override
  String get cameraRetry => 'Reintentar';

  @override
  String get shotSaved => 'Foto guardada';

  @override
  String get shotSaveFailed => 'No se pudo guardar la foto.';

  @override
  String get filmsLoadFailed => 'No se pudieron cargar las películas.';

  @override
  String get filmsLoading => 'Cargando las películas';

  @override
  String get rollReadyTitle => 'Ya puedes revelar tu carrete';

  @override
  String rollReadyBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Abre la app para revelar tus $count fotos. Mantenla abierta hasta terminar.',
      one: 'Abre la app para revelar tu foto. Mantenla abierta hasta terminar.',
    );
    return '$_temp0';
  }

  @override
  String get rollKeyLoad => 'Cargar carrete';

  @override
  String rollKeyOpen(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'quedan $count fotos',
      one: 'queda una foto',
    );
    return 'Carrete cargado, $_temp0';
  }

  @override
  String rollKeyLeft(String count) {
    return 'Quedan $count';
  }

  @override
  String rollKeyPaused(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'quedan $count fotos',
      one: 'queda una foto',
    );
    return 'Cámara desechable en pausa, $_temp0';
  }

  @override
  String get rollKeyPausedTitle => 'Desechable en pausa';

  @override
  String get rollCounterLabel => 'Quedan';

  @override
  String rollCounterSemantics(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Quedan $count fotos',
      one: 'Queda una foto',
      zero: 'No quedan fotos',
    );
    return '$_temp0';
  }

  @override
  String get rollFilmLocked =>
      'La película queda fijada mientras haya un carrete cargado';

  @override
  String get rollClosedNotice => 'Carrete terminado';

  @override
  String get rollActionFailed =>
      'No se ha podido completar. Inténtalo de nuevo.';

  @override
  String get rollLoadTitle => 'Cargar un carrete';

  @override
  String get rollSheetIntro =>
      'Una película para todo el carrete. Las fotos quedan ocultas hasta que lo reveles.';

  @override
  String get rollFilmRow => 'Película';

  @override
  String get rollLengthLabel => 'Fotos';

  @override
  String get rollDelayLabel => 'Espera para revelar';

  @override
  String get rollDelayNote => 'La espera empieza cuando cierras el carrete.';

  @override
  String get delayInstant => 'Al momento';

  @override
  String get delayOneHour => '1 hora';

  @override
  String get delayNextMorning => 'Mañana temprano';

  @override
  String get delayThreeDays => '3 días';

  @override
  String get rollLoadAction => 'Cargar carrete';

  @override
  String get rollLoadNote =>
      'Mientras haya un carrete cargado no verás tus fotos, solo cuántas quedan.';

  @override
  String get rollLossWarning =>
      'Las fotos de un carrete sin revelar solo existen en este móvil. Si desinstalas la app, borras sus datos o cambias de móvil, se pierden.';

  @override
  String get rollLossNote =>
      'Solo existen en este móvil: se pierden si desinstalas, borras los datos o cambias de móvil.';

  @override
  String get disposableOption => 'Cámara desechable';

  @override
  String get disposableOptionNote => '27 fotos para compartir la cámara';

  @override
  String disposableOptionSemantics(String title, String detail) {
    return '$title · $detail';
  }

  @override
  String get disposableStartTitle => 'Cámara desechable';

  @override
  String get disposableStartBody =>
      'Tiene 27 fotos y una película fija. Nadie ve las fotos ni toca ajustes: para salir hay que mantener pulsado el sello de salir unos segundos. Al acabar, la revelas como un carrete.';

  @override
  String get disposableStartAction => 'Empezar';

  @override
  String get disposableCounterCaption => 'Fotos que quedan';

  @override
  String get disposableFlashLabel => 'Flash';

  @override
  String get disposableExitWord => 'Salir';

  @override
  String get disposableExitHint => 'Mantén pulsado';

  @override
  String get disposableExitSemantics =>
      'Salir de la cámara desechable. Mantén pulsado durante dos segundos.';

  @override
  String get disposableExitTitle => '¿Salir de la cámara desechable?';

  @override
  String disposableExitBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Quedan $count fotos, que se guardan para más tarde.',
      one: 'Queda 1 foto, que se guarda para más tarde.',
      zero: 'No quedan fotos.',
    );
    return '$_temp0 Podrás seguir desde la llave del carrete.';
  }

  @override
  String get disposableExitConfirm => 'Salir';

  @override
  String get disposableExitStay => 'Seguir';

  @override
  String disposableStrip(int count) {
    return '$count fotos · usar y tirar';
  }

  @override
  String get disposableDone => 'Se acabó la desechable';

  @override
  String get disposableResume => 'Seguir con la desechable';

  @override
  String get disposableAdvanceLabel => 'Avanza';

  @override
  String get disposableFinishAction => 'Terminar carrete';

  @override
  String get disposableFinishInstantNote =>
      'Esta desechable se revela al momento, en cuanto la termines.';

  @override
  String get disposableFinishWarning =>
      'Una vez terminada, ya no se pueden hacer más fotos con ella.';

  @override
  String get disposableFinishKeepWait => 'Mantener la espera';

  @override
  String get disposablePausedNote =>
      'La desechable está a medias: la cámara no la usa. Para cargar otro carrete, sigue con ella, termínala o tírala.';

  @override
  String rollRowSubtitle(String date, String count) {
    return '$date · $count';
  }

  @override
  String get rollRecentTitle => 'Últimos carretes';

  @override
  String get rollStateWaiting => 'Esperando';

  @override
  String get rollStateDeveloping => 'Revelando';

  @override
  String get rollStateDeveloped => 'Revelado';

  @override
  String get rollStateLost => 'Perdido';

  @override
  String rollFramesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count fotos',
      one: '1 foto',
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
  String get rollOpenTitle => 'Carrete en la cámara';

  @override
  String rollOpenSummary(String film, int length) {
    return '$film · $length fotos';
  }

  @override
  String rollDevelopsLine(String delay) {
    return 'Espera para revelar: $delay';
  }

  @override
  String get rollCloseAction => 'Cerrar carrete';

  @override
  String get rollDevelopNowAction => 'Revelar ahora';

  @override
  String get rollDiscardAction => 'Tirar el carrete';

  @override
  String get rollDevelopNowTitle => '¿Revelar ahora?';

  @override
  String rollDevelopNowBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Se revelarán las $count fotos de este carrete ahora.',
      one: 'Se revelará la foto de este carrete ahora.',
      zero: 'Este carrete no tiene fotos.',
    );
    return '$_temp0 La espera termina ya y no se puede deshacer.';
  }

  @override
  String get rollDevelopKeepWaiting => 'Seguir esperando';

  @override
  String get rollDiscardTitle => '¿Tirar el carrete?';

  @override
  String get rollDiscardBody =>
      'Las fotos de este carrete se perderán para siempre. No se puede deshacer.';

  @override
  String get rollDiscardConfirm => 'Tirar';

  @override
  String get dialogCancel => 'Cancelar';

  @override
  String get rollNameEdit => 'Editar nombre del carrete';

  @override
  String get rollNameTitle => 'Nombre del carrete';

  @override
  String get rollNameLabel => 'Nombre';

  @override
  String rollNameNote(String fallback) {
    return 'Es opcional. Sin nombre, el carrete se llama \"$fallback\".';
  }

  @override
  String get rollNameSave => 'Guardar';

  @override
  String rollNameCounter(int count, int max) {
    return '$count de $max caracteres';
  }

  @override
  String get rollWaitingTitle => 'Carrete en espera';

  @override
  String rollReadyOn(String date, String time) {
    return 'Puedes revelar a partir del $date a las $time';
  }

  @override
  String get rollWaitingNote =>
      'Hasta entonces tus fotos siguen guardadas y cifradas en el móvil.';

  @override
  String get rollDevelopingTitle => 'Revelando';

  @override
  String rollDevelopProgressSemantics(int done, int total) {
    return '$done de $total fotos reveladas';
  }

  @override
  String get rollKeepOpen => 'Mantén la app abierta hasta que termine.';

  @override
  String get rollStillOpenTitle => 'Este carrete sigue en la cámara';

  @override
  String get rollLostTitle => 'Este carrete no se puede revelar';

  @override
  String get rollLostBody =>
      'Se perdió la clave que protegía sus fotos, así que no se pueden recuperar.';

  @override
  String get rollDiscardedTitle => 'Este carrete se tiró';

  @override
  String get rollMissingTitle => 'No encuentro este carrete';

  @override
  String get rollShareSheetAction => 'Compartir hoja';

  @override
  String get rollShareSheetRendering => 'Preparando la hoja';

  @override
  String get rollShareSheetError =>
      'No se pudo preparar la hoja. Inténtalo de nuevo.';

  @override
  String get rollShareSheetFailed => 'No se pudo abrir el menú de compartir.';

  @override
  String rollShareSheetPreview(String number) {
    return 'Vista previa de la hoja de contactos del carrete $number';
  }

  @override
  String get contactSheetTitle => 'Hoja de contactos';

  @override
  String rollDevelopedOn(String date) {
    return 'Revelado el $date';
  }

  @override
  String get rollFrameFailed => 'Fallo';

  @override
  String get rollFrameMissing => 'Borrada';

  @override
  String frameSemantics(int number) {
    return 'Fotograma $number';
  }

  @override
  String frameFailedSemantics(int number) {
    return 'Fotograma $number, no se pudo revelar';
  }

  @override
  String frameDevelopingSemantics(int number) {
    return 'Fotograma $number, revelando';
  }

  @override
  String frameMissingSemantics(int number) {
    return 'Fotograma $number, ya no está en la galería';
  }

  @override
  String get frameOpenHint => 'Abre la foto';

  @override
  String viewerPosition(int index, int total) {
    return '$index de $total';
  }

  @override
  String viewerSemantics(int index, int total) {
    return 'Foto $index de $total';
  }

  @override
  String get viewerUnavailable => 'No se puede mostrar la foto.';

  @override
  String rollNumberTitle(String number) {
    return 'Carrete $number';
  }

  @override
  String get galleryEmptyTitle => 'Aún no hay fotos';

  @override
  String get galleryEmptyBody =>
      'Las fotos que hagas aparecerán aquí. Las de un carrete, cuando las reveles.';

  @override
  String get galleryDevelopingLabel => 'En revelado';

  @override
  String get galleryLooseLabel => 'Fotos sueltas';

  @override
  String get galleryToday => 'Hoy';

  @override
  String get galleryYesterday => 'Ayer';

  @override
  String get galleryCardHint => 'Abre las fotos';

  @override
  String get galleryLoadFailed => 'No se ha podido cargar la galería.';

  @override
  String get galleryImportRow => 'Revelar fotos del móvil';

  @override
  String get galleryImportHint =>
      'Elige fotos de tu galería y dales una película';

  @override
  String get importTitle => 'Revelar fotos';

  @override
  String get importPickFailed => 'No se han podido abrir tus fotos.';

  @override
  String importPickLimit(int count) {
    return 'Solo se pueden revelar $count fotos a la vez. Se han cogido las primeras.';
  }

  @override
  String get importCloseLabel => 'Salir sin revelar';

  @override
  String importCounter(int current, int total) {
    return '$current de $total';
  }

  @override
  String importPhotoSemantics(int current, int total, String film) {
    return 'Foto $current de $total, con la película $film';
  }

  @override
  String get importCompareHint => 'Mantén pulsada la foto para ver el original';

  @override
  String get importOriginalPill => 'Original';

  @override
  String get importTuneLabel => 'Ajuste fino';

  @override
  String get importStripLabel => 'Fotos para revelar';

  @override
  String importStripItem(int current, int total) {
    return 'Foto $current de $total';
  }

  @override
  String importDevelopAction(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Revelar las $count fotos',
      one: 'Revelar la foto',
    );
    return '$_temp0';
  }

  @override
  String importProgress(int current, int total) {
    return 'Revelando $current de $total';
  }

  @override
  String get importCancelling => 'Cancelando';

  @override
  String get importPartialTitle => 'Revelado a medias';

  @override
  String importPartialBody(int done, int total) {
    return 'Se han revelado $done de $total fotos. Las demás no se han podido leer o guardar.';
  }

  @override
  String get importFailedTitle => 'No se ha podido revelar';

  @override
  String get importFailedBody =>
      'No se ha guardado ninguna foto. Prueba con otras o inténtalo de nuevo.';

  @override
  String get importOpenGallery => 'Ir a la galería';

  @override
  String get importUnreadable => 'No se puede leer esta foto';

  @override
  String importRejected(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count fotos son demasiado grandes y se han dejado fuera.',
      one: 'Una foto es demasiado grande y se ha dejado fuera.',
    );
    return '$_temp0';
  }

  @override
  String get importNoDate => 'Sin fecha: no se imprimirá';

  @override
  String get importLeftoverTitle => 'Algunas fotos se han quedado';

  @override
  String importLeftoverBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count fotos no se han podido quitar de la galería del móvil. Están en la carpeta Diapo y puedes borrarlas desde ahí.',
      one: 'Una foto no se ha podido quitar de la galería del móvil. Está en la carpeta Diapo y puedes borrarla desde ahí.',
    );
    return '$_temp0';
  }

  @override
  String get galleryDayMissingTitle => 'No encuentro este día';

  @override
  String get viewerShare => 'Compartir';

  @override
  String get viewerDelete => 'Borrar';

  @override
  String get viewerDeleteTitle => '¿Borrar esta foto?';

  @override
  String get viewerDeleteBody =>
      'Se borrará de Diapo y de la galería del móvil. No se puede deshacer.';

  @override
  String get viewerDeleteConfirm => 'Borrar';

  @override
  String get viewerActionFailed =>
      'No se ha podido completar. Inténtalo de nuevo.';

  @override
  String get viewerOriginalKept =>
      'Foto eliminada, pero su original sigue en Pictures/Diapo/Originales.';

  @override
  String get galleryPlaceholder => 'La galería todavía no está aquí.';

  @override
  String get onboardingTitle1 => 'Una cámara, no un filtro.';

  @override
  String get onboardingBody1 =>
      'Eliges la película antes de disparar y la ves en directo en el visor. Tus fotos no salen del móvil.';

  @override
  String get onboardingTitle2 => 'Elige la película.';

  @override
  String get onboardingBody2 =>
      'Desliza los cartuchos para cambiar de película y mira el resultado en directo en el visor.';

  @override
  String get onboardingTitle3 => 'Un carrete: fotos sin mirar.';

  @override
  String get onboardingBody3 =>
      'Con un carrete las fotos quedan ocultas hasta que lo reveles. Cuando pase la espera que elijas, te avisamos y abres la app para revelarlas.';

  @override
  String get onboardingSkip => 'Saltar';

  @override
  String get onboardingNext => 'Siguiente';

  @override
  String get onboardingStart => 'Empezar a disparar';

  @override
  String get onboardingChipNoAccount => 'Sin cuenta';

  @override
  String get onboardingChipNoWatermark => 'Sin marca de agua';

  @override
  String get onboardingChipOnDevice => 'En tu móvil';

  @override
  String get onboardingArtCamera =>
      'Un visor con una escena en película. Sin cuenta, sin marca de agua, todo en tu móvil.';

  @override
  String get onboardingArtFilm =>
      'Un visor con una escena en película y, debajo, cinco cartuchos de película.';

  @override
  String get onboardingRollHidden => 'Hechas · ocultas hasta revelar';

  @override
  String get onboardingReminder => 'Aviso cuando puedas revelar';

  @override
  String get onboardingArtRoll =>
      'El contador de un carrete con 9 de 24 fotos hechas y ocultas, la espera para revelar a elegir y un aviso opcional.';

  @override
  String get settingsHowItWorks => 'Cómo funciona';

  @override
  String get settingsRateTitle => 'Valorar Diapo';

  @override
  String get settingsRateSubtitle =>
      'Una reseña ayuda a que otros la encuentren';

  @override
  String get settingsKofiTitle => 'Invítame a un café';

  @override
  String get settingsKofiSubtitle => 'Ko-fi, se abre en el navegador';

  @override
  String get settingsKofiFailed => 'No se ha podido abrir el navegador';

  @override
  String onboardingStepSemantics(int step, int total) {
    return 'Paso $step de $total';
  }

  @override
  String get settingSaveLocationHint =>
      'El lugar se guarda en los datos de la foto (EXIF), solo con la cámara abierta, y no se envía a ningún sitio. Desactivado por defecto.';

  @override
  String get settingSaveLocationApproximate =>
      'Solo tienes permiso para la ubicación aproximada, así que el lugar será aproximado.';

  @override
  String get settingSaveLocationRevoked =>
      'No se está guardando la ubicación porque se quitó el permiso.';

  @override
  String get settingSaveLocationOpenSettings => 'Abrir los ajustes del sistema';

  @override
  String get locationPermissionNeeded =>
      'Hace falta el permiso de ubicación para guardar el lugar de las fotos.';

  @override
  String get locationPermissionBlocked =>
      'El permiso de ubicación está bloqueado. Actívalo en los ajustes del sistema.';

  @override
  String get locationPermissionBlockedAction => 'Ajustes';

  @override
  String get settingsSectionBackup => 'Tus ajustes, sin fotos';

  @override
  String get settingsExport => 'Exportar ajustes';

  @override
  String get settingsExportHint =>
      'Guarda un archivo con tus ajustes y el afinado de cada película. No guarda tus fotos: no es una copia de seguridad.';

  @override
  String get settingsImport => 'Importar ajustes';

  @override
  String get settingsImportHint =>
      'Lee un archivo exportado antes y lo aplica. No recupera fotos.';

  @override
  String get settingsImportConfirmTitle => '¿Importar ajustes?';

  @override
  String get settingsImportConfirmBody =>
      'Se reemplazarán tus ajustes actuales y el afinado de las películas por los del archivo.';

  @override
  String get settingsImportConfirmAction => 'Importar';

  @override
  String get settingsExportDone => 'Ajustes exportados.';

  @override
  String get settingsImportDone => 'Ajustes importados.';

  @override
  String settingsImportSkippedFilms(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Se han dejado fuera $count películas que esta versión no conoce.',
      one: 'Se ha dejado fuera una película que esta versión no conoce.',
    );
    return '$_temp0';
  }

  @override
  String get settingsImportLocationStaysOff =>
      'La ubicación sigue desactivada; actívala aquí si la quieres.';

  @override
  String get settingsImportOriginalStaysOff =>
      'Guardar también el original sigue desactivado; actívalo aquí si lo quieres.';

  @override
  String get settingsBackupTooLarge =>
      'El archivo es demasiado grande para ser una copia de ajustes de Diapo.';

  @override
  String get settingsBackupInvalidJson =>
      'No se puede leer el archivo: no tiene un formato válido.';

  @override
  String get settingsBackupWrongFormat =>
      'Este archivo no es una copia de ajustes de Diapo.';

  @override
  String get settingsBackupUnsupportedVersion =>
      'Este archivo viene de una versión más nueva de Diapo. Actualiza la app para importarlo.';

  @override
  String get settingsBackupInvalidValue =>
      'El archivo tiene valores no válidos y no se ha importado nada.';

  @override
  String get settingsBackupBusy =>
      'Ya hay una exportación o una importación en curso.';

  @override
  String get settingsBackupStorage =>
      'No se ha podido leer o guardar. Inténtalo de nuevo.';

  @override
  String get settingsBackupInterrupted =>
      'Se interrumpió la operación. Inténtalo de nuevo.';

  @override
  String get settingHaptics => 'Vibración';

  @override
  String saveStatusSaving(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Guardando $count fotos',
      one: 'Guardando 1 foto',
    );
    return '$_temp0';
  }

  @override
  String get saveStatusPending => 'Hay fotos pendientes de guardar';

  @override
  String get saveSheetTitle => 'Fotos pendientes';

  @override
  String saveSheetCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count fotos están esperando a guardarse.',
      one: '1 foto está esperando a guardarse.',
    );
    return '$_temp0';
  }

  @override
  String get saveSheetStorageFull =>
      'El teléfono se ha quedado sin espacio. Libera espacio y vuelve a intentarlo.';

  @override
  String get saveSheetPermission =>
      'Diapo no tiene permiso para guardar en la galería. Revisa los permisos del sistema y vuelve a intentarlo.';

  @override
  String get saveSheetUnknown =>
      'No se han podido guardar ahora. Puedes volver a intentarlo.';

  @override
  String get saveSheetKept =>
      'Mientras tanto se conservan de forma provisional dentro de la app. No borres los datos de la app.';

  @override
  String get saveSheetRetry => 'Reintentar';

  @override
  String get saveSheetLater => 'Más tarde';
}
