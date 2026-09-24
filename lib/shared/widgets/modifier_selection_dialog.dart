import 'package:flutter/material.dart' hide Text;

import '../../core/theme/app_theme.dart';
import '../../core/utils/money.dart';
import '../models/entities.dart';
import 'localized_text.dart';

Future<List<SelectedModifier>?> selectProductModifiers(
  BuildContext context,
  Product product, {
  List<SelectedModifier> initialModifiers = const [],
  String confirmLabel = 'Add to order',
}) {
  final groups = product.modifierGroups
      .where((group) => group.isActive)
      .toList(growable: false);
  if (groups.isEmpty) return Future.value(const <SelectedModifier>[]);
  return showDialog<List<SelectedModifier>>(
    context: context,
    builder: (_) => _ModifierSelectionDialog(
      product: product,
      groups: groups,
      initialModifiers: initialModifiers,
      confirmLabel: confirmLabel,
    ),
  );
}

class _ModifierSelectionDialog extends StatefulWidget {
  const _ModifierSelectionDialog({
    required this.product,
    required this.groups,
    required this.initialModifiers,
    required this.confirmLabel,
  });

  final Product product;
  final List<ModifierGroup> groups;
  final List<SelectedModifier> initialModifiers;
  final String confirmLabel;

  @override
  State<_ModifierSelectionDialog> createState() =>
      _ModifierSelectionDialogState();
}

class _ModifierSelectionDialogState extends State<_ModifierSelectionDialog> {
  final Map<String, Set<String>> _selected = {};

  @override
  void initState() {
    super.initState();
    for (final modifier in widget.initialModifiers) {
      _selected
          .putIfAbsent(modifier.modifierGroupId, () => <String>{})
          .add(modifier.variationId);
    }
  }

  int _minimum(ModifierGroup group) => group.isRequired
      ? group.minSelections.clamp(1, 999999)
      : group.minSelections;

  bool get _valid => widget.groups.every((group) {
    final count = _selected[group.id]?.length ?? 0;
    final maximum = group.maxSelections;
    return count >= _minimum(group) && (maximum == null || count <= maximum);
  });

  void _toggle(ModifierGroup group, ModifierOption option, bool selected) {
    final values = _selected.putIfAbsent(group.id, () => <String>{});
    if (selected) {
      final maximum = group.maxSelections;
      if (maximum != null && maximum == 1) values.clear();
      if (maximum == null || values.length < maximum) {
        values.add(option.variationId);
      }
    } else {
      values.remove(option.variationId);
    }
    setState(() {});
  }

  void _confirm() {
    if (!_valid) return;
    final result = <SelectedModifier>[];
    for (final group in widget.groups) {
      final selected = _selected[group.id] ?? const <String>{};
      for (final option in group.options) {
        if (!selected.contains(option.variationId)) continue;
        result.add(
          SelectedModifier(
            modifierGroupId: group.id,
            modifierGroupName: group.name,
            variationId: option.variationId,
            name: option.name,
            unitPrice: option.priceAdjustment,
            priceIncludesTax: option.priceIncludesTax,
          ),
        );
      }
    }
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    titlePadding: const EdgeInsets.fromLTRB(24, 22, 16, 8),
    contentPadding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
    title: Row(
      children: [
        const Icon(Icons.tune_rounded, color: AppColors.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.product.name,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const Text(
                'Choose modifiers',
                style: TextStyle(
                  color: AppColors.muted,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Close',
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close_rounded),
        ),
      ],
    ),
    content: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 520, maxHeight: 560),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [for (final group in widget.groups) _groupCard(group)],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancel'),
      ),
      FilledButton.icon(
        onPressed: _valid ? _confirm : null,
        icon: const Icon(Icons.add_shopping_cart_rounded),
        label: Text(widget.confirmLabel),
      ),
    ],
  );

  Widget _groupCard(ModifierGroup group) {
    final selected = _selected[group.id] ?? const <String>{};
    final available = group.options
        .where((option) => option.isActive && option.isAvailable)
        .toList(growable: false);
    final minimum = _minimum(group);
    final maximum = group.maxSelections;
    final arabic = context.isArabic;
    final instruction = maximum == 1
        ? (minimum > 0
              ? (arabic ? 'اختر خياراً واحداً' : 'Choose one')
              : (arabic ? 'اختر خياراً واحداً كحد أقصى' : 'Choose up to one'))
        : maximum == null
        ? (minimum > 0
              ? (arabic
                    ? 'اختر $minimum على الأقل'
                    : 'Choose at least $minimum')
              : (arabic ? 'اختياري' : 'Optional'))
        : minimum == maximum
        ? (arabic ? 'اختر $minimum' : 'Choose $minimum')
        : (arabic
              ? 'اختر من $minimum إلى $maximum'
              : 'Choose $minimum–$maximum');
    final missing = selected.length < minimum;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(
          color: missing ? const Color(0xFFF0C9C9) : const Color(0xFFDCE5E2),
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          ListTile(
            dense: true,
            title: Text(
              group.name,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            subtitle: Text(instruction),
            trailing: minimum > 0
                ? const Chip(
                    label: Text('Required'),
                    visualDensity: VisualDensity.compact,
                  )
                : null,
          ),
          const Divider(height: 1),
          if (available.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('No options are currently available.'),
              ),
            )
          else
            for (final option in available)
              CheckboxListTile(
                value: selected.contains(option.variationId),
                onChanged: (value) => _toggle(group, option, value ?? false),
                controlAffinity: ListTileControlAffinity.leading,
                dense: true,
                title: Text(option.name),
                subtitle: option.subSku.isEmpty ? null : Text(option.subSku),
                secondary: option.priceAdjustment == 0
                    ? const Text('Included')
                    : Text('+${money(option.priceAdjustment)}'),
              ),
        ],
      ),
    );
  }
}
