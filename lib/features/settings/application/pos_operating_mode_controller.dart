import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../apis/api.dart';
import '../../../core/network/api_provider.dart';
import '../../../shared/models/entities.dart';
import '../../auth/auth_controller.dart';

enum PosOperatingMode { retail, kitchen, fuel, van }

class PosRoleAccess {
  const PosRoleAccess(this.access);
  final ConnectorAccess access;

  String _normalizeRole(String role) => role
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[_-]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ');

  bool get isVanSalesUser =>
      !access.isAdmin &&
      access.roles.any(
        (role) => const {
          'van',
          'van pos',
          'van sale',
          'van sales',
        }.contains(_normalizeRole(role)),
      );

  bool allowsAny(Iterable<String> permissions) =>
      access.isAdmin || permissions.any(access.permissions.contains);

  bool get canUseVanSales =>
      isVanSalesUser && allowsAny(const {'sell.view', 'sell.create'});

  bool get canViewVanSuppliers =>
      isVanSalesUser &&
      allowsAny(const {
        'supplier.view',
        'suppliers.view',
        'purchase.view',
        'purchases.view',
      });

  bool allows(PosOperatingMode mode) {
    if (access.isAdmin) return true;
    if (!access.hasRoleData) return false;
    const names = {
      PosOperatingMode.retail: {'retail', 'retail pos', 'retail sales'},
      PosOperatingMode.kitchen: {
        'kitchen',
        'kitchen pos',
        'restaurant',
        'restaurant pos',
      },
      PosOperatingMode.fuel: {'fuel', 'fuel pos', 'fuel station', 'fuel sales'},
      PosOperatingMode.van: {'van', 'van pos', 'van sale', 'van sales'},
    };
    return access.roles.any(
      (role) => names[mode]!.contains(_normalizeRole(role)),
    );
  }

  PosOperatingMode? effectiveMode(PosOperatingMode preferred) {
    if (allows(preferred)) return preferred;
    for (final mode in PosOperatingMode.values) {
      if (allows(mode)) return mode;
    }
    return null;
  }
}

final posRoleAccessProvider = FutureProvider<PosRoleAccess>((ref) async {
  final token = await ref.watch(authControllerProvider.future);
  if (token == null || token.isEmpty) {
    throw const ApiException('Sign in to access POS.');
  }
  if (token == 'offline-local-session') {
    return const PosRoleAccess(
      ConnectorAccess(isAdmin: false, permissions: {}, hasRoleData: true),
    );
  }
  final access = await ref.read(apiProvider).connectorAccess(token);
  return PosRoleAccess(access);
});

const fuelPosEnabled = true;

extension PosOperatingModeDetails on PosOperatingMode {
  String get route => switch (this) {
    PosOperatingMode.retail => '/pos',
    PosOperatingMode.kitchen => '/kitchen-pos',
    PosOperatingMode.fuel => '/fuel-pos',
    PosOperatingMode.van => '/van-pos',
  };

  String get label => switch (this) {
    PosOperatingMode.retail => 'Retail POS',
    PosOperatingMode.kitchen => 'Kitchen POS',
    PosOperatingMode.fuel => 'Fuel POS',
    PosOperatingMode.van => 'Van POS',
  };
}

final posOperatingModeProvider =
    NotifierProvider<PosOperatingModeController, PosOperatingMode>(
      PosOperatingModeController.new,
    );

class PosOperatingModeController extends Notifier<PosOperatingMode> {
  static const _preferenceKey = 'eazy_pos_operating_mode';
  int _changeVersion = 0;

  @override
  PosOperatingMode build() {
    _restore(_changeVersion);
    return PosOperatingMode.retail;
  }

  Future<void> _restore(int version) async {
    final saved = (await SharedPreferences.getInstance()).getString(
      _preferenceKey,
    );
    final mode = PosOperatingMode.values.where(
      (item) =>
          item.name == saved &&
          (fuelPosEnabled || item != PosOperatingMode.fuel),
    );
    if (version == _changeVersion && mode.isNotEmpty && state != mode.first) {
      state = mode.first;
    } else if (version == _changeVersion &&
        saved == PosOperatingMode.fuel.name) {
      state = PosOperatingMode.retail;
      await (await SharedPreferences.getInstance()).setString(
        _preferenceKey,
        PosOperatingMode.retail.name,
      );
    }
  }

  Future<void> setMode(PosOperatingMode mode) async {
    if (!fuelPosEnabled && mode == PosOperatingMode.fuel) return;
    _changeVersion++;
    if (state != mode) state = mode;
    await (await SharedPreferences.getInstance()).setString(
      _preferenceKey,
      mode.name,
    );
  }
}
