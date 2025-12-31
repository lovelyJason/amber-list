import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';

import '../../core/constants/constants.dart';
import '../pages/settings/settings_page.dart';
import 'animated_logo.dart';

class AmberMenuBar extends StatelessWidget {
  final Widget child;

  const AmberMenuBar({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    if (!Platform.isMacOS) return child;

    return PlatformMenuBar(
      menus: [
        PlatformMenu(
          label: 'AmberList', // MacOS ignores this label for the first menu
          menus: [
            PlatformMenuItem(
              label: '关于 琥珀清单',
              onSelected: () {
                showAboutDialog(
                  context: context,
                  applicationName: '琥珀清单',
                  applicationVersion: '1.0.0',
                  applicationIcon: const AnimatedLogo(
                    width: 48,
                    height: 48,
                  ),
                  children: [
                    const Text('一款简约而不失质感的桌面端待办应用'),
                  ],
                );
              },
            ),
            const PlatformMenuItemGroup(members: [
              PlatformMenuItem(label: '检查更新...', onSelected: null), // Pending implementation
            ]),
            PlatformMenuItemGroup(members: [
              PlatformMenuItem(
                label: '设置...',
                shortcut: const SingleActivator(LogicalKeyboardKey.comma, meta: true),
                onSelected: () {
                  // 🔧 使用 Dialog 替代独立窗口，完全没有黑屏
                  showDialog(
                    context: context,
                    barrierColor: Colors.black54,
                    builder: (context) => Dialog(
                      backgroundColor: Colors.transparent,
                      insetPadding: const EdgeInsets.all(40),
                      child: Container(
                        width: 1000,
                        height: 700,
                        decoration: BoxDecoration(
                          color: AmberColors.background,
                          borderRadius: BorderRadius.circular(AmberDimens.radiusLg),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.3),
                              blurRadius: 30,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(AmberDimens.radiusLg),
                          child: const SettingsPage(windowId: null),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ]),

            PlatformMenuItemGroup(members: [
              PlatformMenuItem(
                label: '隐藏 琥珀清单',
                shortcut: const SingleActivator(LogicalKeyboardKey.keyH, meta: true),
                onSelected: () {
                  windowManager.hide();
                },
              ),
              PlatformProvidedMenuItem(type: PlatformProvidedMenuItemType.hideOtherApplications),
              PlatformProvidedMenuItem(type: PlatformProvidedMenuItemType.showAllApplications),
            ]),
            PlatformMenuItemGroup(members: [
              PlatformMenuItem(
                label: '退出 琥珀清单',
                shortcut: const SingleActivator(LogicalKeyboardKey.keyQ, meta: true),
                onSelected: () {
                  windowManager.close();
                },
              ),
            ]),
          ],
        ),
        PlatformMenu(
          label: '编辑',
          menus: [
            PlatformMenuItemGroup(members: [
              PlatformMenuItem(
                label: '撤销',
                shortcut: const SingleActivator(LogicalKeyboardKey.keyZ, meta: true),
                onSelected: () {
                    // Undo logic or rely on system focus
                    // For now, these might not work without FocusNode integration
                },
              ),
              PlatformMenuItem(
                label: '重做',
                shortcut: const SingleActivator(LogicalKeyboardKey.keyZ, meta: true, shift: true),
                onSelected: () {},
              ),
            ]),
            PlatformMenuItemGroup(members: [
              PlatformMenuItem(
                label: '剪切',
                shortcut: const SingleActivator(LogicalKeyboardKey.keyX, meta: true),
                 onSelected: () {
                   Clipboard.getData(Clipboard.kTextPlain).then((value) {
                     // Default text editing might handle this if focused
                   });
                 },
              ),
              PlatformMenuItem(
                label: '复制',
                shortcut: const SingleActivator(LogicalKeyboardKey.keyC, meta: true),
                onSelected: () {},
              ),
              PlatformMenuItem(
                label: '粘贴',
                shortcut: const SingleActivator(LogicalKeyboardKey.keyV, meta: true),
                onSelected: () {},
              ),
              PlatformMenuItem(
                label: '全选',
                shortcut: const SingleActivator(LogicalKeyboardKey.keyA, meta: true),
                onSelected: () {},
              )
            ]),
          ],
        ),
        PlatformMenu(
          label: '窗口',
          menus: [
             PlatformMenuItem(
                label: '最小化',
                shortcut: const SingleActivator(LogicalKeyboardKey.keyM, meta: true),
                onSelected: () {
                  windowManager.minimize();
                },
              ),
             PlatformMenuItem(
                label: '缩放',
                onSelected: () {
                   windowManager.maximize(); // Or toggle
                },
              ),
          ],
        ),
      ],
      child: child,
    );
  }
}
