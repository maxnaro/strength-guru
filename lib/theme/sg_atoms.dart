import 'dart:ui';

import 'package:flutter/material.dart';
import 'tokens.dart';
import 'groups.dart';

// ── SGChip ────────────────────────────────────────────────────────────────────

enum ChipTone { neutral, accent, success, warn, ghost }

class SGChip extends StatelessWidget {
  final String label;
  final ChipTone tone;

  const SGChip(this.label, {super.key, this.tone = ChipTone.neutral});

  @override
  Widget build(BuildContext context) {
    final p = pal(context);
    final (bg, fg) = switch (tone) {
      ChipTone.neutral => (p.chipBg, p.textDim),
      ChipTone.accent => (p.accent.withValues(alpha: 0.15), p.accent),
      ChipTone.success => (p.success.withValues(alpha: 0.15), p.success),
      ChipTone.warn => (p.warn.withValues(alpha: 0.15), p.warn),
      ChipTone.ghost => (Colors.transparent, p.textFaint),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(SGRadius.chip),
      ),
      child: Text(
        label.toUpperCase(),
        style: SGText.mono(11, color: fg),
      ),
    );
  }
}

// ── SGButton ──────────────────────────────────────────────────────────────────

enum ButtonVariant { solid, soft, ghost }

class SGButton extends StatelessWidget {
  final String label;
  final Widget? leadingIcon;
  final Widget? trailingIcon;
  final ButtonVariant variant;
  final Color? color;
  final VoidCallback? onTap;
  final bool fullWidth;

  const SGButton({
    super.key,
    required this.label,
    this.leadingIcon,
    this.trailingIcon,
    this.variant = ButtonVariant.solid,
    this.color,
    this.onTap,
    this.fullWidth = false,
  });

  const SGButton.solid({
    super.key,
    required this.label,
    this.leadingIcon,
    this.trailingIcon,
    this.color,
    this.onTap,
    this.fullWidth = false,
  }) : variant = ButtonVariant.solid;

  const SGButton.soft({
    super.key,
    required this.label,
    this.leadingIcon,
    this.trailingIcon,
    this.color,
    this.onTap,
    this.fullWidth = false,
  }) : variant = ButtonVariant.soft;

  const SGButton.ghost({
    super.key,
    required this.label,
    this.leadingIcon,
    this.trailingIcon,
    this.color,
    this.onTap,
    this.fullWidth = false,
  }) : variant = ButtonVariant.ghost;

  @override
  Widget build(BuildContext context) {
    final p = pal(context);
    final baseColor = color ?? p.text;

    final (bg, fg, border) = switch (variant) {
      ButtonVariant.solid => (baseColor, p.bg, Colors.transparent),
      ButtonVariant.soft =>
        (baseColor.withValues(alpha: 0.12), baseColor, Colors.transparent),
      ButtonVariant.ghost =>
        (Colors.transparent, baseColor, Colors.transparent),
    };

    Widget content = Row(
      mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (leadingIcon != null) ...[
          leadingIcon!,
          const SizedBox(width: 6),
        ],
        Text(label, style: SGText.body(15, weight: FontWeight.w700, color: fg)),
        if (trailingIcon != null) ...[
          const SizedBox(width: 6),
          trailingIcon!,
        ],
      ],
    );

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(SGRadius.btn),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(SGRadius.btn),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(SGRadius.btn),
            border: Border.all(color: border, width: 0),
          ),
          width: fullWidth ? double.infinity : null,
          child: content,
        ),
      ),
    );
  }
}

// ── SGTopBar ──────────────────────────────────────────────────────────────────

class SGTopBar extends StatelessWidget {
  final String? title;
  final Widget? leading;
  final Widget? trailing;
  final Color? backgroundColor;

  const SGTopBar({
    super.key,
    this.title,
    this.leading,
    this.trailing,
    this.backgroundColor,
  });

  static const double height = 56;

