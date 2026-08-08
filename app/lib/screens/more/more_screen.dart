import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/auth_provider.dart';
import '../../services/theme_controller.dart';
import '../../widgets/user_avatar.dart';
import '../admin/admin_panel_screen.dart';
import '../admin/backup_server_screen.dart';
import '../auth/server_settings_dialog.dart';
import '../profile/profile_screen.dart';
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
    builder: (context) => AlertDialog(
      title: const Text('화면 테마'),
      content: RadioGroup<ThemeMode>(
        groupValue: controller.mode,
        onChanged: (mode) {
          if (mode == null) return;
          controller.setMode(mode);
          Navigator.of(context).pop();
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: ThemeMode.values
              .map((mode) => RadioListTile<ThemeMode>(value: mode, title: Text(_themeModeLabel(mode))))
              .toList(),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('닫기')),
      ],
    ),
  );
}

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final me = auth.currentUser;
    final themeMode = context.watch<ThemeController>().mode;

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
            leading: const Icon(Icons.dark_mode_outlined),
            title: const Text('화면 테마'),
            subtitle: Text(_themeModeLabel(themeMode)),
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
