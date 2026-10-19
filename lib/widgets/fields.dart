import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_text.dart';
import '../utils/format.dart';

/// A dropdown in the same style as the text fields. [options] maps each value
/// to the words shown.
class SelectField<T> extends StatelessWidget {
  const SelectField({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    this.helper,
  });

  final String label;
  final T? value;
  final Map<T, String> options;
  final ValueChanged<T?>? onChanged;
  final String? helper;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return DropdownButtonFormField<T>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: label, helperText: helper),
      dropdownColor: colors.surface,
      style: AppText.text.copyWith(color: colors.ink),
      items: [
        for (final entry in options.entries)
          DropdownMenuItem<T>(
            value: entry.key,
            child: Text(entry.value, overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: onChanged,
    );
  }
}

/// A money field: digits and one decimal point, shown with KES in front.
class AmountField extends StatelessWidget {
  const AmountField({
    super.key,
    required this.controller,
    required this.label,
    this.helper,
    this.onChanged,
    this.autofocus = false,
  });

  final TextEditingController controller;
  final String label;
  final String? helper;
  final ValueChanged<String>? onChanged;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      autofocus: autofocus,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
      style: AppText.amount.copyWith(
        color: AppColors.of(context).ink,
        fontSize: 17,
      ),
      decoration: InputDecoration(
        labelText: label,
        helperText: helper,
        prefixText: 'KES ',
      ),
      onChanged: onChanged,
    );
  }
}

/// A date chosen from a calendar: "14 Oct 2026".
class DateField extends StatelessWidget {
  const DateField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.firstDate,
    this.lastDate,
  });

  final String label;
  final DateTime value;
  final ValueChanged<DateTime> onChanged;
  final DateTime? firstDate;
  final DateTime? lastDate;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: value,
          firstDate: firstDate ?? DateTime(2020),
          lastDate: lastDate ?? DateTime.now().add(const Duration(days: 365)),
        );

        if (picked != null) onChanged(picked);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: const Icon(Icons.calendar_today_outlined, size: 18),
        ),
        child: Text(
          formatDay(value),
          style: AppText.text.copyWith(color: AppColors.of(context).ink),
        ),
      ),
    );
  }
}
