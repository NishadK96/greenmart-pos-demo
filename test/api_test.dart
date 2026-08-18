import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:retailflow_pos/apis/api.dart';
import 'package:retailflow_pos/shared/models/entities.dart';
import 'package:retailflow_pos/features/purchases/domain/purchase_entities.dart';
import 'package:retailflow_pos/features/zatca/domain/zatca_entities.dart';

void main() {
  test('login sends credentials to the backend-managed endpoint', () async {
    final api = Api(
      loginUrl: 'https://example.test/connector/api/login',
      client: MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.headers['Accept'], 'application/json');
        expect(request.headers['Content-Type'], startsWith('application/json'));
        expect(request.body, '{"username":"cashier","password":"password"}');
        expect(request.body, isNot(contains('client_secret')));
        expect(request.url.path, '/connector/api/login');
        return http.Response('{"access_token":"token-123"}', 200);
      }),
    );

    final result = await api.login('cashier', 'password');

    expect(result.isSuccess, isTrue);
    expect(result.accessToken, 'token-123');
  });

  test('invalid_grant becomes an invalid credentials result', () async {
    final api = Api(
      loginUrl: 'https://example.test/connector/api/login',
      client: MockClient(
        (_) async => http.Response(
          '{"error":"invalid_grant","error_description":"Bad login"}',
          400,
        ),
      ),
    );

    final result = await api.login('wrong', 'wrong');

    expect(result.isSuccess, isFalse);
    expect(result.failure, LoginFailure.invalidCredentials);
  });

  test('business customer sends ZATCA identity and address fields', () async {
    final api = Api(
      client: MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/connector/api/contactapi');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['type'], 'customer');
        expect(body['first_name'], 'Ahmed Ali');
        expect(body['supplier_business_name'], 'Acme Trading');
        expect(body['tax_number'], '300000000000003');
        expect(body['commercial_registration_number'], 'CR-1024');
        expect(body['address_line_1'], 'King Fahd Road');
        expect(body['city'], 'Riyadh');
        expect(body['country'], 'Saudi Arabia');
        expect(body['contact_id'], 'CUST-42');
        expect(body['prefix'], 'Mr');
        expect(body['middle_name'], 'Hassan');
        expect(body['last_name'], 'Ali');
        expect(body['alternate_number'], '0110000000');
        expect(body['landline'], '0111111111');
        expect(body['dob'], '1990-01-02');
        expect(body['customer_group_id'], '7');
        expect(body['pay_term_number'], '30');
        expect(body['pay_term_type'], 'days');
        expect(body['shipping_address'], 'Warehouse 4, Riyadh');
        expect(body['position'], 'Purchasing manager');
        return http.Response(
          jsonEncode({
            'data': {
              'id': 42,
              'name': 'Ahmed Ali',
              'mobile': '0500000000',
              'supplier_business_name': 'Acme Trading',
              'tax_number': '300000000000003',
              'commercial_registration_number': 'CR-1024',
              'address_line_1': 'King Fahd Road',
              'city': 'Riyadh',
              'country': 'Saudi Arabia',
              'contact_id': 'CUST-42',
              'prefix': 'Mr',
              'middle_name': 'Hassan',
              'last_name': 'Ali',
              'alternate_number': '0110000000',
              'landline': '0111111111',
              'dob': '1990-01-02',
              'customer_group_id': 7,
              'pay_term_number': 30,
              'pay_term_type': 'days',
              'shipping_address': 'Warehouse 4, Riyadh',
              'position': 'Purchasing manager',
            },
          }),
          201,
        );
      }),
    );

    final customer = await api.createCustomer(
      accessToken: 'token-123',
      name: 'Ahmed Ali',
      mobile: '0500000000',
      businessName: 'Acme Trading',
      taxNumber: '300000000000003',
      commercialRegistrationNumber: 'CR-1024',
      addressLine1: 'King Fahd Road',
      city: 'Riyadh',
      country: 'Saudi Arabia',
      contactId: 'CUST-42',
      prefix: 'Mr',
      middleName: 'Hassan',
      lastName: 'Ali',
      alternateNumber: '0110000000',
      landline: '0111111111',
      dateOfBirth: '1990-01-02',
      customerGroupId: '7',
      payTermNumber: '30',
      payTermType: 'days',
      shippingAddress: 'Warehouse 4, Riyadh',
      position: 'Purchasing manager',
    );

    expect(customer.isBusiness, isTrue);
    expect(customer.businessName, 'Acme Trading');
    expect(customer.address, 'King Fahd Road, Riyadh, Saudi Arabia');
    expect(customer.contactId, 'CUST-42');
    expect(customer.middleName, 'Hassan');
    expect(customer.shippingAddress, 'Warehouse 4, Riyadh');
  });

  test('sale return sends selected backend sell-line quantities', () async {
    final product = Product(
      id: '3',
      name: 'Rice',
      sku: 'RICE-1',
      barcode: '123',
      categoryId: '1',
      purchasePrice: 4000,
      sellingPrice: 5000,
      stock: 8,
      minimumStock: 2,
      variationId: '4',
      taxPercent: 0,
    );
    final sale = Sale(
      localId: 'server-41',
      serverId: '41',
      invoiceNo: 'INV-41',
      createdAt: DateTime(2026, 8, 16),
      updatedAt: DateTime(2026, 8, 16),
      customer: const Customer(id: '7', name: 'Walk-in Customer'),
      items: [
        CartLine(
          product: product,
          quantity: 3,
          sellLineId: '91',
          quantityReturned: 1,
        ),
      ],
      paymentMethod: 'cash',
      total: 15000,
      tax: 0,
      discount: 0,
      syncStatus: SyncStatus.synced,
    );
    final api = Api(
      client: MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/connector/api/sell-return');
        expect(request.headers['Authorization'], 'Bearer token-123');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['transaction_id'], 41);
        final products = body['products'] as List<dynamic>;
        expect(products.single['sell_line_id'], 91);
        expect(products.single['quantity'], 2);
        expect(products.single['unit_price_inc_tax'], 50.0);
        return http.Response(
          '{"id":88,"invoice_no":"CN-0088","return_parent_id":41}',
          201,
        );
      }),
    );

    final result = await api.createSaleReturn(
      accessToken: 'token-123',
      sale: sale,
      quantities: const {'91': 2},
    );

    expect(result['invoice_no'], 'CN-0088');
  });

  test('purchase orders map Laravel document and line resources', () async {
    final api = Api(
      client: MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/connector/api/purchase-orders');
        return http.Response('''
          {"data":[{
            "id":41,"ref_no":"PO-0041","contact_id":7,
            "contact":{"id":7,"name":"Fresh Foods Ltd"},
            "location_id":2,"location":{"id":2,"name":"Main Store"},
            "transaction_date":"2026-08-12T10:00:00+05:30",
            "status":"ordered","final_total":"250.00",
            "purchase_order_lines":[{
              "id":9,"product_id":3,"variation_id":4,"quantity":"5.00",
              "quantity_returned":"0.00",
              "purchase_price_inc_tax":"50.00",
              "product":{"id":3,"name":"Rice"},
              "variation":{"id":4,"sub_sku":"RICE-5KG"}
            }]
          }]}
        ''', 200);
      }),
    );

    final result = await api.purchaseDocuments(
      'token-123',
      PurchaseDocumentType.order,
    );

    expect(result.single.reference, 'PO-0041');
    expect(result.single.supplierName, 'Fresh Foods Ltd');
    expect(result.single.total, 25000);
    expect(result.single.lines.single.quantity, 5);
    expect(result.single.lines.single.unitCost, 5000);
  });

  test('purchase creation sends the modern Connector JSON contract', () async {
    final api = Api(
      client: MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/connector/api/purchases');
        expect(request.headers['Authorization'], 'Bearer token-123');
        expect(request.body, contains('"contact_id":"7"'));
        expect(request.body, contains('"lines":'));
        expect(request.body, contains('"purchase_price":50.0'));
        return http.Response(
          '{"data":{"id":55,"ref_no":"PUR-55","status":"received","final_total":"100.00"}}',
          201,
        );
      }),
    );

    final saved = await api.savePurchaseDocument(
      accessToken: 'token-123',
      draft: PurchaseDraft(
        type: PurchaseDocumentType.invoice,
        supplierId: '7',
        locationId: '2',
        date: DateTime(2026, 8, 12),
        status: 'received',
        lines: const [
          PurchaseLineRecord(
            productId: '3',
            variationId: '4',
            name: 'Rice',
            quantity: 2,
            unitCost: 5000,
          ),
        ],
      ),
    );

    expect(saved.id, '55');
    expect(saved.total, 10000);
  });

  test('purchase invoice sends totals, expenses, shipping and payment', () async {
    final api = Api(
      client: MockClient((request) async {
        expect(request.method, 'POST');
        final body = request.body;
        expect(body, contains('"discount_type":"percentage"'));
        expect(body, contains('"discount_amount":5.0'));
        expect(body, contains('"shipping_charges":10.0'));
        expect(body, contains('"additional_expense_key_1":"Handling"'));
        expect(body, contains('"additional_expense_value_1":2.5'));
        expect(body, contains('"method":"cash"'));
        expect(body, contains('"account_id":"3"'));
        return http.Response(
          '{"data":{"id":56,"ref_no":"PUR-56","status":"received","final_total":"107.50"}}',
          201,
        );
      }),
    );

    await api.savePurchaseDocument(
      accessToken: 'token',
      draft: PurchaseDraft(
        type: PurchaseDocumentType.invoice,
        supplierId: '7',
        locationId: '2',
        date: DateTime(2026, 8, 12),
        status: 'received',
        discountType: 'percentage',
        discountAmount: 5,
        shippingCharges: 10,
        expenses: const [PurchaseExpense(name: 'Handling', amount: 2.5)],
        payments: [
          PurchasePaymentDraft(
            amount: 50,
            method: 'cash',
            paidOn: DateTime(2026, 8, 12),
            accountId: '3',
          ),
        ],
        lines: const [
          PurchaseLineRecord(
            productId: '3',
            variationId: '4',
            name: 'Rice',
            quantity: 2,
            unitCost: 5000,
          ),
        ],
      ),
    );
  });

  test('supplier creation uses the supplier contact contract', () async {
    final api = Api(
      client: MockClient((request) async {
        expect(request.url.path, '/connector/api/contactapi');
        expect(request.body, contains('"type":"supplier"'));
        expect(request.body, contains('"supplier_business_name":"Acme"'));
        return http.Response(
          '{"data":{"id":99,"supplier_business_name":"Acme"}}',
          201,
        );
      }),
    );
    final supplier = await api.createSupplier(
      accessToken: 'token',
      businessName: 'Acme',
      contactName: 'Asha',
      mobile: '9999999999',
    );
    expect(supplier.id, '99');
    expect(supplier.name, 'Acme');
  });

  test('products maps EazyERP price, stock, category, and image', () async {
    final api = Api(
      client: MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.headers['Authorization'], 'Bearer token-123');
        expect(request.url.queryParameters['per_page'], '-1');
        return http.Response('''
          {"data":[{
            "id":1,"name":"Whole Wheat Flour","sku":"SKU-1001",
            "category":{"id":7,"name":"Grocery"},
            "unit":{"short_name":"pc"},
            "image_url":"http://localhost:8080/uploads/img/flour.jpg",
            "alert_quantity":"6.0000","is_inactive":0,
            "product_variations":[{"variations":[{
              "dpp_inc_tax":"36.7500","sell_price_inc_tax":"51.2500",
              "variation_location_details":[{"qty_available":"19.0000"}]
            }]}]
          }]}
        ''', 200);
      }),
    );

    final products = await api.products('token-123');

    expect(products, hasLength(1));
    expect(products.single.name, 'Whole Wheat Flour');
    expect(products.single.sellingPrice, 5125);
    expect(products.single.stock, 19);
    expect(products.single.categoryId, '7');
    expect(products.single.imageUrl, endsWith('/flour.jpg'));
  });

  test('categories loads product taxonomies from the backend', () async {
    final api = Api(
      client: MockClient((request) async {
        expect(request.headers['Authorization'], 'Bearer token-123');
        expect(request.url.queryParameters['type'], 'product');
        return http.Response(
          '{"data":[{"id":7,"name":"Grocery","category_type":"product"}]}',
          200,
        );
      }),
    );

    final categories = await api.categories('token-123');

    expect(categories, hasLength(1));
    expect(categories.single.id, '7');
    expect(categories.single.name, 'Grocery');
  });

  test('category creation sends bilingual taxonomy data', () async {
    final api = Api(
      client: MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/connector/api/taxonomy');
        expect(request.headers['Authorization'], 'Bearer token-123');
        final body = jsonDecode(request.body);
        expect(body['name_en'], 'Bakery');
        expect(body['name_ar'], 'مخبز');
        expect(body['parent_id'], '7');
        return http.Response('{"data":{"id":8}}', 201);
      }),
    );

    await api.createCategory(
      accessToken: 'token-123',
      name: 'Bakery',
      nameAr: 'مخبز',
      parentId: '7',
    );
  });

  test(
    'SKU availability sends the edit exclusion and maps availability',
    () async {
      final api = Api(
        client: MockClient((request) async {
          expect(request.url.path, '/connector/api/products/check-sku');
          final body = jsonDecode(request.body);
          expect(body['sku'], 'SKU-1000');
          expect(body['exclude_product_id'], '10');
          return http.Response('{"available":true}', 200);
        }),
      );

      final available = await api.checkSku(
        accessToken: 'token-123',
        sku: 'SKU-1000',
        excludeProductId: '10',
      );

      expect(available, isTrue);
    },
  );

  test('stock report follows backend pagination', () async {
    var requests = 0;
    final api = Api(
      client: MockClient((request) async {
        requests++;
        final page = request.url.queryParameters['page'];
        return http.Response(
          '{"data":[{"product_id":$page,"variation_id":$page,"product":"Item $page","sku":"SKU-$page","unit":"pc","stock":"2","alert_quantity":"1","unit_price":"5","location_name":"Main"}],"meta":{"last_page":2}}',
          200,
        );
      }),
    );

    final stock = await api.stockReport('token-123');

    expect(requests, 2);
    expect(stock.map((item) => item.name), ['Item 1', 'Item 2']);
  });

  test('create sale unwraps HTTP 200 item-level backend errors', () async {
    final api = Api(
      client: MockClient(
        (_) async => http.Response(
          '[{"headers":{},"original":{"error":{"message":"Stock allocation failed"}},"exception":null}]',
          200,
        ),
      ),
    );
    const product = Product(
      id: '1',
      variationId: '2',
      name: 'Rice',
      sku: 'SKU-1',
      barcode: 'SKU-1',
      categoryId: '3',
      purchasePrice: 4000,
      sellingPrice: 4900,
      stock: 2,
      minimumStock: 1,
    );

    expect(
      () => api.createSale(
        accessToken: 'token-123',
        locationId: '1',
        customer: const Customer(id: '1', name: 'Walk-in'),
        lines: const [CartLine(product: product)],
        paymentMethod: 'cash',
        total: 4900,
      ),
      throwsA(
        isA<ApiException>().having(
          (error) => error.message,
          'message',
          'Stock allocation failed',
        ),
      ),
    );
  });

  test('standard and quick product creation use their API contracts', () async {
    final seen = <Uri>[];
    final api = Api(
      client: MockClient((request) async {
        seen.add(request.url);
        expect(request.method, 'POST');
        expect(request.headers['Authorization'], 'Bearer token-123');
        expect(request.body, contains('name="name"'));
        expect(request.body, contains('Test Product'));
        return http.Response(
          _productResponse,
          201,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    const draft = ProductDraft(
      name: 'Test Product',
      unitId: '1',
      purchasePrice: 1000,
      sellingPrice: 1250,
      locationIds: ['2'],
      openingStock: 4,
    );

    await api.createProduct(accessToken: 'token-123', draft: draft);
    await api.createProduct(
      accessToken: 'token-123',
      draft: draft,
      quick: true,
    );

    expect(seen[0].path, '/connector/api/products');
    expect(seen[1].path, '/connector/api/products/save_quick_product');
  });

  test(
    'blank product SKU is generated before the stateless API call',
    () async {
      final api = Api(
        client: MockClient((request) async {
          expect(request.body, contains('name="sku"'));
          expect(request.body, contains('GM-'));
          return http.Response(_productResponse, 201);
        }),
      );

      await api.createProduct(
        accessToken: 'token-123',
        draft: const ProductDraft(
          name: 'Auto SKU Product',
          unitId: '1',
          purchasePrice: 1000,
          sellingPrice: 1250,
        ),
      );
    },
  );

  test('product edit sends a multipart PATCH override', () async {
    final api = Api(
      client: MockClient((request) async {
        expect(request.url.path, '/connector/api/products/8');
        expect(request.body, contains('name="_method"'));
        expect(request.body, contains('PATCH'));
        return http.Response(_productResponse, 200);
      }),
    );

    await api.updateProduct(
      accessToken: 'token-123',
      product: _product,
      draft: const ProductDraft(
        name: 'Test Product',
        unitId: '1',
        purchasePrice: 1000,
        sellingPrice: 1250,
      ),
    );
  });

  test('bulk update sends selected product and variation IDs', () async {
    final api = Api(
      client: MockClient((request) async {
        expect(request.url.path, '/connector/api/products/bulk-update');
        expect(request.body, contains('"id":8'));
        expect(request.body, contains('"11"'));
        expect(request.body, contains('"category_id":3'));
        return http.Response('{"data":[$_productJson]}', 200);
      }),
    );

    final products = await api.bulkUpdateProducts(
      accessToken: 'token-123',
      products: const [_product],
      categoryId: '3',
      sellingPrice: 1500,
    );
    expect(products, hasLength(1));
  });

  test('product import uploads products_file and maps imported rows', () async {
    final api = Api(
      client: MockClient((request) async {
        expect(request.url.path, '/connector/api/import-products/store');
        expect(request.body, contains('name="products_file"'));
        expect(request.body, contains('filename="products.csv"'));
        return http.Response(
          '{"data":[$_productJson],"meta":{"imported":1}}',
          201,
        );
      }),
    );

    final products = await api.importProducts(
      accessToken: 'token-123',
      bytes: 'product_name\nTest'.codeUnits,
      fileName: 'products.csv',
    );
    expect(products.single.id, '8');
  });

  test('sale return history maps parent invoice and refund metadata', () async {
    final api = Api(
      client: MockClient((request) async {
        expect(request.url.path, '/connector/api/list-sell-return');
        expect(request.url.queryParameters['per_page'], '-1');
        expect(request.headers['Authorization'], 'Bearer token-123');
        return http.Response(
          '''{"data":[{"id":71,"invoice_no":"SR-0071","return_parent_id":41,"transaction_date":"2026-08-16 14:30:00","final_total":"-75.50","payment_status":"paid","contact":{"name":"Riyadh Retail"},"payment_lines":[{"method":"cash"}],"return_parent_sell":{"id":41,"invoice_no":"INV-0041"}}]}''',
          200,
        );
      }),
    );

    final returns = await api.saleReturns('token-123');

    expect(returns, hasLength(1));
    expect(returns.single.invoiceNo, 'SR-0071');
    expect(returns.single.parentInvoiceNo, 'INV-0041');
    expect(returns.single.customerName, 'Riyadh Retail');
    expect(returns.single.total, 7550);
    expect(returns.single.paymentMethod, 'cash');
  });

  test('ZATCA status maps safe integration and location metadata', () async {
    final api = Api(
      client: MockClient((request) async {
        expect(request.url.path, '/connector/api/zatca/status');
        expect(request.headers['Authorization'], 'Bearer token-123');
        return http.Response(
          '{"data":{"installed":true,"subscription_enabled":true,"sync_frequency":"instant","locations":[{"id":2,"name":"Main Store","configured":true,"portal_mode":"simulation"}],"totals":{"pending":2,"success":18,"failed":1}}}',
          200,
        );
      }),
    );

    final status = await api.zatcaStatus('token-123');

    expect(status.installed, isTrue);
    expect(status.locations.single.portalMode, 'simulation');
    expect(status.totals.success, 18);
  });

  test(
    'ZATCA onboarding sends exact device contract without client secrets',
    () async {
      final api = Api(
        client: MockClient((request) async {
          expect(request.url.path, '/connector/api/zatca/onboarding/2');
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['otp'], '123456');
          expect(body['country_code'], 'SA');
          expect(body['invoice_type'], '1100');
          expect(body, isNot(contains('client_secret')));
          return http.Response(
            '{"success":true,"data":{"location_id":2,"name":"Main Store","configured":true,"portal_mode":"simulation"}}',
            200,
          );
        }),
      );

      final location = await api.onboardZatca(
        accessToken: 'token-123',
        locationId: '2',
        draft: const ZatcaOnboardingDraft(
          portalMode: 'simulation',
          otp: '123456',
          email: 'zatca@example.test',
          commonName: 'Main Store Device',
          organizationUnitName: 'Main Store',
          organizationName: 'GreenMart LLC',
          vatNumber: '300000000000003',
          invoiceType: '1100',
          registeredAddress: 'RRRD2929',
          businessCategory: 'Retail',
        ),
      );

      expect(location.configured, isTrue);
    },
  );

  test('ZATCA rejected invoice is returned as a retry result', () async {
    final api = Api(
      client: MockClient(
        (request) async => http.Response(
          '{"success":false,"message":"ZATCA rejected the invoice.","data":{"sale_id":55,"zatca_status":"failed"}}',
          409,
        ),
      ),
    );

    final result = await api.syncZatcaInvoice('token-123', '55');

    expect(result.success, isFalse);
    expect(result.status, 'failed');
    expect(result.message, contains('rejected'));
  });

  test('ZATCA sales return submits to the credit-note sync endpoint', () async {
    final api = Api(
      client: MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/connector/api/zatca/returns/71/sync');
        expect(request.headers['Authorization'], 'Bearer token-123');
        return http.Response(
          '{"success":true,"message":"Credit note submitted.","data":{"zatca_status":"success"}}',
          200,
        );
      }),
    );

    final result = await api.syncZatcaReturn('token-123', '71');

    expect(result.success, isTrue);
    expect(result.status, 'success');
    expect(result.message, contains('Credit note'));
  });

  test('ZATCA invoice queue maps filters and backend pagination', () async {
    final api = Api(
      client: MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/connector/api/zatca/invoices');
        expect(request.url.queryParameters['status'], 'pending');
        expect(request.url.queryParameters['search'], 'INV-77');
        expect(request.url.queryParameters['page'], '2');
        return http.Response(
          '''{"data":[{"id":77,"invoice_no":"INV-77","zatca_status":"pending","transaction_date":"2026-08-18 09:30:00","final_total":"150.50","location_name":"Main Store","customer":{"name":"Retail Customer","mobile":"500000000"}}],"meta":{"current_page":2,"last_page":3,"per_page":20,"total":41}}''',
          200,
        );
      }),
    );

    final result = await api.zatcaInvoices(
      'token-123',
      const ZatcaListFilter(status: 'pending', search: 'INV-77', page: 2),
    );

    expect(result.items.single.invoiceNo, 'INV-77');
    expect(result.items.single.customerName, 'Retail Customer');
    expect(result.items.single.total, 150.5);
    expect(result.currentPage, 2);
    expect(result.total, 41);
  });

  test(
    'ZATCA return bulk sync sends the documented invoice_ids payload',
    () async {
      final api = Api(
        client: MockClient((request) async {
          expect(request.method, 'POST');
          expect(request.url.path, '/connector/api/zatca/returns/syncBulk');
          expect(jsonDecode(request.body), {
            'invoice_ids': [71, 72],
          });
          return http.Response(
            '''{"success":true,"summary":{"requested":2,"successful":1,"failed":1},"data":[{"id":71,"success":true,"zatca_status":"success","message":"Submitted"},{"id":72,"success":false,"zatca_status":"failed","message":"Rejected"}]}''',
            200,
          );
        }),
      );

      final result = await api.syncZatcaReturnsBulk('token-123', ['71', '72']);

      expect(result.requested, 2);
      expect(result.successful, 1);
      expect(result.failed, 1);
      expect(result.results.last.success, isFalse);
    },
  );

  test('ZATCA settings update and sync summary map the backend contract', () async {
    var calls = 0;
    final api = Api(
      client: MockClient((request) async {
        calls++;
        if (request.method == 'PATCH') {
          expect(request.url.path, '/connector/api/zatca/settings');
          expect(jsonDecode(request.body)['sync_frequency'], 'instant');
          return http.Response(
            '''{"data":{"sync_frequency":"instant","disable_discount":true,"disable_order_tax":false,"default_sales_discount":"0","locations":[{"location_id":2,"location_name":"Main Store","sync_from_datetime":"2026-08-18 00:00:00"}]}}''',
            200,
          );
        }
        expect(request.url.path, '/connector/api/zatca/sync-summary');
        return http.Response(
          '''{"data":{"total_invoices":10,"pending_not_synced":2,"successful":7,"failed":1,"developer_synced":3,"simulation_synced":4}}''',
          200,
        );
      }),
    );

    final settings = await api.updateZatcaSettings('token-123', {
      'sync_frequency': 'instant',
    });
    final summary = await api.zatcaSyncSummary('token-123');

    expect(settings.syncFrequency, 'instant');
    expect(settings.locations.single.name, 'Main Store');
    expect(summary.pending, 2);
    expect(summary.simulationSynced, 4);
    expect(calls, 2);
  });
}

const _product = Product(
  id: '8',
  variationId: '11',
  name: 'Test Product',
  sku: 'TEST-8',
  barcode: 'TEST-8',
  categoryId: '3',
  purchasePrice: 1000,
  sellingPrice: 1250,
  stock: 4,
  minimumStock: 1,
  unitId: '1',
);

const _productJson =
    '''{"id":8,"name":"Test Product","sku":"TEST-8","unit":{"id":1,"short_name":"pc"},"category":{"id":3},"product_variations":[{"variations":[{"id":11,"dpp_inc_tax":"10","sell_price_inc_tax":"12.5","variation_location_details":[]}]}]}''';
const _productResponse = '{"data":$_productJson}';
