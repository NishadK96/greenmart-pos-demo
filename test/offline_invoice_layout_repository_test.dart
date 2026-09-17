import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:eazy_pos/features/invoice_layouts/data/offline_invoice_layout_repository.dart';
import 'package:eazy_pos/features/invoice_layouts/domain/invoice_layout_entities.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('stores every offline layout and loads the assigned one', () async {
    final repository = OfflineInvoiceLayoutRepository();
    final first = _bundle('4', 'sha256:first', [1, 2]);
    final second = _bundle('9', 'sha256:second', [3, 4]);

    await repository.save(first, layoutId: '4');
    await repository.save(second, layoutId: '9', selected: false);

    expect((await repository.load('3', 'pos'))?.revision, 'sha256:first');
    expect((await repository.loadLayout('3', 'pos', '9'))?.assets['logo'], [
      3,
      4,
    ]);
  });

  test('cached catalog retains multiple layout templates', () async {
    final repository = OfflineInvoiceLayoutRepository();
    const catalog = ErpInvoiceLayoutCatalog(
      locationId: '3',
      documentType: 'pos',
      currentLayoutId: '9',
      layouts: [
        ErpInvoiceLayout(
          id: '4',
          name: 'Thermal',
          design: 'receipt',
          designName: '80mm receipt',
          isSelected: false,
          previewUrl: '/preview/4',
          offlineSupported: true,
          rendererProfile: 'thermal-80-v1',
        ),
        ErpInvoiceLayout(
          id: '9',
          name: 'A4 bilingual',
          design: 'a4',
          designName: 'A4 Arabic and English',
          isSelected: true,
          previewUrl: '/preview/9',
          offlineSupported: true,
          rendererProfile: 'a4-bilingual-v1',
        ),
      ],
    );

    await repository.saveCatalog(catalog);
    final restored = await repository.loadCatalog('3', 'pos');

    expect(restored?.layouts.map((layout) => layout.id), ['4', '9']);
    expect(restored?.selectedLayout?.name, 'A4 bilingual');
    expect(restored?.layouts.first.offlineSupported, isTrue);
  });
}

OfflineInvoiceLayoutBundle _bundle(
  String id,
  String revision,
  List<int> logo,
) => OfflineInvoiceLayoutBundle(
  manifest: {
    'layout': {
      'id': id,
      'location_id': 3,
      'document_type': 'pos',
      'revision': revision,
    },
  },
  assets: {'logo': Uint8List.fromList(logo)},
);
