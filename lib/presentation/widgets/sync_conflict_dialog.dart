import 'package:flutter/material.dart';
import '../../core/constants/constants.dart';
import '../../data/services/sync/three_way_merge.dart';
import '../providers/sync_provider.dart';

/// ============================================================
/// 同步冲突决策弹窗
/// ============================================================
/// 当三向合并检测到冲突时，弹窗让用户选择保留哪个版本：
/// - 本地版本
/// - 云端版本
///
/// 支持的冲突类型：
/// - bothModified: 两边都修改了同一条记录
/// - localModifiedRemoteDeleted: 本地修改了，远程删除了
/// - localDeletedRemoteModified: 本地删除了，远程修改了

class SyncConflictDialog extends StatefulWidget {
  /// 冲突列表
  final List<RecordConflict> conflicts;

  const SyncConflictDialog({
    super.key,
    required this.conflicts,
  });

  @override
  State<SyncConflictDialog> createState() => _SyncConflictDialogState();
}

class _SyncConflictDialogState extends State<SyncConflictDialog> {
  /// 当前显示的冲突索引
  int _currentIndex = 0;

  /// 用户的决策列表
  late List<ConflictResolution?> _resolutions;

  @override
  void initState() {
    super.initState();
    _resolutions = List.filled(widget.conflicts.length, null);
  }

  /// 当前冲突
  RecordConflict get _currentConflict => widget.conflicts[_currentIndex];

  /// 是否已完成所有决策
  bool get _allResolved => _resolutions.every((r) => r != null);

  /// 选择保留本地
  void _keepLocal() {
    setState(() {
      _resolutions[_currentIndex] = ConflictResolution.keepLocal;
      _moveToNext();
    });
  }

  /// 选择保留远程
  void _keepRemote() {
    setState(() {
      _resolutions[_currentIndex] = ConflictResolution.keepRemote;
      _moveToNext();
    });
  }

  /// 移动到下一个冲突
  void _moveToNext() {
    if (_currentIndex < widget.conflicts.length - 1) {
      setState(() => _currentIndex++);
    }
  }

  /// 移动到上一个冲突
  void _moveToPrevious() {
    if (_currentIndex > 0) {
      setState(() => _currentIndex--);
    }
  }

  /// 完成并返回决策结果
  void _finish() {
    if (_allResolved) {
      Navigator.of(context).pop(_resolutions.cast<ConflictResolution>());
    }
  }

  /// 取消
  void _cancel() {
    Navigator.of(context).pop(null);
  }

