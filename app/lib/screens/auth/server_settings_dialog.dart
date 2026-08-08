import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/auth_provider.dart';
import '../../services/server_config_service.dart';
import '../../services/server_discovery_service.dart';

Future<void> showServerSettingsDialog(BuildContext context) async {
  final auth = context.read<AuthProvider>();
  final controller = TextEditingController(text: auth.api.baseUrl);
  var searching = false;
  String? notFoundMessage;

  await showDialog<void>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) {
        Future<void> autoDetect() async {
          setState(() {
            searching = true;
            notFoundMessage = null;
          });
          final found = await ServerDiscoveryService.discover();
          setState(() {
            searching = false;
            if (found != null) {
              controller.text = found;
            } else {
              notFoundMessage = '같은 Wi-Fi에서 서버를 찾지 못했어요. PC에서 백엔드가 켜져 있고, 폰과 PC가 같은 Wi-Fi에 연결되어 있는지 확인해주세요.';
            }
          });
        }

        return AlertDialog(
          title: const Text('백엔드 서버 주소'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('이 앱이 연결할 FAMil APP 백엔드 서버 주소를 입력하세요.'),
              const SizedBox(height: 4),
              Text(
                '예: ${ServerConfigService.defaultUrl} (PC) 또는 http://192.168.0.10:4000 (실기기)',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  labelText: '서버 주소',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.url,
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: searching ? null : autoDetect,
                icon: searching
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.wifi_find_outlined),
                label: Text(searching ? '같은 Wi-Fi에서 찾는 중...' : '같은 Wi-Fi에서 자동 감지'),
              ),
              if (notFoundMessage != null) ...[
                const SizedBox(height: 8),
                Text(notFoundMessage!, style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12)),
              ],
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('취소')),
            FilledButton(
              onPressed: () async {
                await auth.setServerUrl(controller.text);
                if (context.mounted) Navigator.of(context).pop();
              },
              child: const Text('저장'),
            ),
          ],
        );
      },
    ),
  );
}
