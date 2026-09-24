import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/network/api_provider.dart';
import '../../../core/utils/money.dart';
import '../../../apis/api.dart' show ApiException;
import '../../../shared/models/entities.dart';
import '../../../shared/widgets/localized_text.dart';
import '../../auth/auth_controller.dart';
import '../../home/module_screens.dart' show PagePad;
import '../../store/app_store.dart';
import 'kitchen_pos_screen.dart' show kitchenOrdersProvider;
import 'kitchen_settings_panel.dart';

final restaurantTablesProvider = FutureProvider.autoDispose
    .family<List<RestaurantTable>, String>((ref, location) async {
      final token = await ref.watch(authControllerProvider.future);
      if (token == null || token.isEmpty || token == 'offline-local-session') {
        throw const ApiException(
          'Restaurant tables require an online session.',
        );
      }
      final api = ref.read(apiProvider);
      try {
        return await api.restaurantTables(token, location);
      } on ApiException catch (error) {
        if (error.statusCode != 401) rethrow;
        final refreshed = await ref
            .read(authControllerProvider.notifier)
            .refreshAccessToken();
        return api.restaurantTables(refreshed, location);
      }
    });

final restaurantModifierGroupsProvider = FutureProvider.autoDispose((
  ref,
) async {
  final token = await ref.watch(authControllerProvider.future);
  if (token == null || token.isEmpty || token == 'offline-local-session') {
    throw const ApiException('Modifier settings require an online session.');
  }
  final api = ref.read(apiProvider);
  try {
    return await api.modifierGroups(token);
  } on ApiException catch (error) {
    if (error.statusCode != 401) rethrow;
    final refreshed = await ref
        .read(authControllerProvider.notifier)
        .refreshAccessToken();
    return api.modifierGroups(refreshed);
  }
});

final restaurantModifierAccessProvider = FutureProvider.autoDispose((
  ref,
) async {
  final token = await ref.watch(authControllerProvider.future);
  if (token == null || token.isEmpty || token == 'offline-local-session') {
    throw const ApiException('Modifier settings require an online session.');
  }
  final api = ref.read(apiProvider);
  try {
    return await api.connectorAccess(token);
  } on ApiException catch (error) {
    if (error.statusCode != 401) rethrow;
    final refreshed = await ref
        .read(authControllerProvider.notifier)
        .refreshAccessToken();
    return api.connectorAccess(refreshed);
  }
});

enum _RestaurantView { orders, tables, modifiers, printing }

class RestaurantScreen extends ConsumerStatefulWidget {
  const RestaurantScreen({super.key});
  @override
  ConsumerState<RestaurantScreen> createState() => _RestaurantScreenState();
}

class _RestaurantScreenState extends ConsumerState<RestaurantScreen> {
  String? _location;
  _RestaurantView _view = _RestaurantView.orders;

