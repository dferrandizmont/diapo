import Flutter
import Foundation
import UIKit

/// MediaChannel.kt's metadata staged until the matching pixel transport arrives.
private struct PendingSave {
  let token: Int
  let width: Int
  let height: Int
  let quality: Int
  let name: String
  let source: URL?
  let includeLocation: Bool
  let location: PhotoLocation?
  let takenAt: Int64?
}

/// TileRaster.kt's ordered raster: a duplicate, gap or incorrect size never publishes.
private final class TiledSave {
  let save: PendingSave
  let side: Int
  var rgba: Data
  var nextX = 0
  var nextY = 0
  var touched = Date()

  init(_ save: PendingSave, side: Int) {
    self.save = save
    self.side = side
    rgba = Data(count: save.width * save.height * 4)
  }

  func copy(_ message: Data) throws -> Bool {
    let x = message.int32(4), y = message.int32(8)
    let width = message.int32(12), height = message.int32(16)
    guard x == nextX, y == nextY, nextY < save.height,
      width == min(side, save.width - x), height == min(side, save.height - y),
      message.count == 20 + width * height * 4 else {
      throw NativeFailure("save_failed", "Invalid or out of order tile")
    }
    // TileRaster.copy: tile pixels are straight RGBA; row copies retain the same byte order.
    rgba.withUnsafeMutableBytes { (target: UnsafeMutableRawBufferPointer) in
      message.withUnsafeBytes { (source: UnsafeRawBufferPointer) in
        for row in 0..<height {
          target.baseAddress!.advanced(by: ((y + row) * save.width + x) * 4).copyMemory(
            from: source.baseAddress!.advanced(by: 20 + row * width * 4), byteCount: width * 4)
        }
      }
    }
    nextX += width
    if nextX == save.width { nextX = 0; nextY += height }
    touched = Date()
    return nextY == save.height
  }
}

/// Unaligned little-endian decoding matching Dart's ByteData.setInt32 and Kotlin ByteBuffer.
private extension Data {
  func int32(_ offset: Int) -> Int {
    let bytes = self[startIndex + offset..<startIndex + offset + 4]
    let value = bytes.enumerated().reduce(UInt32(0)) { $0 | UInt32($1.element) << ($1.offset * 8) }
    return Int(Int32(bitPattern: value))
  }
}

/// MediaChannel.kt port: serial saves and two bounded reader tasks, with all Flutter replies on main.
final class MediaChannel {
  private let worker = DispatchQueue(label: "es.diapo.media.save")
  private let readers: OperationQueue = {
    let queue = OperationQueue()
    queue.name = "es.diapo.media.read"
    queue.maxConcurrentOperationCount = 2
    return queue
  }()
  private var library: PhotoLibrary?
  private var pending: [Int: PendingSave] = [:]
  private var pendingToken: Int?
  private var tiled: TiledSave?
  private var nextToken = 1
  private var channels: [FlutterBasicMessageChannel] = []
  private var methodChannel: FlutterMethodChannel?
  private var watchdog: DispatchWorkItem?

