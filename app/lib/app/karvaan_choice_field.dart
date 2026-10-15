import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'bilingual.dart';

/// Intrinsic-height choice control with immediate, keyboard-accessible overlay.
/// Reuses existing items/values/callbacks; null choices differ from dismissal.
class KarvaanChoiceField<T> extends StatelessWidget {
  const KarvaanChoiceField({
    super.key,
    this.initialValue,
    this.decoration = const InputDecoration(),
    required this.items,
    required this.onChanged,
  });
  final T? initialValue;
  final InputDecoration decoration;
  final List<DropdownMenuItem<T>>? items;
  final ValueChanged<T?>? onChanged;
  @override
  Widget build(BuildContext context) {
    final options = items ?? <DropdownMenuItem<T>>[];
    final selected = options
        .where((item) => item.value == initialValue)
        .firstOrNull;
    final enabled = onChanged != null && options.isNotEmpty;
    return PopupMenuButton<_Choice<T>>(
      enabled: enabled,
      tooltip: L10n.choose.inline,
      popUpAnimationStyle: AnimationStyle.noAnimation,
      position: PopupMenuPosition.under,
      constraints: BoxConstraints(
        maxWidth: math.min(480, MediaQuery.sizeOf(context).width - 48),
      ),
      itemBuilder: (_) => [
        for (final item in options)
          PopupMenuItem<_Choice<T>>(
            value: _Choice(item.value),
            enabled: item.enabled,
            child: item.child,
          ),
      ],
      onSelected: (entry) => onChanged?.call(entry.value),
      child: InputDecorator(
        isEmpty: selected == null,
        decoration: decoration.copyWith(
          enabled: enabled,
          suffixIcon: const Icon(Icons.expand_more),
        ),
        child: selected?.child ?? const SizedBox(height: 24),
      ),
    );
  }
}

class _Choice<T> {
  const _Choice(this.value);
  final T? value;
}
