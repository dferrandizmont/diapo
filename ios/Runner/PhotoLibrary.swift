import Foundation
import Photos
import UIKit

/// PhotoKit port of MediaChannel.kt's publish/ownItem/read/delete operations; never enumerates the library.
final class PhotoLibrary {
  private let lock = NSLock()
  private var identifiers: [String: String] = [:]
  private let mapURL: URL
  private let imageManager = PHImageManager()
  private var deleting = false

  init() throws {
    let support = try FileManager.default.url(for: .applicationSupportDirectory,
      in: .userDomainMask, appropriateFor: nil, create: true)
    mapURL = support.appendingPathComponent("diapo-photo-identifiers.json")
    if FileManager.default.fileExists(atPath: mapURL.path) {
      let data = try Data(contentsOf: mapURL)
      do {
        identifiers = try JSONDecoder().decode([String: String].self, from: data)
      } catch {
        // A corrupt map grants nothing. Quarantine it; never reconstruct ownership by scanning Photos.
        let corrupt = mapURL.appendingPathExtension("corrupt")
        if FileManager.default.fileExists(atPath: corrupt.path) { try FileManager.default.removeItem(at: corrupt) }
        try FileManager.default.moveItem(at: mapURL, to: corrupt)
        identifiers = [:]
        NSLog("Diapo: corrupt photo ownership map; starting empty")
      }
    }
  }

  private func key(_ name: String, original: Bool) -> String {
    (original ? "original/" : "photo/") + name
  }

  private func snapshot() -> [String: String] {
    lock.lock()
    defer { lock.unlock() }
    return identifiers
  }

  private func remember(_ id: String, name: String, original: Bool) throws {
    lock.lock()
    defer { lock.unlock() }
    var updated = identifiers
    updated[key(name, original: original)] = id
    try JSONEncoder().encode(updated).write(to: mapURL, options: .atomic)
    identifiers = updated
  }

  private var allowed: Bool {
    let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    return status == .authorized || status == .limited
  }

  private func authorizeSave() throws {
    if PHPhotoLibrary.authorizationStatus(for: .readWrite) == .notDetermined {
      let done = DispatchSemaphore(value: 0)
      DispatchQueue.main.async {
        PHPhotoLibrary.requestAuthorization(for: .readWrite) { _ in done.signal() }
      }
      done.wait()
    }
    guard allowed else { throw NativeFailure("save_failed", "Photo library access denied") }
  }

  private func checkRead() throws {
    guard allowed else { throw NativeFailure("not_allowed", "Photo library access denied") }
  }

  private func asset(_ id: String) -> PHAsset? {
    let options = PHFetchOptions()
    options.includeHiddenAssets = true
    return PHAsset.fetchAssets(withLocalIdentifiers: [id], options: options).firstObject
  }

  func findSaved(_ name: String, original: Bool) throws -> String? {
    guard let id = snapshot()[key(name, original: original)] else { return nil }
    try checkRead()
    return asset(id) == nil ? nil : "ph://" + id
  }

  private func ownAsset(_ uri: String) throws -> PHAsset {
    guard uri.hasPrefix("ph://"), snapshot().contains(where: {
      $0.key.hasPrefix("photo/") && uri == "ph://" + $0.value
    }) else { throw NativeFailure("not_allowed", "Not an image saved by Diapo") }
    try checkRead()
    guard let found = asset(String(uri.dropFirst(5))) else {
      throw NativeFailure("not_found", "Photo no longer exists")
    }
    return found
  }

  private func album(original: Bool) -> PHAssetCollection? {
    let cacheKey = original ? "diapo.originalAlbum" : "diapo.photoAlbum"
    if let id = UserDefaults.standard.string(forKey: cacheKey) {
      if let existing = PHAssetCollection.fetchAssetCollections(withLocalIdentifiers: [id], options: nil).firstObject {
        return existing
      }
      // Limited access may hide the album; do not create another copy on every save.
      if PHPhotoLibrary.authorizationStatus(for: .readWrite) == .limited { return nil }
    }
    var id: String?
    do {
      try PHPhotoLibrary.shared().performChangesAndWait {
        id = PHAssetCollectionChangeRequest.creationRequestForAssetCollection(
          withTitle: original ? "Diapo Originales" : "Diapo").placeholderForCreatedAssetCollection.localIdentifier
      }
    } catch { return nil }
    guard let created = id else { return nil }
    UserDefaults.standard.set(created, forKey: cacheKey)
    return PHAssetCollection.fetchAssetCollections(withLocalIdentifiers: [created], options: nil).firstObject
  }

