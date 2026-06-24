import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'screens/auth/login_page.dart';
import 'screens/auth/change_password_page.dart';
import 'screens/manager/manager_home.dart';
import 'screens/supervisor/supervisor_home.dart';
import 'screens/staff/staff_home.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://lfrtgloficmyutqazuok.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImxmcnRnbG9maWNteXV0cWF6dW9rIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODE1MjYyNDUsImV4cCI6MjA5NzEwMjI0NX0.rMmuvvVtpWX1TnO7D7Z7bEz5O_T9ats0IR_kRZpb-qU',
  );

  runApp(const BistroLogApp());
}

class BistroLogApp extends StatelessWidget {
  const BistroLogApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BISTROLOG',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF8F5FC),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.deepPurple,
          foregroundColor: Colors.white,
          centerTitle: true,
        ),
      ),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final supabase = Supabase.instance.client;

  bool isLoading = true;
  String? errorMessage;

  String? role;
  String? fullName;
  bool mustChangePassword = false;

  @override
  void initState() {
    super.initState();
    checkSession();
  }

  Future<void> checkSession() async {
    final user = supabase.auth.currentUser;

    if (user == null) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
      });

      return;
    }

    try {
      final profile = await supabase
          .from('profiles')
          .select(
            'role, full_name, is_active, staff_status, must_change_password',
          )
          .eq('id', user.id)
          .maybeSingle();

      if (profile == null) {
        await supabase.auth.signOut();

        if (!mounted) return;

        setState(() {
          role = null;
          fullName = null;
          mustChangePassword = false;
          isLoading = false;
        });

        return;
      }

      final isActive = profile['is_active'];
      final staffStatus = (profile['staff_status'] ?? 'active').toString();

      if (isActive == false || staffStatus == 'inactive') {
        await supabase.auth.signOut();

        if (!mounted) return;

        setState(() {
          role = null;
          fullName = null;
          mustChangePassword = false;
          isLoading = false;
        });

        return;
      }

      if (!mounted) return;

      setState(() {
        role = (profile['role'] ?? '').toString();
        fullName = (profile['full_name'] ?? '').toString();
        mustChangePassword = profile['must_change_password'] == true;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        errorMessage = 'Failed to load profile: $e';
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (errorMessage != null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('BISTROLOG'),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ),
      );
    }

    if (role == null || role!.isEmpty) {
      return const LoginPage();
    }

    if (mustChangePassword) {
      return const ChangePasswordPage();
    }

    if (role == 'manager') {
      return ManagerHome(fullName: fullName ?? 'Manager');
    } else if (role == 'supervisor') {
      return SupervisorHome(fullName: fullName ?? 'Supervisor');
    } else if (role == 'staff') {
      return StaffHome(fullName: fullName ?? 'Staff');
    } else {
      return const LoginPage();
    }
  }
}