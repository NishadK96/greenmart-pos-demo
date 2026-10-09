import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

/// Classic Bluetooth SPP printing for paired ESC/POS receipt printers.
/// The Android side owns the socket; this side renders the existing PDF receipt
/// so online and offline invoices use the same layout and RTL fonts.
class AndroidBluetoothPrinter {
  static const urlPrefix = 'bluetooth://';
  static const _channel = MethodChannel('com.eazy.pos/bluetooth_printer');

  static bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static Future<List<Printer>> pairedPrinters() async {
    if (!supported) return const [];
    final devices = await _channel.invokeListMethod<Map<Object?, Object?>>(
      'listPairedPrinters',
    );
    return [
      for (final device in devices ?? const <Map<Object?, Object?>>[])
        if ((device['address'] as String?)?.isNotEmpty == true)
          Printer(
            url: '$urlPrefix${device['address']}',
            name: (device['name'] as String?)?.trim().isNotEmpty == true
                ? device['name'] as String
                : 'Bluetooth printer',
            model: 'Paired Bluetooth (ESC/POS)',
          ),
    ];
  }

  static Future<bool> printPdf(
    Printer printer,
    Uint8List pdf, {
    required PdfPageFormat format,
  }) async {
    if (!supported || !printer.url.startsWith(urlPrefix)) {
      throw StateError(
        'This Bluetooth printer is only supported in the Android app.',
      );
    }
    final address = printer.url.substring(urlPrefix.length);
    final width = format.width < 70 * PdfPageFormat.mm ? 384 : 576;
    final output = BytesBuilder(copy: false)..add([0x1b, 0x40]);
    var pages = 0;
    await for (final page in Printing.raster(pdf, dpi: 203)) {
      final png = img.decodePng(await page.toPng());
      if (png == null)
        throw StateError(
          'Could not render the receipt for Bluetooth printing.',
        );
      final bitmap = png.width == width
          ? png
          : img.copyResize(
              png,
              width: width,
              interpolation: img.Interpolation.average,
            );
      output.add(rasterCommands(bitmap));
      output.add([0x0a, 0x0a]);
      pages++;
    }
    if (pages == 0) throw StateError('The receipt has no printable pages.');
    final printed = await _channel.invokeMethod<bool>('printBytes', {
      'address': address,
      'bytes': output.takeBytes(),
    });
    return printed == true;
  }

  /// GS v 0 raster blocks, capped so portable printers need little buffer.
  @visibleForTesting
  static Uint8List rasterCommands(img.Image bitmap) {
    final bytesPerRow = (bitmap.width + 7) ~/ 8;
    final output = BytesBuilder(copy: false);
    for (var top = 0; top < bitmap.height; top += 128) {
      final rows = (bitmap.height - top).clamp(0, 128);
      output.add([
        0x1d,
        0x76,
        0x30,
        0x00,
        bytesPerRow & 0xff,
        (bytesPerRow >> 8) & 0xff,
        rows & 0xff,
        (rows >> 8) & 0xff,
      ]);
      final pixels = Uint8List(bytesPerRow * rows);
      for (var y = 0; y < rows; y++) {
        for (var x = 0; x < bitmap.width; x++) {
          final pixel = bitmap.getPixel(x, top + y);
          final dark =
              pixel.aNormalized >= 0.5 && pixel.luminanceNormalized < 0.66;
          if (dark) pixels[y * bytesPerRow + (x >> 3)] |= 0x80 >> (x & 7);
        }
      }
      output.add(pixels);
    }
    return output.takeBytes();
  }
}