  func save(_ data: Data, name: String, original: Bool) throws -> String {
    try authorizeSave()
    if let existing = try findSaved(name, original: original) { return existing }
    let file = MediaFiles.output()
    defer { try? FileManager.default.removeItem(at: file) }
    try data.write(to: file, options: .atomic)
    // MediaChannel.publish: album management is best effort and separate from publishing the asset.
    let collection = album(original: original)
    var id: String?
    var persistenceError: Error?
    do {
      try PHPhotoLibrary.shared().performChangesAndWait {
        let request = PHAssetCreationRequest.forAsset()
        // CHECK ON MAC: confirm placeholder availability before adding a resource, including failure of the ownership-map write.
        id = request.placeholderForCreatedAsset?.localIdentifier
        guard let identifier = id else { return }
        do {
          // Like Kotlin's recoverable pending row: record ownership before PhotoKit can commit the JPEG.
          // A failed transaction leaves only a harmless missing identifier; retries never scan the library.
          try self.remember(identifier, name: name, original: original)
        } catch { persistenceError = error; return }
        let options = PHAssetResourceCreationOptions()
        options.originalFilename = name + ".jpg"
        request.addResource(with: .photo, fileURL: file, options: options)
      }
    } catch { throw persistenceError ?? error }
    if let error = persistenceError { throw error }
    guard let saved = id else {
      throw NativeFailure("save_failed", "No saved asset identifier")
    }
    if let collection = collection, let savedAsset = asset(saved) {
      // CHECK ON MAC: limited access with no selected photos may refuse album changes; the saved identifier still works.
      try? PHPhotoLibrary.shared().performChangesAndWait {
        PHAssetCollectionChangeRequest(for: collection)?.addAssets([savedAsset] as NSArray)
      }
    }
    return "ph://" + saved
  }

  func readImage(_ uri: String) throws -> Data {
    let item = try ownAsset(uri)
    let resources = PHAssetResource.assetResources(for: item)
    guard let resource = resources.first(where: { $0.type == .fullSizePhoto })
      ?? resources.first(where: { $0.type == .photo }) else {
      throw NativeFailure("read_failed", "Photo has no image resource")
    }
    let options = PHAssetResourceRequestOptions()
    options.isNetworkAccessAllowed = false
    let manager = PHAssetResourceManager.default()
    let done = DispatchSemaphore(value: 0)
    let stateLock = NSLock()
    let limit = 64 * 1024 * 1024
    var data = Data()
    var request: PHAssetResourceDataRequestID?
    var tooLarge = false
    var failed = false
    // MediaChannel.readBounded: never accumulate more than 64 MiB, even for a local asset.
    // CHECK ON MAC: verify resource selection for edited photos and cancellation at the 64 MiB boundary.
    let id = manager.requestData(for: resource, options: options, dataReceivedHandler: { chunk in
      stateLock.lock()
      guard !tooLarge else { stateLock.unlock(); return }
      if chunk.count > limit - data.count {
        tooLarge = true
        data.removeAll()
        let pending = request
        stateLock.unlock()
        if let pending = pending { manager.cancelDataRequest(pending) }
      } else {
        data.append(chunk)
        stateLock.unlock()
      }
    }, completionHandler: { error in
      stateLock.lock()
      failed = error != nil
      stateLock.unlock()
      // Only completion signals the waiter (also after cancellation), so there is one channel reply.
      done.signal()
    })
    // A data callback may exceed the limit before requestData returns its identifier.
    stateLock.lock()
    request = id
    let cancel = tooLarge
    stateLock.unlock()
    if cancel { manager.cancelDataRequest(id) }
    // Never block a reader thread for good if PhotoKit does not call back.
    guard done.wait(timeout: .now() + 60) == .success else {
      manager.cancelDataRequest(id)
      throw NativeFailure("read_failed", "Photo read timed out")
    }
    if tooLarge { throw NativeFailure("not_allowed", "Photo exceeds the size limit") }
    guard !failed, !data.isEmpty else { throw NativeFailure("read_failed", "Photo is not available locally") }
    return data
  }

