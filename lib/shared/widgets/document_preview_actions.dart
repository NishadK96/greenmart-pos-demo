import 'dart:typed_data';

import 'package:flutter/material.dart' hide Text;
import 'package:printing/printing.dart';

import '../../core/theme/app_theme.dart';
import 'localized_text.dart';

Future<void> showDocumentPreviewPrintAction(
  BuildContext context, {
  required String title,
  required Uint8List bytes,
  required Future<void> Function() onPrint,
}) => showDialog<void>(
  context: context,
  barrierDismissible: false,
  builder: (_) =>
      _DocumentPreviewPrintDialog(title: title, bytes: bytes, onPrint: onPrint),
);

class _DocumentPreviewPrintDialog extends StatefulWidget {
  const _DocumentPreviewPrintDialog({
    required this.title,
    required this.bytes,
    required this.onPrint,
  });

  final String title;
  final Uint8List bytes;
  final Future<void> Function() onPrint;

  @override
  State<_DocumentPreviewPrintDialog> createState() =>
      _DocumentPreviewPrintDialogState();
}

class _DocumentPreviewPrintDialogState
    extends State<_DocumentPreviewPrintDialog> {
  late final Future<List<Uint8List>> pages = _renderPages();
  bool printing = false;
  String? printError;

  Future<List<Uint8List>> _renderPages() async {
    final rendered = <Uint8List>[];
    await for (final page in Printing.raster(widget.bytes, dpi: 110)) {
      rendered.add(await page.toPng());
    }
    if (rendered.isEmpty) {
      throw StateError('The PDF does not contain any pages.');
    }
    return rendered;
  }

  Future<void> _print() async {
    if (printing) return;
    setState(() {
      printing = true;
      printError = null;
    });
    try {
      await widget.onPrint();
    } catch (exception) {
      if (mounted) setState(() => printError = exception.toString());
    } finally {
      if (mounted) setState(() => printing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return Dialog(
      insetPadding: const EdgeInsets.all(20),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: size.width.clamp(320, 1050),
        height: size.height.clamp(480, 900),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 12, 14),
              child: Row(
                children: [
                  const Icon(Icons.preview_outlined, color: AppColors.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    tooltip: context.tr('Close'),
                    onPressed: printing ? null : () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ColoredBox(
                color: const Color(0xff555a5d),
                child: FutureBuilder<List<Uint8List>>(
                  future: pages,
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            '${context.tr('Unable to load preview')}: ${snapshot.error}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                      );
                    }
                    final images = snapshot.data;
                    if (images == null) {
                      return const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      );
                    }
                    return ListView.separated(
                      padding: const EdgeInsets.all(20),
                      itemCount: images.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 16),
                      itemBuilder: (_, index) => Center(
                        child: Image.memory(
                          images[index],
                          gaplessPlayback: true,
                          filterQuality: FilterQuality.medium,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            if (printError != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: Text(
                  '${context.tr('Print failed')}: $printError',
                  style: const TextStyle(color: AppColors.danger),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: printing ? null : () => Navigator.pop(context),
                    child: Text(context.tr('Close')),
                  ),
                  const SizedBox(width: 10),
                  FilledButton.icon(
                    onPressed: printing ? null : _print,
                    icon: printing
                        ? const SizedBox.square(
                            dimension: 17,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.print_outlined),
                    label: Text(context.tr(printing ? 'Printing…' : 'Print')),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
