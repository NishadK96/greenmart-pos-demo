import 'package:intl/intl.dart';

import '../domain/kitchen_entities.dart';

/// Local 80 mm kitchen-ticket sample used to verify Arabic shaping, alignment
/// and printer margins without contacting the ERP.
abstract final class OfflineKitchenTemplate {
  static String sampleHtml({String businessName = 'مطبخ جرين مارت'}) {
    final now = DateTime.now();
    final date = DateFormat('yyyy/MM/dd').format(now);
    final time = DateFormat('HH:mm:ss').format(now);
    return '''<!doctype html>
<html lang="ar" dir="rtl">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <style>
    @page { size: 80mm auto; margin: 0; }
    * { box-sizing: border-box; color: #000 !important; }
    html, body { width: 80mm; margin: 0; padding: 0; }
    .ticket {
      width: 80mm; max-width: 80mm; margin: 0; padding: 2mm 3mm;
      font-family: Tahoma, Arial, sans-serif; font-size: 12px;
      line-height: 1.3; direction: rtl; unicode-bidi: plaintext;
    }
    .center { text-align: center; }
    .strong { font-weight: 800; }
    .num, .en { direction: ltr; unicode-bidi: plaintext; }
    .business { font-size: 16px; font-weight: 900; margin-bottom: 3px; }
    .title { font-size: 19px; font-weight: 900; margin: 2px 0; }
    .section { padding-top: 6px; margin-top: 6px; border-top: 1px dashed #777; }
    .kv { display: flex; justify-content: space-between; gap: 8px; padding: 2px 0; }
    .kv .k { font-weight: 700; }
    .kv .v { font-weight: 800; text-align: left; }
    .items { width: 100%; border-collapse: collapse; table-layout: fixed; }
    .items th { padding: 4px 2px; border-bottom: 1px solid #777; font-weight: 900; }
    .items td { padding: 6px 2px; vertical-align: top; border-bottom: 1px dotted #aaa; }
    .qty { width: 16%; text-align: center; }
    .item { width: 84%; text-align: right; overflow-wrap: anywhere; }
    .modifier { margin-top: 2px; font-size: 11px; font-weight: 700; }
    .note { margin-top: 3px; padding: 3px; border: 1px solid #000; font-weight: 800; }
    .footer { margin-top: 8px; padding-top: 6px; border-top: 1px dashed #777; font-size: 10px; }
    @media print {
      html, body { width: 80mm; margin: 0; padding: 0; }
      tr, .section { page-break-inside: avoid; break-inside: avoid; }
    }
  </style>
</head>
<body>
  <main class="ticket">
    <header class="center">
      <div class="business">${_escape(businessName)}</div>
      <div class="title">طلب المطبخ</div>
      <div class="strong en">KITCHEN ORDER</div>
      <div class="title num">#OFFLINE-001</div>
    </header>
    <section class="section">
      <div class="kv"><span class="k">التاريخ <span class="en">Date</span></span><span class="v num">$date</span></div>
      <div class="kv"><span class="k">الوقت <span class="en">Time</span></span><span class="v num">$time</span></div>
      <div class="kv"><span class="k">نوع الطلب <span class="en">Type</span></span><span class="v">سفري / Takeaway</span></div>
      <div class="kv"><span class="k">العميل <span class="en">Customer</span></span><span class="v">عميل نقدي</span></div>
    </section>
    <section class="section">
      <table class="items">
        <thead><tr><th class="item">الصنف / Item</th><th class="qty">الكمية<br><span class="en">Qty</span></th></tr></thead>
        <tbody>
          <tr>
            <td class="item"><div class="strong">برجر دجاج / Chicken Burger</div><div class="modifier">+ حجم كبير / Large</div><div class="modifier">+ جبنة / Cheese</div><div class="note">ملاحظة: بدون بصل / No onions</div></td>
            <td class="qty num strong">2</td>
          </tr>
          <tr>
            <td class="item"><div class="strong">بطاطس مقلية / French Fries</div><div class="modifier">+ حار / Spicy</div></td>
            <td class="qty num strong">1</td>
          </tr>
        </tbody>
      </table>
    </section>
    <footer class="footer center">OFFLINE PRINTER TEST · اختبار الطباعة دون اتصال</footer>
  </main>
</body>
</html>''';
  }

  static KitchenPrintJob sampleJob({String businessName = 'مطبخ جرين مارت'}) {
    final now = DateTime.now();
    return KitchenPrintJob(
      id: 'offline-demo',
      status: 'preview',
      transactionId: 'OFFLINE-001',
      locationId: 'offline',
      template: 'offline_demo',
      printer: const KitchenErpPrinter(
        id: 'offline',
        name: 'Offline printer test',
      ),
      items: const [
        KitchenJobItem(
          productName: 'برجر دجاج / Chicken Burger',
          quantity: 2,
          variation: 'حجم كبير / Large',
          note: 'بدون بصل / No onions',
          modifiers: [
            KitchenJobItem(productName: 'جبنة / Cheese', quantity: 1),
          ],
        ),
        KitchenJobItem(
          productName: 'بطاطس مقلية / French Fries',
          quantity: 1,
          variation: 'حار / Spicy',
        ),
      ],
      attempts: 0,
      htmlContent:
          '<div class="kitchen-order__business">${_escape(businessName)}</div>'
          '<div class="kitchen-order__number">#OFFLINE-001</div>'
          '<div class="kitchen-order__meta">'
          'اختبار دون اتصال · Offline test<br>'
          '${DateFormat('yyyy/MM/dd HH:mm:ss').format(now)}<br>'
          'سفري · Takeaway'
          '</div>',
      createdAt: now,
    );
  }

  static String _escape(String value) => value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');
}
