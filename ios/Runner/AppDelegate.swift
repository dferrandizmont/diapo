import Flutter
import UIKit

@main
/// MainActivity.kt's channel registration and Android's application-data backup exclusion.
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let media = MediaChannel()
  private let system = SystemChannel()
  private let location = LocationChannel()

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    do {
      var values = URLResourceValues()
      values.isExcludedFromBackup = true
      // Drift uses Documents (including SQLite WAL/SHM); the vault uses Application Support.
      for directory in [FileManager.SearchPathDirectory.documentDirectory, .applicationSupportDirectory] {
        var folder = try FileManager.default.url(for: directory,
          in: .userDomainMask, appropriateFor: nil, create: true)
        try folder.setResourceValues(values)
      }
    } catch {
      // Android backup_rules.xml equivalent: stop before Flutter starts; returning false does not stop iOS.
      fatalError("Diapo: cannot exclude app data from backup")
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "CarreteMedia") {
      media.register(messenger: registrar.messenger())
    }
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "CarreteSystem") {
      system.register(messenger: registrar.messenger())
    }
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "CarreteLocation") {
      location.register(messenger: registrar.messenger())
    }
  }
}
