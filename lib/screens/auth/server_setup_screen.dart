import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_session.dart';

/// 자체 백엔드(server/) 주소를 처음 입력받는 화면.
/// 한 번 입력하면 기기에 저장되어 다음 실행부터는 다시 묻지 않는다.
class ServerSetupScreen extends StatefulWidget {
  const ServerSetupScreen({super.key});

  @override
  State<ServerSetupScreen> createState() => _ServerSetupScreenState();
}

class _ServerSetupScreenState extends State<ServerSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _urlController = TextEditingController(text: 'http://');
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await context.read<AppSession>().configureServer(_urlController.text.trim());
    } catch (e) {
      setState(() => _error = '서버 주소를 저장하지 못했습니다: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.dns_outlined, size: 64),
                  const SizedBox(height: 8),
                  Text(
                    '서버 주소 설정',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '패밀은 여러분이 직접 실행하는 자체 백엔드(server/)와 통신합니다.\n'
                    '먼저 서버를 실행한 뒤, 그 주소를 입력하세요.\n'
                    '(예: http://192.168.0.10:8080)',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _urlController,
                    keyboardType: TextInputType.url,
                    decoration: const InputDecoration(
                      labelText: '서버 주소 (http://호스트:포트)',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return '서버 주소를 입력하세요';
                      if (!v.trim().startsWith('http://') &&
                          !v.trim().startsWith('https://')) {
                        return 'http:// 또는 https://로 시작해야 합니다';
                      }
                      return null;
                    },
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!, style: const TextStyle(color: Colors.red)),
                  ],
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _loading ? null : _submit,
                    child: _loading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('저장하고 계속'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
