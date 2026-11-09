import 'package:eazy_pos/features/printers/application/android_bluetooth_printer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

void main() {
  test('packs black dots into ESC/POS raster bytes', () {
    final image = img.Image(width: 8, height: 1);
    img.fill(image, color: img.ColorRgb8(255, 255, 255));
    image.setPixelRgb(0, 0, 0, 0, 0);
    image.setPixelRgb(7, 0, 0, 0, 0);

    expect(AndroidBluetoothPrinter.rasterCommands(image), [
      0x1d,
      0x76,
      0x30,
      0x00,
      1,
      0,
      1,
      0,
      0x81,
    ]);
  });

  test('splits long receipts into bounded raster blocks', () {
    final image = img.Image(width: 8, height: 129);
    img.fill(image, color: img.ColorRgb8(255, 255, 255));
    final bytes = AndroidBluetoothPrinter.rasterCommands(image);

    expect(bytes.length, 128 + 8 + 1 + 8);
    expect(bytes.sublist(0, 8), [0x1d, 0x76, 0x30, 0, 1, 0, 128, 0]);
    expect(bytes.sublist(136, 144), [0x1d, 0x76, 0x30, 0, 1, 0, 1, 0]);
  });

  test('removes trailing PDF whitespace and keeps a receipt margin', () {
    final image = img.Image(width: 80, height: 300);
    img.fill(image, color: img.ColorRgb8(255, 255, 255));
    image.setPixelRgb(10, 99, 0, 0, 0);

    final cropped = AndroidBluetoothPrinter.trimTrailingWhitespace(image);

    expect(cropped.width, 80);
    expect(cropped.height, 132);
    expect(cropped.getPixel(10, 99).luminanceNormalized, 0);
  });

  test('does not crop an entirely blank or already full page', () {
    final blank = img.Image(width: 8, height: 20);
    img.fill(blank, color: img.ColorRgb8(255, 255, 255));
    expect(AndroidBluetoothPrinter.trimTrailingWhitespace(blank).height, 20);

    blank.setPixelRgb(0, 19, 0, 0, 0);
    expect(AndroidBluetoothPrinter.trimTrailingWhitespace(blank).height, 20);
  });
}
