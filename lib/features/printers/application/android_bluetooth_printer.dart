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
  static const usbUrlPrefix = 'usb://';
  static const _channel = MethodChannel('com.eazy.pos/bluetooth_printer');

  static bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static bool handles(Printer printer) =>
      printer.url.startsWith(urlPrefix) || printer.url.startsWith(usbUrlPrefix);

  static Future<List<Printer>> availablePrinters() async {
    if (!supported) return const [];
    final devices = await _channel.invokeListMethod<Map<Object?, Object?>>(
      'listPairedPrinters',
    );
    return [
      for (final device in devices ?? const <Map<Object?, Object?>>[])
        if ((device['address'] as String?)?.isNotEmpty == true)
          Printer(
            url:
                (device['transport']?.toString() == 'usb'
                    ? usbUrlPrefix
                    : urlPrefix) +
                device['address'].toString(),
            name: (device['name'] as String?)?.trim().isNotEmpty == true
                ? device['name'] as String
                : device['transport']?.toString() == 'usb'
                ? 'USB printer'
                : 'Bluetooth printer',
            model: device['transport']?.toString() == 'usb'
                ? 'Connected USB (ESC/POS)'
                : 'Paired Bluetooth (ESC/POS)',
          ),
    ];
  }

  static Future<List<Printer>> pairedPrinters() => availablePrinters();

  static Future<bool> printPdf(
    Printer printer,
    Uint8List pdf, {
    required PdfPageFormat format,
  }) async {
    if (!supported || !handles(printer)) {
      throw StateError(
        'This direct printer is only supported in the Android app.',
      );
    }
    final usb = printer.url.startsWith(usbUrlPrefix);
    final address = printer.url.substring(
      usb ? usbUrlPrefix.length : urlPrefix.length,
    );
    final width = format.width < 70 * PdfPageFormat.mm ? 384 : 576;
    final output = BytesBuilder(copy: false)..add([0x1b, 0x40]);
    var pages = 0;
    await for (final page in Printing.raster(pdf, dpi: 203)) {
      final png = img.decodePng(await page.toPng());
      if (png == null)
        throw StateError(
          'Could not render the receipt for Bluetooth printing.',
        );
      final cropped = trimTrailingWhitespace(png);
      final bitmap = cropped.width == width
          ? cropped
          : img.copyResize(
              cropped,
              width: width,
              interpolation: img.Interpolation.average,
            );
      output.add(rasterCommands(bitmap));
      pages++;
    }
    if (pages == 0) throw StateError('The receipt has no printable pages.');
    // Feed past the cutter and request a full cut. Printers without an
    // automatic cutter safely ignore the final GS V command.
    output.add([0x0a, 0x0a, 0x0a, 0x1d, 0x56, 0x00]);
    final printed = await _channel.invokeMethod<bool>('printBytes', {
      'transport': usb ? 'usb' : 'bluetooth',
      'address': address,
      'bytes': output.takeBytes(),
    });
    return printed == true;
  }

  /// Removes the unused fixed-height PDF area below the last visible element.
  ///
  /// PDF invoice layouts are commonly rendered on a tall page. Sending that
  /// entire white bitmap to a roll printer wastes paper before the cut. Keep a
  /// small physical margin (roughly 4 mm at 203 DPI) after the content instead.
  @visibleForTesting
  static img.Image trimTrailingWhitespace(img.Image bitmap) {
    var lastInkRow = -1;
    for (var y = bitmap.height - 1; y >= 0 && lastInkRow < 0; y--) {
      for (var x = 0; x < bitmap.width; x++) {
        final pixel = bitmap.getPixel(x, y);
        if (pixel.aNormalized >= 0.5 && pixel.luminanceNormalized < 0.96) {
          lastInkRow = y;
          break;
        }
      }
    }

    if (lastInkRow < 0) return bitmap;
    final croppedHeight = (lastInkRow + 33).clamp(1, bitmap.height);
    if (croppedHeight == bitmap.height) return bitmap;
    return img.copyCrop(
      bitmap,
      x: 0,
      y: 0,
      width: bitmap.width,
      height: croppedHeight,
    );
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
