import 'package:flutter/material.dart';

import '../theme.dart';

/// Card header with icon and title - reusable for all environmental data sections
class EnvironmentalDataCardHeader extends StatelessWidget {
  final IconData icon;
  final String title;

  const EnvironmentalDataCardHeader({
    super.key,
    required this.icon,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          color: AppTheme.brandGreen,
          size: 20,
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.3,
          ),
        ),
      ],
    );
  }
}

/// Editable field for environmental data collection with proper controller handling
class EnvironmentalDataField extends StatefulWidget {
  final String label;
  final String value;
  final ValueChanged<String> onChanged;
  final String? suffix;
  final TextInputType? keyboardType;
  final bool readOnly;

  const EnvironmentalDataField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.suffix,
    this.keyboardType,
    this.readOnly = false,
  });

  @override
  State<EnvironmentalDataField> createState() => _EnvironmentalDataFieldState();
}

class _EnvironmentalDataFieldState extends State<EnvironmentalDataField> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(EnvironmentalDataField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _controller.text = widget.value;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: const TextStyle(
            fontSize: 13,
            color: AppTheme.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _controller,
          onChanged: widget.onChanged,
          keyboardType: widget.keyboardType ?? TextInputType.numberWithOptions(decimal: true),
          readOnly: widget.readOnly,
          textAlignVertical: TextAlignVertical.center,
          decoration: InputDecoration(
            suffixText: widget.suffix,
            filled: true,
            fillColor: const Color(0xFFF3F4F6),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
            hintStyle: TextStyle(color: AppTheme.textSecondary.withValues(alpha: 0.5)),
          ),
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
      ],
    );
  }
}

/// Read-only display field for fetched data
class EnvironmentalDataDisplay extends StatelessWidget {
  final String label;
  final String value;
  final String? suffix;

  const EnvironmentalDataDisplay({
    super.key,
    required this.label,
    required this.value,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            color: AppTheme.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 10,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFFF7F8F9),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE8ECEF)),
          ),
          child: Text(
            '$value${suffix ?? ''}',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}

/// Progress indicator for each step of the auto-fetch process
class AutoFetchProgressStep extends StatelessWidget {
  final String label;
  final bool isActive;
  final bool isComplete;

  const AutoFetchProgressStep({
    super.key,
    required this.label,
    required this.isActive,
    required this.isComplete,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: isComplete
                ? AppTheme.brandGreen
                : isActive
                    ? AppTheme.brandGreen.withValues(alpha: 0.3)
                    : const Color(0xFFE8ECEF),
            shape: BoxShape.circle,
          ),
          child: isComplete
              ? const Icon(
                  Icons.check_rounded,
                  color: Colors.white,
                  size: 16,
                )
              : isActive
                  ? const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : null,
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isComplete
                ? AppTheme.brandGreen
                : isActive
                    ? AppTheme.textPrimary
                    : AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }
}