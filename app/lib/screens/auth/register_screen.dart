import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/backend_mode.dart';
import '../../services/api_client.dart';
import '../../services/auth_provider.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _displayNameController = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _displayNameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = context.read<ApiClient>();
      await context.read<AuthProvider>().register(
            _usernameController.text.trim(),
            _passwordController.text,
            _displayNameController.text.trim(),
          );
      // PC가 꺼져 있어서 Firebase 모드로 가입한 경우, 완전히 연동되기 전까지
      // 가족 목록/메신저 등이 제한된다는 걸 바로 알려준다 - register()가
      // 성공하면 곧 화면이 HomeShell로 바뀌므로, 그 전에 한 번만 띄운다.
      if (mounted && api.mode == BackendMode.firebase) {
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('가입 완료'),
            content: const Text(
              '지금은 PC 서버가 꺼져 있어서 Firebase로 가입되었습니다.\n'
              '로그인은 바로 되지만, 가족 목록에 보이거나 메신저를 쓰려면 '
              'PC 서버가 켜진 뒤 한 번 더 로그인해주세요 — 그때 자동으로 완전히 연동됩니다.',
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('확인')),
            ],
          ),
        );
      }
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = '회원가입 중 오류가 발생했습니다: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('회원가입')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text('가장 먼저 가입하는 계정이 이 시스템의 관리자 계정이 됩니다.'),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _displayNameController,
                      decoration: const InputDecoration(labelText: '이름', border: OutlineInputBorder()),
                      validator: (v) => (v == null || v.trim().isEmpty) ? '이름을 입력해주세요.' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _usernameController,
                      decoration: const InputDecoration(labelText: '아이디', border: OutlineInputBorder()),
                      validator: (v) => (v == null || v.trim().isEmpty) ? '아이디를 입력해주세요.' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _passwordController,
                      decoration: const InputDecoration(labelText: '비밀번호 (4자 이상)', border: OutlineInputBorder()),
                      obscureText: true,
                      validator: (v) => (v == null || v.length < 4) ? '비밀번호는 4자 이상이어야 합니다.' : null,
                      onFieldSubmitted: (_) => _submit(),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                    ],
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: _loading ? null : _submit,
                      child: _loading
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('회원가입'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
