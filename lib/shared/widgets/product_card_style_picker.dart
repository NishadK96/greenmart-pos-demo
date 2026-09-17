import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final productCardImagesProvider =
    NotifierProvider<ProductCardImagesController, Map<String, bool>>(
      ProductCardImagesController.new,
    );

class ProductCardImagesController extends Notifier<Map<String, bool>> {
  final _changedModes = <String>{};
  @override
  Map<String, bool> build() {
    _load();
    return const {'retail': true, 'kitchen': false};
  }

  Future<void> _load() async {
    final preferences = await SharedPreferences.getInstance();
    if (!ref.mounted) return;
    state = {
      for (final mode in ['retail', 'kitchen'])
        mode: _changedModes.contains(mode)
            ? state[mode]!
            : preferences.getBool('product_card_images_$mode') ?? state[mode]!,
    };
  }

  Future<void> select(String mode, bool images) async {
    _changedModes.add(mode);
    state = {...state, mode: images};
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool('product_card_images_$mode', images);
  }
}

class ProductCardStylePicker extends ConsumerWidget {
  const ProductCardStylePicker({super.key, required this.mode});
  final String mode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final images = ref.watch(productCardImagesProvider)[mode] ?? false;
    final arabic = Localizations.localeOf(context).languageCode == 'ar';
    return PopupMenuButton<bool>(
      tooltip: arabic ? 'تصميم بطاقات المنتجات' : 'Product card style',
      initialValue: images,
      onSelected: (value) =>
          ref.read(productCardImagesProvider.notifier).select(mode, value),
      itemBuilder: (_) => [
        CheckedPopupMenuItem(
          value: true,
          checked: images,
          child: Text(arabic ? 'مع الصور' : 'With images'),
        ),
        CheckedPopupMenuItem(
          value: false,
          checked: !images,
          child: Text(arabic ? 'بطاقات بسيطة' : 'Simple cards'),
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              images ? Icons.image_outlined : Icons.view_agenda_outlined,
              size: 18,
            ),
            const SizedBox(width: 5),
            Text(arabic ? 'البطاقات' : 'Cards'),
            const Icon(Icons.expand_more, size: 16),
          ],
        ),
      ),
    );
  }
}
