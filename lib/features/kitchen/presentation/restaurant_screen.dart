import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/network/api_provider.dart';
import '../../../apis/api.dart' show ApiException;
import '../../../shared/models/entities.dart';
import '../../../shared/widgets/localized_text.dart';
import '../../auth/auth_controller.dart';
import '../../home/module_screens.dart' show PagePad;
import '../../store/app_store.dart';
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

enum _RestaurantView { tables, modifiers, printing }

class RestaurantScreen extends ConsumerStatefulWidget {
  const RestaurantScreen({super.key});
  @override
  ConsumerState<RestaurantScreen> createState() => _RestaurantScreenState();
}

class _RestaurantScreenState extends ConsumerState<RestaurantScreen> {
  String? _location;
  _RestaurantView _view = _RestaurantView.tables;

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
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Modifier groups are created in EazyERP. Configure their rules and assign them to POS products here.',
                    ),
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
              if (groups.isEmpty)
                const Text('No modifier groups are configured in EazyERP.'),
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
