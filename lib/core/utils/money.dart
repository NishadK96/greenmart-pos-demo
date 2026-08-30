import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart' hide TextDirection;

const saudiRiyalAsset = 'assets/icons/saudi_riyal_symbol.svg';

// Kept for compatibility with the business-context bootstrap. Eazy POS uses
// the official Saudi riyal mark in the UI and SAR in text-only output.
void configureCurrency(String symbol) {}

String money(int minorUnits) => NumberFormat.currency(
  symbol: 'SAR ',
  decimalDigits: 2,
).format(minorUnits / 100);

String moneyAmount(int minorUnits) => NumberFormat.currency(
  symbol: '',
  decimalDigits: 2,
).format(minorUnits / 100);

class RiyalAmount extends StatelessWidget {
  const RiyalAmount(
    this.minorUnits, {
    super.key,
    this.style,
    this.textAlign,
    this.maxLines = 1,
    this.overflow = TextOverflow.ellipsis,
    this.semanticLabel,
  });

  final int minorUnits;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow overflow;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final effectiveStyle = DefaultTextStyle.of(context).style.merge(style);
    final fontSize = effectiveStyle.fontSize ?? 14;
    final color =
        effectiveStyle.color ??
        IconTheme.of(context).color ??
        Theme.of(context).colorScheme.onSurface;

    return Semantics(
      label: semanticLabel ?? '${moneyAmount(minorUnits)} Saudi riyals',
      excludeSemantics: true,
      child: Text.rich(
        TextSpan(
          style: effectiveStyle,
          children: [
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: RiyalSymbol(size: fontSize, color: color),
            ),
            const TextSpan(text: ' '),
            TextSpan(text: moneyAmount(minorUnits)),
          ],
        ),
        textAlign: textAlign,
        maxLines: maxLines,
        overflow: overflow,
        textDirection: TextDirection.ltr,
      ),
    );
  }
}

class RiyalSymbol extends StatelessWidget {
  const RiyalSymbol({super.key, this.size = 16, this.color});

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) => SvgPicture.asset(
    saudiRiyalAsset,
    width: size * .9,
    height: size,
    colorFilter: ColorFilter.mode(
      color ??
          IconTheme.of(context).color ??
          Theme.of(context).colorScheme.onSurface,
      BlendMode.srcIn,
    ),
  );
}

int toPaise(num value) => (value * 100).round();
