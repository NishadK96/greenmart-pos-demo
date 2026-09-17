import 'dart:convert';
import 'package:eazy_pos/apis/api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('lists built-in designs independently of saved layouts', () async {
    final api = Api(
      client: MockClient((request) async {
        expect(request.url.path, '/connector/api/invoice-template-designs');
        return http.Response(
          jsonEncode({
            'data': {
              'templates': [
                {'design': 'classic', 'name': 'Classic'},
                {'design': 'elegant', 'design_name': 'Elegant'},
              ],
            },
          }),
          200,
        );
      }),
    );
    final designs = await api.invoiceTemplateDesigns('token');
    expect(designs.map((item) => item.key), ['classic', 'elegant']);
    expect(designs.last.name, 'Elegant');
  });

  for (final useDesign in [true, false]) {
    test(
      'assigns ${useDesign ? 'design key' : 'layout ID'} then refreshes catalog',
      () async {
        var patched = false;
        final api = Api(
          client: MockClient((request) async {
            if (request.method == 'PATCH') {
              patched = true;
              expect(jsonDecode(request.body), {
                'document_type': 'pos',
                if (useDesign) 'design': 'elegant' else 'invoice_layout_id': 8,
              });
              return http.Response('{"data":{}}', 200);
            }
            expect(patched, isTrue);
            expect(request.url.queryParameters['location_id'], '3');
            return http.Response(
              '{"data":{"current_layout_id":8,"layouts":[]}}',
              200,
            );
          }),
        );
        final result = await api.assignInvoiceLayout(
          accessToken: 'token',
          locationId: '3',
          layoutId: useDesign ? null : '8',
          design: useDesign ? 'elegant' : null,
        );
        expect(result.currentLayoutId, '8');
      },
    );
  }
}
