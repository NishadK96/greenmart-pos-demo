import 'package:flutter/material.dart' as material;

import '../../core/localization/app_localizations.dart';

export '../../core/localization/app_localizations.dart';

/// Drop-in replacement for Flutter's [material.Text] that translates plain
/// string content through the application's localization catalogue.
///
/// This keeps labels created deep inside dialogs and reusable components from
/// bypassing localization. Dynamic/backend values remain unchanged when they
/// do not have a catalogue entry.
class Text extends material.StatelessWidget {
  const Text(
    this.data, {
    super.key,
    this.style,
    this.strutStyle,
    this.textAlign,
    this.textDirection,
    this.locale,
    this.softWrap,
    this.overflow,
    this.textScaler,
    this.maxLines,
    this.semanticsLabel,
    this.semanticsIdentifier,
    this.textWidthBasis,
    this.textHeightBehavior,
    this.selectionColor,
  }) : textSpan = null;

  const Text.rich(
    this.textSpan, {
    super.key,
    this.style,
    this.strutStyle,
    this.textAlign,
    this.textDirection,
    this.locale,
    this.softWrap,
    this.overflow,
    this.textScaler,
    this.maxLines,
    this.semanticsLabel,
    this.semanticsIdentifier,
    this.textWidthBasis,
    this.textHeightBehavior,
    this.selectionColor,
  }) : data = null;

  final String? data;
  final material.InlineSpan? textSpan;
  final material.TextStyle? style;
  final material.StrutStyle? strutStyle;
  final material.TextAlign? textAlign;
  final material.TextDirection? textDirection;
  final material.Locale? locale;
  final bool? softWrap;
  final material.TextOverflow? overflow;
  final material.TextScaler? textScaler;
  final int? maxLines;
  final String? semanticsLabel;
  final String? semanticsIdentifier;
  final material.TextWidthBasis? textWidthBasis;
  final material.TextHeightBehavior? textHeightBehavior;
  final material.Color? selectionColor;

  @override
  material.Widget build(material.BuildContext context) {
    final localizedStyle = _localizedStyle(context, style);
    if (data != null) {
      return material.Text(
        context.tr(data!),
        style: localizedStyle,
        strutStyle: strutStyle,
        textAlign: textAlign,
        textDirection: textDirection,
        locale: locale,
        softWrap: softWrap,
        overflow: overflow,
        textScaler: textScaler,
        maxLines: maxLines,
        semanticsLabel: semanticsLabel,
        semanticsIdentifier: semanticsIdentifier,
        textWidthBasis: textWidthBasis,
        textHeightBehavior: textHeightBehavior,
        selectionColor: selectionColor,
      );
    }
    return material.Text.rich(
      _localizedSpan(context, textSpan!),
      style: localizedStyle,
      strutStyle: strutStyle,
      textAlign: textAlign,
      textDirection: textDirection,
      locale: locale,
      softWrap: softWrap,
      overflow: overflow,
      textScaler: textScaler,
      maxLines: maxLines,
      semanticsLabel: semanticsLabel,
      semanticsIdentifier: semanticsIdentifier,
      textWidthBasis: textWidthBasis,
      textHeightBehavior: textHeightBehavior,
      selectionColor: selectionColor,
    );
  }

  material.InlineSpan _localizedSpan(
    material.BuildContext context,
    material.InlineSpan span,
  ) {
    if (span is! material.TextSpan) return span;
    return material.TextSpan(
      text: span.text == null ? null : context.tr(span.text!),
      children: span.children
          ?.map((child) => _localizedSpan(context, child))
          .toList(growable: false),
      style: _localizedStyle(context, span.style),
      recognizer: span.recognizer,
      mouseCursor: span.mouseCursor,
      onEnter: span.onEnter,
      onExit: span.onExit,
      semanticsLabel: span.semanticsLabel,
      locale: span.locale,
      spellOut: span.spellOut,
    );
  }

  material.TextStyle? _localizedStyle(
    material.BuildContext context,
    material.TextStyle? source,
  ) {
    if (!context.isArabic) return source;
    return (source ?? const material.TextStyle()).copyWith(
      fontFamily: 'NotoSansArabic',
      fontFamilyFallback: const ['NotoSans'],
    );
  }
}
