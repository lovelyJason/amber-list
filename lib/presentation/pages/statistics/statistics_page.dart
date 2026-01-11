import 'package:flutter/material.dart';
import '../../../../core/constants/constants.dart';
import '../../../../core/utils/responsive_helper.dart';
import '../../../presentation/widgets/adaptive/bottom_nav_bar.dart';
import 'monthly_view.dart';
import 'weekly_view.dart';

/// 统计页面
///
/// 设计说明：
/// - PC 端：无 AppBar，标题和切换按钮在页面内部
/// - 移动端：有 AppBar（标题+切换按钮）+ 底部导航栏，独立全屏页面
/// - 支持月视图和周视图切换
class StatisticsPage extends StatefulWidget {
  const StatisticsPage({super.key});

  @override
  State<StatisticsPage> createState() => _StatisticsPageState();
}

class _StatisticsPageState extends State<StatisticsPage> {
  // 0: Month, 1: Week
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < ResponsiveHelper.mobileBreakpoint;

    if (isMobile) {
      return _buildMobileLayout();
    } else {
      return _buildDesktopLayout();
    }
  }

  /// 构建移动端布局
  /// 独立全屏页面，包含 AppBar 和底部导航栏
  Widget _buildMobileLayout() {
    return Scaffold(
      backgroundColor: AmberColors.background,
      appBar: AppBar(
        title: const Text(
          '统计',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AmberColors.textPrimary,
          ),
        ),
        backgroundColor: AmberColors.cardBackground,
        elevation: 0,
        centerTitle: false,
        actions: [
          // 月/周视图切换按钮
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: _buildSegmentControl(),
          ),
        ],
      ),
      body: _selectedIndex == 0
          ? const MonthlyView(isMobile: true)
          : const WeeklyView(isMobile: true),
      bottomNavigationBar: const MobileBottomNavBar(),
    );
  }

  /// 构建桌面端布局（保持原有布局）
  Widget _buildDesktopLayout() {
    return Scaffold(
      backgroundColor: AmberColors.background,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
            child: Row(
              children: [
                const Text(
                  '统计',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AmberColors.textPrimary,
                  ),
                ),
                const Spacer(),
                // Segmented Control
                _buildSegmentControl(),
              ],
            ),
          ),

          // Content
          Expanded(
            child: _selectedIndex == 0 ? const MonthlyView() : const WeeklyView(),
          ),
        ],
      ),
    );
  }

  /// 构建分段控制器（月/周视图切换）
  Widget _buildSegmentControl() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AmberColors.cardBackground,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AmberColors.divider),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildSegmentButton('月视图', 0),
          _buildSegmentButton('周视图', 1),
        ],
      ),
    );
  }

  Widget _buildSegmentButton(String text, int index) {
    final isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedIndex = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AmberColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isSelected ? Colors.white : AmberColors.textSecondary,
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