  @override
  Widget build(BuildContext context) {
    final p = pal(context);
    return Container(
      height: height,
      color: backgroundColor ?? Colors.transparent,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          if (leading != null) leading! else const SizedBox(width: 40),
          const Spacer(),
          if (title != null)
            Text(title!, style: SGText.display(17, ls: -0.2, color: p.text)),
          const Spacer(),
          if (trailing != null) trailing! else const SizedBox(width: 40),
        ],
      ),
    );
  }
}

// ── SGTabBar ──────────────────────────────────────────────────────────────────

class SGTabBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTabChanged;

  const SGTabBar({
    super.key,
    required this.currentIndex,
    required this.onTabChanged,
  });

  static const double kBaseHeight = 60.0;

  @override
  Widget build(BuildContext context) {
    final p = pal(context);
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                p.bg.withValues(alpha: 0.7),
                p.bg.withValues(alpha: 0.96),
              ],
            ),
            border: Border(top: BorderSide(color: p.border, width: 0.5)),
          ),
          padding: EdgeInsets.only(top: 8, bottom: bottomPad + 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _TabItem(
                icon: Icons.local_fire_department_outlined,
                activeIcon: Icons.local_fire_department,
                label: 'TODAY',
                index: 0,
                currentIndex: currentIndex,
                palette: p,
                onTap: () => onTabChanged(0),
              ),
              _TabItem(
                icon: Icons.fitness_center_outlined,
                activeIcon: Icons.fitness_center,
                label: 'LOG',
                index: 1,
                currentIndex: currentIndex,
                palette: p,
                onTap: () => onTabChanged(1),
              ),
              _TabItem(
                icon: Icons.loop_outlined,
                activeIcon: Icons.loop,
                label: 'MESO',
                index: 2,
                currentIndex: currentIndex,
                palette: p,
                onTap: () => onTabChanged(2),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final int index;
  final int currentIndex;
  final SGPalette palette;
  final VoidCallback onTap;

  const _TabItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.index,
    required this.currentIndex,
    required this.palette,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final active = index == currentIndex;
    final color = active ? palette.text : palette.textFaint;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 72,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(active ? activeIcon : icon, color: color, size: 22),
            const SizedBox(height: 3),
            Text(
              label,
              style: SGText.mono(10, color: color, ls: 0.5),
            ),
          ],
        ),
      ),
    );
  }
}

// ── SGPlateDisc ───────────────────────────────────────────────────────────────

class SGPlateDisc extends StatelessWidget {
  final double size;
  final String label;
  final Color color;

  const SGPlateDisc({
    super.key,
    required this.size,
    required this.label,
    required this.color,
  });

  String _formatLabel(String text) {
    final trimmed = text.trim();
    if (trimmed.length <= 4) return trimmed.toUpperCase();
    final words = trimmed
        .split(RegExp(r'[\s&]+'))
        .where((w) => w.isNotEmpty)
        .toList();
    if (words.length == 1) {
      return '${words.first.substring(0, 3).toUpperCase()}-';
    }
    String acronym = words.map((w) => w[0]).join('').toUpperCase();
    if (acronym.length <= 4) return acronym;
    return '${acronym.substring(0, 3)}-';
  }

  @override
  Widget build(BuildContext context) {
    final p = pal(context);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.2),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.35),
            blurRadius: 0,
            spreadRadius: -(size * 0.08),
          ),
          BoxShadow(
            color: color.withValues(alpha: 0.18),
            blurRadius: 0,
            spreadRadius: size * 0.1,
          ),
        ],
        border: Border.all(color: color.withValues(alpha: 0.6), width: size * 0.04),
      ),
      child: Center(
        child: Text(
          _formatLabel(label),
          textAlign: TextAlign.center,
          style: SGText.display(size * 0.2, color: p.text),
        ),
      ),
    );
  }
}

// ── SGStat ────────────────────────────────────────────────────────────────────

class SGStat extends StatelessWidget {
  final String label;
  final String value;
  final Color accentBar;

  const SGStat({
    super.key,
    required this.label,
    required this.value,
    required this.accentBar,
  });

