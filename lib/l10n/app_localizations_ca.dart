// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Catalan Valencian (`ca`).
class AppLocalizationsCa extends AppLocalizations {
  AppLocalizationsCa([String locale = 'ca']) : super(locale);

  @override
  String get appTitle => 'Diapo';

  @override
  String get galleryTitle => 'Galeria';

  @override
  String get settingsTitle => 'Configuració';

  @override
  String get rollTitle => 'Rodet';

  @override
  String get settingCameraSounds => 'Sons de la càmera';

  @override
  String get settingSaveOriginal => 'Desa també l\'original';

  @override
  String get settingSaveOriginalHint =>
      'Si es pot, també desa la foto sense pel·lícula.';

  @override
  String get settingSaveLocation => 'Desa la ubicació';

  @override
  String get settingGrid => 'Reixeta';

  @override
  String get settingLevel => 'Nivell';

  @override
  String get settingDateStamp => 'Data a la foto';

  @override
  String get settingDefaultFilm => 'Pel·lícula per defecte';

  @override
  String get settingTheme => 'Tema';

  @override
  String get settingLanguage => 'Idioma';

  @override
  String get settingDateStyle => 'Estil de la data';

  @override
  String get dateStyleYearFirst => 'Any primer';

  @override
  String get dateStyleDayFirst => 'Dia primer';

  @override
  String dateStyleSemantics(String style, String date) {
    return '$style: $date';
  }

  @override
  String get settingsSectionCamera => 'Càmera';

  @override
  String get settingsSectionLook => 'Aspecte';

  @override
  String get settingsSectionAdvanced => 'Avançat';

  @override
  String get settingsSectionAbout => 'Quant a';

  @override
  String get themeSystem => 'Sistema';

  @override
  String get themeLight => 'Clar';

  @override
  String get themeDark => 'Fosc';

  @override
  String get languageSystem => 'Sistema';

  @override
  String get languageSpanish => 'Español';

  @override
  String get languageCatalan => 'Català';

  @override
  String get languageEnglish => 'English';

  @override
  String get settingsVersion => 'Versió';

  @override
  String get settingsOfflineNote =>
      'Funciona sense connexió, sense comptes ni anuncis. Les teves fotos mai no surten del mòbil.';

  @override
  String get settingsFreeSoftwareNote =>
      'Diapo és programari lliure sota la llicència GPL-3.0-only. Codi font: https://github.com/dferrandizmont/diapo';

  @override
  String get settingsLicences => 'Llicències';

  @override
  String get settingsPrivacyPolicy => 'Política de privacitat';

  @override
  String get settingsLegalNotice => 'Avís legal';

  @override
  String get cameraCounterLabel => 'Fotos soltes';

  @override
  String cameraCounterSemantics(String film) {
    return '$film, fotos soltes';
  }

  @override
  String get flashOff => 'Apagat';

  @override
  String get flashAuto => 'Automàtic';

  @override
  String get flashOn => 'Encès';

  @override
  String get flashParty => 'Festa';

  @override
  String flashKeyLabel(String mode) {
    return 'Flaix: $mode';
  }

  @override
  String get flashKeyHint => 'Toca per passar al mode següent';

  @override
  String get switchCameraLabel => 'Canviar de càmera';

  @override
  String get shutterLabel => 'Disparar';

  @override
  String formatKeyLabel(String format) {
    return 'Format $format';
  }

  @override
  String get formatKeyHint => 'Canvia el format del quadre';

  @override
  String get viewfinderLabel => 'Visor de la càmera';

  @override
  String get viewfinderSwipeHint =>
      'Fes lliscar els cartutxos per canviar de pel·lícula';

  @override
  String get swipeHintClose => 'Tanca el consell';

  @override
  String get rollOfferTitle => 'Prova un rodet de 12';

  @override
  String rollOfferBody(String film) {
    return 'Amb $film. Les fotos queden amagades fins que tanquis el rodet. Aleshores les reveles al moment, sense espera.';
  }

