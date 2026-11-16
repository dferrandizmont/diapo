import 'dart:io';
import 'dart:typed_data';

/// The CRC-32 of a PNG chunk.
int _crc32(List<int> bytes) {
  var crc = 0xFFFFFFFF;
  for (final byte in bytes) {
    crc ^= byte;
    for (var i = 0; i < 8; i++) {
      crc = (crc & 1) != 0 ? (crc >> 1) ^ 0xEDB88320 : crc >> 1;
    }
  }
  return crc ^ 0xFFFFFFFF;
}

List<int> _chunk(String type, List<int> data) {
  final body = [...type.codeUnits, ...data];
  final length = ByteData(4)..setUint32(0, data.length);
  final crc = ByteData(4)..setUint32(0, _crc32(body));
  return [...length.buffer.asUint8List(), ...body, ...crc.buffer.asUint8List()];
}

List<int> _header(int width, int height) {
  final ihdr = ByteData(13)
    ..setUint32(0, width)
    ..setUint32(4, height)
    ..setUint8(8, 8) // bit depth
    ..setUint8(9, 0); // grayscale
  return [
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, //
    ..._chunk('IHDR', ihdr.buffer.asUint8List()),
  ];
}

/// A real grayscale PNG of [width] x [height], all black. It is a few hundred
/// bytes: the rows compress to almost nothing.
Uint8List makePng(int width, int height) {
  final raw = Uint8List((width + 1) * height); // filter byte 0 + black pixels
  final data = ZLibCodec().encode(raw);
  return Uint8List.fromList([
    ..._header(width, height),
    ..._chunk('IDAT', data),
    ..._chunk('IEND', const []),
  ]);
}

/// A PNG that only declares [width] x [height]: the header, a few bytes of
/// data that are not the pixels, and the end. Enough to ask a decoder for the
/// size, never to decode it.
Uint8List pngDeclaring(int width, int height) => Uint8List.fromList([
  ..._header(width, height),
  ..._chunk('IDAT', ZLibCodec().encode(const [0])),
  ..._chunk('IEND', const []),
]);
