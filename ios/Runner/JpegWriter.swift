import Foundation
import ImageIO
import UIKit
import UniformTypeIdentifiers

/// Channel failures corresponding to MediaChannel.kt's explicit error codes.
struct NativeFailure: Error {
  let code: String
  let message: String
  init(_ code: String, _ message: String) {
    self.code = code
    self.message = message
  }
}

/// SaveSource.kt and ContactSheetFile.kt: confine all Dart paths to temporary app storage.
enum MediaFiles {
  static func temporary(_ path: String) throws -> URL {
    guard path.hasPrefix("/"), !path.contains("\0") else {
      throw NativeFailure("not_allowed", "Invalid cache path")
    }
    let file = URL(fileURLWithPath: path).standardizedFileURL.resolvingSymlinksInPath()
    let roots = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)
      + [FileManager.default.temporaryDirectory]
    guard roots.contains(where: {
      let root = $0.standardizedFileURL.resolvingSymlinksInPath().path
      return file.path.hasPrefix(root.hasSuffix("/") ? root : root + "/")
    }), FileManager.default.fileExists(atPath: file.path),
      try file.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile == true else {
      throw NativeFailure("not_allowed", "Not a regular file of the cache")
    }
    return file
  }

  static func contactSheet(_ path: String) throws -> URL {
    guard !(path as NSString).pathComponents.contains("..") else {
      throw NativeFailure("not_allowed", "Invalid contact sheet path")
    }
    let requested = URL(fileURLWithPath: path).standardizedFileURL
    let file = requested.resolvingSymlinksInPath()
    let roots = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)
      + [FileManager.default.temporaryDirectory]
    guard roots.contains(where: {
      let folder = $0.standardizedFileURL.resolvingSymlinksInPath().appendingPathComponent("contact-sheets")
      return folder.resolvingSymlinksInPath() == folder && file.deletingLastPathComponent() == folder
    }), path.hasPrefix("/"), !path.contains("\0"),
      requested.deletingLastPathComponent().lastPathComponent == "contact-sheets",
      ["jpg", "jpeg", "png"].contains(file.pathExtension.lowercased()) else {
      throw NativeFailure("not_allowed", "Not a contact sheet image")
    }
    guard FileManager.default.fileExists(atPath: file.path) else {
      throw NativeFailure("not_found", "Contact sheet no longer exists")
    }
    guard try requested.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink != true,
      try requested.deletingLastPathComponent().resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink != true else {
      throw NativeFailure("not_allowed", "Symlink in contact sheet path")
    }
    return try temporary(path)
  }

  static func output(_ suffix: String = "jpg") -> URL {
    FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + "." + suffix)
  }
}

/// PhotoLocation.kt's validated shutter snapshot, shared with LocationChannel.kt's port.
struct PhotoLocation {
  let latitude: Double
  let longitude: Double
  let altitude: Double?
  let accuracy: Double
  let time: Int64
  let approximate: Bool

  var valid: Bool {
    latitude.isFinite && (-90...90).contains(latitude)
      && longitude.isFinite && (-180...180).contains(longitude)
      && accuracy.isFinite && accuracy >= 0
      && (approximate ? accuracy <= 5000 : accuracy < 100)
      && time > 0
      && (altitude.map { $0.isFinite && (-1000...100000).contains($0) } ?? true)
  }

  func usable(at shutter: Int64) -> Bool {
    valid && shutter >= time && shutter - time <= (approximate ? 600000 : 120000)
  }

  static func from(_ value: Any?) -> PhotoLocation? {
    guard let map = value as? [String: Any],
      let lat = number(map["latitude"]), let lon = number(map["longitude"]),
      let accuracy = number(map["accuracy"]), let time = milliseconds(map["time"]),
      map["approximate"] == nil || map["approximate"] is NSNull || boolean(map["approximate"]) != nil else { return nil }
    let fix = PhotoLocation(latitude: lat, longitude: lon, altitude: number(map["altitude"]),
      accuracy: accuracy, time: time, approximate: boolean(map["approximate"]) ?? false)
    return fix.valid ? fix : nil
  }