  @override
  String get rollOfferAction => 'Carregar rodet de 12';

  @override
  String get rollOfferDismiss => 'Ara no';

  @override
  String get filmCarouselLabel => 'Pel·lícules';

  @override
  String get filmCartridgeHint => 'Mantén premut per als ajustos fins';

  @override
  String tunePanelLabel(String film) {
    return 'Ajustos fins de $film';
  }

  @override
  String get tuneSubtitle => 'Ajustos fins';

  @override
  String get tuneClose => 'Tancar';

  @override
  String get tuneGrain => 'Gra';

  @override
  String get tuneHalation => 'Halos';

  @override
  String get tuneLeak => 'Fuita de llum';

  @override
  String get tuneVignette => 'Vinyeta';

  @override
  String get tuneDateStamp => 'Data impresa';

  @override
  String get tuneCinemaBands => 'Bandes de cinema';

  @override
  String get tuneFormat => 'Format';

  @override
  String get whiteFrameHint => 'Marc blanc en desar';

  @override
  String get focusLockedLabel =>
      'Enfocament i exposició bloquejats. Toca per deixar anar';

  @override
  String zoomLabel(String zoom) {
    return '${zoom}x';
  }

  @override
  String get cameraPermissionDenied =>
      'Cal el permís de la càmera per fer fotos. Pots concedir-lo als ajustos del sistema.';

  @override
  String get cameraOpenSettings => 'Obre els ajustos';

  @override
  String get cameraUnavailable => 'No es pot obrir la càmera.';

  @override
  String get cameraRetry => 'Tornar-ho a provar';

  @override
  String get shotSaved => 'Foto desada';

  @override
  String get shotSaveFailed => 'No s\'ha pogut desar la foto.';

  @override
  String get filmsLoadFailed => 'No s\'han pogut carregar les pel·lícules.';

  @override
  String get filmsLoading => 'S\'estan carregant les pel·lícules';

  @override
  String get rollReadyTitle => 'Ja pots revelar el teu rodet';

