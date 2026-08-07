import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'services/alarm_scheduler.dart';
import 'services/api_client.dart';
import 'services/auth_provider.dart';
import 'services/kst_time.dart';
import 'services/local_notifications_service.dart';
import 'services/server_config_service.dart';
import 'services/socket_service.dart';
import 'screens/auth/login_screen.dart';
import 'screens/home/home_shell.dart';

final rootScaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  KstTime.init();
  await initializeDateFormatting('ko_KR');
  runApp(const FamilApp());
}

class FamilApp extends StatefulWidget {
  const FamilApp({super.key});

  @override
  State<FamilApp> createState() => _FamilAppState();
}

class _FamilAppState extends State<FamilApp> {
  late final ApiClient _api;
  late final SocketService _socket;
  late final AuthProvider _auth;
  late final LocalNotificationsService _localNotifications;
  late final AlarmScheduler _alarmScheduler;

  @override
  void initState() {
    super.initState();
    _api = ApiClient(baseUrl: ServerConfigService.defaultUrl);
    _socket = SocketService();
    _auth = AuthProvider(api: _api, socket: _socket);
    _localNotifications = LocalNotificationsService();
    _alarmScheduler = AlarmScheduler(localNotifications: _localNotifications);
    _localNotifications.init();
    _auth.bootstrap();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<ApiClient>.value(value: _api),
        Provider<SocketService>.value(value: _socket),
        ChangeNotifierProvider<AuthProvider>.value(value: _auth),
        Provider<AlarmScheduler>.value(value: _alarmScheduler),
      ],
      child: MaterialApp(
        title: 'FAMil APP',
        scaffoldMessengerKey: rootScaffoldMessengerKey,
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF3D6BFF)),
          useMaterial3: true,
        ),
        home: Consumer<AuthProvider>(
          builder: (context, auth, _) {
            switch (auth.status) {
              case AuthStatus.unknown:
                return const _SplashScreen();
              case AuthStatus.signedOut:
                return const LoginScreen();
              case AuthStatus.signedIn:
                return const HomeShell();
            }
          },
        ),
      ),
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
