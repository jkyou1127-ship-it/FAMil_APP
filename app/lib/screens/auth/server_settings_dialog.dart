import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/auth_provider.dart';
import '../../services/server_config_service.dart';

Future<void> showServerSettingsDialog(BuildContext context) async {
  final auth = context.read<AuthProvider>();
  final controller = TextEditingController(text: auth.api.baseUrl);

  await showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
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
    ),
  );
}
