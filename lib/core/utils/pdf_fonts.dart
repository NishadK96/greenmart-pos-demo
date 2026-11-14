import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:pdf/widgets.dart' as pw;

abstract final class PdfFonts {
  static pw.ThemeData? _theme;
  static pw.Font? _latinRegular;
  static pw.Font? _latinBold;
  static pw.Font? _arabicRegular;
  static pw.Font? _arabicBold;

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
    _latinRegular = regular;
    _latinBold = bold;
    _arabicRegular = arabicRegular;
    _arabicBold = arabicBold;
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
  }) {
    value = _safePdfText(value);
    final arabic = containsArabic(value);
    final arabicFont = style?.fontWeight == pw.FontWeight.bold
        ? _arabicBold
        : _arabicRegular;
    final latinFont = style?.fontWeight == pw.FontWeight.bold
        ? _latinBold
        : _latinRegular;
    final resolvedStyle = arabic && arabicFont != null
        ? (style ?? const pw.TextStyle()).copyWith(
            font: arabicFont,
            fontFallback: latinFont == null ? null : [latinFont],
          )
        : style;
    return pw.Text(
      value,
      style: resolvedStyle,
      textAlign: textAlign,
      textDirection: directionFor(value),
      maxLines: maxLines,
    );
  }

  /// The JavaScript build of package:bidi can overrun its composition-length
  /// table for canonically decomposable Arabic glyphs. Native builds do not
  /// exhibit the issue. Normalize those glyphs only for web PDF generation so
  /// offline previews remain renderable instead of failing the whole receipt.
  static String _safePdfText(String value) {
    if (!kIsWeb || !containsArabic(value)) return value;
    return value
        .replaceAll(RegExp(r'[\u064B-\u065F\u0670]'), '')
        .replaceAll('آ', 'ا')
        .replaceAll('أ', 'ا')
        .replaceAll('إ', 'ا')
        .replaceAll('ؤ', 'و')
        .replaceAll('ئ', 'ي');
  }

  static pw.Widget bilingual(
    String label, {
    pw.TextStyle? style,
    pw.TextAlign? textAlign,
    pw.CrossAxisAlignment crossAxisAlignment = pw.CrossAxisAlignment.start,
  }) {
    final parts = label.split(RegExp(r'\s+(?:/|\||·)\s+'));
    if (parts.length != 2 ||
        containsArabic(parts.first) == containsArabic(parts.last)) {
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
