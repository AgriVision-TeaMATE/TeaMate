import 'package:flutter/material.dart';

import '../theme.dart';

class FieldContextHero extends StatelessWidget {
  final String name;
  final String subtitle;

  const FieldContextHero({
    super.key,
    required this.name,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE1E6E2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: const Color(0xFFF0F3F1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.landscape_outlined,
              color: AppTheme.textPrimary,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F3F1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'FIELD',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 9,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.8,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

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
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppTheme.brandGreen.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppTheme.accentGreenText, size: 20),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 16.5,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.3,
            ),
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
          keyboardType:
              widget.keyboardType ??
              TextInputType.numberWithOptions(decimal: true),
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
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(
                color: Color(0xFFDDE4D8),
                width: 1.1,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(
                color: AppTheme.primaryButton,
                width: 1.2,
              ),
            ),
            hintStyle: TextStyle(
              color: AppTheme.textSecondary.withValues(alpha: 0.5),
            ),
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
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFF7F8F9),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFDDE4D8), width: 1.1),
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
                : const Color(0xFFDDE4D8),
            shape: BoxShape.circle,
          ),
          child: isComplete
              ? const Icon(Icons.check_rounded, color: Colors.white, size: 16)
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
