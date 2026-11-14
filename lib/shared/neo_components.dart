import 'package:flutter/material.dart';

import '../app/theme/neo_theme.dart';

class NeoCard extends StatelessWidget {
  const NeoCard(
      {required this.child,
      this.color,
      this.padding = const EdgeInsets.all(16),
      this.shadow = true,
      super.key});

  final Widget child;
  final Color? color;
  final EdgeInsetsGeometry padding;
  final bool shadow;

  @override
  Widget build(BuildContext context) {
    final palette = NeoPalette.of(context);
    final featured = color != null;
    final radius = featured
        ? const BorderRadius.only(topLeft: Radius.circular(28), topRight: Radius.circular(28), bottomLeft: Radius.circular(10), bottomRight: Radius.circular(28))
        : BorderRadius.circular(22);
    return Container(
      decoration: BoxDecoration(
        color: color ?? palette.surface,
        borderRadius: radius,
        border: Border.all(color: featured ? palette.border.withValues(alpha: .75) : palette.mutedSurface, width: featured ? 1.3 : 1),
        boxShadow: shadow && featured
            ? [BoxShadow(color: palette.shadow, offset: const Offset(3, 4))]
            : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

class NeoSectionTitle extends StatelessWidget {
  const NeoSectionTitle(this.title, {this.trailing, super.key});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(
            child: Text(title, style: Theme.of(context).textTheme.titleLarge)),
        if (trailing != null) trailing!,
      ]);
}

class NeoTag extends StatelessWidget {
  const NeoTag(this.label, {this.color, super.key});

  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final palette = NeoPalette.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
          color: color ?? palette.highlight,
          borderRadius: BorderRadius.circular(99)),
      child: Text(label,
          style: TextStyle(
              color: palette.text, fontSize: 10, fontWeight: FontWeight.w900)),
    );
  }
}

class NeoProgressBar extends StatelessWidget {
  const NeoProgressBar({required this.progress, this.color, super.key});

  final double progress;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final palette = NeoPalette.of(context);
    final reduced = MediaQuery.disableAnimationsOf(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(99),
      child: SizedBox(
        height: 10,
        child: LayoutBuilder(builder: (context, constraints) => Stack(children: [
          Positioned.fill(child: ColoredBox(color: palette.mutedSurface.withValues(alpha: .55))),
          AnimatedContainer(
            duration: reduced ? Duration.zero : const Duration(milliseconds: 350),
            curve: Curves.easeOutCubic,
            width: constraints.maxWidth * progress.clamp(0, 1).toDouble(),
            decoration: BoxDecoration(color: color ?? palette.primary, borderRadius: BorderRadius.circular(99)),
          ),
        ])),
      ),
    );
  }
}

class NeoActionButton extends StatelessWidget {
  const NeoActionButton(
      {required this.icon,
      required this.label,
      required this.onPressed,
      this.color,
      super.key});

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final palette = NeoPalette.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onPressed,
        child: Ink(
          decoration: BoxDecoration(
            color: color ?? palette.primary,
            borderRadius: const BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24), bottomLeft: Radius.circular(8), bottomRight: Radius.circular(24)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 13),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, color: palette.text, size: 23),
              const SizedBox(height: 7),
              Text(label, textAlign: TextAlign.center, maxLines: 1,
                style: TextStyle(color: palette.text, fontSize: 10, fontWeight: FontWeight.w800)),
            ]),
          ),
        ),
      ),
    );
  }
}

class NeoErrorCard extends StatelessWidget {
  const NeoErrorCard({required this.onRetry, this.message = 'Data gagal dimuat.', super.key});
  final VoidCallback onRetry;
  final String message;
  @override
  Widget build(BuildContext context) => NeoCard(
        color: NeoPalette.of(context).secondary,
        child: Row(children: [
          Expanded(
              child: Text(message,
                  style: const TextStyle(
                      color: Color(0xFF171717), fontWeight: FontWeight.w800))),
          IconButton(
              tooltip: 'Coba lagi',
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, color: Color(0xFF171717))),
        ]),
      );
}

/// A compact ring for progress; the semantic label keeps the value accessible.
class NeoProgressRing extends StatelessWidget {
  const NeoProgressRing({required this.progress, this.size = 74, this.color, this.label, super.key});
  final double progress, size;
  final Color? color;
  final String? label;
  @override
  Widget build(BuildContext context) {
    final palette = NeoPalette.of(context);
    return Semantics(label: label ?? 'Progres ${(progress.clamp(0, 1) * 100).round()} persen',
      child: SizedBox(width: size, height: size, child: Stack(alignment: Alignment.center, children: [
        SizedBox.expand(child: CircularProgressIndicator(value: progress.clamp(0, 1).toDouble(),
          strokeWidth: 7, strokeCap: StrokeCap.round,
          backgroundColor: palette.text.withValues(alpha: .12), color: color ?? palette.text)),
        Text('${(progress.clamp(0, 1) * 100).round()}%', style: Theme.of(context).textTheme.titleMedium),
      ])),
    );
  }
}
