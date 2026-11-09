import 'package:eazy_pos/features/vouchers/domain/voucher_entities.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('contact draft omits unused nullable fields', () {
    const draft = VoucherDraft(
      type: VoucherType.receipt,
      submissionKey: 'uuid',
      locationId: 1,
      operationDate: '2026-10-31T14:30',
      partyMode: 'contact',
      contactId: 25,
      cashAccountId: 10,
      counterAccountId: 20,
      amount: '150.0000',
      paymentMethod: 'cash',
    );

    final json = draft.toJson();

    expect(json['amount'], '150.0000');
    expect(json['contact_id'], 25);
    expect(json, isNot(contains('payee_name')));
    expect(json, isNot(contains('revision')));
  });

  test('edit draft includes optimistic revision', () {
    const draft = VoucherDraft(
      type: VoucherType.payment,
      submissionKey: 'uuid',
      revision: 3,
      locationId: 2,
      operationDate: '2026-10-31T15:00',
      partyMode: 'ledger',
      payeeName: 'Office rent',
      cashAccountId: 11,
      counterAccountId: 40,
      amount: '900.5000',
      paymentMethod: 'bank_transfer',
    );

    expect(draft.toJson()['revision'], 3);
    expect(draft.toJson()['payee_name'], 'Office rent');
  });

  test('simplified voucher sends party token without legacy party fields', () {
    const draft = VoucherDraft(
      type: VoucherType.receipt,
      submissionKey: 'uuid-new',
      locationId: 3,
      operationDate: '2026-11-09T01:20',
      partySelection: 'contact:42',
      cashAccountId: 10,
      amount: '250.0000',
      paymentMethod: 'cash',
      description: 'Advance received',
      note: 'Internal note',
    );

    final json = draft.toJson();

    expect(json['party_selection'], 'contact:42');
    expect(json['description'], 'Advance received');
    expect(json, isNot(contains('party_mode')));
    expect(json, isNot(contains('contact_id')));
    expect(json, isNot(contains('counter_account_id')));
  });

  test('contra voucher retains explicit destination account', () {
    const draft = VoucherDraft(
      type: VoucherType.contra,
      submissionKey: 'uuid-contra',
      locationId: 1,
      operationDate: '2026-11-09T01:20',
      partyMode: 'none',
      cashAccountId: 10,
      counterAccountId: 11,
      amount: '75.0000',
    );

    expect(draft.toJson()['counter_account_id'], 11);
    expect(draft.toJson()['party_mode'], 'none');
  });
}
