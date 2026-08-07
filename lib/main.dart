import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app_session.dart';
import 'firebase_options.dart';
import 'screens/auth/login_screen.dart';
import 'screens/home/home_shell.dart';
import 'services/auth_service.dart';

Object? _initError;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  } catch (e) {
    // firebase_options.dart가 아직 실제 프로젝트 값으로 설정되지 않았거나
    // 네트워크에 연결할 수 없는 경우. 앱은 뜨되 안내 화면을 보여준다.
    _initError = e;
  }
  runApp(const FamilApp());
}

class FamilApp extends StatelessWidget {
  const FamilApp({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = ThemeData(
      colorSchemeSeed: Colors.teal,
      useMaterial3: true,
    );

    if (_initError != null) {
      return MaterialApp(
        title: '패밀 (FAMil)',
        theme: theme,
        home: _FirebaseSetupNeededScreen(error: _initError!),
      );
    }

    return ChangeNotifierProvider<AppSession>(
      create: (_) => AppSession(AuthService()),
      child: MaterialApp(
        title: '패밀 (FAMil)',
        theme: theme,
        debugShowCheckedModeBanner: false,
        home: const _AuthGate(),
      ),
    );
  }
}

class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    final session = context.watch<AppSession>();
    switch (session.status) {
      case SessionStatus.loading:
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      case SessionStatus.signedOut:
        return const LoginScreen();
      case SessionStatus.signedIn:
        return HomeShell(session: session);
    }
  }
}

class _FirebaseSetupNeededScreen extends StatelessWidget {
  const _FirebaseSetupNeededScreen({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.settings_suggest, size: 64, color: Colors.orange),
                const SizedBox(height: 16),
                Text('Firebase 설정이 필요합니다',
                    style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 12),
                const Text(
                  'lib/firebase_options.dart가 아직 자리표시자(placeholder) 값입니다.\n'
                  '프로젝트 루트에서 아래 명령을 실행해 여러분의 Firebase 프로젝트로 '
                  '연결한 뒤 다시 실행하세요.\n\n'
                  '  flutterfire configure\n\n'
                  '자세한 내용은 README.md의 "Firebase 설정" 섹션을 참고하세요.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text('오류: $error',
                    style: const TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