  static func number(_ value: Any?) -> Double? {
    guard let value = value as? NSNumber, CFGetTypeID(value) != CFBooleanGetTypeID() else { return nil }
    return value.doubleValue
  }

  static func boolean(_ value: Any?) -> Bool? {
    guard let value = value as? NSNumber, CFGetTypeID(value) == CFBooleanGetTypeID() else { return nil }
    return value.boolValue
  }

  static func integer(_ value: Any?) -> Int? {
    guard let value = value as? NSNumber, CFGetTypeID(value) != CFBooleanGetTypeID(),
      !["f", "d"].contains(String(cString: value.objCType)) else { return nil }
    return milliseconds(value).flatMap { Int(exactly: $0) }
  }

  static func milliseconds(_ value: Any?) -> Int64? {
    guard let value = value as? NSNumber, CFGetTypeID(value) != CFBooleanGetTypeID() else { return nil }
    // Kotlin Number.toLong: truncate numeric milliseconds, but reject overflow and non-finite values.
    if ["f", "d"].contains(String(cString: value.objCType)) {
      return Int64(exactly: value.doubleValue.rounded(.towardZero))
    }
    guard value.compare(NSNumber(value: Int64.min)) != .orderedAscending,
      value.compare(NSNumber(value: Int64.max)) != .orderedDescending else { return nil }
    return value.int64Value
  }

  var dictionary: [String: Any] {
    // Dart PhotoLocation.fromJson requires an int timestamp; the other numeric fields accept num.
    ["latitude": latitude, "longitude": longitude, "altitude": altitude.map { $0 as Any } ?? NSNull(),
      "accuracy": accuracy, "time": time, "approximate": approximate]
  }
}

