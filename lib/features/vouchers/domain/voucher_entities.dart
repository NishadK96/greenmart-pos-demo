enum VoucherType {
  receipt('receipt_voucher', 'Receipt'),
  payment('payment_voucher', 'Payment'),
  contra('contra_voucher', 'Contra');

  const VoucherType(this.code, this.label);
  final String code;
  final String label;

  static VoucherType fromCode(String value) =>
      values.firstWhere((item) => item.code == value, orElse: () => receipt);
}

class Voucher {
  const Voucher({
    required this.id,
    required this.type,
    required this.reference,
    required this.revision,
    required this.submissionKey,
    required this.operationDate,
    required this.locationId,
    required this.partyMode,
    required this.cashAccountId,
    required this.counterAccountId,
    required this.amount,
    this.contactId,
    this.payeeName,
    this.partyLabel,
    this.advanceAmount = '0.0000',
    this.paymentMethod,
    this.paymentReference,
    this.partySelection,
    this.description,
    this.note,
    this.lines = const [],
    this.allocations = const [],
  });

  final int id;
  final VoucherType type;
  final String reference;
  final int revision;
  final String submissionKey;
  final DateTime operationDate;
  final int locationId;
  final String partyMode;
  final int? contactId;
  final String? payeeName, partyLabel;
  final int cashAccountId, counterAccountId;
  final String amount, advanceAmount;
  final String? paymentMethod,
      paymentReference,
      partySelection,
      description,
      note;
  final List<VoucherLine> lines;
  final List<VoucherAllocation> allocations;
}

class VoucherLine {
  const VoucherLine({
    required this.accountId,
    required this.type,
    required this.amount,
  });
  final int accountId;
  final String type, amount;
}

class VoucherAllocation {
  const VoucherAllocation({
    required this.transactionId,
    required this.amount,
    this.invoiceNo,
    this.reference,
  });
  final int transactionId;
  final String amount;
  final String? invoiceNo, reference;
}

class VoucherPage {
  const VoucherPage({
    required this.items,
    required this.page,
    required this.lastPage,
    required this.total,
  });
  final List<Voucher> items;
  final int page, lastPage, total;
}

class VoucherAccount {
  const VoucherAccount({
    required this.id,
    required this.name,
    required this.primaryType,
    this.cashKind,
    this.glCode,
    this.displayName,
    this.partySelection,
  });
  final int id;
  final String name, primaryType;
  final String? cashKind, glCode, displayName, partySelection;
  String get label =>
      displayName?.trim().isNotEmpty == true ? displayName! : name;
  bool get isCashOrBank => cashKind == 'cash' || cashKind == 'bank';
}

class VoucherLocation {
  const VoucherLocation({
    required this.id,
    required this.name,
    this.controlAccountId,
    this.defaultSourceAccountId,
  });
  final int id;
  final String name;
  final int? controlAccountId;
  final int? defaultSourceAccountId;
}

class VoucherOptions {
  const VoucherOptions({
    required this.type,
    required this.partyModes,
    required this.paymentMethods,
    required this.accounts,
    required this.locations,
    this.sourceAccounts = const [],
    this.partyAccounts = const [],
    this.defaultOperationDate,
    this.defaultPaymentMethod,
  });
  final VoucherType type;
  final List<String> partyModes, paymentMethods;
  final List<VoucherAccount> accounts;
  final List<VoucherAccount> sourceAccounts, partyAccounts;
  final List<VoucherLocation> locations;
  final DateTime? defaultOperationDate;
  final String? defaultPaymentMethod;
}

class VoucherParty {
  const VoucherParty({
    required this.id,
    required this.label,
    required this.type,
    this.partySelection,
  });
  final int id;
  final String label, type;
  final String? partySelection;
}

class VoucherDues {
  const VoucherDues({required this.due, this.advance});
  final String due;
  final String? advance;
}

class VoucherConfigurationAccount {
  const VoucherConfigurationAccount({
    required this.id,
    required this.name,
    required this.active,
    this.kind,
    this.coreAccountId,
  });
  final int id;
  final String name;
  final bool active;
  final String? kind;
  final int? coreAccountId;
}

class VoucherCoreAccount {
  const VoucherCoreAccount({required this.id, required this.name});
  final int id;
  final String name;
}

class VoucherConfiguration {
  const VoucherConfiguration({
    required this.accounts,
    required this.coreAccounts,
  });
  final List<VoucherConfigurationAccount> accounts;
  final List<VoucherCoreAccount> coreAccounts;
}

class VoucherDraft {
  const VoucherDraft({
    required this.type,
    required this.submissionKey,
    required this.locationId,
    required this.operationDate,
    required this.cashAccountId,
    required this.amount,
    this.partyMode,
    this.partySelection,
    this.counterAccountId,
    this.revision,
    this.contactId,
    this.payeeName,
    this.paymentMethod,
    this.paymentReference,
    this.description,
    this.note,
  });
  final VoucherType type;
  final String submissionKey, operationDate, amount;
  final String? partyMode, partySelection;
  final int locationId, cashAccountId;
  final int? counterAccountId;
  final int? revision, contactId;
  final String? payeeName, paymentMethod, paymentReference, description, note;

  Map<String, Object?> toJson() => {
    'type': type.code,
    'submission_key': submissionKey,
    if (revision != null) 'revision': revision,
    'location_id': locationId,
    'operation_date': operationDate,
    if (partySelection?.trim().isNotEmpty == true)
      'party_selection': partySelection!.trim(),
    if (partySelection?.trim().isEmpty != false && partyMode != null)
      'party_mode': partyMode,
    if (partySelection?.trim().isEmpty != false && contactId != null)
      'contact_id': contactId,
    if (partySelection?.trim().isEmpty != false &&
        payeeName?.trim().isNotEmpty == true)
      'payee_name': payeeName!.trim(),
    'cash_account_id': cashAccountId,
    if (counterAccountId != null) 'counter_account_id': counterAccountId,
    'amount': amount,
    if (paymentMethod != null) 'payment_method': paymentMethod,
    if (paymentReference?.trim().isNotEmpty == true)
      'payment_reference': paymentReference!.trim(),
    if (description != null) 'description': description!.trim(),
    if (note?.trim().isNotEmpty == true) 'note': note!.trim(),
  };
}
