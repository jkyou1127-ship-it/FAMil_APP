import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'services/alarm_scheduler.dart';
import 'services/api_client.dart';
import 'services/auth_provider.dart';
import 'services/kst_time.dart';
import 'services/local_notifications_service.dart';
import 'services/local_server_controller.dart';
import 'services/push_service.dart';
import 'services/server_config_service.dart';
import 'services/socket_service.dart';
import 'services/theme_controller.dart';
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
  late final PushService _pushService;
  late final ThemeController _themeController;
  late final LocalServerController _localServerController;

  @override
  void initState() {
    super.initState();
    _api = ApiClient(baseUrl: ServerConfigService.defaultUrl);
    _socket = SocketService();
    _auth = AuthProvider(api: _api, socket: _socket);
    _localNotifications = LocalNotificationsService();
    _alarmScheduler = AlarmScheduler(localNotifications: _localNotifications);
    _pushService = PushService(localNotifications: _localNotifications);
    _themeController = ThemeController();
    _localServerController = LocalServerController();
    _localNotifications.init();
    _auth.bootstrap();
    _themeController.load();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<ApiClient>.value(value: _api),
        Provider<SocketService>.value(value: _socket),
        ChangeNotifierProvider<AuthProvider>.value(value: _auth),
        Provider<AlarmScheduler>.value(value: _alarmScheduler),
        Provider<PushService>.value(value: _pushService),
        ChangeNotifierProvider<ThemeController>.value(value: _themeController),
        ChangeNotifierProvider<LocalServerController>.value(value: _localServerController),
      ],
      child: Consumer<ThemeController>(
        builder: (context, themeController, _) => MaterialApp(
          title: 'FAMil APP',
          scaffoldMessengerKey: rootScaffoldMessengerKey,
          debugShowCheckedModeBanner: false,
          themeMode: themeController.mode,
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: themeController.seedColor),
            useMaterial3: true,
          ),
          darkTheme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: themeController.seedColor,
              brightness: Brightness.dark,
            ),
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