  @override
  String rollReadyBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Obre l\'app per revelar les teves $count fotos. Mantén-la oberta fins que acabi.',
      one: 'Obre l\'app per revelar la teva foto. Mantén-la oberta fins que acabi.',
    );
    return '$_temp0';
  }

  @override
  String get rollKeyLoad => 'Carregar rodet';

  @override
  String rollKeyOpen(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'queden $count fotos',
      one: 'queda una foto',
    );
    return 'Rodet carregat, $_temp0';
  }

  @override
  String rollKeyLeft(String count) {
    return 'Queden $count';
  }

  @override
  String rollKeyPaused(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'queden $count fotos',
      one: 'queda una foto',
    );
    return 'Càmera d\'un sol ús en pausa, $_temp0';
  }

  @override
  String get rollKeyPausedTitle => 'Un sol ús en pausa';

  @override
  String get rollCounterLabel => 'Queden';

  @override
  String rollCounterSemantics(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Queden $count fotos',
      one: 'Queda una foto',
      zero: 'No queden fotos',
    );
    return '$_temp0';
  }

  @override
  String get rollFilmLocked =>
      'La pel·lícula queda fixada mentre hi hagi un rodet carregat';

  @override
  String get rollClosedNotice => 'Rodet acabat';

  @override
  String get rollActionFailed => 'No s\'ha pogut completar. Torna-ho a provar.';

  @override
  String get rollLoadTitle => 'Carregar un rodet';

  @override
  String get rollSheetIntro =>
      'Una pel·lícula per a tot el rodet. Les fotos queden amagades fins que el reveles.';

  @override
  String get rollFilmRow => 'Pel·lícula';

  @override
  String get rollLengthLabel => 'Fotos';

  @override
  String get rollDelayLabel => 'Espera per revelar';

  @override
  String get rollDelayNote => 'L\'espera comença quan tanques el rodet.';

  @override
  String get delayInstant => 'Al moment';

  @override
  String get delayOneHour => '1 hora';

  @override
  String get delayNextMorning => 'Demà al matí';

  @override
  String get delayThreeDays => '3 dies';

  @override
  String get rollLoadAction => 'Carregar rodet';

  @override
  String get rollLoadNote =>
      'Mentre hi hagi un rodet carregat no veuràs les teves fotos, només quantes en queden.';

  @override
  String get rollLossWarning =>
      'Les fotos d\'un rodet sense revelar només existeixen en aquest mòbil. Si desinstal·les l\'app, n\'esborres les dades o canvies de mòbil, es perden.';

  @override
  String get rollLossNote =>
      'Només existeixen en aquest mòbil: es perden si desinstal·les, esborres les dades o canvies de mòbil.';

  @override
  String get disposableOption => 'Càmera d\'un sol ús';

  @override
  String get disposableOptionNote => '27 fotos per compartir la càmera';

  @override
  String disposableOptionSemantics(String title, String detail) {
    return '$title · $detail';
  }

  @override
  String get disposableStartTitle => 'Càmera d\'un sol ús';

  @override
  String get disposableStartBody =>
      'Té 27 fotos i una pel·lícula fixa. Ningú no veu les fotos ni toca els ajustos: per sortir cal mantenir premut el segell de sortida uns segons. En acabar, la reveles com un rodet.';

  @override
  String get disposableStartAction => 'Començar';

  @override
  String get disposableCounterCaption => 'Fotos que queden';

  @override
  String get disposableFlashLabel => 'Flaix';

  @override
  String get disposableExitWord => 'Sortir';

  @override
  String get disposableExitHint => 'Mantén premut';

  @override
  String get disposableExitSemantics =>
      'Sortir de la càmera d\'un sol ús. Mantén premut durant dos segons.';

  @override
  String get disposableExitTitle => 'Sortir de la càmera d\'un sol ús?';

  @override
  String disposableExitBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Queden $count fotos, que es guarden per més tard.',
      one: 'Queda 1 foto, que es guarda per més tard.',
      zero: 'No queden fotos.',
    );
    return '$_temp0 Podràs continuar des de la clau del rodet.';
  }

  @override
  String get disposableExitConfirm => 'Sortir';

  @override
  String get disposableExitStay => 'Continuar';

  @override
  String disposableStrip(int count) {
    return '$count fotos · usar i llençar';
  }

  @override
  String get disposableDone => 'S\'ha acabat la càmera d\'un sol ús';

  @override
  String get disposableResume => 'Tornar a la càmera d\'un sol ús';

  @override
  String get disposableAdvanceLabel => 'Avança';

  @override
  String get disposableFinishAction => 'Acabar el rodet';

  @override
  String get disposableFinishInstantNote =>
      'Aquesta càmera d\'un sol ús es revela a l\'instant, tan bon punt l\'acabis.';

  @override
  String get disposableFinishWarning =>
      'Un cop acabada, ja no s\'hi poden fer més fotos.';

  @override
  String get disposableFinishKeepWait => 'Mantenir l\'espera';

  @override
  String get disposablePausedNote =>
      'La càmera d\'un sol ús és a mitges: la càmera no la fa servir. Per carregar un altre rodet, continua-hi, acaba-la o llença-la.';

  @override
  String rollRowSubtitle(String date, String count) {
    return '$date · $count';
  }

  @override
  String get rollRecentTitle => 'Últims rodets';

  @override
  String get rollStateWaiting => 'Esperant';

  @override
  String get rollStateDeveloping => 'Revelant';

  @override
  String get rollStateDeveloped => 'Revelat';

  @override
  String get rollStateLost => 'Perdut';

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
  String get rollOpenTitle => 'Rodet a la càmera';

  @override
  String rollOpenSummary(String film, int length) {
    return '$film · $length fotos';
  }

  @override
  String rollDevelopsLine(String delay) {
    return 'Espera per revelar: $delay';
  }

  @override
  String get rollCloseAction => 'Tancar rodet';

  @override
  String get rollDevelopNowAction => 'Revelar ara';

  @override
  String get rollDiscardAction => 'Llençar el rodet';

  @override
  String get rollDevelopNowTitle => 'Revelar ara?';

  @override
  String rollDevelopNowBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Es revelaran ara les $count fotos d\'aquest rodet.',
      one: 'Es revelarà ara la foto d\'aquest rodet.',
      zero: 'Aquest rodet no té fotos.',
    );
    return '$_temp0 L\'espera acaba ara i no es pot desfer.';
  }

  @override
  String get rollDevelopKeepWaiting => 'Continuar esperant';

  @override
  String get rollDiscardTitle => 'Llençar el rodet?';

  @override
  String get rollDiscardBody =>
      'Les fotos d\'aquest rodet es perdran per sempre. No es pot desfer.';

  @override
  String get rollDiscardConfirm => 'Llençar';

  @override
  String get dialogCancel => 'Cancel·lar';

  @override
  String get rollNameEdit => 'Edita el nom del rodet';

  @override
  String get rollNameTitle => 'Nom del rodet';

  @override
  String get rollNameLabel => 'Nom';

  @override
  String rollNameNote(String fallback) {
    return 'És opcional. Sense nom, el rodet es diu \"$fallback\".';
  }

  @override
  String get rollNameSave => 'Desa';

  @override
  String rollNameCounter(int count, int max) {
    return '$count de $max caràcters';
  }

  @override
  String get rollWaitingTitle => 'Rodet en espera';

  @override
  String rollReadyOn(String date, String time) {
    return 'Pots revelar a partir del $date a les $time';
  }

  @override
  String get rollWaitingNote =>
      'Fins aleshores les teves fotos queden desades i xifrades al mòbil.';

  @override
  String get rollDevelopingTitle => 'Revelant';

  @override
  String rollDevelopProgressSemantics(int done, int total) {
    return '$done de $total fotos revelades';
  }

  @override
  String get rollKeepOpen => 'Mantén l\'app oberta fins que acabi.';

  @override
  String get rollStillOpenTitle => 'Aquest rodet encara és a la càmera';

  @override
  String get rollLostTitle => 'Aquest rodet no es pot revelar';

  @override
  String get rollLostBody =>
      'Es va perdre la clau que protegia les seves fotos, així que no es poden recuperar.';

  @override
  String get rollDiscardedTitle => 'Aquest rodet es va llençar';

  @override
  String get rollMissingTitle => 'No trobo aquest rodet';

  @override
  String get rollShareSheetAction => 'Comparteix el full';

  @override
  String get rollShareSheetRendering => 'Preparant el full';

  @override
  String get rollShareSheetError =>
      'No s\'ha pogut preparar el full. Torna-ho a provar.';

  @override
  String get rollShareSheetFailed =>
      'No s\'ha pogut obrir el menú de compartir.';

  @override
  String rollShareSheetPreview(String number) {
    return 'Vista prèvia del full de contactes del rodet $number';
  }

  @override
  String get contactSheetTitle => 'Full de contactes';

  @override
  String rollDevelopedOn(String date) {
    return 'Revelat el $date';
  }

  @override
  String get rollFrameFailed => 'Error';

  @override
  String get rollFrameMissing => 'Esborrada';

  @override
  String frameSemantics(int number) {
    return 'Fotograma $number';
  }

  @override
  String frameFailedSemantics(int number) {
    return 'Fotograma $number, no s\'ha pogut revelar';
  }

  @override
  String frameDevelopingSemantics(int number) {
    return 'Fotograma $number, revelant';
  }

  @override
  String frameMissingSemantics(int number) {
    return 'Fotograma $number, ja no és a la galeria';
  }

  @override
  String get frameOpenHint => 'Obre la foto';

  @override
  String viewerPosition(int index, int total) {
    return '$index de $total';
  }

  @override
  String viewerSemantics(int index, int total) {
    return 'Foto $index de $total';
  }

  @override
  String get viewerUnavailable => 'No es pot mostrar la foto.';

  @override
  String rollNumberTitle(String number) {
    return 'Rodet $number';
  }

  @override
  String get galleryEmptyTitle => 'Encara no hi ha fotos';

  @override
  String get galleryEmptyBody =>
      'Les fotos que facis apareixeran aquí. Les d\'un rodet, quan les revelis.';

  @override
  String get galleryDevelopingLabel => 'En revelat';

  @override
  String get galleryLooseLabel => 'Fotos soltes';

  @override
  String get galleryToday => 'Avui';

  @override
  String get galleryYesterday => 'Ahir';

  @override
  String get galleryCardHint => 'Obre les fotos';

  @override
  String get galleryLoadFailed => 'No s\'ha pogut carregar la galeria.';

  @override
  String get galleryImportRow => 'Revela fotos del mòbil';

  @override
  String get galleryImportHint =>
      'Tria fotos de la teva galeria i dona\'ls una pel·lícula';

  @override
  String get importTitle => 'Revela fotos';

  @override
  String get importPickFailed => 'No s\'han pogut obrir les teves fotos.';

  @override
  String importPickLimit(int count) {
    return 'Només es poden revelar $count fotos alhora. S\'han agafat les primeres.';
  }

  @override
  String get importCloseLabel => 'Sortir sense revelar';

  @override
  String importCounter(int current, int total) {
    return '$current de $total';
  }

  @override
  String importPhotoSemantics(int current, int total, String film) {
    return 'Foto $current de $total, amb la pel·lícula $film';
  }

  @override
  String get importCompareHint =>
      'Mantén premuda la foto per veure l\'original';

  @override
  String get importOriginalPill => 'Original';

  @override
  String get importTuneLabel => 'Ajust fi';

  @override
  String get importStripLabel => 'Fotos per revelar';

  @override
  String importStripItem(int current, int total) {
    return 'Foto $current de $total';
  }

  @override
  String importDevelopAction(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Revela les $count fotos',
      one: 'Revela la foto',
    );
    return '$_temp0';
  }

  @override
  String importProgress(int current, int total) {
    return 'Revelant $current de $total';
  }

  @override
  String get importCancelling => 'Cancel·lant';

  @override
  String get importPartialTitle => 'Revelat a mitges';

  @override
  String importPartialBody(int done, int total) {
    return 'S\'han revelat $done de $total fotos. Les altres no s\'han pogut llegir o desar.';
  }

  @override
  String get importFailedTitle => 'No s\'ha pogut revelar';

  @override
  String get importFailedBody =>
      'No s\'ha desat cap foto. Prova-ho amb unes altres o torna-ho a intentar.';

  @override
  String get importOpenGallery => 'Anar a la galeria';

  @override
  String get importUnreadable => 'No es pot llegir aquesta foto';

  @override
  String importRejected(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count fotos són massa grans i s\'han deixat fora.',
      one: 'Una foto és massa gran i s\'ha deixat fora.',
    );
    return '$_temp0';
  }

  @override
  String get importNoDate => 'Sense data: no s\'imprimirà';

  @override
  String get importLeftoverTitle => 'Algunes fotos s\'han quedat';

  @override
  String importLeftoverBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count fotos no s\'han pogut treure de la galeria del mòbil. Són a la carpeta Diapo i les pots esborrar des d\'allà.',
      one: 'Una foto no s\'ha pogut treure de la galeria del mòbil. És a la carpeta Diapo i la pots esborrar des d\'allà.',
    );
    return '$_temp0';
  }

  @override
  String get galleryDayMissingTitle => 'No trobo aquest dia';

  @override
  String get viewerShare => 'Comparteix';

  @override
  String get viewerDelete => 'Esborra';

  @override
  String get viewerDeleteTitle => 'Vols esborrar aquesta foto?';

  @override
  String get viewerDeleteBody =>
      'S\'esborrarà de Diapo i de la galeria del mòbil. No es pot desfer.';

  @override
  String get viewerDeleteConfirm => 'Esborra';

  @override
  String get viewerActionFailed =>
      'No s\'ha pogut completar. Torna-ho a provar.';

  @override
  String get viewerOriginalKept =>
      'Foto eliminada, però el seu original continua a Pictures/Diapo/Originales.';

  @override
  String get galleryPlaceholder => 'La galeria encara no és aquí.';

  @override
  String get onboardingTitle1 => 'Una càmera, no un filtre.';

  @override
  String get onboardingBody1 =>
      'Tries la pel·lícula abans de disparar i la veus en directe al visor. Les teves fotos no surten del mòbil.';

  @override
  String get onboardingTitle2 => 'Tria la pel·lícula.';

  @override
  String get onboardingBody2 =>
      'Fes lliscar els cartutxos per canviar de pel·lícula i mira el resultat en directe al visor.';

  @override
  String get onboardingTitle3 => 'Un rodet: fotos sense mirar.';

  @override
  String get onboardingBody3 =>
      'Amb un rodet les fotos queden amagades fins que el reveles. Quan passi l\'espera que triïs, t\'avisem i obres l\'app per revelar-les.';

  @override
  String get onboardingSkip => 'Saltar';

  @override
  String get onboardingNext => 'Següent';

  @override
  String get onboardingStart => 'Començar a disparar';

  @override
  String get onboardingChipNoAccount => 'Sense compte';

  @override
  String get onboardingChipNoWatermark => 'Sense marca d\'aigua';

  @override
  String get onboardingChipOnDevice => 'Al teu mòbil';

  @override
  String get onboardingArtCamera =>
      'Un visor amb una escena en pel·lícula. Sense compte, sense marca d\'aigua, tot al teu mòbil.';

  @override
  String get onboardingArtFilm =>
      'Un visor amb una escena en pel·lícula i, a sota, cinc cartutxos de pel·lícula.';

  @override
  String get onboardingRollHidden => 'Fetes · amagades fins a revelar';

  @override
  String get onboardingReminder => 'Avís quan puguis revelar';

  @override
  String get onboardingArtRoll =>
      'El comptador d\'un rodet amb 9 de 24 fotos fetes i amagades, l\'espera per revelar a triar i un avís opcional.';

  @override
  String get settingsHowItWorks => 'Com funciona';

  @override
  String get settingsRateTitle => 'Valorar Diapo';

  @override
  String get settingsRateSubtitle => 'Una ressenya ajuda que altres la trobin';

  @override
  String get settingsKofiTitle => 'Convida\'m a un cafè';

  @override
  String get settingsKofiSubtitle => 'Ko-fi, s\'obre al navegador';

  @override
  String get settingsKofiFailed => 'No s\'ha pogut obrir el navegador';

  @override
  String onboardingStepSemantics(int step, int total) {
    return 'Pas $step de $total';
  }

  @override
  String get settingSaveLocationHint =>
      'El lloc es desa a les dades de la foto (EXIF), només amb la càmera oberta, i no s\'envia enlloc. Desactivat per defecte.';

  @override
  String get settingSaveLocationApproximate =>
      'Només tens permís per a la ubicació aproximada, així que el lloc serà aproximat.';

  @override
  String get settingSaveLocationRevoked =>
      'No s\'està desant la ubicació perquè s\'ha retirat el permís.';

  @override
  String get settingSaveLocationOpenSettings => 'Obre els ajustos del sistema';

  @override
  String get locationPermissionNeeded =>
      'Cal el permís d\'ubicació per desar el lloc de les fotos.';

  @override
  String get locationPermissionBlocked =>
      'El permís d\'ubicació està bloquejat. Activa\'l als ajustos del sistema.';

  @override
  String get locationPermissionBlockedAction => 'Ajustos';

  @override
  String get settingsSectionBackup => 'Els teus ajustos, sense fotos';

  @override
  String get settingsExport => 'Exporta els ajustos';

  @override
  String get settingsExportHint =>
      'Desa un fitxer amb els teus ajustos i l\'afinament de cada pel·lícula. No desa les teves fotos: no és una còpia de seguretat.';

  @override
  String get settingsImport => 'Importa els ajustos';

  @override
  String get settingsImportHint =>
      'Llegeix un fitxer exportat abans i l\'aplica. No recupera fotos.';

  @override
  String get settingsImportConfirmTitle => 'Vols importar els ajustos?';

  @override
  String get settingsImportConfirmBody =>
      'Es reemplaçaran els teus ajustos actuals i l\'afinament de les pel·lícules pels del fitxer.';

  @override
  String get settingsImportConfirmAction => 'Importa';

  @override
  String get settingsExportDone => 'Ajustos exportats.';

  @override
  String get settingsImportDone => 'Ajustos importats.';

  @override
  String settingsImportSkippedFilms(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'S\'han deixat fora $count pel·lícules que aquesta versió no coneix.',
      one: 'S\'ha deixat fora una pel·lícula que aquesta versió no coneix.',
    );
    return '$_temp0';
  }

  @override
  String get settingsImportLocationStaysOff =>
      'La ubicació continua desactivada; activa-la aquí si la vols.';

  @override
  String get settingsImportOriginalStaysOff =>
      'Desa també l\'original continua desactivat; activa\'l aquí si el vols.';

  @override
  String get settingsBackupTooLarge =>
      'El fitxer és massa gran per ser una còpia d\'ajustos de Diapo.';

  @override
  String get settingsBackupInvalidJson =>
      'No es pot llegir el fitxer: no té un format vàlid.';

  @override
  String get settingsBackupWrongFormat =>
      'Aquest fitxer no és una còpia d\'ajustos de Diapo.';

  @override
  String get settingsBackupUnsupportedVersion =>
      'Aquest fitxer ve d\'una versió més nova de Diapo. Actualitza l\'app per importar-lo.';

  @override
  String get settingsBackupInvalidValue =>
      'El fitxer té valors no vàlids i no s\'ha importat res.';

  @override
  String get settingsBackupBusy =>
      'Ja hi ha una exportació o una importació en curs.';

  @override
  String get settingsBackupStorage =>
      'No s\'ha pogut llegir o desar. Torna-ho a provar.';

  @override
  String get settingsBackupInterrupted =>
      'S\'ha interromput l\'operació. Torna-ho a provar.';

  @override
  String get settingHaptics => 'Vibració';

  @override
  String saveStatusSaving(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Desant $count fotos',
      one: 'Desant 1 foto',
    );
    return '$_temp0';
  }

  @override
  String get saveStatusPending => 'Hi ha fotos pendents de desar';

  @override
  String get saveSheetTitle => 'Fotos pendents';

  @override
  String saveSheetCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count fotos estan esperant per desar-se.',
      one: '1 foto està esperant per desar-se.',
    );
    return '$_temp0';
  }

  @override
  String get saveSheetStorageFull =>
      'El telèfon s\'ha quedat sense espai. Allibera espai i torna-ho a provar.';

  @override
  String get saveSheetPermission =>
      'Diapo no té permís per desar a la galeria. Revisa els permisos del sistema i torna-ho a provar.';

  @override
  String get saveSheetUnknown =>
      'Ara no s\'han pogut desar. Pots tornar-ho a provar.';

  @override
  String get saveSheetKept =>
      'Mentrestant es conserven de manera provisional dins de l\'app. No esborris les dades de l\'app.';

  @override
  String get saveSheetRetry => 'Tornar-ho a provar';

  @override
  String get saveSheetLater => 'Més tard';
}