  @override
  Widget build(BuildContext context) {
    final locations = ref.watch(
      appStoreProvider.select((state) => state.locations),
    );
    final location = locations.any((item) => item.id == _location)
        ? _location!
        : locations.firstOrNull?.id;
    return PagePad(
      child: ListView(
        children: [
          Text('Restaurant', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          const Text(
            'Create kitchen orders, browse ERP tables and manage kitchen printing.',
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                onPressed: () => context.go('/kitchen-pos'),
                icon: const Icon(Icons.restaurant),
                label: const Text('Open Kitchen POS'),
              ),
              OutlinedButton.icon(
                onPressed: () => setState(() => _view = _RestaurantView.orders),
                icon: Icon(
                  _view == _RestaurantView.orders
                      ? Icons.check
                      : Icons.receipt_long_outlined,
                ),
                label: const Text('Kitchen orders'),
              ),
              OutlinedButton.icon(
                onPressed: () => setState(() => _view = _RestaurantView.tables),
                icon: Icon(
                  _view == _RestaurantView.tables
                      ? Icons.check
                      : Icons.table_restaurant_outlined,
                ),
                label: const Text('Tables'),
              ),
              OutlinedButton.icon(
                onPressed: () =>
                    setState(() => _view = _RestaurantView.modifiers),
                icon: Icon(
                  _view == _RestaurantView.modifiers
                      ? Icons.check
                      : Icons.tune_rounded,
                ),
                label: const Text('Modifiers'),
              ),
              OutlinedButton.icon(
                onPressed: () =>
                    setState(() => _view = _RestaurantView.printing),
                icon: Icon(
                  _view == _RestaurantView.printing
                      ? Icons.check
                      : Icons.print_outlined,
                ),
                label: const Text('Kitchen printing'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (_view == _RestaurantView.printing)
            KitchenSettingsPanel(locations: locations)
          else if (_view == _RestaurantView.modifiers)
            _modifierGroups()
          else if (location == null)
            const Text('No business locations are available.')
          else if (_view == _RestaurantView.orders)
            _kitchenOrders(location, locations)
          else ...[
            DropdownButtonFormField<String>(
              key: ValueKey(location),
              initialValue: location,
              decoration: InputDecoration(
                labelText: context.tr('Business location'),
              ),
              items: locations
                  .map(
                    (item) => DropdownMenuItem(
                      value: item.id,
                      child: Text(item.name),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() => _location = value),
            ),
            const SizedBox(height: 12),
            const Text(
              'Tables are managed in EazyERP. Occupancy and booking status are not provided by this API.',
            ),
            const SizedBox(height: 12),
            ref
                .watch(restaurantTablesProvider(location))
                .when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (error, _) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(error.toString()),
                      TextButton(
                        onPressed: () =>
                            ref.invalidate(restaurantTablesProvider(location)),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                  data: (tables) => Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: IconButton(
                          tooltip: context.tr('Refresh'),
                          icon: const Icon(Icons.refresh),
                          onPressed: () => ref.invalidate(
                            restaurantTablesProvider(location),
                          ),
                        ),
                      ),
                      if (tables.isEmpty)
                        const Text(
                          'No restaurant tables are configured for this location.',
                        ),
                      for (final table in tables)
                        Card(
                          child: ListTile(
                            leading: const Icon(
                              Icons.table_restaurant_outlined,
                            ),
                            title: Text(table.name),
                            subtitle: table.description.isEmpty
                                ? null
                                : Text(table.description),
                          ),
                        ),
                    ],
                  ),
                ),
          ],
        ],
      ),
    );
  }

  Widget _kitchenOrders(String location, List<BusinessLocation> locations) {
    final orders = ref.watch(kitchenOrdersProvider(location));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                key: ValueKey('kitchen-orders-$location'),
                initialValue: location,
                decoration: InputDecoration(
                  labelText: context.tr('Business location'),
                ),
                items: locations
                    .map(
                      (item) => DropdownMenuItem(
                        value: item.id,
                        child: Text(item.name),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() => _location = value),
              ),
            ),
            const SizedBox(width: 10),
            IconButton.filledTonal(
              tooltip: context.tr('Refresh'),
              onPressed: () => ref.invalidate(kitchenOrdersProvider(location)),
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        const SizedBox(height: 16),
        orders.when(
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(),
            ),
          ),
          error: (error, _) => Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const Icon(Icons.cloud_off_outlined, size: 36),
                  const SizedBox(height: 8),
                  const Text('Unable to load kitchen orders.'),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () =>
                        ref.invalidate(kitchenOrdersProvider(location)),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
          data: (items) {
            final sorted = [...items]
              ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
            if (sorted.isEmpty) {
              return Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 48),
                  child: Column(
                    children: [
                      const Icon(Icons.receipt_long_outlined, size: 42),
                      const SizedBox(height: 10),
                      Text(
                        'No kitchen orders yet',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Orders sent from Kitchen POS will appear here.',
                      ),
                    ],
                  ),
                ),
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '${sorted.length} kitchen order${sorted.length == 1 ? '' : 's'}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 10),
                for (final order in sorted)
                  Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: order.status == 'draft'
                                ? const Color(0xFFFFE9B8)
                                : const Color(0xFFDDF3EC),
                            foregroundColor: order.status == 'draft'
                                ? const Color(0xFF8A5A00)
                                : const Color(0xFF08745D),
                            child: Icon(
                              order.status == 'draft'
                                  ? Icons.pause_rounded
                                  : Icons.restaurant_rounded,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  order.invoiceNo.isEmpty
                                      ? 'Order #${order.serverId ?? order.localId}'
                                      : order.invoiceNo,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${order.customer.name} • ${order.items.length} item${order.items.length == 1 ? '' : 's'} • ${DateFormat('dd MMM yyyy, hh:mm a').format(order.createdAt.toLocal())}',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              RiyalAmount(
                                order.total,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                order.status == 'draft' ? 'Held' : 'Sent',
                                style: TextStyle(
                                  color: order.status == 'draft'
                                      ? const Color(0xFF8A5A00)
                                      : const Color(0xFF08745D),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _modifierGroups() => ref
      .watch(restaurantModifierGroupsProvider)
      .when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(error.toString()),
            TextButton.icon(
              onPressed: () => ref.invalidate(restaurantModifierGroupsProvider),
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
        data: (groups) {
          final products = ref.watch(
            appStoreProvider.select((state) => state.products),
          );
          final access = ref.watch(restaurantModifierAccessProvider);
          final canCreate =
              access.asData?.value.allows('product.create') == true;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Create modifier groups, configure their rules and assign them to POS products.',
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: canCreate ? _createGroup : null,
                    icon: const Icon(Icons.add),
                    label: const Text('New group'),
                  ),
                  IconButton(
                    tooltip: context.tr('Refresh'),
                    onPressed: () =>
                        ref.invalidate(restaurantModifierGroupsProvider),
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (access.hasError)
                Text(
                  'Account permissions could not be loaded. Refresh and try again.',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                )
              else if (access.hasValue && !canCreate)
                const Text(
                  'Creating modifier groups requires the product.create permission.',
                ),
              if ((access.hasError || (access.hasValue && !canCreate)))
                const SizedBox(height: 12),
              if (groups.isEmpty)
                const Text('No modifier groups are configured.'),
              for (final group in groups)
                Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    leading: CircleAvatar(
                      child: Text('${group.options.length}'),
                    ),
                    title: Text(group.name),
                    subtitle: Text(
                      context.isArabic
                          ? '${group.isRequired ? 'مطلوب' : 'اختياري'} • '
                                'الحد الأدنى ${group.minSelections} • '
                                'الحد الأقصى ${group.maxSelections?.toString() ?? 'بلا حد'} • '
                                '${products.where((product) => product.modifierGroups.any((item) => item.id == group.id)).length} منتج'
                          : '${group.isRequired ? 'Required' : 'Optional'} • '
                                '${group.minSelections} min • '
                                '${group.maxSelections?.toString() ?? 'No'} max • '
                                '${products.where((product) => product.modifierGroups.any((item) => item.id == group.id)).length} products',
                    ),
                    trailing: PopupMenuButton<String>(
                      tooltip: 'Modifier actions',
                      onSelected: (value) {
                        if (value == 'assign') {
                          _assignGroup(group, groups, products);
                        } else {
                          _editGroup(group);
                        }
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(
                          value: 'configure',
                          child: Text('Configure'),
                        ),
                        PopupMenuItem(
                          value: 'assign',
                          child: Text('Assign products'),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      );

  Future<void> _createGroup() async {
    final draft = await showDialog<_ModifierGroupDraft>(
      context: context,
      builder: (_) => const _CreateModifierGroupDialog(),
    );
    if (draft == null || !mounted) return;
    try {
      await ref
          .read(apiProvider)
          .createModifierGroup(
            accessToken: await _token(),
            name: draft.name,
            sku: draft.sku,
            isActive: draft.isActive,
            isRequired: draft.isRequired,
            minSelections: draft.minSelections,
            maxSelections: draft.maxSelections,
            options: [
              for (final option in draft.options)
                (
                  name: option.name,
                  subSku: option.subSku,
                  priceAdjustment: option.priceAdjustment,
                  isActive: option.isActive,
                ),
            ],
          );
      ref.invalidate(restaurantModifierGroupsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Modifier group created.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }

  Future<String> _token() async {
    final token = await ref.read(authControllerProvider.future);
    if (token == null || token.isEmpty || token == 'offline-local-session') {
      throw const ApiException('Modifier settings require an online session.');
    }
    return token;
  }

  Future<void> _editGroup(ModifierGroup group) async {
    final updated = await showDialog<ModifierGroup>(
      context: context,
      builder: (_) => _ModifierGroupDialog(group: group),
    );
    if (updated == null || !mounted) return;
    try {
      await ref
          .read(apiProvider)
          .updateModifierGroup(accessToken: await _token(), group: updated);
      ref.invalidate(restaurantModifierGroupsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Modifier group updated.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }

  Future<void> _assignGroup(
    ModifierGroup group,
    List<ModifierGroup> groups,
    List<Product> products,
  ) async {
    final selected = await showDialog<Set<String>>(
      context: context,
      builder: (_) =>
          _ProductAssignmentDialog(group: group, products: products),
    );
    if (selected == null || !mounted) return;
    try {
      final token = await _token();
      final api = ref.read(apiProvider);
      for (final product in products) {
        final wasAssigned = product.modifierGroups.any(
          (item) => item.id == group.id,
        );
        final shouldAssign = selected.contains(product.id);
        if (wasAssigned == shouldAssign) continue;
        final ids = product.modifierGroups
            .where((item) => item.id != group.id)
            .map((item) => item.id)
            .toList();
        if (shouldAssign) ids.add(group.id);
        await api.assignProductModifierGroups(
          accessToken: token,
          productId: product.id,
          modifierGroupIds: ids,
        );
        ref
            .read(appStoreProvider.notifier)
            .upsertProduct(
              product.copyWith(
                modifierGroups: [
                  for (final id in ids)
                    groups.firstWhere((item) => item.id == id),
                ],
              ),
            );
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Product assignments updated.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }
}

class _ModifierGroupDraft {
  const _ModifierGroupDraft({
    required this.name,
    required this.sku,
    required this.isActive,
    required this.isRequired,
    required this.minSelections,
    required this.maxSelections,
    required this.options,
  });

  final String name, sku;
  final bool isActive, isRequired;
  final int minSelections;
  final int? maxSelections;
  final List<_ModifierOptionDraft> options;
}

class _ModifierOptionDraft {
  const _ModifierOptionDraft({
    required this.name,
    required this.subSku,
    required this.priceAdjustment,
    required this.isActive,
  });

  final String name, subSku;
  final int priceAdjustment;
  final bool isActive;
}

class _EditableModifierOption {
  _EditableModifierOption();

  final name = TextEditingController();
  final subSku = TextEditingController();
  final price = TextEditingController(text: '0.00');
  bool isActive = true;

  void dispose() {
    name.dispose();
    subSku.dispose();
    price.dispose();
  }
}

class _CreateModifierGroupDialog extends StatefulWidget {
  const _CreateModifierGroupDialog();

  @override
  State<_CreateModifierGroupDialog> createState() =>
      _CreateModifierGroupDialogState();
}

class _CreateModifierGroupDialogState
    extends State<_CreateModifierGroupDialog> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _sku = TextEditingController();
  final _minimum = TextEditingController(text: '0');
  final _maximum = TextEditingController();
  final List<_EditableModifierOption> _options = [_EditableModifierOption()];
  bool _active = true;
  bool _required = false;

  @override
  void dispose() {
    _name.dispose();
    _sku.dispose();
    _minimum.dispose();
    _maximum.dispose();
    for (final option in _options) {
      option.dispose();
    }
    super.dispose();
  }

  int? _wholeNumber(String value) => int.tryParse(value.trim());

  int? _money(String value) {
    final amount = double.tryParse(value.trim());
    return amount == null ? null : (amount * 100).round();
  }

  void _addOption() => setState(() => _options.add(_EditableModifierOption()));

  void _removeOption(int index) {
    if (_options.length == 1) return;
    final removed = _options.removeAt(index);
    removed.dispose();
    setState(() {});
  }

  void _submit() {
    if (_formKey.currentState?.validate() != true) return;
    final min = _wholeNumber(_minimum.text) ?? 0;
    final max = _maximum.text.trim().isEmpty
        ? null
        : _wholeNumber(_maximum.text);
    if (max != null && max < min) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Maximum selections cannot be below the minimum.'),
        ),
      );
      return;
    }
    if (_required && max != null && max < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('A required group must allow at least one selection.'),
        ),
      );
      return;
    }
    final activeOptions = _options.where((option) => option.isActive).length;
    if (min > activeOptions || (max != null && max > activeOptions)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selection limits must fit the enabled options.'),
        ),
      );
      return;
    }
    Navigator.of(context).pop(
      _ModifierGroupDraft(
        name: _name.text.trim(),
        sku: _sku.text.trim(),
        isActive: _active,
        isRequired: _required,
        minSelections: min,
        maxSelections: max,
        options: [
          for (final option in _options)
            _ModifierOptionDraft(
              name: option.name.text.trim(),
              subSku: option.subSku.text.trim(),
              priceAdjustment: _money(option.price.text) ?? 0,
              isActive: option.isActive,
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Create modifier group'),
    content: SizedBox(
      width: 620,
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _name,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Group name *'),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Enter a group name.'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _sku,
                decoration: const InputDecoration(
                  labelText: 'Group SKU (optional)',
                  helperText: 'A unique SKU is generated when left blank.',
                ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Active in POS'),
                value: _active,
                onChanged: (value) => setState(() => _active = value),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Selection required'),
                value: _required,
                onChanged: (value) => setState(() {
                  _required = value;
                  if (value && (_wholeNumber(_minimum.text) ?? 0) == 0) {
                    _minimum.text = '1';
                  }
                }),
              ),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _minimum,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Minimum selections',
                      ),
                      validator: (value) {
                        final number = _wholeNumber(value ?? '');
                        return number == null || number < 0
                            ? 'Enter 0 or more.'
                            : null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _maximum,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Maximum selections',
                        hintText: 'No limit',
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) return null;
                        final number = _wholeNumber(value);
                        return number == null || number < 0
                            ? 'Enter 0 or more.'
                            : null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Options',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _addOption,
                    icon: const Icon(Icons.add),
                    label: const Text('Add option'),
                  ),
                ],
              ),
              for (var index = 0; index < _options.length; index++)
                _optionCard(index),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancel'),
      ),
      FilledButton(onPressed: _submit, child: const Text('Create group')),
    ],
  );

  Widget _optionCard(int index) {
    final option = _options[index];
    return Card(
      margin: const EdgeInsets.only(top: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Option ${index + 1}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton(
                  tooltip: 'Remove option',
                  onPressed: _options.length == 1
                      ? null
                      : () => _removeOption(index),
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
            TextFormField(
              controller: option.name,
              decoration: const InputDecoration(labelText: 'Option name *'),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Enter an option name.'
                  : null,
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    controller: option.subSku,
                    decoration: const InputDecoration(
                      labelText: 'Option SKU (optional)',
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    controller: option.price,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Price adjustment',
                    ),
                    validator: (value) {
                      final amount = _money(value ?? '');
                      return amount == null || amount < 0
                          ? 'Enter a valid price.'
                          : null;
                    },
                  ),
                ),
              ],
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Option active'),
              value: option.isActive,
              onChanged: (value) => setState(() => option.isActive = value),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModifierGroupDialog extends StatefulWidget {
  const _ModifierGroupDialog({required this.group});

  final ModifierGroup group;

  @override
  State<_ModifierGroupDialog> createState() => _ModifierGroupDialogState();
}

class _ModifierGroupDialogState extends State<_ModifierGroupDialog> {
  late bool _active = widget.group.isActive;
  late bool _required = widget.group.isRequired;
  late int _minimum = widget.group.minSelections;
  late int? _maximum = widget.group.maxSelections;
  late final Set<String> _activeOptions = widget.group.options
      .where((option) => option.isActive)
      .map((option) => option.variationId)
      .toSet();

  @override
  Widget build(BuildContext context) {
    final availableCount = _activeOptions.length;
    final selectionCeiling = [
      availableCount,
      _minimum,
      _maximum ?? 0,
    ].reduce((left, right) => left > right ? left : right);
    final invalid =
        _minimum > availableCount ||
        (_maximum != null &&
            (_maximum! < _minimum || _maximum! > availableCount));
    return AlertDialog(
      title: Text('${context.tr('Configure')} ${widget.group.name}'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 600),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Active in POS'),
                value: _active,
                onChanged: (value) => setState(() => _active = value),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Selection required'),
                value: _required,
                onChanged: (value) => setState(() {
                  _required = value;
                  if (value && _minimum == 0) _minimum = 1;
                }),
              ),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: _minimum.clamp(0, availableCount),
                      decoration: const InputDecoration(
                        labelText: 'Minimum selections',
                      ),
                      items: [
                        for (var value = 0; value <= selectionCeiling; value++)
                          DropdownMenuItem(value: value, child: Text('$value')),
                      ],
                      onChanged: (value) =>
                          setState(() => _minimum = value ?? 0),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<int?>(
                      initialValue: _maximum,
                      decoration: const InputDecoration(
                        labelText: 'Maximum selections',
                      ),
                      items: [
                        const DropdownMenuItem<int?>(
                          value: null,
                          child: Text('No limit'),
                        ),
                        for (var value = 1; value <= selectionCeiling; value++)
                          DropdownMenuItem<int?>(
                            value: value,
                            child: Text('$value'),
                          ),
                      ],
                      onChanged: (value) => setState(() => _maximum = value),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  'Available options',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              for (final option in widget.group.options)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _activeOptions.contains(option.variationId),
                  title: Text(option.name),
                  subtitle: option.subSku.isEmpty ? null : Text(option.subSku),
                  onChanged: (value) => setState(() {
                    if (value == true) {
                      _activeOptions.add(option.variationId);
                    } else {
                      _activeOptions.remove(option.variationId);
                    }
                  }),
                ),
              if (invalid)
                const Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    'Selection limits must fit the enabled options.',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: invalid
              ? null
              : () => Navigator.of(context).pop(
                  ModifierGroup(
                    id: widget.group.id,
                    name: widget.group.name,
                    isActive: _active,
                    isRequired: _required,
                    minSelections: _minimum,
                    maxSelections: _maximum,
                    options: [
                      for (final option in widget.group.options)
                        ModifierOption(
                          variationId: option.variationId,
                          name: option.name,
                          subSku: option.subSku,
                          isActive: _activeOptions.contains(option.variationId),
                          isAvailable: option.isAvailable,
                          priceAdjustment: option.priceAdjustment,
                          priceIncludesTax: option.priceIncludesTax,
                        ),
                    ],
                  ),
                ),
          child: const Text('Save changes'),
        ),
      ],
    );
  }
}

class _ProductAssignmentDialog extends StatefulWidget {
  const _ProductAssignmentDialog({required this.group, required this.products});

  final ModifierGroup group;
  final List<Product> products;

  @override
  State<_ProductAssignmentDialog> createState() =>
      _ProductAssignmentDialogState();
}

class _ProductAssignmentDialogState extends State<_ProductAssignmentDialog> {
  late final Set<String> _selected = widget.products
      .where(
        (product) =>
            product.modifierGroups.any((group) => group.id == widget.group.id),
      )
      .map((product) => product.id)
      .toSet();
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final products = widget.products
        .where(
          (product) =>
              product.name.toLowerCase().contains(_query.trim().toLowerCase()),
        )
        .toList(growable: false);
    return AlertDialog(
      title: Text('${context.tr('Assign products')}: ${widget.group.name}'),
      content: SizedBox(
        width: 520,
        height: 520,
        child: Column(
          children: [
            TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search products',
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: products.length,
                itemBuilder: (_, index) {
                  final product = products[index];
                  return CheckboxListTile(
                    value: _selected.contains(product.id),
                    title: Text(product.name),
                    subtitle: Text(product.sku),
                    onChanged: (value) => setState(() {
                      if (value == true) {
                        _selected.add(product.id);
                      } else {
                        _selected.remove(product.id);
                      }
                    }),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_selected),
          child: const Text('Save assignments'),
        ),
      ],
    );
  }
}