  @override
  Widget build(BuildContext context) {
    final conflict = _currentConflict;
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    // 响应式宽度：小屏幕占满（留边距），大屏幕最大600
    final isMobile = screenWidth < 600;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AmberDimens.radiusLg),
      ),
      insetPadding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 40,
        vertical: 24,
      ),
      child: Container(
        width: isMobile ? double.infinity : 600,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        padding: EdgeInsets.all(isMobile ? AmberDimens.spacingMd : AmberDimens.spacingLg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题栏
            _buildHeader(theme),
            const SizedBox(height: AmberDimens.spacingMd),

            // 冲突描述
            _buildConflictDescription(conflict, theme),
            SizedBox(height: isMobile ? AmberDimens.spacingMd : AmberDimens.spacingLg),

            // 对比区域
            Flexible(
              child: _buildComparisonArea(conflict, theme, isMobile: isMobile),
            ),
            SizedBox(height: isMobile ? AmberDimens.spacingMd : AmberDimens.spacingLg),

            // 底部操作栏
            _buildBottomBar(theme, isMobile: isMobile),
          ],
        ),
      ),
    );
  }

  /// 构建标题栏
  Widget _buildHeader(ThemeData theme) {
    return Row(
      children: [
        const Icon(
          Icons.warning_amber_rounded,
          color: AmberColors.warning,
          size: 28,
        ),
        const SizedBox(width: AmberDimens.spacingSm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '数据冲突',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '第 ${_currentIndex + 1} / ${widget.conflicts.length} 个冲突',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AmberColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        // 进度指示器
        _buildProgressIndicator(),
      ],
    );
  }

  /// 构建进度指示器
  Widget _buildProgressIndicator() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(widget.conflicts.length, (index) {
        final isResolved = _resolutions[index] != null;
        final isCurrent = index == _currentIndex;
        return Container(
          width: 8,
          height: 8,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isResolved
                ? AmberColors.success
                : isCurrent
                    ? AmberColors.primary
                    : AmberColors.divider,
          ),
        );
      }),
    );
  }

  /// 构建冲突描述
  Widget _buildConflictDescription(RecordConflict conflict, ThemeData theme) {
    final tableName = _getTableDisplayName(conflict.tableName);
    final itemName = conflict.displayName;

    String description;
    switch (conflict.type) {
      case ConflictType.bothModified:
        description = '$tableName「$itemName」在多端都有修改，请选择保留哪个版本：';
        break;
      case ConflictType.localModifiedRemoteDeleted:
        description = '$tableName「$itemName」在本地有修改，但在其他设备上已删除：';
        break;
      case ConflictType.localDeletedRemoteModified:
        description = '$tableName「$itemName」在本地已删除，但在其他设备上有修改：';
        break;
    }

    return Text(
      description,
      style: theme.textTheme.bodyMedium?.copyWith(
        color: AmberColors.textSecondary,
      ),
    );
  }

  /// 构建对比区域
  Widget _buildComparisonArea(RecordConflict conflict, ThemeData theme, {bool isMobile = false}) {
    // 移动端使用垂直布局，不用 Expanded
    if (isMobile) {
      return SingleChildScrollView(
        child: Column(
          children: [
            // 本地版本
            _buildVersionCard(
              title: '📱 本地版本',
              data: conflict.local,
              updatedAt: conflict.localUpdatedAt,
              // 软删除场景：local 有数据但 is_deleted=1，也应显示"已删除"
              isDeleted: conflict.type == ConflictType.localDeletedRemoteModified ||
                  (conflict.local != null && conflict.local!['is_deleted'] == 1),
              isLocal: true,
              isSelected: _resolutions[_currentIndex] == ConflictResolution.keepLocal,
              onTap: _keepLocal,
              theme: theme,
              isMobile: isMobile,
            ),
            const SizedBox(height: AmberDimens.spacingSm),
            // 远程版本
            _buildVersionCard(
              title: '☁️ 云端版本',
              data: conflict.remote,
              updatedAt: conflict.remoteUpdatedAt,
              // 软删除场景：remote 有数据但 is_deleted=1，也应显示"已删除"
              isDeleted: conflict.type == ConflictType.localModifiedRemoteDeleted ||
                  (conflict.remote != null && conflict.remote!['is_deleted'] == 1),
              isLocal: false,
              isSelected: _resolutions[_currentIndex] == ConflictResolution.keepRemote,
              onTap: _keepRemote,
              theme: theme,
              isMobile: isMobile,
            ),
          ],
        ),
      );
    }

    // 桌面端使用水平布局，用 Expanded
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _buildVersionCard(
            title: '📱 本地版本',
            data: conflict.local,
            updatedAt: conflict.localUpdatedAt,
            // 软删除场景：local 有数据但 is_deleted=1，也应显示"已删除"
            isDeleted: conflict.type == ConflictType.localDeletedRemoteModified ||
                (conflict.local != null && conflict.local!['is_deleted'] == 1),
            isLocal: true,
            isSelected: _resolutions[_currentIndex] == ConflictResolution.keepLocal,
            onTap: _keepLocal,
            theme: theme,
            isMobile: isMobile,
          ),
        ),
        const SizedBox(width: AmberDimens.spacingMd),
        Expanded(
          child: _buildVersionCard(
            title: '☁️ 云端版本',
            data: conflict.remote,
            updatedAt: conflict.remoteUpdatedAt,
            // 软删除场景：remote 有数据但 is_deleted=1，也应显示"已删除"
            isDeleted: conflict.type == ConflictType.localModifiedRemoteDeleted ||
                (conflict.remote != null && conflict.remote!['is_deleted'] == 1),
            isLocal: false,
            isSelected: _resolutions[_currentIndex] == ConflictResolution.keepRemote,
            onTap: _keepRemote,
            theme: theme,
            isMobile: isMobile,
          ),
        ),
      ],
    );
  }

  /// 构建版本卡片
  Widget _buildVersionCard({
    required String title,
    required Map<String, dynamic>? data,
    required DateTime? updatedAt,
    required bool isDeleted,
    required bool isLocal,
    required bool isSelected,
    required VoidCallback onTap,
    required ThemeData theme,
    bool isMobile = false,
  }) {
    final baseColor = isLocal ? Colors.blue : Colors.green;
    final borderColor = isSelected ? baseColor : AmberColors.divider;
    final bgColor = isSelected
        ? baseColor.withValues(alpha: 0.1)
        : theme.cardColor;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(AmberDimens.spacingMd),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(AmberDimens.radiusMd),
          border: Border.all(
            color: borderColor,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // 标题行
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: baseColor,
                      fontSize: isMobile ? 13 : 14,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isSelected)
                  Icon(
                    Icons.check_circle,
                    color: baseColor,
                    size: isMobile ? 18 : 20,
                  ),
              ],
            ),
            const SizedBox(height: AmberDimens.spacingSm),

            // 内容
            if (isDeleted)
              Container(
                padding: const EdgeInsets.all(AmberDimens.spacingMd),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AmberDimens.radiusSm),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.delete_outline,
                      color: Colors.red,
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Text(
                      '已删除',
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              )
            else if (data != null)
              _buildDataPreview(data, theme)
            else
              const Text('无数据'),

            const SizedBox(height: AmberDimens.spacingSm),

            // 更新时间
            if (updatedAt != null)
              Text(
                '更新: ${_formatDateTime(updatedAt)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AmberColors.textSecondary,
                ),
              ),

            const SizedBox(height: AmberDimens.spacingMd),

            // 选择按钮
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onTap,
                style: ElevatedButton.styleFrom(
                  backgroundColor: isSelected ? baseColor : Colors.grey.shade200,
                  foregroundColor: isSelected ? Colors.white : Colors.black87,
                ),
                child: Text(isDeleted ? '接受删除' : '保留此版本'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建数据预览
  Widget _buildDataPreview(Map<String, dynamic> data, ThemeData theme) {
    // 提取关键字段显示
    final title = data['title'] as String? ?? data['name'] as String? ?? '未命名';
    final description = data['description'] as String?;
    final isCompleted = data['is_completed'] == 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 标题
        Row(
          children: [
            if (data.containsKey('is_completed'))
              Icon(
                isCompleted ? Icons.check_circle : Icons.radio_button_unchecked,
                size: 16,
                color: isCompleted ? AmberColors.success : AmberColors.textSecondary,
              ),
            if (data.containsKey('is_completed'))
              const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  decoration: isCompleted ? TextDecoration.lineThrough : null,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        // 描述
        if (description != null && description.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            description,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AmberColors.textSecondary,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );
  }

  /// 构建底部操作栏
  Widget _buildBottomBar(ThemeData theme, {bool isMobile = false}) {
    // 移动端使用紧凑布局
    if (isMobile) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 主要操作按钮行
          Row(
            children: [
              // 取消按钮
              Expanded(
                child: OutlinedButton(
                  onPressed: _cancel,
                  child: const Text('取消'),
                ),
              ),
              const SizedBox(width: AmberDimens.spacingSm),
              // 完成/下一个按钮
              Expanded(
                child: _currentIndex < widget.conflicts.length - 1
                    ? ElevatedButton(
                        onPressed: _resolutions[_currentIndex] != null ? _moveToNext : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AmberColors.primary,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('下一个'),
                      )
                    : ElevatedButton(
                        onPressed: _allResolved ? _finish : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AmberColors.success,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('完成'),
                      ),
              ),
            ],
          ),
          // 上一个按钮（如果有多个冲突）
          if (widget.conflicts.length > 1 && _currentIndex > 0) ...[
            const SizedBox(height: AmberDimens.spacingXs),
            TextButton(
              onPressed: _moveToPrevious,
              child: const Text('← 上一个'),
            ),
          ],
        ],
      );
    }

    // 桌面端保持原有布局
    return Row(
      children: [
        // 上一个
        if (widget.conflicts.length > 1)
          TextButton.icon(
            onPressed: _currentIndex > 0 ? _moveToPrevious : null,
            icon: const Icon(Icons.arrow_back),
            label: const Text('上一个'),
          ),

        const Spacer(),

        // 取消按钮
        TextButton(
          onPressed: _cancel,
          child: const Text('取消同步'),
        ),
        const SizedBox(width: AmberDimens.spacingSm),

        // 下一个/完成按钮
        if (_currentIndex < widget.conflicts.length - 1)
          ElevatedButton.icon(
            onPressed: _resolutions[_currentIndex] != null ? _moveToNext : null,
            icon: const Icon(Icons.arrow_forward),
            label: const Text('下一个'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AmberColors.primary,
              foregroundColor: Colors.white,
            ),
          )
        else
          ElevatedButton.icon(
            onPressed: _allResolved ? _finish : null,
            icon: const Icon(Icons.check),
            label: const Text('完成'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AmberColors.success,
              foregroundColor: Colors.white,
            ),
          ),
      ],
    );
  }

  /// 获取表的显示名称
  String _getTableDisplayName(String tableName) {
    switch (tableName) {
      case 'tasks':
        return '任务';
      case 'task_lists':
        return '清单';
      case 'notes':
        return '笔记';
      case 'tags':
        return '标签';
      default:
        return tableName;
    }
  }

  /// 格式化日期时间
  String _formatDateTime(DateTime dt) {
    return '${dt.month}/${dt.day} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

/// 显示冲突决策弹窗
/// 返回用户决策列表，如果用户取消则返回 null
Future<List<ConflictResolution>?> showSyncConflictDialog(
  BuildContext context, {
  required List<RecordConflict> conflicts,
}) {
  return showDialog<List<ConflictResolution>>(
    context: context,
    barrierDismissible: false,
    builder: (context) => SyncConflictDialog(conflicts: conflicts),
  );
}

/// ============================================================
/// 首次同步冲突弹窗
/// ============================================================
/// 当检测到首次同步且双端都有数据时，询问用户如何处理：
/// - 从云端恢复（覆盖本地）
/// - 上传到云端（覆盖云端）
/// - 取消同步
///
/// 这通常发生在：
/// - 换新设备后首次同步
/// - 重装 App 后首次同步
/// - 切换到新的同步服务商后首次同步

/// 显示首次同步冲突弹窗
/// 返回用户选择，如果用户取消则返回 null
Future<FirstSyncChoice?> showFirstSyncConflictDialog(
  BuildContext context, {
  required int localTaskCount,
  required int remoteVersion,
  String? remoteDevice,
  DateTime? remoteLastSync,
}) {
  final screenWidth = MediaQuery.of(context).size.width;
  final isMobile = screenWidth < 600;

  return showDialog<FirstSyncChoice>(
    context: context,
    barrierDismissible: false,
    builder: (context) => Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AmberDimens.radiusLg),
      ),
      insetPadding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 40,
        vertical: 24,
      ),
      child: Container(
        width: isMobile ? double.infinity : 480,
        padding: EdgeInsets.all(isMobile ? AmberDimens.spacingMd : AmberDimens.spacingLg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题
            Row(
              children: [
                const Icon(
                  Icons.info_outline,
                  color: AmberColors.primary,
                  size: 28,
                ),
                const SizedBox(width: AmberDimens.spacingSm),
                Expanded(
                  child: Text(
                    '检测到数据差异',
                    style: TextStyle(
                      fontSize: isMobile ? 18 : 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AmberDimens.spacingMd),

            // 说明文字
            Text(
              '这是本设备首次同步，检测到本地和云端数据不一致。请选择如何处理：',
              style: TextStyle(
                fontSize: isMobile ? 13 : 14,
                color: AmberColors.textSecondary,
              ),
            ),
            const SizedBox(height: AmberDimens.spacingLg),

            // 本地数据信息
            _buildInfoCard(
              icon: Icons.phone_android,
              title: '本地数据',
              subtitle: '共 $localTaskCount 条任务',
              color: Colors.blue,
            ),
            const SizedBox(height: AmberDimens.spacingSm),

            // 云端数据信息
            _buildInfoCard(
              icon: Icons.cloud_outlined,
              title: '云端数据',
              subtitle: _buildRemoteDescription(remoteVersion, remoteDevice, remoteLastSync),
              color: Colors.green,
            ),
            const SizedBox(height: AmberDimens.spacingLg),

            // 选项按钮
            // 从云端恢复
            _buildChoiceButton(
              context: context,
              icon: Icons.cloud_download_outlined,
              title: '从云端恢复',
              subtitle: '用云端数据覆盖本地（推荐换设备时使用）',
              color: Colors.green,
              onTap: () => Navigator.of(context).pop(FirstSyncChoice.downloadFromCloud),
            ),
            const SizedBox(height: AmberDimens.spacingSm),

            // 上传到云端
            _buildChoiceButtonWithWarning(
              context: context,
              icon: Icons.cloud_upload_outlined,
              title: '上传到云端',
              subtitle: '用本地数据覆盖云端',
              warning: '请谨慎操作！',
              color: Colors.blue,
              onTap: () => Navigator.of(context).pop(FirstSyncChoice.uploadToCloud),
            ),
            const SizedBox(height: AmberDimens.spacingMd),

            // 取消按钮
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(FirstSyncChoice.cancel),
                child: const Text('暂不同步'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// 构建信息卡片
Widget _buildInfoCard({
  required IconData icon,
  required String title,
  required String subtitle,
  required Color color,
}) {
  return Container(
    padding: const EdgeInsets.all(AmberDimens.spacingMd),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(AmberDimens.radiusMd),
      border: Border.all(color: color.withValues(alpha: 0.3)),
    ),
    child: Row(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(width: AmberDimens.spacingSm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 12,
                  color: AmberColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

/// 构建选择按钮
Widget _buildChoiceButton({
  required BuildContext context,
  required IconData icon,
  required String title,
  required String subtitle,
  required Color color,
  required VoidCallback onTap,
}) {
  return InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(AmberDimens.radiusMd),
    child: Container(
      padding: const EdgeInsets.all(AmberDimens.spacingMd),
      decoration: BoxDecoration(
        border: Border.all(color: AmberColors.divider),
        borderRadius: BorderRadius.circular(AmberDimens.radiusMd),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: AmberDimens.spacingMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AmberColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right,
            color: AmberColors.textSecondary.withValues(alpha: 0.5),
          ),
        ],
      ),
    ),
  );
}

/// 构建带警告文字的选择按钮
Widget _buildChoiceButtonWithWarning({
  required BuildContext context,
  required IconData icon,
  required String title,
  required String subtitle,
  required String warning,
  required Color color,
  required VoidCallback onTap,
}) {
  return InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(AmberDimens.radiusMd),
    child: Container(
      padding: const EdgeInsets.all(AmberDimens.spacingMd),
      decoration: BoxDecoration(
        border: Border.all(color: AmberColors.divider),
        borderRadius: BorderRadius.circular(AmberDimens.radiusMd),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: AmberDimens.spacingMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                Row(
                  children: [
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AmberColors.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      warning,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.red,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right,
            color: AmberColors.textSecondary.withValues(alpha: 0.5),
          ),
        ],
      ),
    ),
  );
}

/// 构建云端描述
String _buildRemoteDescription(int version, String? device, DateTime? lastSync) {
  final parts = <String>[];
  parts.add('版本 $version');
  if (device != null) {
    parts.add('来自 $device');
  }
  if (lastSync != null) {
    final now = DateTime.now();
    final diff = now.difference(lastSync);
    if (diff.inDays > 0) {
      parts.add('${diff.inDays} 天前同步');
    } else if (diff.inHours > 0) {
      parts.add('${diff.inHours} 小时前同步');
    } else {
      parts.add('刚刚同步');
    }
  }
  return parts.join(' · ');
}
