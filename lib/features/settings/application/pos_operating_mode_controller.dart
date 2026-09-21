import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum PosOperatingMode { retail, kitchen }

extension PosOperatingModeDetails on PosOperatingMode {
  String get route => switch (this) {
    PosOperatingMode.retail => '/pos',
    PosOperatingMode.kitchen => '/kitchen-pos',
  };

  String get label => switch (this) {
    PosOperatingMode.retail => 'Retail POS',
    PosOperatingMode.kitchen => 'Kitchen POS',
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
    final mode = PosOperatingMode.values.where((item) => item.name == saved);
    if (version == _changeVersion && mode.isNotEmpty && state != mode.first) {
      state = mode.first;
    }
  }

  Future<void> setMode(PosOperatingMode mode) async {
    _changeVersion++;
    if (state != mode) state = mode;
    await (await SharedPreferences.getInstance()).setString(
      _preferenceKey,
      mode.name,
    );
  }
}
