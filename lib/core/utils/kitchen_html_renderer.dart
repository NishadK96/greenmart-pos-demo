import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

/// Renders the ERP-provided kitchen ticket with a real browser engine.
///
/// Mixed Arabic/Latin text must be shaped and laid out by the HTML renderer;
/// rebuilding the ticket as ESC/POS text or PDF text changes bidi ordering.
abstract final class KitchenHtmlRenderer {
  static Future<Uint8List?> render(String html, {required double width}) async {
    if (html.trim().isEmpty || kIsWeb) return null;
    if (!const [
      TargetPlatform.android,
      TargetPlatform.iOS,
      TargetPlatform.macOS,
      TargetPlatform.windows,
    ].contains(defaultTargetPlatform)) {
      return null;
    }

    final created = Completer<InAppWebViewController>();
    final loaded = Completer<void>();
    final renderedHtml = _document(html, width.round());
    final webView = HeadlessInAppWebView(
      initialSize: Size(width, 900),
      initialData: InAppWebViewInitialData(
        data: renderedHtml,
        mimeType: 'text/html',
        encoding: 'utf-8',
        baseUrl: WebUri('https://eazyerp.co/'),
      ),
      initialSettings: InAppWebViewSettings(
        transparentBackground: false,
        supportZoom: false,
        disableContextMenu: true,
        javaScriptEnabled: true,
      ),
      onWebViewCreated: (controller) {
        if (!created.isCompleted) created.complete(controller);
      },
      onLoadStop: (_, __) {
        if (!loaded.isCompleted) loaded.complete();
      },
      onReceivedError: (_, __, error) {
        if (!loaded.isCompleted) {
          loaded.completeError(StateError(error.description));
        }
      },
    );

    try {
      await webView.run();
      final controller = await created.future.timeout(
        const Duration(seconds: 12),
      );
      await loaded.future.timeout(const Duration(seconds: 20));
      await controller.evaluateJavascript(
        source: 'document.fonts ? document.fonts.ready : Promise.resolve()',
      );
      final rawHeight = await controller.evaluateJavascript(
        source: '''
          Math.max(
            document.documentElement.scrollHeight,
            document.body ? document.body.scrollHeight : 0,
            document.documentElement.offsetHeight,
            document.body ? document.body.offsetHeight : 0
          )
        ''',
      );
      final measured = double.tryParse(rawHeight?.toString() ?? '') ?? 900;
      final height = measured.ceilToDouble().clamp(120, 16000).toDouble();
      await webView.setSize(Size(width, height));
      await Future<void>.delayed(const Duration(milliseconds: 120));
      return controller.takeScreenshot(
        screenshotConfiguration: ScreenshotConfiguration(
          compressFormat: CompressFormat.PNG,
          quality: 100,
          rect: InAppWebViewRect(x: 0, y: 0, width: width, height: height),
        ),
      );
    } finally {
      await webView.dispose();
    }
  }

  static String _document(String source, int width) {
    const head = '''
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<style>
  @page { size: auto; margin: 0; }
  html, body {
    width: 100% !important;
    min-width: 0 !important;
    max-width: 100% !important;
    margin: 0 !important;
    padding: 0 !important;
    background: #fff !important;
    overflow: hidden !important;
    -webkit-print-color-adjust: exact;
    print-color-adjust: exact;
  }
  .kitchen-order {
    width: 100% !important;
    min-width: 0 !important;
    max-width: 100% !important;
  }
  *, *::before, *::after { box-sizing: border-box; }
</style>
''';
    final trimmed = source.trim();
    if (RegExp(r'<html[\s>]', caseSensitive: false).hasMatch(trimmed)) {
      if (RegExp(r'</head>', caseSensitive: false).hasMatch(trimmed)) {
        return trimmed.replaceFirst(
          RegExp(r'</head>', caseSensitive: false),
          '$head</head>',
        );
      }
      return trimmed.replaceFirstMapped(
        RegExp(r'<html[^>]*>', caseSensitive: false),
        (match) => '${match.group(0)}<head>$head</head>',
      );
    }
    return '''<!doctype html>
<html><head>$head</head><body><main style="width:${width}px">$trimmed</main></body></html>''';
  }
}
