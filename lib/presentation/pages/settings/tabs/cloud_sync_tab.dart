import 'package:flutter/material.dart';
import '../../../../core/constants/constants.dart';
import '../../../widgets/webdav_config_section.dart';

/// 云同步标签页（直接嵌入 WebDavConfigSection）
class CloudSyncTab extends StatelessWidget {
  const CloudSyncTab({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AmberDimens.spacingLg),
      children: const [
        WebDavConfigSection(), // 🎯 直接复用现有组件
      ],
    );
  }
}
