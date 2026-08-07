import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app_session.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/server_setup_screen.dart';
import 'screens/home/home_shell.dart';
import 'services/auth_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
      case SessionStatus.needsServer:
        return const ServerSetupScreen();
      case SessionStatus.signedOut:
        return const LoginScreen();
      case SessionStatus.signedIn:
        return HomeShell(session: session);
    }
  }
}