  func register(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "carrete/media", binaryMessenger: messenger)
    methodChannel = channel
    channel.setMethodCallHandler { [self] call, reply in handle(call, reply: reply) }
    for name in ["pixels", "tiles", "contact-sheet"] {
      let binary = FlutterBasicMessageChannel(name: "carrete/media/" + name,
        binaryMessenger: messenger, codec: FlutterBinaryCodec.sharedInstance())
      binary.setMessageHandler { [self] message, reply in
        let data = message as? Data
        worker.async {
          autoreleasepool {
            switch name {
            case "pixels": self.onPixels(data, reply: reply)
            case "tiles": self.onTilePixels(data, reply: reply)
            default: self.onContactSheetPixels(data, reply: reply)
            }
          }
        }
      }
      channels.append(binary)
    }
  }

  private func photos() throws -> PhotoLibrary {
    if let library = library { return library }
    let created = try PhotoLibrary()
    library = created
    return created
  }

  private func finish(_ reply: @escaping FlutterResult, _ value: Any?) {
    DispatchQueue.main.async { reply(value) }
  }

  private func failure(_ reply: @escaping FlutterResult, _ error: Error, code: String, preserve: Bool = false) {
    let native = error as? NativeFailure
    finish(reply, FlutterError(code: preserve ? native?.code ?? code : code,
      message: native?.message ?? "Cannot complete media operation", details: nil))
  }

  private func clearTiled() {
    watchdog?.cancel()
    watchdog = nil
    tiled = nil
  }

  private func touchTiled() {
    watchdog?.cancel()
    let timeout = DispatchWorkItem { [weak self] in self?.clearTiled() }
    watchdog = timeout
    worker.asyncAfter(deadline: .now() + 60.001, execute: timeout)
  }

  private func validateName(_ name: Any?, original: Bool = false) throws -> String {
    let pattern = original ? "^CARRETE_[A-Za-z0-9_]+_original\\z" : "^CARRETE_[A-Za-z0-9_]+\\z"
    guard let name = name as? String, name.count <= 120,
      name.range(of: pattern, options: .regularExpression) != nil
      else { throw NativeFailure("bad_arguments", "Invalid display name") }
    return name
  }

  private func metadata(_ args: [String: Any], tiled: Bool) throws -> PendingSave {
    guard let width = PhotoLocation.integer(args["width"]), let height = PhotoLocation.integer(args["height"]) else {
      throw NativeFailure("bad_arguments", "Missing dimensions")
    }
    let framed = tiled && PhotoLocation.boolean(args["framed"]) == true
    let maxSide = framed ? 10324 : 8192, maxPixels = framed ? 71000000 : 50000000
    guard (1...maxSide).contains(width), (1...maxSide).contains(height), width * height <= maxPixels else {
      throw NativeFailure("bad_arguments", "Invalid image dimensions")
    }
    let name = try validateName(args["displayName"])
    if let source = args["sourcePath"], !(source is NSNull), !(source is String) {
      throw NativeFailure("bad_arguments", "Invalid source path")
    }
    let source = try (args["sourcePath"] as? String).map { try MediaFiles.temporary($0) }
    let takenAt = PhotoLocation.milliseconds(args["takenAt"])
    let include = PhotoLocation.boolean(args["includeLocation"]) == true && (args["takenAt"] == nil || takenAt != nil)
    let quality = PhotoLocation.integer(args["quality"]) ?? 95
    let save = PendingSave(token: nextToken, width: width, height: height,
      quality: tiled ? min(100, max(1, quality)) : quality, name: name, source: source,
      includeLocation: include, location: PhotoLocation.from(args["location"]), takenAt: takenAt)
    nextToken = nextToken == Int(Int32.max) ? 1 : nextToken + 1
    return save
  }

  private func handle(_ call: FlutterMethodCall, reply: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any] ?? [:]
    worker.async {
      autoreleasepool {
        do {
          switch call.method {
          case "beginSave", "beginTiledSave":
            let isTiled = call.method == "beginTiledSave"
            do {
              if isTiled { self.clearTiled(); self.pending.removeAll(); self.pendingToken = nil }
              let save = try self.metadata(args, tiled: isTiled)
              if isTiled {
                guard let side = PhotoLocation.integer(args["tileSize"]), (1...1024).contains(side) else {
                  throw NativeFailure("save_failed", "Invalid tile side")
                }
                self.tiled = TiledSave(save, side: side)
                self.touchTiled()
              } else {
                self.clearTiled()
                self.pending = [save.token: save]
                self.pendingToken = save.token
              }
              self.finish(reply, save.token)
            } catch { self.failure(reply, error, code: isTiled ? "save_failed" : "bad_arguments") }
          case "cancelTiledSave":
            if self.tiled?.save.token == PhotoLocation.integer(args["token"]) { self.clearTiled() }
            self.finish(reply, nil)
          case "findSaved":
            let name = try self.validateName(args["displayName"])
            do { self.finish(reply, try self.photos().findSaved(name, original: PhotoLocation.boolean(args["original"]) == true)) }
            catch { self.failure(reply, error, code: "lookup_failed") }
          case "saveOriginal": self.saveOriginal(args, reply: reply)
          case "readExifDates":
            guard let path = args["path"] as? String else { throw NativeFailure("bad_arguments", "No path") }
            do { self.finish(reply, JpegWriter.readExifDates(try MediaFiles.temporary(path))) }
            catch { self.failure(reply, error, code: "read_failed", preserve: true) }
          case "loadThumbnail", "readImage", "shareImage", "deleteImage":
            let reading = call.method == "loadThumbnail" || call.method == "readImage"
            guard let uri = args["uri"] as? String else {
              throw NativeFailure(reading ? "read_failed" : "bad_arguments", "No uri")
            }
            do {
              let library = try self.photos()
              self.readerCall(call.method, uri: uri, args: args, library: library, reply: reply)
            } catch {
              self.failure(reply, error, code: reading ? "read_failed" : call.method == "deleteImage" ? "delete_failed" : "share_failed")
            }
          case "shareFile":
            guard let path = args["path"] as? String else { throw NativeFailure("bad_arguments", "No path") }
            do {
              let file = try MediaFiles.contactSheet(path)
              let copy = MediaFiles.output(file.pathExtension)
              do { try FileManager.default.copyItem(at: file, to: copy) }
              catch { try? FileManager.default.removeItem(at: copy); throw error }
              self.share(copy, reply: reply)
            } catch { self.failure(reply, error, code: "share_failed", preserve: true) }
          case "missingImages":
            guard let uris = args["uris"] as? [String] else { throw NativeFailure("bad_arguments", "No uris") }
            do { self.finish(reply, try self.photos().missingImages(uris)) }
            catch { self.failure(reply, error, code: "lookup_failed") }
          default: self.finish(reply, FlutterMethodNotImplemented)
          }
        } catch { self.failure(reply, error, code: "bad_arguments", preserve: true) }
      }
    }
  }

  private func saveOriginal(_ args: [String: Any], reply: @escaping FlutterResult) {
    do {
      let name = try validateName(args["displayName"], original: true)
      guard let path = args["sourcePath"] as? String else { throw NativeFailure("bad_arguments", "No source") }
      do {
        let library = try photos()
        if let saved = try library.findSaved(name, original: true) { finish(reply, saved); return }
        let source = try MediaFiles.temporary(path)
        let takenAt = PhotoLocation.milliseconds(args["takenAt"])
        let include = PhotoLocation.boolean(args["includeLocation"]) == true && (args["takenAt"] == nil || takenAt != nil)
        let data = try JpegWriter.original(source, includeLocation: include,
          location: PhotoLocation.from(args["location"]), takenAt: takenAt)
        finish(reply, try library.save(data, name: name, original: true))
      } catch { failure(reply, error, code: "save_failed") }
    } catch { failure(reply, error, code: "bad_arguments") }
  }

  private func readerCall(_ method: String, uri: String, args: [String: Any],
    library: PhotoLibrary, reply: @escaping FlutterResult) {
    readers.addOperation {
      autoreleasepool {
        let code = method == "deleteImage" ? "delete_failed" : method == "shareImage" ? "share_failed" : "read_failed"
        do {
          switch method {
          case "loadThumbnail":
            let extent = min(2048, max(1, PhotoLocation.integer(args["extent"]) ?? 320))
            self.finish(reply, FlutterStandardTypedData(bytes: try library.thumbnail(uri, extent: extent)))
          case "readImage": self.finish(reply, FlutterStandardTypedData(bytes: try library.readImage(uri)))
          case "deleteImage": self.finish(reply, try library.deleteImage(uri))
          default:
            let data = try library.readImage(uri)
            let file = MediaFiles.output()
            do { try data.write(to: file, options: .atomic) }
            catch { try? FileManager.default.removeItem(at: file); throw error }
            self.share(file, reply: reply)
          }
        } catch {
          let nativeCode = (error as? NativeFailure)?.code
          let preserve = method != "shareImage" || nativeCode == "not_found" || nativeCode == "not_allowed"
          self.failure(reply, error, code: code, preserve: preserve)
        }
      }
    }
  }

  private func share(_ file: URL, reply: @escaping FlutterResult) {
    DispatchQueue.main.async {
      guard let presenter = SettingsDocuments.presenter(), !(presenter is UIActivityViewController) else {
        try? FileManager.default.removeItem(at: file)
        reply(false)
        return
      }
      let sheet = UIActivityViewController(activityItems: [file], applicationActivities: nil)
      sheet.completionWithItemsHandler = { _, _, _, _ in try? FileManager.default.removeItem(at: file) }
      sheet.popoverPresentationController?.sourceView = presenter.view
      sheet.popoverPresentationController?.sourceRect = presenter.view.bounds
      presenter.present(sheet, animated: true)
      // Kotlin launchShare answers whether the chooser opened, not whether the user shared.
      reply(true)
    }
  }

  private func json(_ value: [String: Any], reply: @escaping FlutterReply) {
    let data = try? JSONSerialization.data(withJSONObject: value)
    DispatchQueue.main.async { reply(data) }
  }

  private func binaryFailure(_ message: String, reply: @escaping FlutterReply) {
    json(["ok": false, "error": message], reply: reply)
  }

  private func publish(_ rgba: Data, save: PendingSave, straightAlpha: Bool,
    reply: @escaping FlutterReply) {
    do {
      let started = Date()
      let image = try JpegWriter.image(rgba, width: save.width, height: save.height, straightAlpha: straightAlpha)
      let properties = JpegWriter.metadata(save.source, width: save.width, height: save.height,
        includeLocation: save.includeLocation, location: save.location, takenAt: save.takenAt)
      let metadataEnd = Date()
      let bytes = try JpegWriter.encode(image, quality: save.quality, properties: properties)
      let encoded = Date()
      let uri = try photos().save(bytes, name: save.name, original: false)
      json(["ok": true, "uri": uri, "encodeMs": encoded.timeIntervalSince(metadataEnd) * 1000,
        "exifMs": metadataEnd.timeIntervalSince(started) * 1000,
        "writeMs": Date().timeIntervalSince(encoded) * 1000], reply: reply)
    } catch { binaryFailure("Cannot encode or save photo", reply: reply) }
  }

  private func onPixels(_ message: Data?, reply: @escaping FlutterReply) {
    guard let token = pendingToken, let save = pending.removeValue(forKey: token) else {
      binaryFailure("no pending save for the pixels", reply: reply); return
    }
    pendingToken = nil
    guard let bytes = message, bytes.count == save.width * save.height * 4 else {
      binaryFailure("Invalid RGBA byte count", reply: reply); return
    }
    publish(bytes, save: save, straightAlpha: false, reply: reply)
  }

  private func onTilePixels(_ message: Data?, reply: @escaping FlutterReply) {
    guard let session = tiled else { binaryFailure("no pending tiled save", reply: reply); return }
    guard let bytes = message, bytes.count >= 20 else {
      clearTiled(); binaryFailure("no tile header", reply: reply); return
    }
    guard bytes.int32(0) == session.save.token else {
      binaryFailure("stale tile token", reply: reply); return
    }
    do {
      if try session.copy(bytes) {
        clearTiled()
        publish(session.rgba, save: session.save, straightAlpha: true, reply: reply)
      } else { touchTiled(); json(["ok": true], reply: reply) }
    } catch { clearTiled(); binaryFailure("Invalid tile", reply: reply) }
  }

  private func onContactSheetPixels(_ message: Data?, reply: @escaping FlutterReply) {
    var encoded: Data?
    if let bytes = message, bytes.count >= 12 {
      let width = bytes.int32(0), height = bytes.int32(4), quality = bytes.int32(8)
      if (1...4096).contains(width), (1...4096).contains(height), width * height <= 16000000,
        (1...100).contains(quality), bytes.count == 12 + width * height * 4 {
        encoded = try? JpegWriter.encode(JpegWriter.image(Data(bytes.dropFirst(12)), width: width, height: height),
          quality: quality)
      }
    }
    // onContactSheetPixels replies JPEG bytes or null, never the save channels' JSON.
    let response = encoded
    DispatchQueue.main.async { reply(response) }
  }
}
