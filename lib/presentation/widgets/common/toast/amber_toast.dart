import 'package:flutter/material.dart';
import '../../../../core/constants/constants.dart';
import 'toast_types.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';

class AmberToast extends StatelessWidget {
  final String message;
  final ToastType type;
  final VoidCallback? onDismiss;

  const AmberToast({
    super.key,
    required this.message,
    required this.type,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: _getBorderColor(type).withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_getIcon(type), color: _getColor(type), size: 20),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 14,
                color: AmberColors.textPrimary,
                fontWeight: FontWeight.w500,
                decoration: TextDecoration.none, // Prevent underline when not in Material
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Color _getColor(ToastType type) {
    switch (type) {
      case ToastType.success:
        return Colors.green;
      case ToastType.warning:
        return Colors.orange;
      case ToastType.error:
        return Colors.red;
      case ToastType.info:
        return AmberColors.primary;
    }
  }

  Color _getBorderColor(ToastType type) {
    switch (type) {
      case ToastType.success:
        return Colors.green;
      case ToastType.warning:
        return Colors.orange;
      case ToastType.error:
        return Colors.red;
      case ToastType.info:
        return AmberColors.primary;
    }
  }

  IconData _getIcon(ToastType type) {
    switch (type) {
      case ToastType.success:
        return FluentIcons.checkmark_circle_24_filled;
      case ToastType.warning:
        return FluentIcons.warning_24_filled;
      case ToastType.error:
        return FluentIcons.dismiss_circle_24_filled;
      case ToastType.info:
        return FluentIcons.info_24_filled;
    }
  }
}
