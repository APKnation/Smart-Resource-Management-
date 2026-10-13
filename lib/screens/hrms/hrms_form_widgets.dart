import 'package:flutter/material.dart';

/// Consistent section card used by HRMS data-entry forms.
class HrmsFormSection extends StatelessWidget {
  const HrmsFormSection({
    super.key,
    required this.title,
    required this.description,
    required this.icon,
    required this.child,
  });

  final String title;
  final String description;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text(
                      description,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    ),
  );
}

/// Places fields in two columns when there is room and one column on mobile.
class HrmsFormGrid extends StatelessWidget {
  const HrmsFormGrid({
    super.key,
    required this.children,
    this.minFieldWidth = 220,
  });
  final List<Widget> children;
  final double minFieldWidth;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columns = (constraints.maxWidth / minFieldWidth).floor().clamp(
        1,
        2,
      );
      final gap = 12.0;
      final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [
          for (final child in children) SizedBox(width: width, child: child),
        ],
      );
    },
  );
}

/// Material date input backed by the platform date picker.
class HrmsDateField extends StatelessWidget {
  const HrmsDateField({
    super.key,
    required this.controller,
    required this.label,
    this.required = false,
  });
  final TextEditingController controller;
  final String label;
  final bool required;

  @override
  Widget build(BuildContext context) => TextFormField(
    controller: controller,
    readOnly: true,
    decoration: InputDecoration(
      labelText: label,
      hintText: 'YYYY-MM-DD',
      prefixIcon: const Icon(Icons.calendar_month_outlined),
      suffixIcon: controller.text.isEmpty
          ? null
          : IconButton(
              tooltip: 'Clear date',
              onPressed: controller.clear,
              icon: const Icon(Icons.clear),
            ),
    ),
    validator: required
        ? (value) =>
              value == null || value.trim().isEmpty ? 'Select $label' : null
        : null,
    onTap: () async {
      final initial = DateTime.tryParse(controller.text) ?? DateTime.now();
      final picked = await showDatePicker(
        context: context,
        initialDate: initial,
        firstDate: DateTime(1900),
        lastDate: DateTime(2200),
      );
      if (picked != null) {
        controller.text =
            '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
      }
    },
  );
}
