import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'providers/auth_provider.dart';
import 'providers/patrol_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/supervisor/dashboard.dart';
import 'screens/so/so_dashboard.dart';
import 'models/user_model.dart';
import 'services/notification_service.dart';

// Global navigator key for notification redirection
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const String supabaseUrl = 'https://rndgqheinwvkbheppmyi.supabase.co';
  const String supabaseAnonKey = 'sb_publishable_HUml26vDTq0SWfZFItnN4g_uxVR0U5z';

  try {
    await Hive.initFlutter();
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(UserModelAdapter());
    }
    await Hive.openBox<UserModel>('users');
    await Hive.openBox('patrol_cache');

    await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);

    await Firebase.initializeApp();
    await NotificationService().initialize();

    runApp(const MyApp());
  } catch (e) {
    debugPrint('Startup error: $e');
    runApp(const MyApp());
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => PatrolProvider()),
      ],
      child: MaterialApp(
        title: 'Embassy Patrol',
        navigatorKey: navigatorKey, // Set the key here
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          primarySwatch: Colors.blue,
          useMaterial3: true,
          appBarTheme: const AppBarTheme(elevation: 0, centerTitle: true),
        ),
        home: Consumer<AuthProvider>(
          builder: (context, auth, _) {
            if (auth.isInitializing) {
              return const Scaffold(
                body: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Initializing Session...', style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                ),
              );
            }

            if (auth.currentUser != null) {
              return auth.currentUser!.role == 'SO' 
                  ? const SODashboard() 
                  : const SupervisorDashboard();
            }

            return const LoginScreen();
          },
        ),
      ),
    );
  }
}
