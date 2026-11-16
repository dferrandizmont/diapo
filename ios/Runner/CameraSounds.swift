import AVFoundation
import Flutter
import Foundation

/// CameraSounds.kt's fixed sound names; ambient audio lets iOS apply the silent switch.
final class CameraSounds {
  private var players: [String: AVAudioPlayer] = [:]
  private let names = ["shutter", "advance", "cartridge", "load", "rewind"]

  func load() -> Bool {
    do {
      // Ambient already mixes with other apps' audio, as CameraSounds.kt's sonification usage does.
      try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
      for name in names where players[name] == nil {
        let key = FlutterDartProject.lookupKey(forAsset: "assets/sounds/" + name + ".wav")
        guard let path = Bundle.main.path(forResource: key, ofType: nil) else { return false }
        let player = try AVAudioPlayer(contentsOf: URL(fileURLWithPath: path))
        guard player.prepareToPlay() else { return false }
        players[name] = player
      }
      return true
    } catch { return false }
  }

  func play(_ name: String) -> Bool {
    guard let player = players[name] else { return false }
    do { try AVAudioSession.sharedInstance().setActive(true) }
    catch { return false }
    player.currentTime = 0
    return player.play()
  }
}
