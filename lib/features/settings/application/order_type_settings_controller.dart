import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const defaultPosOrderTypes = <PosOrderType>[
  PosOrderType(code: 'Dine in', label: 'Dine in'),
  PosOrderType(code: 'Takeaway', label: 'Takeaway'),
  PosOrderType(code: 'Delivery', label: 'Delivery'),
];

class PosOrderType {
  const PosOrderType({required this.code, required this.label});
  final String code, label;
}

final orderTypeSettingsProvider =
    NotifierProvider<OrderTypeSettingsController, OrderTypeSettings>(
      OrderTypeSettingsController.new,
    );

class OrderTypeSettings {
  const OrderTypeSettings({
    this.disabledCodes = const {},
    this.order = const [],
    this.labels = const {},
  });

  final Set<String> disabledCodes;
  final List<String> order;
  final Map<String, String> labels;

  List<PosOrderType> apply([
    List<PosOrderType> options = defaultPosOrderTypes,
  ]) {
    final byCode = {for (final option in options) option.code: option};
    final result = <PosOrderType>[];
    for (final code in order) {
      final option = byCode.remove(code);
      if (option != null) result.add(option);
    }
    result.addAll(byCode.values);
    return result
        .where((option) => !disabledCodes.contains(option.code))
        .map(
          (option) => PosOrderType(
            code: option.code,
            label: labels[option.code] ?? option.label,
          ),
        )
        .toList(growable: false);
  }

  OrderTypeSettings copyWith({
    Set<String>? disabledCodes,
    List<String>? order,
    Map<String, String>? labels,
  }) => OrderTypeSettings(
    disabledCodes: disabledCodes ?? this.disabledCodes,
    order: order ?? this.order,
    labels: labels ?? this.labels,
  );

  Map<String, Object> toJson() => {
    'disabled_codes': disabledCodes.toList(),
    'order': order,
    'labels': labels,
  };

  factory OrderTypeSettings.fromJson(Map<String, dynamic> json) =>
      OrderTypeSettings(
        disabledCodes: (json['disabled_codes'] as List? ?? const [])
            .map((item) => item.toString())
            .toSet(),
        order: (json['order'] as List? ?? const [])
            .map((item) => item.toString())
            .toList(growable: false),
        labels: (json['labels'] as Map? ?? const {}).map(
          (key, value) => MapEntry(key.toString(), value.toString()),
        ),
      );
}

class OrderTypeSettingsController extends Notifier<OrderTypeSettings> {
  static const _key = 'eazy_pos_order_type_settings';
  var _version = 0;

  @override
  OrderTypeSettings build() {
    _restore(_version);
    return const OrderTypeSettings();
  }

  Future<void> _restore(int version) async {
    final raw = (await SharedPreferences.getInstance()).getString(_key);
    if (raw == null || version != _version) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic> && version == _version) {
        state = OrderTypeSettings.fromJson(decoded);
      }
    } on FormatException {
      // Retain defaults when a local preference is corrupt.
    }
  }

  Future<void> restore() => _restore(_version);

  Future<void> setEnabled(String code, bool enabled) async {
    final disabled = {...state.disabledCodes};
    enabled ? disabled.remove(code) : disabled.add(code);
    await _save(state.copyWith(disabledCodes: disabled));
  }

  Future<void> rename(String code, String value) async {
    final labels = {...state.labels};
    final label = value.trim();
    label.isEmpty ? labels.remove(code) : labels[code] = label;
    await _save(state.copyWith(labels: labels));
  }

  Future<void> move(List<PosOrderType> options, int from, int to) async {
    if (from == to ||
        from < 0 ||
        to < 0 ||
        from >= options.length ||
        to >= options.length)
      return;
    final codes = options.map((item) => item.code).toList(growable: true);
    final item = codes.removeAt(from);
    codes.insert(to, item);
    await _save(state.copyWith(order: codes));
  }

  Future<void> reset() async {
    _version++;
    state = const OrderTypeSettings();
    await (await SharedPreferences.getInstance()).remove(_key);
  }

  Future<void> _save(OrderTypeSettings value) async {
    _version++;
    state = value;
    await (await SharedPreferences.getInstance()).setString(
      _key,
      jsonEncode(value.toJson()),
    );
  }
}
