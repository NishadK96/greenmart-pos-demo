import 'package:flutter/material.dart' hide Text;

import '../../core/theme/app_theme.dart';
import 'localized_text.dart';

Future<void> showDocumentPreviewPrintAction(
  BuildContext context, {
  required String title,
  required Future<void> Function() onPrint,
}) => showDialog<void>(
  context: context,
  builder: (_) => _DocumentPreviewPrintDialog(title: title, onPrint: onPrint),
);

class _DocumentPreviewPrintDialog extends StatefulWidget {
  const _DocumentPreviewPrintDialog({
    required this.title,
    required this.onPrint,
  });

  final String title;
  final Future<void> Function() onPrint;

  @override
  State<_DocumentPreviewPrintDialog> createState() =>
      _DocumentPreviewPrintDialogState();
}

class _DocumentPreviewPrintDialogState
    extends State<_DocumentPreviewPrintDialog> {
  bool printing = false;
  String? error;

  Future<void> _print() async {
    if (printing) return;
    setState(() {
      printing = true;
      error = null;
    });
    try {
      await widget.onPrint();
    } catch (exception) {
      if (mounted) setState(() => error = exception.toString());
    } finally {
      if (mounted) setState(() => printing = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Row(
      children: [
        const Icon(Icons.preview_outlined, color: AppColors.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            widget.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    ),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.tr(
            'Review the document in the preview window. When it is correct, use Print below to send it to your selected printer.',
          ),
        ),
        if (error != null) ...[
          const SizedBox(height: 12),
          Text(
            '${context.tr('Print failed')}: $error',
            style: const TextStyle(color: AppColors.danger),
          ),
        ],
      ],
    ),
    actions: [
      TextButton(
        onPressed: printing ? null : () => Navigator.pop(context),
        child: Text(context.tr('Close')),
      ),
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
  );
}
