import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../shared/models/entities.dart';

final paymentMethodSettingsProvider =
    NotifierProvider<PaymentMethodSettingsController, PaymentMethodSettings>(
      PaymentMethodSettingsController.new,
    );

class PaymentMethodSettings {
  const PaymentMethodSettings({
    this.disabledCodes = const {},
    this.order = const [],
    this.labels = const {},
  });

  final Set<String> disabledCodes;
  final List<String> order;
  final Map<String, String> labels;

  List<PaymentOption> apply(List<PaymentOption> options) {
    final byCode = <String, PaymentOption>{
      for (final option in options) option.code.toLowerCase(): option,
    };
    final ordered = <PaymentOption>[];
    for (final code in order) {
      final option = byCode.remove(code);
      if (option != null) ordered.add(option);
    }
    ordered.addAll(byCode.values);
    return ordered
        .where((option) => !disabledCodes.contains(option.code.toLowerCase()))
        .map(
          (option) => PaymentOption(
            code: option.code,
            label: labels[option.code.toLowerCase()] ?? option.label,
          ),
        )
        .toList(growable: false);
  }

  PaymentMethodSettings copyWith({
    Set<String>? disabledCodes,
    List<String>? order,
    Map<String, String>? labels,
  }) => PaymentMethodSettings(
    disabledCodes: disabledCodes ?? this.disabledCodes,
    order: order ?? this.order,
    labels: labels ?? this.labels,
  );

  Map<String, Object> toJson() => {
    'disabled_codes': disabledCodes.toList(),
    'order': order,
    'labels': labels,
  };

  factory PaymentMethodSettings.fromJson(Map<String, dynamic> json) =>
      PaymentMethodSettings(
        disabledCodes: (json['disabled_codes'] as List? ?? const [])
            .map((item) => item.toString().toLowerCase())
            .toSet(),
        order: (json['order'] as List? ?? const [])
            .map((item) => item.toString().toLowerCase())
            .toList(growable: false),
        labels: (json['labels'] as Map? ?? const {}).map(
          (key, value) =>
              MapEntry(key.toString().toLowerCase(), value.toString()),
        ),
      );
}

class PaymentMethodSettingsController extends Notifier<PaymentMethodSettings> {
  static const _preferenceKey = 'eazy_pos_payment_method_settings';
  var _changeVersion = 0;

  @override
  PaymentMethodSettings build() {
    _restore(_changeVersion);
    return const PaymentMethodSettings();
  }

  Future<void> _restore(int version) async {
    final raw = (await SharedPreferences.getInstance()).getString(
      _preferenceKey,
    );
    if (raw == null || raw.isEmpty || version != _changeVersion) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic> && version == _changeVersion) {
        state = PaymentMethodSettings.fromJson(decoded);
      }
    } on FormatException {
      // Ignore corrupt local preferences and retain safe defaults.
    }
  }

  Future<void> setEnabled(String code, bool enabled) async {
    final normalized = code.toLowerCase();
    final disabled = {...state.disabledCodes};
    enabled ? disabled.remove(normalized) : disabled.add(normalized);
    await _save(state.copyWith(disabledCodes: disabled));
  }

  Future<void> rename(String code, String? label) async {
    final normalized = code.toLowerCase();
    final labels = {...state.labels};
    final value = label?.trim() ?? '';
    value.isEmpty ? labels.remove(normalized) : labels[normalized] = value;
    await _save(state.copyWith(labels: labels));
  }

  Future<void> move(List<PaymentOption> available, int from, int to) async {
    if (from == to ||
        from < 0 ||
        to < 0 ||
        from >= available.length ||
        to >= available.length) {
      return;
    }
    final codes = available
        .map((option) => option.code.toLowerCase())
        .toList(growable: true);
    final item = codes.removeAt(from);
    codes.insert(to, item);
    await _save(state.copyWith(order: codes));
  }

  Future<void> reset() async {
    _changeVersion++;
    state = const PaymentMethodSettings();
    await (await SharedPreferences.getInstance()).remove(_preferenceKey);
  }

  Future<void> _save(PaymentMethodSettings value) async {
    _changeVersion++;
    state = value;
    await (await SharedPreferences.getInstance()).setString(
      _preferenceKey,
      jsonEncode(value.toJson()),
    );
  }
}
