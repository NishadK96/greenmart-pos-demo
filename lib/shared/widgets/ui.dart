import 'package:flutter/material.dart' hide Text;
import 'package:eazy_pos/shared/widgets/localized_text.dart';
import '../../core/theme/app_theme.dart';

class PageTitle extends StatelessWidget {
  const PageTitle(this.title, {super.key, this.subtitle, this.action});
  final String title;
  final String? subtitle;
  final Widget? action;
  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 600;
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.tr(title),
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontSize: compact ? 20 : null,
            fontWeight: FontWeight.w800,
            letterSpacing: -.5,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          Text(
            context.tr(subtitle!),
            style: TextStyle(
              color: AppColors.muted,
              fontSize: compact ? 11 : 13,
            ),
          ),
        ],
      ],
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 520 && action != null) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              text,
              const SizedBox(height: 8),
              Align(alignment: Alignment.centerLeft, child: action!),
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: text),
            if (action != null) action!,
          ],
        );
      },
    );
  }
}

class Surface extends StatelessWidget {
  const Surface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });
  final Widget child;
  final EdgeInsets padding;
  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 600;
    final resolvedPadding = compact && padding == const EdgeInsets.all(16)
        ? const EdgeInsets.all(12)
        : padding;
    return Container(
      padding: resolvedPadding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: const Color(0xFFE5EAE8)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A10231F),
            blurRadius: 22,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}

class MetricCard extends StatelessWidget {
  const MetricCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.tint = AppColors.primary,
  });
  final String label, value;
  final IconData icon;
  final Color tint;
  @override
  Widget build(BuildContext context) => Surface(
    child: LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 150;
        final iconWidget = Container(
          padding: EdgeInsets.all(narrow ? 7 : 10),
          decoration: BoxDecoration(
            color: tint.withValues(alpha: .1),
            borderRadius: BorderRadius.circular(narrow ? 9 : 12),
          ),
          child: Icon(icon, color: tint, size: narrow ? 20 : 24),
        );
        final content = Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: narrow
              ? CrossAxisAlignment.center
              : CrossAxisAlignment.start,
          children: [
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: narrow ? TextAlign.center : TextAlign.start,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontSize: narrow ? 18 : null,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              context.tr(label),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: narrow ? TextAlign.center : TextAlign.start,
              style: TextStyle(
                color: AppColors.muted,
                fontSize: narrow ? 10 : null,
              ),
            ),
          ],
        );
        if (narrow) {
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [iconWidget, const SizedBox(height: 7), content],
          );
        }
        return Row(
          children: [
            iconWidget,
            const SizedBox(width: 12),
            Expanded(child: content),
          ],
        );
      },
    ),
  );
}

class StatusBadge extends StatelessWidget {
  const StatusBadge(this.text, {super.key, this.color = AppColors.primary});
  final String text;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .1),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      context.tr(text),
      style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700),
    ),
  );
}

class EmptyState extends StatelessWidget {
  const EmptyState(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.inbox_outlined, size: 42, color: AppColors.muted),
          const SizedBox(height: 12),
          Text(
            context.tr(text),
            style: const TextStyle(color: AppColors.muted),
          ),
        ],
      ),
    ),
  );
}

class ProductImage extends StatelessWidget {
  const ProductImage(
    this.url, {
    super.key,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
  });
  final String url;
  final double? width, height;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final placeholder = SizedBox(
      width: width,
      height: height,
      child: const Icon(
        Icons.inventory_2_outlined,
        size: 42,
        color: AppColors.muted,
      ),
    );
    if (url.isEmpty) return placeholder;
    return Image.network(
      url,
      key: ValueKey(url),
      width: width,
      height: height,
      fit: fit,
      // EazyERP's uploaded product assets are served without CORS headers.
      // Flutter Web normally fetches the bytes and the browser blocks that
      // request. Falling back to a native HTML image keeps the same widget API
      // and also remains harmless on Android, iOS and desktop.
      webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
      errorBuilder: (_, __, ___) => placeholder,
    );
  }
}
