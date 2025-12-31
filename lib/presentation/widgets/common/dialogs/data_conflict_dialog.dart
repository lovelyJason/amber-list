import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../../core/constants/constants.dart';

/// 数据冲突解决弹窗
/// 用于让用户在本地数据和远程数据之间做出选择
class DataConflictDialog extends StatelessWidget {
  final String title;
  final String description;
  final Map<String, dynamic> localData;
  final Map<String, dynamic> remoteData;
  final String localLabel;
  final String remoteLabel;

  const DataConflictDialog({
    super.key,
    required this.title,
    this.description = '检测到数据冲突，请选择保留哪份数据。',
    required this.localData,
    required this.remoteData,
    this.localLabel = '本地数据',
    this.remoteLabel = '远程数据',
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AmberDimens.radiusLg),
      ),
      child: Container(
        width: 600,
        height: 500,
        padding: const EdgeInsets.all(AmberDimens.spacingLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: AmberDimens.spacingSm),
            Text(
              description,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AmberColors.textSecondary,
                  ),
            ),
            const SizedBox(height: AmberDimens.spacingLg),

            // 对比区域
            Expanded(
              child: Row(
                children: [
                  // 本地数据列
                  Expanded(
                    child: _buildDataColumn(
                      context,
                      label: localLabel,
                      data: localData,
                      isLocal: true,
                    ),
                  ),
                  const VerticalDivider(width: 32),
                  // 远程数据列
                  Expanded(
                    child: _buildDataColumn(
                      context,
                      label: remoteLabel,
                      data: remoteData,
                      isLocal: false,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataColumn(
    BuildContext context, {
    required String label,
    required Map<String, dynamic> data,
    required bool isLocal,
  }) {
    // 格式化 JSON 显示
    final jsonString = const JsonEncoder.withIndent('  ').convert(data);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 头部标签
        Container(
          padding: const EdgeInsets.symmetric(
            vertical: AmberDimens.spacingXs,
            horizontal: AmberDimens.spacingSm,
          ),
          decoration: BoxDecoration(
            color: isLocal ? Colors.blue.withOpacity(0.1) : Colors.green.withOpacity(0.1),
            borderRadius: BorderRadius.circular(AmberDimens.radiusSm),
            border: Border.all(
              color: isLocal ? Colors.blue.withOpacity(0.3) : Colors.green.withOpacity(0.3),
            ),
          ),
          child: Row(
            children: [
              Icon(
                isLocal ? Icons.computer : Icons.cloud,
                size: 16,
                color: isLocal ? Colors.blue : Colors.green,
              ),
              const SizedBox(width: AmberDimens.spacingXs),
              Text(
                label,
                style: TextStyle(
                  color: isLocal ? Colors.blue : Colors.green,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AmberDimens.spacingMd),

        // 数据内容展示
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(AmberDimens.spacingSm),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AmberDimens.radiusMd),
              border: Border.all(color: AmberColors.divider),
            ),
            child: SingleChildScrollView(
              child: Text(
                jsonString,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: AmberDimens.spacingMd),

        // 选择按钮
        ElevatedButton.icon(
          onPressed: () => Navigator.of(context).pop(isLocal ? true : false),
          icon: Icon(isLocal ? Icons.save_alt : Icons.cloud_download),
          label: Text('保留${isLocal ? "本地" : "远程"}'),
          style: ElevatedButton.styleFrom(
            backgroundColor: isLocal ? Colors.blue : Colors.green,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AmberDimens.radiusMd),
            ),
          ),
        ),
      ],
    );
  }
}
