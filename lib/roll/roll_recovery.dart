import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import '../capture/capture_queue.dart';
import '../capture/failed_shots.dart';
import '../core/database/shot_vault.dart';
import '../core/database/tables.dart';

/// A write-ahead record of a shutter press. The identity is also included in
/// the committed shot's capture JSON, so deleting plaintext can be retried.
class RecoveryCapture {
  RecoveryCapture(this.journal, this.data);
  final File journal;
  final Map<String, Object?> data;
  String get id => data['captureId'] as String;
  int? get rollId => data['rollId'] as int?;
  ShotLens get lens => ShotLens.values.byName(data['lens'] as String);
  Map<String, Object?> get snapshot =>
      Map<String, Object?>.from(data['job'] as Map);
  Directory get folder => Directory(data['folder'] as String);
  Directory get failedFolder => Directory(data['failedFolder'] as String);
  List<File> get originals => [
    File('${folder.path}/original.jpg'),
    File('${failedFolder.path}/original.jpg'),
    File(data['originalPath'] as String),
  ];

  Future<File?> source() async {
    for (final file in originals) {
      if (await file.exists()) return file;
    }
    return null;
  }
}

class RollRecovery {
  RollRecovery(this.cache, {this.vault});
  final Directory cache;
  final ShotVault? vault;

  Future<Map<String, Object?>> snapshotOf(RecoveryCapture entry) async {
    final path = entry.snapshot['encryptedJobPath'];
    if (path is! String) return entry.snapshot;
    return Map<String, Object?>.from(
      jsonDecode(utf8.decode(await vault!.read(path))) as Map,
    );
  }

  Future<RecoveryCapture> stage(
    CaptureJob job,
    int? rollId,
    ShotLens lens,
  ) async {
    final random = Random.secure();
    final id = List.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    final snapshot = FailedShots.encode(job, attempts: 0);
    String? encryptedPath;
    if (job.includeLocation && job.location != null) {
      final encrypted = {
        ...snapshot,
        'includeLocation': true,
        'location': job.location!.toJson(),
      };
      // Encrypt before writing any recovery sidecar. On encryption failure
      // leave only the camera original; never fall back to plaintext GPS.
      final path = await vault!.store(
        Uint8List.fromList(utf8.encode(jsonEncode(encrypted))),
      );
      encryptedPath = path;
      snapshot['encryptedJobPath'] = path;
    }
    final entry = RecoveryCapture(File('${job.filePath}.roll.json'), {
      'captureId': id,
      'rollId': rollId,
      'lens': lens.name,
      'originalPath': job.filePath,
      'folder': '${cache.path}/roll-recovery/shot_$id',
      'failedFolder': '${cache.path}/failed/roll_$id',
      'job': snapshot,
    });
    // Register before any mkdir, rename or copy. If even this write fails,
    // startup's conservative camera cleanup still keeps the original.
    try {
      await entry.journal.writeAsString(jsonEncode(entry.data), flush: true);
    } on Object {
      if (encryptedPath != null) await vault!.delete(encryptedPath);
      rethrow;
    }
    try {
      await _stageIn(entry, entry.folder);
    } on FileSystemException {
      // Roll retries have their own subdirectory and the same snapshot format
      // as FailedShots. Loose-photo retries must never publish these early.
      await _stageIn(entry, entry.failedFolder);
    }
    return entry;
  }

  Future<void> _stageIn(RecoveryCapture entry, Directory folder) async {
    await folder.create(recursive: true);
    await File('${folder.path}/capture.json')
        .writeAsString(jsonEncode(entry.data), flush: true);
    final source = (await entry.source())!;
    final destination = '${folder.path}/original.jpg';
    if (source.path == destination) return;
    try {
      await source.rename(destination);
    } on FileSystemException {
      // Never mistake a partial copy for the recoverable original after a
      // crash or a failed copy. The final name means the copy completed.
      final copied = await source.copy('$destination.copy');
      await copied.rename(destination);
      await source.delete();
    }
  }

  Future<List<RecoveryCapture>> pending() async {
    if (!await cache.exists()) return [];
    final entries = <RecoveryCapture>[];
    await for (final file in cache.list(followLinks: false)) {
      if (file is! File || !file.path.endsWith('.roll.json')) continue;
      try {
        final data = Map<String, Object?>.from(
          jsonDecode(await file.readAsString()) as Map,
        );
        if (data['captureId'] is! String ||
            data['job'] is! Map ||
            data['folder'] is! String ||
            data['failedFolder'] is! String ||
            data['originalPath'] is! String ||
            (data['rollId'] != null && data['rollId'] is! int) ||
            !ShotLens.values.any((lens) => lens.name == data['lens']) ||
            (data['job'] as Map)['takenAt'] is! String) {
          continue;
        }
        entries.add(RecoveryCapture(file, data));
      } on Object {
        // Keep unreadable records and their originals for recovery.
      }
    }
    entries.sort(
      (a, b) => (a.snapshot['takenAt'] as String).compareTo(
        b.snapshot['takenAt'] as String,
      ),
    );
    return entries;
  }

  Future<void> remove(RecoveryCapture entry) async {
    // Keep the journal until every copy is gone, including a copy whose
    // source deletion failed during the cross-volume move fallback.
    for (final source in entry.originals) {
      if (await source.exists()) await source.delete();
    }
    for (final folder in [entry.folder, entry.failedFolder]) {
      final partial = File('${folder.path}/original.jpg.copy');
      if (await partial.exists()) await partial.delete();
      final manifest = File('${folder.path}/capture.json');
      if (await manifest.exists()) await manifest.delete();
      if (await folder.exists()) await folder.delete();
    }
    final metadata = entry.snapshot['encryptedJobPath'];
    if (metadata is String) await vault!.delete(metadata);
    if (await entry.journal.exists()) await entry.journal.delete();
  }

  Future<void> removeBestEffort(RecoveryCapture entry) async {
    try {
      await remove(entry);
    } on Object {
      // Startup retries using the committed capture identity.
    }
  }

  Future<void> removeRoll(int rollId) async {
    for (final entry in await pending()) {
      if (entry.rollId == rollId) await remove(entry);
    }
  }
}
