import 'dart:convert';
import 'dart:typed_data';

/// An envelope INSIDE ShotVault encryption. Legacy/no-location entries remain
/// plain JPEG payloads. Coordinates never go in the database or recovery JSON.
class RollVaultPayload {
  static const _magic = [0x43, 0x52, 0x4a, 0x46]; // CRJF

  static Uint8List encode(Uint8List jpeg, Map<String, Object?> job) {
    final metadata = utf8.encode(jsonEncode(job));
    final out = Uint8List(8 + metadata.length + jpeg.length);
    out.setAll(0, _magic);
    ByteData.sublistView(out).setUint32(4, metadata.length);
    out.setAll(8, metadata);
    out.setAll(8 + metadata.length, jpeg);
    return out;
  }

  static ({Uint8List jpeg, Map<String, Object?>? job}) decode(Uint8List bytes) {
    if (bytes.length < 4 ||
        List.generate(4, (i) => bytes[i] == _magic[i]).contains(false)) {
      return (jpeg: bytes, job: null);
    }
    if (bytes.length < 8) throw const FormatException('Truncated vault job');
    final length = ByteData.sublistView(bytes).getUint32(4);
    if (length > bytes.length - 8) {
      throw const FormatException('Truncated vault job');
    }
    final job = Map<String, Object?>.from(
      jsonDecode(utf8.decode(Uint8List.sublistView(bytes, 8, 8 + length)))
          as Map,
    );
    return (jpeg: Uint8List.sublistView(bytes, 8 + length), job: job);
  }
}
