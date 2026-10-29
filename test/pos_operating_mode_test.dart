import 'package:eazy_pos/features/settings/application/pos_operating_mode_controller.dart';
import 'package:eazy_pos/core/localization/app_localizations.dart';
import 'package:eazy_pos/core/theme/app_theme.dart';
import 'package:eazy_pos/features/home/module_screens.dart';
import 'package:eazy_pos/shared/models/entities.dart';
import 'package:eazy_pos/apis/api.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('POS operating mode persists per device', () async {
    final first = ProviderContainer();
    addTearDown(first.dispose);

    expect(first.read(posOperatingModeProvider), PosOperatingMode.retail);
    await first
        .read(posOperatingModeProvider.notifier)
        .setMode(PosOperatingMode.kitchen);
    expect(first.read(posOperatingModeProvider), PosOperatingMode.kitchen);
    expect(PosOperatingMode.kitchen.route, '/kitchen-pos');

    final second = ProviderContainer();
    addTearDown(second.dispose);
    second.read(posOperatingModeProvider);
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(second.read(posOperatingModeProvider), PosOperatingMode.kitchen);
    await second
        .read(posOperatingModeProvider.notifier)
        .setMode(PosOperatingMode.van);
    expect(second.read(posOperatingModeProvider), PosOperatingMode.van);
    expect(PosOperatingMode.van.route, '/van-pos');
  });

  testWidgets('settings exposes a responsive device mode selector', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final container = ProviderContainer(
      overrides: [
        posRoleAccessProvider.overrideWith(
          (ref) async => const PosRoleAccess(
            ConnectorAccess(isAdmin: true, permissions: {}, hasRoleData: true),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: buildTheme(compact: true),
          localizationsDelegates: const [AppLocalizations.delegate],
          supportedLocales: const [Locale('en'), Locale('ar')],
          home: const Scaffold(body: SettingsScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('POS operating mode'), findsOneWidget);
    expect(find.text('Retail POS'), findsOneWidget);
    expect(find.text('Kitchen POS'), findsOneWidget);
    expect(find.text('Fuel POS'), findsOneWidget);
    expect(find.text('Van POS'), findsOneWidget);
    await tester.tap(find.text('Kitchen POS'));
    await tester.pumpAndSettle();
    expect(container.read(posOperatingModeProvider), PosOperatingMode.kitchen);
    await tester.tap(find.text('Fuel POS'));
    await tester.pumpAndSettle();
    expect(container.read(posOperatingModeProvider), PosOperatingMode.fuel);
    await tester.ensureVisible(find.text('Van POS'));
    await tester.tap(find.text('Van POS'));
    await tester.pumpAndSettle();
    expect(container.read(posOperatingModeProvider), PosOperatingMode.van);
    expect(tester.takeException(), isNull);
  });

  test(
    'POS roles allow only their assigned workspace and admins can use all',
    () {
      const van = PosRoleAccess(
        ConnectorAccess(
          isAdmin: false,
          permissions: {'sell.view', 'sell.create'},
          roles: ['Van Sales'],
          hasRoleData: true,
        ),
      );
      expect(van.allows(PosOperatingMode.van), isTrue);
      expect(van.allows(PosOperatingMode.kitchen), isFalse);
      expect(van.allows(PosOperatingMode.retail), isFalse);
      expect(van.effectiveMode(PosOperatingMode.retail), PosOperatingMode.van);
      expect(van.isVanSalesUser, isTrue);
      expect(van.canUseVanSales, isTrue);
      expect(van.canViewVanSuppliers, isFalse);

      const vanPurchaser = PosRoleAccess(
        ConnectorAccess(
          isAdmin: false,
          permissions: {'sell.view', 'purchase.view'},
          roles: ['VAN SALE'],
          hasRoleData: true,
        ),
      );
      expect(vanPurchaser.isVanSalesUser, isTrue);
      expect(vanPurchaser.allows(PosOperatingMode.van), isTrue);
      expect(vanPurchaser.canViewVanSuppliers, isTrue);

      const noRoles = PosRoleAccess(
        ConnectorAccess(isAdmin: false, permissions: {}, hasRoleData: true),
      );
      expect(noRoles.effectiveMode(PosOperatingMode.retail), isNull);

      const admin = PosRoleAccess(
        ConnectorAccess(isAdmin: true, permissions: {}, hasRoleData: true),
      );
      for (final mode in PosOperatingMode.values) {
        expect(admin.allows(mode), isTrue);
      }
    },
  );

  test('auth context reads role names from the session user', () async {
    final api = Api(
      client: MockClient((request) async {
        expect(request.url.path, '/connector/api/auth/context');
        return http.Response(
          '{"data":{"user":{"roles":[{"id":12,"name":"Van Sales"}]},"is_admin":false,"permissions":["sell.view"],"allowed_location_ids":[3,48],"default_location_id":48}}',
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    final access = await api.connectorAccess('token');
    expect(access.roles, ['Van Sales']);
    expect(access.hasRoleData, isTrue);
    expect(PosRoleAccess(access).allows(PosOperatingMode.van), isTrue);
    expect(PosRoleAccess(access).allows(PosOperatingMode.retail), isFalse);
    expect(access.allowedLocationIds, {'3', '48'});
    expect(access.defaultLocationId, '48');
    expect(access.allowsLocation('48'), isTrue);
    expect(access.allowsLocation('2'), isFalse);
  });
}
