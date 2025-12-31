import 'package:flutter/material.dart';
import '../../../core/constants/constants.dart';
import 'settings_tab_config.dart';
import 'widgets/settings_tab_navigator.dart';

/// 设置页面 - 支持多种显示模式(Dialog/独立窗口/页面跳转)
class SettingsPage extends StatelessWidget {
  final int? windowId;

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
        // Dialog 模式显示 macOS 风格的关闭按钮
        leading: isDialog ? _buildMacOSCloseButton(context) : null,
      ),
      body: const SettingsContent(), // 🔧 内容已封装，可复用
    );
  }

  /// macOS 风格的关闭按钮 (红色圆点 + hover 效果)
  Widget _buildMacOSCloseButton(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(left: 12),
        child: _MacOSCloseButton(
          onTap: () => Navigator.of(context).pop(),
        ),
      ),
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

  /// 构建当前标签内容
  Widget _buildTabContent() {
    return KeyedSubtree(
      key: ValueKey(_currentTabIndex),
      child: _tabs[_currentTabIndex].builder(context),
    );
  }
}

/// macOS 窗口控制按钮 (红色关闭按钮)
class _MacOSCloseButton extends StatefulWidget {
  final VoidCallback onTap;

  const _MacOSCloseButton({required this.onTap});

  @override
  State<_MacOSCloseButton> createState() => _MacOSCloseButtonState();
}

class _MacOSCloseButtonState extends State<_MacOSCloseButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: const Color(0xFFFF5F57), // macOS 红色
            shape: BoxShape.circle,
            border: _isHovered ? null : Border.all(
              color: const Color(0xFFE14C40),
              width: 0.5,
            ),
          ),
          // Hover 时显示关闭图标
          child: _isHovered
              ? const Icon(
                  Icons.close,
                  size: 8,
                  color: Color(0xFF4D0000),
                )
              : null,
        ),
      ),
    );
  }
}