  func thumbnail(_ uri: String, extent: Int) throws -> Data {
    let item = try ownAsset(uri)
    let options = PHImageRequestOptions()
    options.isNetworkAccessAllowed = false
    options.isSynchronous = true
    options.deliveryMode = .highQualityFormat
    options.resizeMode = .exact
    var data: Data?
    imageManager.requestImage(for: item, targetSize: CGSize(width: CGFloat(extent), height: CGFloat(extent)),
      contentMode: .aspectFit, options: options) { image, info in
      if info?[PHImageErrorKey] == nil { data = image?.jpegData(compressionQuality: 0.85) }
    }
    guard let bytes = data else { throw NativeFailure("read_failed", "Thumbnail is not available locally") }
    return bytes
  }

  func missingImages(_ uris: [String]) -> [String] {
    // MissingRules.kt: inability to read says nothing about whether a photo was deleted.
    guard allowed else { return [] }
    let authorization = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    let own = Set(snapshot().filter { $0.key.hasPrefix("photo/") }.values)
    let candidates = uris.prefix(5000).filter { $0.hasPrefix("ph://") && own.contains(String($0.dropFirst(5))) }
    var present = Set<String>()
    let options = PHFetchOptions()
    options.includeHiddenAssets = true
    let fetched = PHAsset.fetchAssets(withLocalIdentifiers: candidates.map { String($0.dropFirst(5)) }, options: options)
    fetched.enumerateObjects { item, _, _ in present.insert(item.localIdentifier) }
    guard allowed, PHPhotoLibrary.authorizationStatus(for: .readWrite) == authorization else { return [] }
    // CHECK ON MAC: on XR with limited access and no photos selected, app-created assets must stay visible.
    // If identifier fetches can hide them under .limited, return [] under .limited instead of reporting deletions.
    return candidates.filter { !present.contains(String($0.dropFirst(5))) }
  }

  func deleteImage(_ uri: String) throws -> String {
    lock.lock()
    if deleting { lock.unlock(); throw NativeFailure("not_allowed", "A delete is already pending") }
    deleting = true
    lock.unlock()
    defer { lock.lock(); deleting = false; lock.unlock() }
    let item: PHAsset
    do { item = try ownAsset(uri) }
    catch let failure as NativeFailure where failure.code == "not_found" {
      // CHECK ON MAC: on XR with limited access and no photos selected, confirm own assets remain visible.
      // If .limited can hide them, throw not_allowed under .limited here instead of answering gone.
      return "gone"
    }
    let records = snapshot()
    let photoName = records.first { $0.key.hasPrefix("photo/") && $0.value == item.localIdentifier }?.key.dropFirst(6)
    let original = photoName.flatMap { records[key(String($0) + "_original", original: true)] }.flatMap { asset($0) }
    // OriginalRules.kt: only the explicitly recorded companion original goes with the photo.
    let both = [item] + (original.map { [$0] } ?? [])
    do {
      try PHPhotoLibrary.shared().performChangesAndWait { PHAssetChangeRequest.deleteAssets(both as NSArray) }
    } catch {
      let error = error as NSError
      if error.domain == PHPhotosErrorDomain && error.code == PHPhotosError.Code.userCancelled.rawValue {
        return "cancelled"
      }
      throw NativeFailure("delete_failed", "Cannot delete photo")
    }
    // PhotoKit deletes the pair atomically; retain the tombstone map so stale URIs still answer gone.
    return original.map { asset($0.localIdentifier) != nil } == true ? "deletedPhotoKeptOriginal" : "deleted"
  }
}
