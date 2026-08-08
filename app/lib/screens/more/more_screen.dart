import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/theme_colors.dart';
import '../../services/auth_provider.dart';
import '../../services/theme_controller.dart';
import '../../widgets/user_avatar.dart';
import '../admin/admin_panel_screen.dart';
import '../admin/backup_server_screen.dart';
import '../auth/server_settings_dialog.dart';
import '../profile/profile_screen.dart';
import '../shopping/shopping_list_screen.dart';
import '../sleep/sleep_screen.dart';
import '../suggestions/suggestion_screen.dart';

String _themeModeLabel(ThemeMode mode) => switch (mode) {
      ThemeMode.system => '시스템 설정 따름',
      ThemeMode.light => '라이트 모드',
      ThemeMode.dark => '다크 모드',
    };

Future<void> _showThemeDialog(BuildContext context) async {
  final controller = context.read<ThemeController>();
  await showDialog<void>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text('화면 테마'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RadioGroup<ThemeMode>(
                groupValue: controller.mode,
                onChanged: (mode) {
                  if (mode == null) return;
                  controller.setMode(mode);
                  setState(() {});
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: ThemeMode.values
                      .map((mode) => RadioListTile<ThemeMode>(value: mode, title: Text(_themeModeLabel(mode))))
                      .toList(),
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Text('강조 색상'),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: kThemeColors.map((option) {
                    final selected = controller.colorId == option.id;
                    return InkWell(
                      onTap: () {
                        controller.setColorId(option.id);
                        setState(() {});
                      },
                      customBorder: const CircleBorder(),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: option.color,
                          shape: BoxShape.circle,
                          border: selected
                              ? Border.all(color: Theme.of(context).colorScheme.onSurface, width: 2)
                              : null,
                        ),
                        child: selected ? const Icon(Icons.check, color: Colors.white, size: 18) : null,
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('닫기')),
        ],
      ),
    ),
  );
}

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final me = auth.currentUser;
    final themeController = context.watch<ThemeController>();
    final matchingColors = kThemeColors.where((c) => c.id == themeController.colorId);
    final themeColorLabel = matchingColors.isNotEmpty ? matchingColors.first.label : kThemeColors.first.label;

    return Scaffold(
      appBar: AppBar(title: const Text('더보기')),
      body: ListView(
        children: [
          if (me != null)
            ListTile(
              leading: UserAvatar(photoUrl: me.profilePhoto, name: me.displayName),
              title: Text(me.displayName),
              subtitle: Text(me.isAdmin ? '관리자' : '사용자'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ProfileScreen())),
            ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.campaign_outlined),
            title: const Text('건의사항'),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SuggestionScreen())),
          ),
          ListTile(
            leading: const Icon(Icons.bedtime_outlined),
            title: const Text('취침 / 기상'),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SleepScreen())),
          ),
          ListTile(
            leading: const Icon(Icons.shopping_cart_outlined),
            title: const Text('장보기 목록'),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ShoppingListScreen())),
          ),
          ListTile(
            leading: const Icon(Icons.backup_outlined),
            title: const Text('백업 서버 (임시)'),
            subtitle: const Text('PC 서버가 꺼졌을 때 이 기기를 임시 서버로 켜기'),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const BackupServerScreen())),
          ),
          if (me?.isAdmin == true) ...[
            const Divider(),
            ListTile(
              leading: const Icon(Icons.admin_panel_settings_outlined),
              title: const Text('관리자 패널'),
              subtitle: const Text('방 만들기 · 소유자 배정'),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AdminPanelScreen())),
            ),
          ],
          const Divider(),
          ListTile(
            leading: CircleAvatar(radius: 12, backgroundColor: themeController.seedColor),
            title: const Text('화면 테마'),
            subtitle: Text('${_themeModeLabel(themeController.mode)} · $themeColorLabel'),
            onTap: () => _showThemeDialog(context),
          ),
          ListTile(
            leading: const Icon(Icons.settings_ethernet),
            title: const Text('서버 주소 설정'),
            onTap: () => showServerSettingsDialog(context),
          ),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('로그아웃'),
            onTap: () => auth.logout(),
          ),
        ],
      ),
    );
  }
}
