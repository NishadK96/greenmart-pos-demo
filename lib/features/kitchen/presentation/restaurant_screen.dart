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

class RestaurantScreen extends ConsumerStatefulWidget {
  const RestaurantScreen({super.key});
  @override
  ConsumerState<RestaurantScreen> createState() => _RestaurantScreenState();
}

class _RestaurantScreenState extends ConsumerState<RestaurantScreen> {
  String? _location;
  bool _printing = false;

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
                onPressed: () => setState(() => _printing = false),
                icon: Icon(
                  _printing ? Icons.table_restaurant_outlined : Icons.check,
                ),
                label: const Text('Tables'),
              ),
              OutlinedButton.icon(
                onPressed: () => setState(() => _printing = true),
                icon: Icon(_printing ? Icons.check : Icons.print_outlined),
                label: const Text('Kitchen printing'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (_printing)
            KitchenSettingsPanel(locations: locations)
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
}
