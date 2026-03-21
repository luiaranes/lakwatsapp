import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:larga/config/supabase_config.dart';
import 'package:larga/screens/sign_in_screen.dart';
import 'package:larga/screens/main_shell.dart';
import 'package:larga/utils/url_helper.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint('Error loading .env file: $e');
  }

  await Supabase.initialize(
    url: SupabaseConfig.supabaseUrl,
    anonKey: SupabaseConfig.supabaseAnonKey,
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce,
    ),
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lakwatsapp',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFF06B64), // Coral from logo
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _isLoading = true;
  Session? _session;
  StreamSubscription<AuthState>? _authSubscription;

  @override
  void initState() {
    super.initState();
    _initAuth();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initAuth() async {
    // Get initial session
    _session = Supabase.instance.client.auth.currentSession;
    debugPrint('Initial session: ${_session != null ? "exists" : "null"}');
    
    // Listen to auth state changes
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      debugPrint('Auth state changed: ${data.event}, session: ${data.session != null}');
      if (mounted) {
        setState(() {
          _session = data.session;
          debugPrint('Session updated in state: ${_session != null}');
        });
      }
    }, onError: (error) {
      debugPrint('Auth state error: $error');
    });

    // Cleanup web OAuth parameters
    UrlHelper.cleanupOAuthParameters();

    // Small delay to allow deep link processing
    await Future.delayed(const Duration(milliseconds: 500));
    
    // Check session again after delay (in case deep link was processed)
    if (mounted) {
      final currentSession = Supabase.instance.client.auth.currentSession;
      if (currentSession != null && _session == null) {
        debugPrint('Session found after delay, updating state');
        setState(() {
          _session = currentSession;
        });
      }
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_session != null) {
      return const MainShell();
    } else {
      return const SignInScreen();
    }
  }
}
