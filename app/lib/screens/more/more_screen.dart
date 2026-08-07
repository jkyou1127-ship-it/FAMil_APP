import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/auth_provider.dart';
import '../../widgets/user_avatar.dart';
import '../admin/admin_panel_screen.dart';
import '../auth/server_settings_dialog.dart';
import '../lottery/lottery_screen.dart';
import '../profile/profile_screen.dart';
import '../sleep/sleep_screen.dart';
import '../suggestions/suggestion_screen.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final me = auth.currentUser;

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
            leading: const Icon(Icons.casino_outlined),
            title: const Text('추첨'),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LotteryScreen())),
          ),
          ListTile(
            leading: const Icon(Icons.bedtime_outlined),
            title: const Text('취침 / 기상'),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SleepScreen())),
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
