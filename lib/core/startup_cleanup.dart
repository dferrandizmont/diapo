import 'dart:io';

import '../capture/failed_shots.dart';
import '../roll/contact_sheet_image.dart';
import '../roll/roll_temp_files.dart';

/// The temporary files the app removes at every start, before anything else
/// reads the cache.
///
/// * Disposable encoder copies of the capture queue. Unconfirmed camera
///   originals and roll recovery records stay: they must survive until their
///   durable save.
/// * The decrypted copies of a roll that was being developed.
/// * The contact sheets rendered to share: plaintext copies of the user's
///   photos that a closed preview, or a process that died, left behind.
Future<void> cleanStartupTemps(Directory cache) async {
  await cleanCaptureLeftovers(cache);
  await cleanRollDevelopmentTemps(cache);
  await cleanContactSheets(cache);
}
