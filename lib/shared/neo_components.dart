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
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? palette.surface,
        border: Border.all(color: palette.border, width: 2.5),
        borderRadius: BorderRadius.circular(4),
        boxShadow: shadow
            ? [BoxShadow(color: palette.shadow, offset: const Offset(4, 4))]
            : null,
      ),
      child: Material(
        type: MaterialType.transparency,
        borderRadius: BorderRadius.circular(4),
        child: child,
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
          border: Border.all(color: palette.border, width: 1.5),
          borderRadius: BorderRadius.circular(3)),
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
    return Container(
      height: 18,
      decoration: BoxDecoration(
          color: palette.surface,
          border: Border.all(color: palette.border, width: 2)),
      child: Align(
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: progress.clamp(0, 1).toDouble(),
          child: Container(color: color ?? palette.primary),
        ),
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
      color: color ?? palette.primary,
      child: InkWell(
        onTap: onPressed,
        child: Ink(
          decoration: BoxDecoration(
              border: Border.all(color: palette.border, width: 2.5),
              borderRadius: BorderRadius.circular(4)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 12),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, color: palette.text, size: 22),
              const SizedBox(height: 6),
              Text(label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: palette.text,
                      fontSize: 11,
                      fontWeight: FontWeight.w900)),
            ]),
          ),
        ),
      ),
    );
  }
}
