import 'package:flutter/material.dart';
import '../../../core/constants/constants.dart';
import '../../../core/utils/responsive_helper.dart';
import 'settings_tab_config.dart';
import 'widgets/settings_tab_navigator.dart';

/// 设置页面 - 支持多种显示模式(Dialog/独立窗口/页面跳转)
class SettingsPage extends StatelessWidget {
  /// 窗口唯一标识符
  /// desktop_multi_window 0.3.0 使用 String UUID
  /// 为 null 时表示在 Dialog 中显示
  final String? windowId;

  const SettingsPage({super.key, this.windowId});

  @override
  Widget build(BuildContext context) {
    // Dialog 模式(windowId == null)显示 macOS 风格关闭按钮
    final isDialog = windowId == null;

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 56,
        title: const Text('设置'),
        centerTitle: false,
        backgroundColor: AmberColors.cardBackground,
        elevation: 0,
        automaticallyImplyLeading: false, // 禁用默认返回按钮
        // Dialog Mode: Close button on the top left
        leading: isDialog
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
                tooltip: 'Close',
              )
            : null,
      ),
      body: const SettingsContent(),
    );
  }
}

/// 设置页面主体内容 - 封装的核心内容组件
///
/// 设计哲学:
/// - 完全独立，不依赖外层 Scaffold/AppBar
/// - 可用于 Dialog、独立窗口、页面跳转等任何场景
/// - 所有业务逻辑封装在此，外层只负责容器样式
class SettingsContent extends StatefulWidget {
  const SettingsContent({super.key});

  @override
  State<SettingsContent> createState() => _SettingsContentState();
}

class _SettingsContentState extends State<SettingsContent> {
  // 当前选中的标签索引
  int _currentTabIndex = 0;

  // 标签配置列表（从配置类加载）
  late final List<SettingsTabConfig> _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = SettingsTabConfig.getAllTabs();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile =
            constraints.maxWidth < ResponsiveHelper.mobileBreakpoint;

        if (isMobile) {
          return _buildMobileLayout();
        } else {
          return _buildDesktopLayout();
        }
      },
    );
  }

  /// 构建桌面端布局（原有布局）
  Widget _buildDesktopLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 左侧导航栏
        SettingsTabNavigator(
          tabs: _tabs,
          currentIndex: _currentTabIndex,
          onTabChanged: (index) {
            setState(() => _currentTabIndex = index);
          },
        ),

        // 分隔线
        const VerticalDivider(width: 1, thickness: 1),

        // 右侧内容区
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            switchInCurve: Curves.easeInOut,
            switchOutCurve: Curves.easeInOut,
            child: _buildTabContent(),
          ),
        ),
      ],
    );
  }

  /// 构建移动端布局
  /// 使用列表导航替代左侧栏
  Widget _buildMobileLayout() {
    // 如果选中了某个设置项，显示详情
    if (_currentTabIndex >= 0 && _showDetail) {
      return Column(
        children: [
          // 顶部返回栏
          Container(
            color: AmberColors.cardBackground,
            padding: const EdgeInsets.symmetric(
              horizontal: AmberDimens.spacingSm,
              vertical: AmberDimens.spacingSm,
            ),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => setState(() => _showDetail = false),
                  icon: const Icon(Icons.arrow_back),
                ),
                Text(
                  _tabs[_currentTabIndex].type.displayName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // 内容区
          Expanded(child: _buildTabContent()),
        ],
      );
    }

    // 设置项列表
    return ListView.builder(
      itemCount: _tabs.length,
      itemBuilder: (context, index) {
        final tab = _tabs[index];
        return ListTile(
          leading: Icon(
            tab.type.icon,
            color: AmberColors.textSecondary,
          ),
          title: Text(tab.type.displayName),
          trailing: const Icon(
            Icons.chevron_right,
            color: AmberColors.textDisabled,
          ),
          onTap: () {
            setState(() {
              _currentTabIndex = index;
              _showDetail = true;
            });
          },
        );
      },
    );
  }

  // 移动端是否显示详情页
  bool _showDetail = false;

  /// 构建当前标签内容
  Widget _buildTabContent() {
    return KeyedSubtree(
      key: ValueKey(_currentTabIndex),
      child: _tabs[_currentTabIndex].builder(context),
    );
  }
}

