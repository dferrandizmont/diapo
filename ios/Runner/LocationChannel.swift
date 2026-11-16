import CoreLocation
import Flutter
import UIKit

/// LocationChannel.kt: foreground, when-in-use acquisition with fixes tied to their permission level.
final class LocationChannel: NSObject, CLLocationManagerDelegate {
  private let manager = CLLocationManager()
  private var updates: CLLocationManager?
  private var channel: FlutterMethodChannel?
  private var permissionReply: FlutterResult?
  private var best: PhotoLocation?
  private var fixPermission: String?
  private var updating = false
  private var observers: [NSObjectProtocol] = []

  override init() {
    super.init()
    manager.delegate = self
    manager.desiredAccuracy = kCLLocationAccuracyBest
    manager.distanceFilter = kCLDistanceFilterNone
    manager.allowsBackgroundLocationUpdates = false
    observers.append(NotificationCenter.default.addObserver(forName: UIApplication.willResignActiveNotification,
      object: nil, queue: .main) { [weak self] _ in self?.stop() })
  }

  deinit {
    observers.forEach { NotificationCenter.default.removeObserver($0) }
    updates?.stopUpdatingLocation()
  }

  func register(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "carrete/location", binaryMessenger: messenger)
    self.channel = channel
    channel.setMethodCallHandler { [self] call, result in
      switch call.method {
      case "permission": result(permission())
      case "requestPermission": requestPermission(result)
      case "start": start(); result(nil)
      case "stop": stop(); result(nil)
      case "current": result(current())
      default: result(FlutterMethodNotImplemented)
      }
    }
  }

  private func permission() -> String {
    let state: String
    switch manager.authorizationStatus {
    case .authorizedWhenInUse, .authorizedAlways:
      state = manager.accuracyAuthorization == .fullAccuracy ? "granted" : "coarseOnly"
    case .denied, .restricted: state = "permanentlyDenied"
    default: state = "denied"
    }
    // LocationChannel.permission(): changing precise/approximate permission discards the old fix and listener.
    if let held = fixPermission, held != state { stop() }
    return state
  }

  private func requestPermission(_ result: @escaping FlutterResult) {
    guard permissionReply == nil else {
      result(FlutterError(code: "permission_pending", message: "A location request is already pending", details: nil)); return
    }
    let state = permission()
    guard manager.authorizationStatus == .notDetermined,
      UIApplication.shared.applicationState == .active else { result(state); return }
    permissionReply = result
    manager.requestWhenInUseAuthorization()
  }

  func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
    guard manager === self.manager || manager === updates else { return }
    let state = permission()
    if manager.authorizationStatus != .notDetermined, let reply = permissionReply {
      permissionReply = nil
      reply(state)
    }
  }

  private func start() {
    let state = permission()
    guard UIApplication.shared.applicationState == .active, state == "granted" || state == "coarseOnly" else { return }
    if updating { return }
    fixPermission = state
    updating = true
    // Kotlin creates a listener per generation. A new manager gives callbacks the same session identity on iOS.
    let acquisition = CLLocationManager()
    updates = acquisition
    acquisition.delegate = self
    acquisition.desiredAccuracy = kCLLocationAccuracyBest
    acquisition.distanceFilter = kCLDistanceFilterNone
    acquisition.allowsBackgroundLocationUpdates = false
    // Kotlin seeds from last-known locations. Only didUpdateLocations supplies a fix on iOS, tied to this session.
    acquisition.startUpdatingLocation()
  }

  private func stop() {
    updates?.delegate = nil
    updates?.stopUpdatingLocation()
    updates = nil
    updating = false
    best = nil
    fixPermission = nil
  }

  func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    guard manager === updates else { return }
    guard updating, UIApplication.shared.applicationState == .active,
      let acquisitionPermission = fixPermission, permission() == acquisitionPermission else { stop(); return }
    let now = Int64(Date().timeIntervalSince1970 * 1000)
    for location in locations {
      guard let time = Int64(exactly: (location.timestamp.timeIntervalSince1970 * 1000).rounded(.towardZero)) else { continue }
      let candidate = PhotoLocation(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude,
        altitude: location.verticalAccuracy >= 0 ? location.altitude : nil, accuracy: location.horizontalAccuracy,
        time: time, approximate: acquisitionPermission == "coarseOnly")
      guard candidate.usable(at: now) else { continue }
      if best?.usable(at: now) != true || candidate.time > best!.time
        || (candidate.time == best!.time && candidate.accuracy < best!.accuracy) { best = candidate }
    }
  }

  func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
    guard manager === updates else { return }
    if (error as? CLError)?.code == .denied { stop() }
  }

  private func current() -> [String: Any] {
    let state = permission()
    let now = Int64(Date().timeIntervalSince1970 * 1000)
    let usable = updating && UIApplication.shared.applicationState == .active
      && state == fixPermission && best?.usable(at: now) == true
    return ["permission": state, "fix": usable ? best!.dictionary : NSNull()]
  }
}
