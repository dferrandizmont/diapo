import Flutter
import Foundation
import UIKit
import UniformTypeIdentifiers

/// SettingsBackupDocuments.kt's single document session and SettingsBackupBytes.kt's bounded reads.
final class SettingsDocuments: NSObject, UIDocumentPickerDelegate, UIAdaptivePresentationControllerDelegate {
  private static let maxBytes = 256 * 1024
  private var result: FlutterResult?
  private var exportURL: URL?
  private var exportDirectory: URL?
  private var picker: UIDocumentPickerViewController?
  private let worker = DispatchQueue(label: "es.diapo.settings.documents")
  private let pendingKey = "diapo.settingsDocumentPending"
  private let directoryKey = "diapo.settingsDocumentExportDirectory"
  private var interrupted = false

  override init() {
    super.init()
    let preferences = UserDefaults.standard
    interrupted = preferences.bool(forKey: pendingKey)
    preferences.set(false, forKey: pendingKey)
    if let identifier = preferences.string(forKey: directoryKey), UUID(uuidString: identifier) != nil {
      let root = FileManager.default.temporaryDirectory.standardizedFileURL.resolvingSymlinksInPath()
      let folder = root.appendingPathComponent(identifier)
      if folder.resolvingSymlinksInPath().deletingLastPathComponent() == root {
        try? FileManager.default.removeItem(at: folder)
      }
    }
    preferences.removeObject(forKey: directoryKey)
  }

  static func presenter() -> UIViewController? {
    let window = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
      .filter { $0.activationState == .foregroundActive }.flatMap { $0.windows }.first { $0.isKeyWindow }
    var controller = window?.rootViewController
    while let presented = controller?.presentedViewController { controller = presented }
    return controller
  }

  func handle(_ call: FlutterMethodCall, reply: @escaping FlutterResult) {
    if interrupted {
      interrupted = false
      reply(FlutterError(code: "interrupted", message: "Previous settings document operation was interrupted", details: nil)); return
    }
    guard result == nil else {
      reply(FlutterError(code: "busy", message: "A settings document is already open", details: nil)); return
    }
    let exporting = call.method == "exportSettings"
    let args = call.arguments as? [String: Any] ?? [:]
    var bytes: Data?
    var name: String?
    if exporting {
      guard let typed = args["bytes"] as? FlutterStandardTypedData,
        let suggested = args["suggestedName"] as? String, !suggested.isEmpty else {
        reply(FlutterError(code: "invalid_arguments", message: "Invalid settings document", details: nil)); return
      }
      guard typed.data.count <= Self.maxBytes else {
        reply(FlutterError(code: "too_large", message: "Settings document exceeds the size limit", details: nil)); return
      }
      // SettingsBackupDocuments.NAME: no user-controlled directories, separators or traversal in tmp.
      let plain = (suggested.replacingOccurrences(of: "\\", with: "/") as NSString).lastPathComponent
      guard plain != ".", plain != "..", plain.utf8.count <= 200,
        plain.range(of: "^[A-Za-z0-9_-]+\\.json\\z", options: .regularExpression) != nil else {
        reply(FlutterError(code: "invalid_arguments", message: "Invalid settings file name", details: nil)); return
      }
      bytes = typed.data
      name = plain
    }
    guard let presenter = Self.presenter() else {
      reply(FlutterError(code: "storage", message: "No screen for document picker", details: nil)); return
    }
    result = reply
    UserDefaults.standard.set(true, forKey: pendingKey)
    if exporting, let data = bytes, let name = name {
      // A unique tmp subdirectory avoids overwriting another operation's export with the same suggested name.
      let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
      exportDirectory = folder
      UserDefaults.standard.set(folder.lastPathComponent, forKey: directoryKey)
      let file = folder.appendingPathComponent(name)
      exportURL = file
      do {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: false)
        try data.write(to: file, options: .atomic)
      } catch { finishError("storage"); return }
      picker = UIDocumentPickerViewController(forExporting: [file], asCopy: true)
    } else {
      picker = UIDocumentPickerViewController(forOpeningContentTypes: [.json], asCopy: true)
    }
    guard let picker = picker else { finishError("storage"); return }
    picker.delegate = self
    picker.allowsMultipleSelection = false
    picker.presentationController?.delegate = self
    presenter.present(picker, animated: true)
    picker.presentationController?.delegate = self
  }

  func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
    guard controller === picker else { return }
    finish(exportURL == nil ? nil : false)
  }

  func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
    guard presentationController.presentedViewController === picker else { return }
    finish(exportURL == nil ? nil : false)
  }

  func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
    guard controller === picker else { return }
    if exportURL != nil { finish(true); return }
    guard let url = urls.first else { finishError("storage"); return }
    let operation = controller
    worker.async {
      let scoped = url.startAccessingSecurityScopedResource()
      defer {
        if scoped { url.stopAccessingSecurityScopedResource() }
        // asCopy imports live in tmp/Inbox. Never delete a URL outside this app's temporary directory.
        let local = url.standardizedFileURL.resolvingSymlinksInPath()
        let root = FileManager.default.temporaryDirectory.standardizedFileURL.resolvingSymlinksInPath().path
        if local.path.hasPrefix(root.hasSuffix("/") ? root : root + "/") {
          try? FileManager.default.removeItem(at: local)
        }
      }
      do {
        // SettingsBackupBytes: stop after MAX_BYTES + 1, without mapping or loading an arbitrary document.
        let input = try FileHandle(forReadingFrom: url)
        defer { try? input.close() }
        var data = Data()
        while data.count <= Self.maxBytes {
          guard let chunk = try input.read(upToCount: min(16384, Self.maxBytes + 1 - data.count)),
            !chunk.isEmpty else { break }
          data.append(chunk)
        }
        if data.count > Self.maxBytes {
          DispatchQueue.main.async { if self.picker === operation { self.finishError("too_large") } }
        } else {
          DispatchQueue.main.async {
            if self.picker === operation { self.finish(FlutterStandardTypedData(bytes: data)) }
          }
        }
      } catch {
        DispatchQueue.main.async { if self.picker === operation { self.finishError("storage") } }
      }
    }
  }

  private func finishError(_ code: String) {
    finish(FlutterError(code: code, message: "Cannot complete settings document operation", details: nil))
  }

  private func finish(_ value: Any?) {
    guard let reply = result else { return }
    result = nil
    picker = nil
    if let file = exportURL { try? FileManager.default.removeItem(at: file) }
    if let folder = exportDirectory { try? FileManager.default.removeItem(at: folder) }
    exportURL = nil
    exportDirectory = nil
    UserDefaults.standard.set(false, forKey: pendingKey)
    UserDefaults.standard.removeObject(forKey: directoryKey)
    reply(value)
  }
}
