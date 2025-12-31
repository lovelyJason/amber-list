import 'package:flutter/material.dart';
import '../../../core/constants/dimensions.dart';
import '../../../core/constants/colors.dart';
import '../../../core/theme/amber_theme.dart';

class SettingsSkeleton extends StatelessWidget {
  const SettingsSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    debugPrint('MultiWindow: SettingsSkeleton building...');
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AmberTheme.lightTheme,
      home: Scaffold(
        appBar: AppBar(
          toolbarHeight: 56, // Standard height
          title: const Text('设置'),
          centerTitle: false,
          backgroundColor: AmberColors.cardBackground,
          elevation: 0,
          leading: const Icon(Icons.arrow_back, color: AmberColors.textPrimary),
        ),
        body: ListView(
          padding: const EdgeInsets.all(AmberDimens.spacingMd),
          children: [
            _buildSectionSkeleton(),
            const SizedBox(height: AmberDimens.spacingLg),
            _buildSectionSkeleton(),
            const SizedBox(height: AmberDimens.spacingLg),
            _buildSectionSkeleton(),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionSkeleton() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AmberDimens.spacingSm,
            vertical: AmberDimens.spacingSm,
          ),
          child: Container(
            width: 60,
            height: 12,
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: AmberColors.cardBackground,
            borderRadius: BorderRadius.circular(AmberDimens.radiusMd),
            border: Border.all(color: AmberColors.divider),
          ),
          child: Column(
            children: List.generate(2, (index) => _buildTileSkeleton(isLast: index == 1)),
          ),
        ),
      ],
    );
  }

  Widget _buildTileSkeleton({bool isLast = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: isLast ? null : Border(bottom: BorderSide(color: AmberColors.divider.withOpacity(0.5))),
      ),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 100,
                  height: 14,
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  width: 180,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ],
      ),
    );
  }
}