  @override
  Widget build(BuildContext context) {
    final p = pal(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(SGRadius.stat),
        border: Border.all(color: p.border, width: 0.5),
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 28,
            decoration: BoxDecoration(
              color: accentBar,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, style: SGText.mono(9, color: p.textFaint)),
                const SizedBox(height: 2),
                Text(value, style: SGText.display(15, color: p.text)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── SGStepper ─────────────────────────────────────────────────────────────────

class SGStepper extends StatelessWidget {
  final num value;
  final num min;
  final num max;
  final num step;
  final String? label;
  final Color? accentColor;
  final ValueChanged<num> onChanged;

  const SGStepper({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    required this.step,
    required this.onChanged,
    this.label,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final p = pal(context);
    return Container(
      decoration: BoxDecoration(
        color: p.inputBg,
        borderRadius: BorderRadius.circular(SGRadius.stepper),
        border: Border.all(color: p.border, width: 0.5),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (label != null) ...[
            Text(label!, style: SGText.mono(9, color: p.textFaint)),
            const SizedBox(height: 4),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _StepBtn(
                icon: Icons.remove,
                onTap: value > min
                    ? () => onChanged(
                          (value - step).clamp(min, max),
                        )
                    : null,
                palette: p,
              ),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.center,
                  child: Text(
                    _format(value),
                    style: SGText.display(22,
                        color: accentColor ?? p.text, ls: -0.2),
                    maxLines: 1,
                  ),
                ),
              ),
              _StepBtn(
                icon: Icons.add,
                onTap: value < max
                    ? () => onChanged(
                          (value + step).clamp(min, max),
                        )
                    : null,
                palette: p,
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _format(num v) {
    if (v is double && v == v.truncateToDouble()) {
      return v.toInt().toString();
    }
    return v.toString();
  }
}

class _StepBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final SGPalette palette;

  const _StepBtn({required this.icon, required this.onTap, required this.palette});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: palette.chipBg,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon,
            size: 18,
            color: onTap == null ? palette.textFaint : palette.text),
      ),
    );
  }
}

// ── SGSheet helper ────────────────────────────────────────────────────────────

Future<T?> showSGSheet<T>(
  BuildContext context, {
  required Widget child,
  bool isScrollControlled = false,
  double? maxHeightFraction,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled || maxHeightFraction != null,
    useSafeArea: true,
    builder: (ctx) {
      Widget content = Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          0,
          20,
          MediaQuery.of(ctx).viewInsets.bottom + 38,
        ),
        child: child,
      );

      if (maxHeightFraction != null) {
        content = DraggableScrollableSheet(
          initialChildSize: maxHeightFraction,
          minChildSize: 0.3,
          maxChildSize: maxHeightFraction,
          expand: false,
          builder: (_, ctrl) => SingleChildScrollView(
            controller: ctrl,
            padding: EdgeInsets.fromLTRB(
              20,
              0,
              20,
              MediaQuery.of(ctx).viewInsets.bottom + 38,
            ),
            child: child,
          ),
        );
      }

      final p = pal(ctx);
      return Column(
        mainAxisSize:
            maxHeightFraction != null ? MainAxisSize.max : MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: p.textFaint.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Flexible(child: content),
        ],
      );
    },
  );
}

// ── SGProgressRail ────────────────────────────────────────────────────────────

class SGProgressRail extends StatelessWidget {
  final double progress; // 0.0..1.0
  final Color color;
  final double height;
  final double width;

  const SGProgressRail({
    super.key,
    required this.progress,
    required this.color,
    this.height = 6,
    this.width = double.infinity,
  });

  @override
  Widget build(BuildContext context) {
    final p = pal(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(height / 2),
      child: SizedBox(
        width: width,
        height: height,
        child: Stack(
          children: [
            Container(color: p.railBg),
            FractionallySizedBox(
              widthFactor: progress.clamp(0.0, 1.0),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 240),
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── SGGroupDot ────────────────────────────────────────────────────────────────

class SGGroupDot extends StatelessWidget {
  final MuscleGroup group;
  final double size;

  const SGGroupDot(this.group, {super.key, this.size = 8});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: group.color,
      ),
    );
  }
}