/// ImageIO counterpart of MediaChannel.kt's JPEG encoder and ExifCopy.kt.
enum JpegWriter {
  static func image(_ rgba: Data, width: Int, height: Int, straightAlpha: Bool = false) throws -> CGImage {
    guard rgba.count == width * height * 4,
      let provider = CGDataProvider(data: rgba as CFData),
      let image = CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32,
        bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGBitmapInfo(rawValue: (straightAlpha ? CGImageAlphaInfo.last : .premultipliedLast).rawValue)
          .union(.byteOrder32Big), provider: provider, decode: nil, shouldInterpolate: false,
        intent: .defaultIntent) else { throw NativeFailure("save_failed", "Invalid RGBA") }
    return image
  }

  static func properties(_ source: URL?) -> [String: Any] {
    guard let source = source, let input = CGImageSourceCreateWithURL(source as CFURL, nil) else { return [:] }
    return CGImageSourceCopyPropertiesAtIndex(input, 0, nil) as? [String: Any] ?? [:]
  }

  static func metadata(_ source: URL?, width: Int, height: Int, includeLocation: Bool,
    location: PhotoLocation?, takenAt: Int64?) -> [String: Any] {
    let sourceProperties = properties(source)
    // ExifCopy.BASE_TAGS: keep camera metadata, excluding opaque maker notes and auxiliary dictionaries.
    var tiff = sourceProperties[kCGImagePropertyTIFFDictionary as String] as? [String: Any] ?? [:]
    let tiffKeys = ["DateTime", "Make", "Model"]
    tiff = tiff.filter { tiffKeys.contains($0.key) }
    tiff[kCGImagePropertyTIFFSoftware as String] = "Diapo"
    tiff[kCGImagePropertyTIFFOrientation as String] = 1
    var exif = sourceProperties[kCGImagePropertyExifDictionary as String] as? [String: Any] ?? [:]
    let keys = ["DateTimeOriginal", "DateTimeDigitized", "OffsetTime", "OffsetTimeOriginal",
      "OffsetTimeDigitized", "SubsecTimeOriginal", "FNumber", "ExposureTime", "ISOSpeedRatings",
      "FocalLength", "FocalLenIn35mmFilm", "ApertureValue", "WhiteBalance", "Flash"]
    exif = exif.filter { keys.contains($0.key) }
    exif[kCGImagePropertyExifPixelXDimension as String] = width
    exif[kCGImagePropertyExifPixelYDimension as String] = height
    var output: [String: Any] = [kCGImagePropertyTIFFDictionary as String: tiff,
      kCGImagePropertyExifDictionary as String: exif, kCGImagePropertyOrientation as String: 1,
      kCGImagePropertyPixelWidth as String: width, kCGImagePropertyPixelHeight as String: height]
    // ExifCopy.writeLocation: never copy camera GPS. The brief requires a validated Dart snapshot.
    output.removeValue(forKey: kCGImagePropertyGPSDictionary as String)
    if includeLocation, let fix = location, fix.valid, takenAt.map({ fix.usable(at: $0) }) ?? true {
      var gps: [String: Any] = ["Version": "2.3.0.0", "Latitude": abs(fix.latitude),
        "LatitudeRef": fix.latitude < 0 ? "S" : "N", "Longitude": abs(fix.longitude),
        "LongitudeRef": fix.longitude < 0 ? "W" : "E", "MapDatum": "WGS-84",
        "HPositioningError": fix.accuracy]
      if let altitude = fix.altitude {
        gps["Altitude"] = abs(altitude)
        gps["AltitudeRef"] = altitude < 0 ? 1 : 0
      }
      let date = Date(timeIntervalSince1970: Double(fix.time) / 1000)
      let formatter = DateFormatter()
      formatter.locale = Locale(identifier: "en_US_POSIX")
      formatter.timeZone = TimeZone(secondsFromGMT: 0)
      formatter.dateFormat = "yyyy:MM:dd"
      gps["DateStamp"] = formatter.string(from: date)
      formatter.dateFormat = "HH:mm:ss"
      gps["TimeStamp"] = formatter.string(from: date)
      output[kCGImagePropertyGPSDictionary as String] = gps
    }
    // Kotlin uses takenAt only to validate GPS freshness; the source supplies EXIF capture dates.
    return output
  }

  static func encode(_ image: CGImage, quality: Int, properties: [String: Any] = [:]) throws -> Data {
    guard (0...100).contains(quality) else { throw NativeFailure("save_failed", "Invalid JPEG quality") }
    let data = NSMutableData()
    guard let destination = CGImageDestinationCreateWithData(data, UTType.jpeg.identifier as CFString, 1, nil)
      else { throw NativeFailure("save_failed", "Cannot create JPEG") }
    var options = properties
    options[kCGImageDestinationLossyCompressionQuality as String] = Double(quality) / 100
    CGImageDestinationAddImage(destination, image, options as CFDictionary)
    guard CGImageDestinationFinalize(destination) else { throw NativeFailure("save_failed", "Cannot encode JPEG") }
    return data as Data
  }

  static func original(_ source: URL, includeLocation: Bool, location: PhotoLocation?, takenAt: Int64?) throws -> Data {
    // MediaChannel.saveOriginal: copy compressed JPEG data, replacing metadata without recompressing pixels.
    let size = try source.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
    guard (4...64 * 1024 * 1024).contains(size) else { throw NativeFailure("save_failed", "Invalid original size") }
    let bytes = try Data(contentsOf: source)
    guard (4...64 * 1024 * 1024).contains(bytes.count), bytes.prefix(2) == Data([0xff, 0xd8]),
      let input = CGImageSourceCreateWithData(bytes as CFData, nil) else {
      throw NativeFailure("save_failed", "Invalid original JPEG")
    }
    let original = properties(source)
    guard let width = original[kCGImagePropertyPixelWidth as String] as? Int,
      let height = original[kCGImagePropertyPixelHeight as String] as? Int else {
      throw NativeFailure("save_failed", "Missing original dimensions")
    }
    let sanitized = metadata(source, width: width, height: height, includeLocation: includeLocation,
      location: location, takenAt: takenAt)
    let output = NSMutableData()
    guard let destination = CGImageDestinationCreateWithData(output, UTType.jpeg.identifier as CFString, 1, nil)
      else { throw NativeFailure("save_failed", "Cannot copy original") }
    // CGImageDestinationCopyImageSource takes CGImageMetadata, not the image-properties dictionary used by AddImage.
    let clean: CGMutableImageMetadata
    if let sourceMetadata = CGImageSourceCopyMetadataAtIndex(input, 0, nil),
      let copy = CGImageMetadataCreateMutableCopy(sourceMetadata) { clean = copy }
    else { clean = CGImageMetadataCreateMutable() }
    // ExifCopy.writeLocation: retain original non-GPS metadata and orientation, then replace every GPS tag.
    var gpsPaths: [CFString] = []
    let enumeration = [kCGImageMetadataEnumerateRecursively as String: true] as CFDictionary
    CGImageMetadataEnumerateTagsUsingBlock(clean, nil, enumeration) { path, tag in
      let name = (CGImageMetadataTagCopyName(tag) as String?) ?? ""
      if name.uppercased().contains("GPS") { gpsPaths.append(path) }
      return true
    }
    for path in gpsPaths {
      guard CGImageMetadataRemoveTagWithPath(clean, nil, path) else {
        throw NativeFailure("save_failed", "Cannot remove original GPS tag")
      }
    }
    if let tags = sanitized[kCGImagePropertyGPSDictionary as String] as? [String: Any] {
      for (name, value) in tags {
        // CHECK ON MAC: verify ImageIO accepts the GPS version and positioning-error properties when copying JPEG metadata.
        if !CGImageMetadataSetValueMatchingImageProperty(clean, kCGImagePropertyGPSDictionary,
          name as CFString, value as CFTypeRef) {
          throw NativeFailure("save_failed", "Cannot copy original EXIF property")
        }
      }
    }
    let copyOptions: [String: Any] = [kCGImageDestinationMetadata as String: clean,
      kCGImageDestinationMergeMetadata as String: false,
      kCGImageMetadataShouldExcludeGPS as String: sanitized[kCGImagePropertyGPSDictionary as String] == nil,
      kCGImageDestinationOrientation as String: original[kCGImagePropertyOrientation as String] ?? 1]
    // CHECK ON MAC: confirm the original keeps its compressed JPEG scans and source GPS is fully replaced.
    var error: Unmanaged<CFError>?
    guard CGImageDestinationCopyImageSource(destination, input, copyOptions as CFDictionary, &error) else {
      throw NativeFailure("save_failed", "Cannot rewrite original metadata")
    }
    // ExifCopy.writeLocation: verify the actual output before it can reach Photos.
    guard let rewritten = CGImageSourceCreateWithData(output as CFData, nil),
      let properties = CGImageSourceCopyPropertiesAtIndex(rewritten, 0, nil) as? [String: Any] else {
      throw NativeFailure("save_failed", "Cannot verify original metadata")
    }
    if let expected = sanitized[kCGImagePropertyGPSDictionary as String] as? [String: Any] {
      // Allow ImageIO's rational coordinate rounding (about one centimetre); hemisphere must match too.
      guard let gps = properties[kCGImagePropertyGPSDictionary as String] as? [String: Any],
        let latitude = PhotoLocation.number(gps["Latitude"]),
        let longitude = PhotoLocation.number(gps["Longitude"]),
        let expectedLatitude = PhotoLocation.number(expected["Latitude"]),
        let expectedLongitude = PhotoLocation.number(expected["Longitude"]),
        // EXIF stores degrees as rationals; about 1 m of round-trip error is allowed.
        abs(latitude - expectedLatitude) <= 0.00001,
        abs(longitude - expectedLongitude) <= 0.00001,
        gps["LatitudeRef"] as? String == expected["LatitudeRef"] as? String,
        gps["LongitudeRef"] as? String == expected["LongitudeRef"] as? String else {
        throw NativeFailure("save_failed", "Original GPS does not match the requested fix")
      }
    } else if properties[kCGImagePropertyGPSDictionary as String] != nil {
      throw NativeFailure("save_failed", "Original still contains GPS")
    }
    return output as Data
  }

  static func readExifDates(_ source: URL) -> [String: Any] {
    let exif = properties(source)[kCGImagePropertyExifDictionary as String] as? [String: Any] ?? [:]
    return ["original": exif["DateTimeOriginal"] ?? NSNull(),
      "originalOffset": exif["OffsetTimeOriginal"] ?? NSNull(),
      "digitized": exif["DateTimeDigitized"] ?? NSNull(),
      "digitizedOffset": exif["OffsetTimeDigitized"] ?? NSNull()]
  }
}
