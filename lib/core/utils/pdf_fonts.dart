import 'package:flutter/services.dart';
import 'package:pdf/widgets.dart' as pw;

abstract final class PdfFonts {
  static pw.ThemeData? _theme;

  static Future<pw.ThemeData> arabicTheme() async {
    final cached = _theme;
    if (cached != null) return cached;
    final regular = pw.Font.ttf(
      await rootBundle.load('assets/fonts/NotoSans-Regular.ttf'),
    );
    final bold = pw.Font.ttf(
      await rootBundle.load('assets/fonts/NotoSans-Bold.ttf'),
    );
    final arabicRegular = pw.Font.ttf(
      await rootBundle.load('assets/fonts/NotoSansArabic-Regular.ttf'),
    );
    final arabicBold = pw.Font.ttf(
      await rootBundle.load('assets/fonts/NotoSansArabic-Bold.ttf'),
    );
    return _theme = pw.ThemeData.withFont(
      base: regular,
      bold: bold,
      fontFallback: [arabicRegular, arabicBold],
    );
  }

  static bool containsArabic(String value) => RegExp(
    r'[\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF\uFB50-\uFDFF\uFE70-\uFEFF]',
  ).hasMatch(value);

  static pw.TextDirection directionFor(String value) =>
      containsArabic(value) ? pw.TextDirection.rtl : pw.TextDirection.ltr;

  static pw.Text text(
    String value, {
    pw.TextStyle? style,
    pw.TextAlign? textAlign,
    int? maxLines,
  }) => pw.Text(
    value,
    style: style,
    textAlign: textAlign,
    textDirection: directionFor(value),
    maxLines: maxLines,
  );

  static pw.Widget bilingual(
    String label, {
    pw.TextStyle? style,
    pw.TextAlign? textAlign,
    pw.CrossAxisAlignment crossAxisAlignment = pw.CrossAxisAlignment.start,
  }) {
    final parts = label.split(' / ');
    if (parts.length != 2 || !containsArabic(parts.last)) {
      return text(label, style: style, textAlign: textAlign);
    }
    return pw.Column(
      crossAxisAlignment: crossAxisAlignment,
      children: [
        text(parts.first, style: style, textAlign: textAlign),
        text(parts.last, style: style, textAlign: textAlign),
      ],
    );
  }
}
