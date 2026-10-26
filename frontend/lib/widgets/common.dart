import 'package:flutter/material.dart';
import '../theme.dart';

class Panel extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final Color color;
  const Panel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(24),
    this.color = Colors.white,
  });
  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: AppColors.line),
    ),
    child: child,
  );
}

class SectionTitle extends StatelessWidget {
  final String title, subtitle;
  final Widget? action;
  const SectionTitle(this.title, this.subtitle, {super.key, this.action});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 22),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 5),
              Text(subtitle, style: const TextStyle(color: AppColors.muted)),
            ],
          ),
        ),
        ?action,
      ],
    ),
  );
}

void toast(BuildContext context, Object message) =>
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message.toString()),
        behavior: SnackBarBehavior.floating,
      ),
    );

class EmptyState extends StatelessWidget {
  final String title, detail;
  final IconData icon;
  const EmptyState(
    this.title,
    this.detail, {
    super.key,
    this.icon = Icons.event_available_outlined,
  });
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 12),
    child: Center(
      child: Column(
        children: [
          Icon(icon, size: 42, color: AppColors.muted),
          const SizedBox(height: 16),
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            detail,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.muted),
          ),
        ],
      ),
    ),
  );
}

class Brand extends StatelessWidget {
  final bool light;
  const Brand({super.key, this.light = false});
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 41,
        height: 41,
        decoration: BoxDecoration(
          color: light ? Colors.white.withValues(alpha: .12) : AppColors.ink,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.content_cut, color: Colors.white, size: 23),
      ),
      const SizedBox(width: 12),
      Flexible(
        child: Text(
          'barbería',
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 25,
            fontWeight: FontWeight.w800,
            letterSpacing: -1,
            color: light ? Colors.white : AppColors.ink,
          ),
        ),
      ),
    ],
  );
}
