import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';
import '../../../apis/api.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/entities.dart';
import '../../../shared/widgets/ui.dart';
import '../domain/zatca_entities.dart';
import 'zatca_controller.dart';

class ZatcaScreen extends ConsumerWidget {
  const ZatcaScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(zatcaControllerProvider);
    return Padding(
      padding: const EdgeInsets.all(20),
      child: status.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _ZatcaError(
          message: error.toString(),
          onRetry: () =>
              ref.read(zatcaControllerProvider.notifier).refreshStatus(),
        ),
        data: (data) => RefreshIndicator(
          onRefresh: () =>
              ref.read(zatcaControllerProvider.notifier).refreshStatus(),
          child: ListView(
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ZATCA e-invoicing',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          'Manage compliance, EGS devices and invoice submissions.',
                          style: TextStyle(color: AppColors.muted),
                        ),
                      ],
                    ),
                  ),
                  IconButton.outlined(
                    tooltip: 'Refresh status',
                    onPressed: () => ref
                        .read(zatcaControllerProvider.notifier)
                        .refreshStatus(),
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _IntegrationBanner(status: data),
              const SizedBox(height: 14),
              LayoutBuilder(
                builder: (_, constraints) => GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: constraints.maxWidth >= 850 ? 3 : 1,
                  childAspectRatio: constraints.maxWidth >= 850 ? 2.5 : 3.2,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  children: [
                    _Metric(
                      'Pending',
                      data.totals.pending,
                      Icons.schedule_outlined,
                      const Color(0xFFB7791F),
                    ),
                    _Metric(
                      'Successful',
                      data.totals.success,
                      Icons.verified_outlined,
                      const Color(0xFF16885F),
                    ),
                    _Metric(
                      'Failed',
                      data.totals.failed,
                      Icons.error_outline,
                      const Color(0xFFC94B4B),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Surface(
                padding: EdgeInsets.zero,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.fromLTRB(18, 18, 18, 12),
                      child: Text(
                        'EGS devices / business locations',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (data.locations.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(28),
                        child: EmptyState(
                          'No permitted business locations were returned.',
                        ),
                      )
                    else
                      for (final location in data.locations)
                        _LocationRow(
                          location: location,
                          enabled: data.installed && data.subscriptionEnabled,
                          onConfigure: () => showDialog<void>(
                            context: context,
                            barrierDismissible: false,
                            builder: (_) =>
                                _OnboardingDialog(location: location),
                          ),
                        ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Surface(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.security_outlined, color: AppColors.primary),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Security: the six-digit Fatoora OTP is sent directly to the backend for onboarding and is never saved by this app. Certificates, private keys and client secrets remain backend-only.',
                        style: TextStyle(color: AppColors.muted, height: 1.45),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IntegrationBanner extends StatelessWidget {
  const _IntegrationBanner({required this.status});
  final ZatcaIntegrationStatus status;
  @override
  Widget build(BuildContext context) {
    final ready = status.installed && status.subscriptionEnabled;
    return Surface(
      child: Wrap(
        spacing: 16,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          CircleAvatar(
            radius: 25,
            backgroundColor: ready
                ? const Color(0xFFE3F5EF)
                : const Color(0xFFFFE9E5),
            child: Icon(
              ready
                  ? Icons.verified_user_outlined
                  : Icons.warning_amber_rounded,
              color: ready ? AppColors.primary : const Color(0xFFC94B4B),
            ),
          ),
          SizedBox(
            width: 280,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ready ? 'ZATCA module available' : 'ZATCA setup unavailable',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  'Sync frequency: ${status.syncFrequency}${status.version == null ? '' : ' • v${status.version}'}',
                  style: const TextStyle(color: AppColors.muted),
                ),
              ],
            ),
          ),
          StatusBadge(
            status.installed ? 'Installed' : 'Not installed',
            color: status.installed
                ? AppColors.primary
                : const Color(0xFFC94B4B),
          ),
          StatusBadge(
            status.subscriptionEnabled
                ? 'Subscription enabled'
                : 'Subscription disabled',
            color: status.subscriptionEnabled
                ? AppColors.primary
                : const Color(0xFFC94B4B),
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric(this.label, this.value, this.icon, this.color);
  final String label;
  final int value;
  final IconData icon;
  final Color color;
  @override
  Widget build(BuildContext context) => Surface(
    child: Row(
      children: [
        CircleAvatar(
          backgroundColor: color.withValues(alpha: .12),
          child: Icon(icon, color: color),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$value',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
            ),
            Text(label, style: const TextStyle(color: AppColors.muted)),
          ],
        ),
      ],
    ),
  );
}

class _LocationRow extends StatelessWidget {
  const _LocationRow({
    required this.location,
    required this.enabled,
    required this.onConfigure,
  });
  final ZatcaLocationStatus location;
  final bool enabled;
  final VoidCallback onConfigure;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (_, constraints) {
      final compact = constraints.maxWidth < 620;
      final details = Row(
        children: [
          const CircleAvatar(
            backgroundColor: Color(0xFFEAF4F1),
            child: Icon(Icons.store_outlined, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  location.name,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                Text(
                  location.configured
                      ? '${location.portalMode ?? 'Configured'}${location.syncFrom == null ? '' : ' • Sync from ${location.syncFrom}'}'
                      : 'Device onboarding required',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.muted, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      );
      final actions = Wrap(
        spacing: 10,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          StatusBadge(
            location.configured ? 'Configured' : 'Not configured',
            color: location.configured
                ? AppColors.primary
                : const Color(0xFFB7791F),
          ),
          OutlinedButton(
            onPressed: enabled ? onConfigure : null,
            child: Text(location.configured ? 'Reconfigure' : 'Onboard device'),
          ),
        ],
      );
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Color(0xFFE4EAE7))),
        ),
        child: compact
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  details,
                  const SizedBox(height: 12),
                  Align(alignment: Alignment.centerLeft, child: actions),
                ],
              )
            : Row(
                children: [
                  Expanded(child: details),
                  const SizedBox(width: 12),
                  actions,
                ],
              ),
      );
    },
  );
}

class _OnboardingDialog extends ConsumerStatefulWidget {
  const _OnboardingDialog({required this.location});
  final ZatcaLocationStatus location;
  @override
  ConsumerState<_OnboardingDialog> createState() => _OnboardingDialogState();
}

class _OnboardingDialogState extends ConsumerState<_OnboardingDialog> {
  final formKey = GlobalKey<FormState>();
  late final Map<String, TextEditingController> fields;
  String portalMode = 'simulation';
  String invoiceType = '1100';
  bool saving = false;
  String? error;

  @override
  void initState() {
    super.initState();
    fields = {
      for (final key in [
        'otp',
        'email',
        'common',
        'unit',
        'organization',
        'vat',
        'vatName',
        'address',
        'category',
        'crn',
        'street',
        'building',
        'plot',
        'district',
        'city',
        'postal',
      ])
        key: TextEditingController(),
    };
    fields['common']!.text = '${widget.location.name} Device';
    fields['unit']!.text = widget.location.name;
  }

  @override
  void dispose() {
    for (final controller in fields.values) {
      controller.dispose();
    }
    super.dispose();
  }

  String? required(String? value) =>
      value == null || value.trim().isEmpty ? 'Required' : null;
  @override
  Widget build(BuildContext context) => Dialog(
    insetPadding: const EdgeInsets.all(16),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 880, maxHeight: 760),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 18, 12, 14),
            child: Row(
              children: [
                const CircleAvatar(
                  backgroundColor: Color(0xFFE3F5EF),
                  child: Icon(
                    Icons.verified_user_outlined,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Onboard ZATCA device',
                        style: TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        widget.location.name,
                        style: const TextStyle(color: AppColors.muted),
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
            child: Form(
              key: formKey,
              child: ListView(
                padding: const EdgeInsets.all(22),
                children: [
                  const Text(
                    'Environment & authorization',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 10),
                  _grid([
                    DropdownButtonFormField<String>(
                      initialValue: portalMode,
                      decoration: const InputDecoration(
                        labelText: 'Portal environment *',
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'developer-portal',
                          child: Text('Developer portal'),
                        ),
                        DropdownMenuItem(
                          value: 'simulation',
                          child: Text('Simulation'),
                        ),
                        DropdownMenuItem(
                          value: 'core',
                          child: Text('Production / Core'),
                        ),
                      ],
                      onChanged: (value) => portalMode = value ?? portalMode,
                    ),
                    TextFormField(
                      controller: fields['otp'],
                      obscureText: true,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      decoration: const InputDecoration(
                        labelText: 'Fatoora OTP *',
                        counterText: '',
                        helperText: 'Used once and never stored',
                      ),
                      validator: (value) =>
                          RegExp(r'^\d{6}$').hasMatch(value ?? '')
                          ? null
                          : 'Enter the 6-digit OTP',
                    ),
                    TextFormField(
                      controller: fields['email'],
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Device contact email *',
                      ),
                      validator: required,
                    ),
                  ]),
                  const SizedBox(height: 18),
                  const Text(
                    'Organization',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 10),
                  _grid([
                    _field('common', 'Device / common name *'),
                    _field('unit', 'Organization unit / branch *'),
                    _field('organization', 'Legal organization name *'),
                    TextFormField(
                      controller: fields['vat'],
                      keyboardType: TextInputType.number,
                      maxLength: 15,
                      decoration: const InputDecoration(
                        labelText: 'Saudi VAT number *',
                        counterText: '',
                      ),
                      validator: (value) =>
                          RegExp(r'^3\d{13}3$').hasMatch(value ?? '')
                          ? null
                          : 'Enter a valid 15-digit VAT number',
                    ),
                    _field('vatName', 'VAT display name'),
                    _field('crn', 'Commercial registration no.'),
                    DropdownButtonFormField<String>(
                      initialValue: invoiceType,
                      decoration: const InputDecoration(
                        labelText: 'Invoice type *',
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: '1100',
                          child: Text('Both standard & simplified'),
                        ),
                        DropdownMenuItem(
                          value: '0100',
                          child: Text('Simplified only'),
                        ),
                        DropdownMenuItem(
                          value: '1000',
                          child: Text('Standard only'),
                        ),
                      ],
                      onChanged: (value) => invoiceType = value ?? invoiceType,
                    ),
                    _field('category', 'Business category *'),
                  ]),
                  const SizedBox(height: 18),
                  const Text(
                    'Registered address',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 10),
                  _grid([
                    _field('address', 'National short address *'),
                    _field('street', 'Street'),
                    _field('building', 'Building number'),
                    _field('plot', 'Secondary / plot number'),
                    _field('district', 'District'),
                    _field('city', 'City'),
                    _field('postal', 'Postal code'),
                  ]),
                  if (error != null) ...[
                    const SizedBox(height: 14),
                    Text(
                      error!,
                      style: const TextStyle(
                        color: Color(0xFFC94B4B),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: saving ? null : () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 10),
                FilledButton.icon(
                  onPressed: saving ? null : _submit,
                  icon: saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.verified_user_outlined),
                  label: Text(saving ? 'Onboarding…' : 'Onboard device'),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  Widget _field(String key, String label) => TextFormField(
    controller: fields[key],
    decoration: InputDecoration(labelText: label),
    validator: label.endsWith('*') ? required : null,
  );
  Widget _grid(List<Widget> children) => LayoutBuilder(
    builder: (_, constraints) => Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        for (final child in children)
          SizedBox(
            width: constraints.maxWidth >= 720
                ? (constraints.maxWidth - 24) / 3
                : constraints.maxWidth,
            child: child,
          ),
      ],
    ),
  );
  Future<void> _submit() async {
    if (!(formKey.currentState?.validate() ?? false)) return;
    setState(() {
      saving = true;
      error = null;
    });
    try {
      await ref
          .read(zatcaControllerProvider.notifier)
          .onboard(
            widget.location.id,
            ZatcaOnboardingDraft(
              portalMode: portalMode,
              otp: fields['otp']!.text,
              email: fields['email']!.text.trim(),
              commonName: fields['common']!.text.trim(),
              organizationUnitName: fields['unit']!.text.trim(),
              organizationName: fields['organization']!.text.trim(),
              vatNumber: fields['vat']!.text.trim(),
              vatName: fields['vatName']!.text.trim(),
              invoiceType: invoiceType,
              registeredAddress: fields['address']!.text.trim(),
              businessCategory: fields['category']!.text.trim(),
              crn: fields['crn']!.text.trim(),
              streetName: fields['street']!.text.trim(),
              buildingNumber: fields['building']!.text.trim(),
              plotIdentification: fields['plot']!.text.trim(),
              subDivisionName: fields['district']!.text.trim(),
              cityName: fields['city']!.text.trim(),
              postalNumber: fields['postal']!.text.trim(),
            ),
          );
      fields['otp']!.clear();
      if (mounted) Navigator.pop(context);
    } catch (exception) {
      fields['otp']!.clear();
      if (mounted)
        setState(() {
          saving = false;
          error = exception.toString();
        });
    }
  }
}

class _ZatcaError extends StatelessWidget {
  const _ZatcaError({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 520),
      child: Surface(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_outlined,
              size: 42,
              color: Color(0xFFC94B4B),
            ),
            const SizedBox(height: 12),
            const Text(
              'Unable to load ZATCA integration',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.muted),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    ),
  );
}

Future<void> showZatcaInvoiceDialog(
  BuildContext context,
  WidgetRef ref,
  Sale sale,
) async {
  final saleId = sale.serverId;
  if (saleId == null || saleId.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('This sale has no server transaction ID.')),
    );
    return;
  }
  await showDialog<void>(
    context: context,
    builder: (_) => _InvoiceDialog(sale: sale),
  );
}

class _InvoiceDialog extends ConsumerStatefulWidget {
  const _InvoiceDialog({required this.sale});
  final Sale sale;
  @override
  ConsumerState<_InvoiceDialog> createState() => _InvoiceDialogState();
}

class _InvoiceDialogState extends ConsumerState<_InvoiceDialog> {
  late Future<ZatcaInvoiceStatus> future;
  bool working = false;
  @override
  void initState() {
    super.initState();
    future = ref
        .read(zatcaControllerProvider.notifier)
        .invoiceStatus(widget.sale.serverId!);
  }

  void reload() => setState(
    () => future = ref
        .read(zatcaControllerProvider.notifier)
        .invoiceStatus(widget.sale.serverId!),
  );
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Row(
      children: [
        const Icon(Icons.verified_user_outlined, color: AppColors.primary),
        const SizedBox(width: 10),
        Expanded(child: Text('ZATCA • ${widget.sale.invoiceNo}')),
      ],
    ),
    content: SizedBox(
      width: 560,
      child: FutureBuilder<ZatcaInvoiceStatus>(
        future: future,
        builder: (_, snapshot) {
          if (snapshot.connectionState != ConnectionState.done)
            return const SizedBox(
              height: 180,
              child: Center(child: CircularProgressIndicator()),
            );
          if (snapshot.hasError)
            return SizedBox(
              height: 180,
              child: _ZatcaError(
                message: snapshot.error.toString(),
                onRetry: reload,
              ),
            );
          final data = snapshot.data!;
          final document = data.document;
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text(
                    'Submission status',
                    style: TextStyle(color: AppColors.muted),
                  ),
                  const Spacer(),
                  StatusBadge(
                    data.status,
                    color: data.status == 'success'
                        ? AppColors.primary
                        : data.status == 'failed'
                        ? const Color(0xFFC94B4B)
                        : const Color(0xFFB7791F),
                  ),
                ],
              ),
              const Divider(height: 28),
              _detail('ICV', document?.icv ?? 'Not generated'),
              _detail('UUID', document?.uuid ?? 'Not generated'),
              _detail('Environment', document?.portalMode ?? '—'),
              _detail('Signing time', document?.signingTime ?? '—'),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: working ? null : _sync,
                    icon: const Icon(Icons.sync),
                    label: Text(
                      data.status == 'success'
                          ? 'Check / resubmit'
                          : 'Submit / retry',
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: document == null || working ? null : _showQr,
                    icon: const Icon(Icons.qr_code_2),
                    label: const Text('QR payload'),
                  ),
                  OutlinedButton.icon(
                    onPressed: document == null || working
                        ? null
                        : _downloadXml,
                    icon: const Icon(Icons.code),
                    label: const Text('XML'),
                  ),
                  OutlinedButton.icon(
                    onPressed: document == null || working
                        ? null
                        : _downloadPdf,
                    icon: const Icon(Icons.picture_as_pdf_outlined),
                    label: const Text('PDF/A-3'),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    ),
    actions: [
      TextButton(
        onPressed: working ? null : () => Navigator.pop(context),
        child: const Text('Close'),
      ),
    ],
  );
  Widget _detail(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110,
          child: Text(label, style: const TextStyle(color: AppColors.muted)),
        ),
        Expanded(child: SelectableText(value)),
      ],
    ),
  );
  Future<void> _run(Future<void> Function() action) async {
    setState(() => working = true);
    try {
      await action();
    } on ApiException catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => working = false);
    }
  }

  Future<void> _sync() => _run(() async {
    final result = await ref
        .read(zatcaControllerProvider.notifier)
        .syncInvoice(widget.sale.serverId!);
    if (mounted)
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result.message)));
    reload();
  });
  Future<void> _showQr() => _run(() async {
    final qr = await ref
        .read(zatcaControllerProvider.notifier)
        .qr(widget.sale.serverId!);
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('ZATCA QR payload'),
        content: SizedBox(width: 460, child: SelectableText(qr.value)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  });
  Future<void> _downloadXml() => _run(() async {
    final file = await ref
        .read(zatcaControllerProvider.notifier)
        .downloadXml(widget.sale.serverId!);
    await FilePicker.platform.saveFile(
      dialogTitle: 'Save signed ZATCA XML',
      fileName: file.fileName,
      bytes: file.bytes,
    );
  });
  Future<void> _downloadPdf() => _run(() async {
    final file = await ref
        .read(zatcaControllerProvider.notifier)
        .downloadPdf(widget.sale.serverId!);
    await Printing.sharePdf(bytes: file.bytes, filename: file.fileName);
  });
}
