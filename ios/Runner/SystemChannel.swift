import AVFoundation
import Flutter
import UIKit

/// MainActivity.kt's carrete/system handler; iOS has no openKofi implementation.
final class SystemChannel {
  private let sounds = CameraSounds()
  private let documents = SettingsDocuments()
  private var channel: FlutterMethodChannel?

  func register(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "carrete/system", binaryMessenger: messenger)
    self.channel = channel
    channel.setMethodCallHandler { [self] call, result in
      switch call.method {
      case "openAppSettings": openAppSettings(result)
      case "cameraPermission": result(AVCaptureDevice.authorizationStatus(for: .video) == .authorized)
      case "ringerMode": result("normal")
      case "loadSounds": result(sounds.load())
      case "playSound":
        let name = (call.arguments as? [String: Any])?["name"] as? String ?? ""
        result(sounds.play(name))
      case "exportSettings", "importSettings": documents.handle(call, reply: result)
      default: result(FlutterMethodNotImplemented)
      }
    }
  }

  private func openAppSettings(_ result: @escaping FlutterResult) {
    guard let url = URL(string: UIApplication.openSettingsURLString) else { result(false); return }
    UIApplication.shared.open(url, options: [:]) { result($0) }
  }
}
