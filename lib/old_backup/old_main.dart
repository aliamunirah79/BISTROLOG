import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/login.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://pdrbscfhfvxeyrhjofjo.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InBkcmJzY2ZoZnZ4ZXlyaGpvZmpvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzU5NDM2NDcsImV4cCI6MjA5MTUxOTY0N30.VUknt5qnCox84xpaygOHssbTdX1RbQNpSO06LaIKKWY',
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  static const Color mulberry = Color(0xFF6D2B50);
  static const Color mulberryDark = Color(0xFF4A1A35);
  static const Color cream = Color(0xFFF5ECD7);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'BistroLog',
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: cream,
        primaryColor: mulberry,
        colorScheme: ColorScheme.fromSeed(
          seedColor: mulberry,
          primary: mulberry,
          secondary: mulberryDark,
          surface: cream,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: cream,
          foregroundColor: mulberryDark,
          elevation: 0,
        ),
        textTheme: const TextTheme(
          bodyMedium: TextStyle(fontSize: 14),
          bodyLarge: TextStyle(fontSize: 16),
        ),
      ),

      // Fix huge text scaling from phone accessibility settings.
      // Also helps keep Stock In / Stock Take UI consistent.
      builder: (context, child) {
        final mediaQuery = MediaQuery.of(context);

        return MediaQuery(
          data: mediaQuery.copyWith(
            textScaler: const TextScaler.linear(1.0),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },

      home: const LoginPage(),
    );
  }
}