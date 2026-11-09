import 'dart:math';

import 'package:flutter/material.dart' hide Text;
import 'package:eazy_pos/shared/widgets/localized_text.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../apis/api.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/ui.dart';
import '../../home/module_screens.dart' show PagePad;
import '../../settings/application/pos_operating_mode_controller.dart';
import '../domain/voucher_entities.dart';
import 'voucher_controller.dart';

class VouchersScreen extends ConsumerStatefulWidget {
  const VouchersScreen({super.key});

  @override
  ConsumerState<VouchersScreen> createState() => _VouchersScreenState();
}

class _VouchersScreenState extends ConsumerState<VouchersScreen> {
  final search = TextEditingController();
  VoucherType? type;
  int page = 1;

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  bool _allowed(String action, VoucherType voucherType) {
    final access = ref.read(posRoleAccessProvider).asData?.value.access;
    return access?.isAdmin == true ||
        access?.permissions.contains(
              'accounting.${action}_${voucherType.code}',
            ) ==
            true;
  }

  Future<void> _openEditor({Voucher? voucher}) async {
    final creatableTypes = VoucherType.values
        .where((item) => _allowed('create', item))
        .toList(growable: false);
    final selectedType =
        voucher?.type ??
        (type != null && creatableTypes.contains(type)
            ? type!
            : creatableTypes.firstOrNull ?? VoucherType.receipt);
    if (!_allowed(voucher == null ? 'create' : 'edit', selectedType)) {
      _message('You do not have permission for this voucher action.');
      return;
    }
    final changed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          VoucherEditorDialog(voucher: voucher, initialType: selectedType),
    );
    if (changed == true) setState(() {});
  }

  Future<void> _openDetail(Voucher item) async {
    try {
      final voucher = await ref
          .read(voucherActionsProvider.notifier)
          .detail(item.id);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (_) => _VoucherDetailDialog(
          voucher: voucher,
          canEdit: _allowed('edit', voucher.type),
          canDelete: _allowed('delete', voucher.type),
          onEdit: () {
            Navigator.pop(context);
            _openEditor(voucher: voucher);
          },
          onDelete: () async {
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Delete voucher?'),
                content: const Text(
                  'This will unwind the voucher posting and cannot be undone.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Delete'),
                  ),
                ],
              ),
            );
            if (confirmed != true) return;
            try {
              await ref.read(voucherActionsProvider.notifier).remove(voucher);
              if (!mounted) return;
              Navigator.pop(context);
              _message('Voucher deleted.');
            } on ApiException catch (error) {
              if (!mounted) return;
              _message(
                error.statusCode == 409
                    ? 'This voucher changed on the server. Reload it and try again.'
                    : error.message,
              );
            }
          },
        ),
      );
    } on ApiException catch (error) {
      _message(error.message);
    }
  }

  Future<void> _openConfiguration() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const VoucherConfigurationDialog(),
    );
  }

  void _message(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(context.tr(message))));
  }

  @override
  Widget build(BuildContext context) {
    final accessState = ref.watch(posRoleAccessProvider);
    final canViewAny =
        accessState.asData?.value.access.isAdmin == true ||
        VoucherType.values.any((item) => _allowed('view', item));
    final query = VoucherQuery(type: type, page: page, party: search.text);
    final vouchers = canViewAny
        ? ref.watch(voucherListProvider(query))
        : const AsyncValue<VoucherPage>.loading();
    final canCreate = VoucherType.values.any(
      (item) => _allowed('create', item),
    );
    final access = accessState.asData?.value.access;
    final canManageAccounts =
        access?.isAdmin == true ||
        access?.permissions.contains('accounting.manage_accounts') == true;

    return PagePad(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PageTitle(
            'Accounting vouchers',
            subtitle: 'Create and manage receipts, payments and transfers.',
            action: canCreate || canManageAccounts
                ? Wrap(
                    spacing: 8,
                    children: [
                      if (canManageAccounts)
                        OutlinedButton.icon(
                          onPressed: _openConfiguration,
                          icon: const Icon(Icons.tune),
                          label: const Text('Account setup'),
                        ),
                      if (canCreate)
                        FilledButton.icon(
                          onPressed: _openEditor,
                          icon: const Icon(Icons.add),
                          label: const Text('New voucher'),
                        ),
                    ],
                  )
                : null,
          ),
          const SizedBox(height: 16),
          if (accessState.isLoading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (!canViewAny)
            const Expanded(
              child: Center(
                child: Text('You do not have permission to view vouchers.'),
              ),
            )
          else ...[
            Surface(
              child: Wrap(
                spacing: 8,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  for (final choice in <VoucherType?>[
                    null,
                    ...VoucherType.values,
                  ])
                    ChoiceChip(
                      selected: type == choice,
                      label: Text(choice?.label ?? 'All'),
                      onSelected: (_) => setState(() {
                        type = choice;
                        page = 1;
                      }),
                    ),
                  SizedBox(
                    width: 320,
                    child: TextField(
                      controller: search,
                      textInputAction: TextInputAction.search,
                      onSubmitted: (_) => setState(() => page = 1),
                      decoration: InputDecoration(
                        hintText: context.tr('Search party or reference'),
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: IconButton(
                          tooltip: context.tr('Search'),
                          onPressed: () => setState(() => page = 1),
                          icon: const Icon(Icons.arrow_forward),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: vouchers.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => _VoucherError(
                  error: error,
                  retry: () => ref.invalidate(voucherListProvider(query)),
                ),
                data: (result) => Column(
                  children: [
                    Expanded(
                      child: result.items.isEmpty
                          ? const _EmptyVouchers()
                          : LayoutBuilder(
                              builder: (context, constraints) =>
                                  constraints.maxWidth < 760
                                  ? ListView.separated(
                                      itemCount: result.items.length,
                                      separatorBuilder: (_, __) =>
                                          const SizedBox(height: 8),
                                      itemBuilder: (_, index) => _VoucherCard(
                                        voucher: result.items[index],
                                        onTap: () =>
                                            _openDetail(result.items[index]),
                                      ),
                                    )
                                  : _VoucherTable(
                                      vouchers: result.items,
                                      onTap: _openDetail,
                                    ),
                            ),
                    ),
                    if (result.lastPage > 1)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text('${result.total} vouchers'),
                            IconButton(
                              onPressed: page > 1
                                  ? () => setState(() => page--)
                                  : null,
                              icon: const Icon(Icons.chevron_left),
                            ),
                            Text('$page / ${result.lastPage}'),
                            IconButton(
                              onPressed: page < result.lastPage
                                  ? () => setState(() => page++)
                                  : null,
                              icon: const Icon(Icons.chevron_right),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class VoucherConfigurationDialog extends ConsumerStatefulWidget {
  const VoucherConfigurationDialog({super.key});

  @override
  ConsumerState<VoucherConfigurationDialog> createState() =>
      _VoucherConfigurationDialogState();
}

class _VoucherConfigurationDialogState
    extends ConsumerState<VoucherConfigurationDialog> {
  late final Future<VoucherConfiguration> future;
  final kinds = <int, String?>{};
  final cores = <int, int?>{};
  bool saving = false;

  @override
  void initState() {
    super.initState();
    future = ref.read(voucherActionsProvider.notifier).configuration();
  }

  Future<void> _save(VoucherConfiguration configuration) async {
    final linked = cores.entries
        .where((entry) => kinds[entry.key] != null && entry.value != null)
        .map((entry) => entry.value)
        .toList();
    if (linked.toSet().length != linked.length) {
      _message('Each payment account can only be linked once.');
      return;
    }
    setState(() => saving = true);
    try {
      await ref.read(voucherActionsProvider.notifier).updateConfiguration([
        for (final account in configuration.accounts)
          {
            'id': account.id,
            'kind': kinds[account.id],
            'core_id': kinds[account.id] == null ? null : cores[account.id],
          },
      ]);
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('Voucher account setup saved.'))),
      );
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => saving = false);
      _message(error.message);
    }
  }

  void _message(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(context.tr(message))));

  @override
  Widget build(BuildContext context) => Dialog(
    insetPadding: const EdgeInsets.all(16),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 860, maxHeight: 720),
      child: FutureBuilder<VoucherConfiguration>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.hasError) return _DialogFailure(error: snapshot.error);
          if (!snapshot.hasData) {
            return const SizedBox(
              height: 260,
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final configuration = snapshot.data!;
          for (final account in configuration.accounts) {
            kinds.putIfAbsent(account.id, () => account.kind);
            cores.putIfAbsent(account.id, () => account.coreAccountId);
          }
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 18, 12, 10),
                child: Row(
                  children: [
                    const Icon(Icons.account_balance_outlined),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Voucher account setup',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            'Classify cash and bank ledgers used for voucher posting.',
                            style: TextStyle(color: AppColors.muted),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: saving ? null : () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: configuration.accounts.isEmpty
                    ? const Center(
                        child: Text('No asset ledgers are available.'),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(18),
                        itemCount: configuration.accounts.length,
                        separatorBuilder: (_, __) => const Divider(),
                        itemBuilder: (context, index) {
                          final account = configuration.accounts[index];
                          return LayoutBuilder(
                            builder: (context, constraints) {
                              final narrow = constraints.maxWidth < 620;
                              final controls = [
                                SizedBox(
                                  width: narrow ? constraints.maxWidth : 180,
                                  child: DropdownButtonFormField<String?>(
                                    initialValue: kinds[account.id],
                                    decoration: const InputDecoration(
                                      labelText: 'Classification',
                                    ),
                                    items: const [
                                      DropdownMenuItem(
                                        value: null,
                                        child: Text('Not used'),
                                      ),
                                      DropdownMenuItem(
                                        value: 'cash',
                                        child: Text('Cash'),
                                      ),
                                      DropdownMenuItem(
                                        value: 'bank',
                                        child: Text('Bank'),
                                      ),
                                    ],
                                    onChanged: account.active
                                        ? (value) => setState(() {
                                            kinds[account.id] = value;
                                            if (value == null) {
                                              cores[account.id] = null;
                                            }
                                          })
                                        : null,
                                  ),
                                ),
                                SizedBox(
                                  width: narrow
                                      ? constraints.maxWidth
                                      : constraints.maxWidth - 410,
                                  child: DropdownButtonFormField<int?>(
                                    initialValue:
                                        configuration.coreAccounts.any(
                                          (item) =>
                                              item.id == cores[account.id],
                                        )
                                        ? cores[account.id]
                                        : null,
                                    decoration: const InputDecoration(
                                      labelText: 'Core payment account',
                                    ),
                                    items: [
                                      const DropdownMenuItem<int?>(
                                        value: null,
                                        child: Text('No link'),
                                      ),
                                      ...configuration.coreAccounts.map(
                                        (item) => DropdownMenuItem<int?>(
                                          value: item.id,
                                          child: Text(item.name),
                                        ),
                                      ),
                                    ],
                                    onChanged:
                                        account.active &&
                                            kinds[account.id] != null
                                        ? (value) => setState(
                                            () => cores[account.id] = value,
                                          )
                                        : null,
                                  ),
                                ),
                              ];
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    account.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  if (!account.active)
                                    const Text(
                                      'Inactive ledger',
                                      style: TextStyle(
                                        color: AppColors.danger,
                                        fontSize: 12,
                                      ),
                                    ),
                                  const SizedBox(height: 8),
                                  narrow
                                      ? Column(
                                          children: [
                                            controls[0],
                                            const SizedBox(height: 8),
                                            controls[1],
                                          ],
                                        )
                                      : Row(
                                          children: [
                                            controls[0],
                                            const SizedBox(width: 12),
                                            controls[1],
                                          ],
                                        ),
                                ],
                              );
                            },
                          );
                        },
                      ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: saving ? null : () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: saving || configuration.accounts.isEmpty
                          ? null
                          : () => _save(configuration),
                      icon: saving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.save_outlined),
                      label: const Text('Save setup'),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    ),
  );
}

class VoucherEditorDialog extends ConsumerStatefulWidget {
  const VoucherEditorDialog({
    super.key,
    this.voucher,
    this.initialType = VoucherType.receipt,
  });
  final Voucher? voucher;
  final VoucherType initialType;

  @override
  ConsumerState<VoucherEditorDialog> createState() =>
      _VoucherEditorDialogState();
}

class _VoucherEditorDialogState extends ConsumerState<VoucherEditorDialog> {
  final formKey = GlobalKey<FormState>();
  late VoucherType type;
  late final TextEditingController amount;
  late final TextEditingController payee;
  late final TextEditingController paymentReference;
  late final TextEditingController description;
  late final TextEditingController note;
  late DateTime operationDate;
  String? partyMode;
  String? partySelection;
  int? locationId, contactId, cashAccountId, counterAccountId;
  String? paymentMethod;
  VoucherDues? dues;
  bool saving = false;
  bool defaultsApplied = false;

  @override
  void initState() {
    super.initState();
    final voucher = widget.voucher;
    type = voucher?.type ?? widget.initialType;
    amount = TextEditingController(text: voucher?.amount ?? '');
    payee = TextEditingController(text: voucher?.payeeName ?? '');
    paymentReference = TextEditingController(
      text: voucher?.paymentReference ?? '',
    );
    description = TextEditingController(text: voucher?.description ?? '');
    note = TextEditingController(text: voucher?.note ?? '');
    operationDate = voucher?.operationDate ?? DateTime.now();
    partyMode = voucher?.partyMode;
    partySelection =
        voucher?.partySelection ??
        (voucher?.contactId == null ? null : 'contact:${voucher!.contactId}');
    locationId = voucher?.locationId;
    contactId = voucher?.contactId;
    cashAccountId = voucher?.cashAccountId;
    counterAccountId = voucher?.counterAccountId;
    paymentMethod = voucher?.paymentMethod;
  }

  @override
  void dispose() {
    amount.dispose();
    payee.dispose();
    paymentReference.dispose();
    description.dispose();
    note.dispose();
    super.dispose();
  }

  Future<void> _save(VoucherOptions options) async {
    if (!formKey.currentState!.validate()) return;
    if (locationId == null || cashAccountId == null) {
      _message('Choose a location and source account.');
      return;
    }
    if (type == VoucherType.contra && counterAccountId == null) {
      _message('Choose a destination account.');
      return;
    }
    if (counterAccountId != null && cashAccountId == counterAccountId) {
      _message('Source and counter accounts must be different.');
      return;
    }
    if (type != VoucherType.contra && partySelection == null) {
      _message(
        type == VoucherType.receipt
            ? 'Choose who the money was received from.'
            : 'Choose who the money was paid to.',
      );
      return;
    }
    setState(() => saving = true);
    final existing = widget.voucher;
    final draft = VoucherDraft(
      type: type,
      submissionKey: existing?.submissionKey.isNotEmpty == true
          ? existing!.submissionKey
          : _uuidV4(),
      revision: existing?.revision,
      locationId: locationId!,
      operationDate: DateFormat("yyyy-MM-dd'T'HH:mm").format(operationDate),
      partyMode: type == VoucherType.contra ? 'none' : null,
      partySelection: type == VoucherType.contra ? null : partySelection,
      cashAccountId: cashAccountId!,
      counterAccountId: type == VoucherType.contra ? counterAccountId : null,
      amount: amount.text.trim(),
      paymentMethod: type == VoucherType.contra ? null : paymentMethod,
      paymentReference: paymentReference.text,
      description: description.text,
      note: note.text,
    );
    try {
      await ref
          .read(voucherActionsProvider.notifier)
          .save(draft, id: existing?.id);
      if (!mounted) return;
      Navigator.pop(context, true);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.tr('Voucher saved.'))));
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => saving = false);
      _message(
        error.statusCode == 409
            ? 'This voucher changed on the server. Close and reload it before editing.'
            : error.message,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => saving = false);
      _message('Unable to save voucher. Please try again.');
    }
  }

  void _applyDefaults(VoucherOptions options) {
    if (!defaultsApplied && widget.voucher == null) {
      operationDate = options.defaultOperationDate ?? operationDate;
      defaultsApplied = true;
    }
    partyMode ??= type == VoucherType.contra ? 'none' : null;
    locationId ??= options.locations.firstOrNull?.id;
    paymentMethod ??=
        options.defaultPaymentMethod ?? options.paymentMethods.firstOrNull;
    final sourceAccounts = options.sourceAccounts.isNotEmpty
        ? options.sourceAccounts
        : options.accounts.where((item) => item.isCashOrBank).toList();
    final location = options.locations
        .where((item) => item.id == locationId)
        .firstOrNull;
    cashAccountId ??=
        location?.defaultSourceAccountId ?? sourceAccounts.firstOrNull?.id;
    counterAccountId ??= type == VoucherType.contra
        ? sourceAccounts
              .where((item) => item.id != cashAccountId)
              .firstOrNull
              ?.id
        : null;
  }

  Future<void> _previewDues() async {
    if (locationId == null || contactId == null) return;
    try {
      final value = await ref
          .read(voucherActionsProvider.notifier)
          .dues(
            type: type,
            locationId: locationId!,
            contactId: contactId!,
            amount: amount.text,
            voucherId: widget.voucher?.id,
          );
      if (mounted) setState(() => dues = value);
    } on ApiException catch (error) {
      _message(error.message);
    }
  }

  void _message(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(context.tr(message))));

  @override
  Widget build(BuildContext context) {
    final action = ref.read(voucherActionsProvider.notifier);
    final access = ref.watch(posRoleAccessProvider).asData?.value.access;
    final allowedTypes = VoucherType.values
        .where((item) {
          if (widget.voucher != null) return item == widget.voucher!.type;
          return access?.isAdmin == true ||
              access?.permissions.contains('accounting.create_${item.code}') ==
                  true;
        })
        .toList(growable: false);
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 820, maxHeight: 760),
        child: FutureBuilder<VoucherOptions>(
          future: action.options(type, voucherId: widget.voucher?.id),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return _DialogFailure(error: snapshot.error);
            }
            if (!snapshot.hasData) {
              return const SizedBox(
                height: 260,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final options = snapshot.data!;
            _applyDefaults(options);
            final sourceAccounts = options.sourceAccounts.isNotEmpty
                ? options.sourceAccounts
                : options.accounts.where((item) => item.isCashOrBank).toList();
            final contactMode = partySelection?.startsWith('contact:') == true;
            return Form(
              key: formKey,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(22, 18, 12, 8),
                    child: Row(
                      children: [
                        Icon(_typeIcon(type), color: AppColors.primary),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            widget.voucher == null
                                ? 'New voucher'
                                : 'Edit ${widget.voucher!.reference}',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ),
                        IconButton(
                          onPressed: saving
                              ? null
                              : () => Navigator.pop(context),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(22),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final width = constraints.maxWidth < 620
                              ? constraints.maxWidth
                              : (constraints.maxWidth - 12) / 2;
                          return Wrap(
                            spacing: 12,
                            runSpacing: 14,
                            children: [
                              SizedBox(
                                width: width,
                                child: DropdownButtonFormField<VoucherType>(
                                  initialValue: type,
                                  decoration: const InputDecoration(
                                    labelText: 'Voucher type',
                                  ),
                                  items: allowedTypes
                                      .map(
                                        (item) => DropdownMenuItem(
                                          value: item,
                                          child: Text(item.label),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: widget.voucher == null
                                      ? (value) {
                                          if (value == null || value == type)
                                            return;
                                          setState(() {
                                            type = value;
                                            partyMode = null;
                                            locationId = null;
                                            contactId = null;
                                            partySelection = null;
                                            cashAccountId = null;
                                            counterAccountId = null;
                                            paymentMethod = null;
                                            defaultsApplied = false;
                                            dues = null;
                                          });
                                        }
                                      : null,
                                ),
                              ),
                              SizedBox(
                                width: width,
                                child: DropdownButtonFormField<int>(
                                  initialValue:
                                      options.locations.any(
                                        (item) => item.id == locationId,
                                      )
                                      ? locationId
                                      : null,
                                  decoration: const InputDecoration(
                                    labelText: 'Location',
                                  ),
                                  items: options.locations
                                      .map(
                                        (item) => DropdownMenuItem(
                                          value: item.id,
                                          child: Text(item.name),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (value) => setState(() {
                                    locationId = value;
                                    dues = null;
                                    cashAccountId =
                                        options.locations
                                            .where((item) => item.id == value)
                                            .firstOrNull
                                            ?.defaultSourceAccountId ??
                                        cashAccountId;
                                  }),
                                ),
                              ),
                              if (type != VoucherType.contra)
                                SizedBox(
                                  width: width,
                                  child: FutureBuilder<List<VoucherParty>>(
                                    future: action.parties(
                                      type,
                                      voucherId: widget.voucher?.id,
                                    ),
                                    builder: (context, parties) =>
                                        DropdownButtonFormField<String>(
                                          initialValue:
                                              [
                                                ...(parties.data ?? const [])
                                                    .map(
                                                      (item) =>
                                                          item.partySelection ??
                                                          'contact:${item.id}',
                                                    ),
                                                ...options.partyAccounts.map(
                                                  (item) =>
                                                      item.partySelection ??
                                                      'ledger:${item.id}',
                                                ),
                                              ].contains(partySelection)
                                              ? partySelection
                                              : null,
                                          decoration: InputDecoration(
                                            labelText:
                                                type == VoucherType.receipt
                                                ? 'Received from'
                                                : 'Paid to',
                                            suffixIcon:
                                                parties.connectionState ==
                                                    ConnectionState.waiting
                                                ? const Padding(
                                                    padding: EdgeInsets.all(12),
                                                    child:
                                                        CircularProgressIndicator(
                                                          strokeWidth: 2,
                                                        ),
                                                  )
                                                : null,
                                          ),
                                          items: [
                                            ...(parties.data ?? const []).map(
                                              (item) => DropdownMenuItem(
                                                value:
                                                    item.partySelection ??
                                                    'contact:${item.id}',
                                                child: Text(
                                                  '${item.type == 'supplier' ? 'Supplier' : 'Customer'} • ${item.label}',
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ),
                                            ...options.partyAccounts.map(
                                              (item) => DropdownMenuItem(
                                                value:
                                                    item.partySelection ??
                                                    'ledger:${item.id}',
                                                child: Text(
                                                  'Ledger • ${item.label}',
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ),
                                          ],
                                          onChanged: (value) => setState(() {
                                            partySelection = value;
                                            contactId =
                                                value?.startsWith('contact:') ==
                                                    true
                                                ? int.tryParse(
                                                    value!.substring(8),
                                                  )
                                                : null;
                                            dues = null;
                                          }),
                                        ),
                                  ),
                                ),
                              SizedBox(
                                width: width,
                                child: DropdownButtonFormField<int>(
                                  initialValue:
                                      sourceAccounts.any(
                                        (item) => item.id == cashAccountId,
                                      )
                                      ? cashAccountId
                                      : null,
                                  decoration: InputDecoration(
                                    labelText: type == VoucherType.contra
                                        ? 'Source account'
                                        : 'Source account',
                                  ),
                                  items: sourceAccounts
                                      .map(
                                        (item) => DropdownMenuItem(
                                          value: item.id,
                                          child: Text(item.label),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (value) =>
                                      setState(() => cashAccountId = value),
                                ),
                              ),
                              if (type == VoucherType.contra)
                                SizedBox(
                                  width: width,
                                  child: DropdownButtonFormField<int>(
                                    initialValue:
                                        options.accounts.any(
                                          (item) => item.id == counterAccountId,
                                        )
                                        ? counterAccountId
                                        : null,
                                    decoration: InputDecoration(
                                      labelText: type == VoucherType.contra
                                          ? 'Destination account'
                                          : 'Counter account',
                                      helperText: contactMode
                                          ? 'Controlled by the selected location'
                                          : null,
                                    ),
                                    items: sourceAccounts
                                        .where(
                                          (item) => item.id != cashAccountId,
                                        )
                                        .map(
                                          (item) => DropdownMenuItem(
                                            value: item.id,
                                            child: Text(item.label),
                                          ),
                                        )
                                        .toList(),
                                    onChanged: (value) => setState(
                                      () => counterAccountId = value,
                                    ),
                                  ),
                                ),
                              SizedBox(
                                width: width,
                                child: TextFormField(
                                  controller: amount,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  decoration: const InputDecoration(
                                    labelText: 'Amount',
                                    prefixText: 'SAR ',
                                  ),
                                  validator: (value) {
                                    final text = value?.trim() ?? '';
                                    if (!RegExp(
                                      r'^\d{1,18}(\.\d{1,4})?$',
                                    ).hasMatch(text)) {
                                      return 'Enter a positive amount with up to 4 decimals.';
                                    }
                                    if ((double.tryParse(text) ?? 0) <= 0) {
                                      return 'Amount must be greater than zero.';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                              if (type != VoucherType.contra)
                                SizedBox(
                                  width: width,
                                  child: DropdownButtonFormField<String>(
                                    initialValue:
                                        options.paymentMethods.contains(
                                          paymentMethod,
                                        )
                                        ? paymentMethod
                                        : null,
                                    decoration: const InputDecoration(
                                      labelText: 'Payment method',
                                    ),
                                    items: options.paymentMethods
                                        .map(
                                          (item) => DropdownMenuItem(
                                            value: item,
                                            child: Text(
                                              item.replaceAll('_', ' '),
                                            ),
                                          ),
                                        )
                                        .toList(),
                                    onChanged: (value) =>
                                        setState(() => paymentMethod = value),
                                  ),
                                ),
                              if (type != VoucherType.contra)
                                SizedBox(
                                  width: width,
                                  child: TextFormField(
                                    controller: paymentReference,
                                    maxLength: 255,
                                    decoration: const InputDecoration(
                                      labelText: 'Payment reference (optional)',
                                      counterText: '',
                                    ),
                                  ),
                                ),
                              SizedBox(
                                width: width,
                                child: InkWell(
                                  onTap: () async {
                                    final date = await showDatePicker(
                                      context: context,
                                      initialDate: operationDate,
                                      firstDate: DateTime(2000),
                                      lastDate: DateTime.now().add(
                                        const Duration(days: 365),
                                      ),
                                    );
                                    if (date == null || !context.mounted)
                                      return;
                                    final time = await showTimePicker(
                                      context: context,
                                      initialTime: TimeOfDay.fromDateTime(
                                        operationDate,
                                      ),
                                    );
                                    if (time == null) return;
                                    setState(() {
                                      operationDate = DateTime(
                                        date.year,
                                        date.month,
                                        date.day,
                                        time.hour,
                                        time.minute,
                                      );
                                    });
                                  },
                                  child: InputDecorator(
                                    decoration: const InputDecoration(
                                      labelText: 'Operation date',
                                      suffixIcon: Icon(Icons.calendar_today),
                                    ),
                                    child: Text(
                                      DateFormat(
                                        'dd MMM yyyy, HH:mm',
                                      ).format(operationDate),
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: constraints.maxWidth,
                                child: TextFormField(
                                  controller: description,
                                  maxLength: 1000,
                                  minLines: 2,
                                  maxLines: 3,
                                  decoration: const InputDecoration(
                                    labelText: 'Description (optional)',
                                    helperText:
                                        'Shown separately from the internal note.',
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: constraints.maxWidth,
                                child: TextFormField(
                                  controller: note,
                                  maxLength: 5000,
                                  minLines: 2,
                                  maxLines: 4,
                                  decoration: const InputDecoration(
                                    labelText: 'Note (optional)',
                                  ),
                                ),
                              ),
                              if (contactMode && contactId != null)
                                SizedBox(
                                  width: constraints.maxWidth,
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withValues(
                                        alpha: .06,
                                      ),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(12),
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons.receipt_long_outlined,
                                            color: AppColors.primary,
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Text(
                                              dues == null
                                                  ? 'Preview outstanding dues before saving.'
                                                  : 'Outstanding: SAR ${dues!.due}  •  Estimated advance: SAR ${dues!.advance ?? '0.0000'}',
                                            ),
                                          ),
                                          TextButton(
                                            onPressed: _previewDues,
                                            child: const Text('Preview dues'),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: saving
                              ? null
                              : () => Navigator.pop(context),
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 8),
                        FilledButton.icon(
                          onPressed: saving ? null : () => _save(options),
                          icon: saving
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.check),
                          label: const Text('Save and post'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _VoucherTable extends StatelessWidget {
  const _VoucherTable({required this.vouchers, required this.onTap});
  final List<Voucher> vouchers;
  final ValueChanged<Voucher> onTap;

  @override
  Widget build(BuildContext context) => Surface(
    padding: EdgeInsets.zero,
    child: SingleChildScrollView(
      child: DataTable(
        showCheckboxColumn: false,
        columns: const [
          DataColumn(label: Text('Reference')),
          DataColumn(label: Text('Type')),
          DataColumn(label: Text('Party')),
          DataColumn(label: Text('Date')),
          DataColumn(label: Text('Amount'), numeric: true),
        ],
        rows: vouchers
            .map(
              (voucher) => DataRow(
                onSelectChanged: (_) => onTap(voucher),
                cells: [
                  DataCell(Text(voucher.reference)),
                  DataCell(_TypeBadge(type: voucher.type)),
                  DataCell(Text(_party(voucher))),
                  DataCell(
                    Text(
                      DateFormat('dd MMM yyyy').format(voucher.operationDate),
                    ),
                  ),
                  DataCell(Text('SAR ${voucher.amount}')),
                ],
              ),
            )
            .toList(),
      ),
    ),
  );
}

class _VoucherCard extends StatelessWidget {
  const _VoucherCard({required this.voucher, required this.onTap});
  final Voucher voucher;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Surface(
    child: InkWell(
      onTap: onTap,
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: AppColors.primary.withValues(alpha: .08),
            child: Icon(_typeIcon(voucher.type), color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        voucher.reference,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    _TypeBadge(type: voucher.type),
                  ],
                ),
                const SizedBox(height: 4),
                Text(_party(voucher)),
                Text(
                  DateFormat(
                    'dd MMM yyyy, HH:mm',
                  ).format(voucher.operationDate),
                  style: const TextStyle(color: AppColors.muted, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'SAR ${voucher.amount}',
            style: const TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    ),
  );
}

class _VoucherDetailDialog extends StatelessWidget {
  const _VoucherDetailDialog({
    required this.voucher,
    required this.canEdit,
    required this.canDelete,
    required this.onEdit,
    required this.onDelete,
  });
  final Voucher voucher;
  final bool canEdit, canDelete;
  final VoidCallback onEdit, onDelete;

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Row(
      children: [
        Icon(_typeIcon(voucher.type), color: AppColors.primary),
        const SizedBox(width: 10),
        Expanded(child: Text(voucher.reference)),
        _TypeBadge(type: voucher.type),
      ],
    ),
    content: SizedBox(
      width: 620,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _DetailRow(label: 'Party', value: _party(voucher)),
            _DetailRow(label: 'Amount', value: 'SAR ${voucher.amount}'),
            _DetailRow(
              label: 'Date',
              value: DateFormat(
                'dd MMM yyyy, HH:mm',
              ).format(voucher.operationDate),
            ),
            if (voucher.paymentMethod != null)
              _DetailRow(
                label: 'Payment method',
                value: voucher.paymentMethod!.replaceAll('_', ' '),
              ),
            if (voucher.advanceAmount != '0.0000')
              _DetailRow(
                label: 'Advance',
                value: 'SAR ${voucher.advanceAmount}',
              ),
            if (voucher.description?.isNotEmpty == true)
              _DetailRow(label: 'Description', value: voucher.description!),
            if (voucher.note?.isNotEmpty == true)
              _DetailRow(label: 'Note', value: voucher.note!),
            if (voucher.allocations.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                'Invoice allocations',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              for (final allocation in voucher.allocations)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    allocation.invoiceNo ??
                        allocation.reference ??
                        '#${allocation.transactionId}',
                  ),
                  trailing: Text('SAR ${allocation.amount}'),
                ),
            ],
          ],
        ),
      ),
    ),
    actions: [
      if (canDelete)
        TextButton.icon(
          onPressed: onDelete,
          icon: const Icon(Icons.delete_outline),
          label: const Text('Delete'),
        ),
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Close'),
      ),
      if (canEdit)
        FilledButton.icon(
          onPressed: onEdit,
          icon: const Icon(Icons.edit_outlined),
          label: const Text('Edit'),
        ),
    ],
  );
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});
  final String label, value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 140,
          child: Text(label, style: const TextStyle(color: AppColors.muted)),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    ),
  );
}

class _TypeBadge extends StatelessWidget {
  const _TypeBadge({required this.type});
  final VoucherType type;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: _typeColor(type).withValues(alpha: .1),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      type.label,
      style: TextStyle(
        color: _typeColor(type),
        fontSize: 11,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}

class _VoucherError extends StatelessWidget {
  const _VoucherError({required this.error, required this.retry});
  final Object error;
  final VoidCallback retry;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.error_outline, size: 42, color: AppColors.danger),
        const SizedBox(height: 10),
        Text(
          error is ApiException ? (error as ApiException).message : '$error',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: retry,
          icon: const Icon(Icons.refresh),
          label: const Text('Retry'),
        ),
      ],
    ),
  );
}

class _DialogFailure extends StatelessWidget {
  const _DialogFailure({required this.error});
  final Object? error;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(28),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.warning_amber_rounded, size: 42),
        const SizedBox(height: 12),
        Text(
          error is ApiException ? (error as ApiException).message : '$error',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 14),
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}

class _EmptyVouchers extends StatelessWidget {
  const _EmptyVouchers();

  @override
  Widget build(BuildContext context) => const Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.account_balance_wallet_outlined, size: 52),
        SizedBox(height: 10),
        Text('No vouchers found.'),
      ],
    ),
  );
}

String _party(Voucher voucher) => voucher.partyLabel?.trim().isNotEmpty == true
    ? voucher.partyLabel!
    : voucher.payeeName?.trim().isNotEmpty == true
    ? voucher.payeeName!
    : voucher.type == VoucherType.contra
    ? 'Account transfer'
    : '—';

IconData _typeIcon(VoucherType type) => switch (type) {
  VoucherType.receipt => Icons.south_west_rounded,
  VoucherType.payment => Icons.north_east_rounded,
  VoucherType.contra => Icons.swap_horiz_rounded,
};

Color _typeColor(VoucherType type) => switch (type) {
  VoucherType.receipt => const Color(0xFF087F5B),
  VoucherType.payment => const Color(0xFFB45309),
  VoucherType.contra => const Color(0xFF356A8A),
};

String _uuidV4() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final value = bytes
      .map((item) => item.toRadixString(16).padLeft(2, '0'))
      .join();
  return '${value.substring(0, 8)}-${value.substring(8, 12)}-'
      '${value.substring(12, 16)}-${value.substring(16, 20)}-'
      '${value.substring(20)}';
}
