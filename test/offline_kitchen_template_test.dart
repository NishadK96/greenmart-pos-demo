import 'package:eazy_pos/features/kitchen/application/offline_kitchen_template.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('offline kitchen sample is an 80 mm bilingual printable document', () {
    final html = OfflineKitchenTemplate.sampleHtml(
      businessName: 'مطبخ الاختبار & Test',
    );

    expect(html, contains('size: 80mm auto'));
    expect(html, contains('dir="rtl"'));
    expect(html, contains('KITCHEN ORDER'));
    expect(html, contains('طلب المطبخ'));
    expect(html, contains('مطبخ الاختبار &amp; Test'));
    expect(html, contains('OFFLINE PRINTER TEST'));

    final job = OfflineKitchenTemplate.sampleJob(businessName: 'مطبخ الاختبار');
    expect(job.transactionId, 'OFFLINE-001');
    expect(job.items, hasLength(2));
    expect(job.htmlContent, contains('مطبخ الاختبار'));
  });
}
