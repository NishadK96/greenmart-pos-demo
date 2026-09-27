import 'dart:typed_data';

import 'package:eazy_pos/features/printers/application/printer_document_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

void main() {
  test('transparent PDF raster background becomes white thermal paper', () {
    final source = img.Image(width: 3, height: 1, numChannels: 4);
    source.setPixelRgba(0, 0, 0, 0, 0, 0);
    source.setPixelRgba(1, 0, 30, 30, 30, 255);
    source.setPixelRgba(2, 0, 245, 245, 245, 255);

    final output = img.decodePng(
      PrinterDocumentService.thermalMonochrome(
        Uint8List.fromList(img.encodePng(source)),
      ),
    )!;

    expect(output.getPixel(0, 0).r, 255);
    expect(output.getPixel(1, 0).r, 0);
    expect(output.getPixel(2, 0).r, 255);
  });
}
