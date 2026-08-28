import 'dart:convert';
import '../../../shared/models/entities.dart';

String provisionalReceiptQrData(Sale sale, String businessName) => jsonEncode({
  'type': 'retailflow_offline_provisional_receipt',
  'reference': sale.invoiceNo,
  'seller': businessName,
  'issued_at': sale.createdAt.toUtc().toIso8601String(),
  'total': (sale.total / 100).toStringAsFixed(2),
  'tax': (sale.tax / 100).toStringAsFixed(2),
  'currency': 'SAR',
  'status': 'provisional_pending_sync',
});
