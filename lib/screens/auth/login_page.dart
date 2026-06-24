import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../manager/manager_home.dart';
import '../supervisor/supervisor_home.dart';
import '../staff/staff_home.dart';
import 'change_password_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final supabase = Supabase.instance.client;

  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  bool isLoading = false;
  bool obscurePassword = true;

  static const Color mulberry = Color(0xFF6D2B50);
  static const Color mulberryDark = Color(0xFF4A1A35);
  static const Color mulberryLight = Color(0xFF8B3D68);
  static const Color cream = Color(0xFFF5ECD7);
  static const Color creamDark = Color(0xFFE8D5B5);
  static const Color softWhite = Color(0xFFFFFCF7);

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> loginUser() async {
    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      showMessage('Please enter email and password.');
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final authResponse = await supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      final user = authResponse.user;

      if (user == null) {
        await supabase.auth.signOut();
        showMessage('Login failed. User not found.');
        return;
      }

      final profile = await supabase
          .from('profiles')
          .select('role, full_name, is_active, staff_status, must_change_password')
          .eq('id', user.id)
          .maybeSingle();

      if (profile == null) {
        await supabase.auth.signOut();
        showMessage('Profile not found. Please contact manager.');
        return;
      }

      final isActive = profile['is_active'];
      final staffStatus = (profile['staff_status'] ?? 'active').toString();

      if (isActive == false || staffStatus == 'inactive') {
        await supabase.auth.signOut();
        showMessage(
          'Your account has been deactivated. Please contact manager.',
        );
        return;
      }

      final mustChangePassword = profile['must_change_password'] == true;

        if (mustChangePassword) {
          if (!mounted) return;

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => const ChangePasswordPage(),
            ),
          );
          return;
        }

      final role = (profile['role'] ?? '').toString();
      final fullName = (profile['full_name'] ?? '').toString();

      if (!mounted) return;

      if (role == 'manager') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => ManagerHome(fullName: fullName),
          ),
        );
      } else if (role == 'supervisor') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => SupervisorHome(fullName: fullName),
          ),
        );
      } else if (role == 'staff') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => StaffHome(fullName: fullName),
          ),
        );
      } else {
        await supabase.auth.signOut();
        showMessage('Invalid role found in profile.');
      }
    } on AuthException catch (e) {
      showMessage(e.message);
    } catch (e) {
      showMessage('Login error: $e');
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> resetPassword() async {
    final email = emailController.text.trim();

    if (email.isEmpty) {
      showMessage('Enter your email first.');
      return;
    }

    try {
      await supabase.auth.resetPasswordForEmail(email);

      showMessage(
        'Password reset email sent.',
        isError: false,
      );
    } on AuthException catch (e) {
      showMessage(e.message);
    } catch (e) {
      showMessage('Failed to send password reset email: $e');
    }
  }

  void showMessage(String message, {bool isError = true}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).clearSnackBars();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(
            color: cream,
            fontFamily: 'Georgia',
          ),
        ),
        backgroundColor: isError ? mulberryDark : mulberry,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );
  }


  Widget buildLogo() {
    return Container(
      width: 122,
      height: 122,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFFF8F1E6),
        border: Border.all(
          color: Colors.white.withOpacity(0.88),
          width: 3,
        ),
        boxShadow: [
          BoxShadow(
            color: mulberryDark.withOpacity(0.35),
            blurRadius: 22,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: ClipOval(
        child: Transform.scale(
          scale: 1.25,
          child: Image.asset(
            'logo.png',
            fit: BoxFit.cover,
            alignment: Alignment.center,
            errorBuilder: (context, error, stackTrace) {
              return const Icon(
                Icons.local_cafe,
                size: 48,
                color: mulberry,
              );
            },
          ),
        ),
      ),
    );
  }

  Widget buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscure = false,
    TextInputType keyboardType = TextInputType.text,
    Widget? suffix,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      enabled: !isLoading,
      style: const TextStyle(
        fontSize: 15,
        color: mulberryDark,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: Colors.grey.shade700,
          fontSize: 14,
        ),
        prefixIcon: Icon(
          icon,
          color: mulberry,
          size: 20,
        ),
        suffixIcon: suffix,
        filled: true,
        fillColor: cream,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: creamDark,
            width: 1.35,
          ),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: creamDark.withOpacity(0.70),
            width: 1.2,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: mulberry,
            width: 2,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
    );
  }

 Widget buildLoginCard() {
  return Container(
    width: double.infinity,
    constraints: const BoxConstraints(maxWidth: 400),
    padding: const EdgeInsets.fromLTRB(24, 26, 24, 20),
    decoration: BoxDecoration(
      color: softWhite,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(
        color: creamDark.withOpacity(0.62),
      ),
      boxShadow: [
        BoxShadow(
          color: mulberryDark.withOpacity(0.15),
          blurRadius: 28,
          offset: const Offset(0, 11),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Welcome back',
          style: TextStyle(
            fontFamily: 'Georgia',
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: mulberryDark,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Sign in to your BISTROLOG account',
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey.shade500,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 24),
        buildTextField(
          controller: emailController,
          label: 'Email',
          icon: Icons.email_outlined,
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 16),
        buildTextField(
          controller: passwordController,
          label: 'Password',
          icon: Icons.lock_outline,
          obscure: obscurePassword,
          suffix: IconButton(
            icon: Icon(
              obscurePassword
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
              color: mulberry,
              size: 20,
            ),
            onPressed: isLoading
                ? null
                : () {
                    setState(() {
                      obscurePassword = !obscurePassword;
                    });
                  },
          ),
        ),
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: isLoading ? null : resetPassword,
            style: TextButton.styleFrom(
              foregroundColor: mulberry,
              padding: EdgeInsets.zero,
              minimumSize: const Size(0, 38),
            ),
            child: const Text(
              'Forgot password?',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 52,
          child: ElevatedButton(
            onPressed: isLoading ? null : loginUser,
            style: ElevatedButton.styleFrom(
              backgroundColor: mulberry,
              foregroundColor: cream,
              disabledBackgroundColor: mulberry.withOpacity(0.45),
              elevation: 5,
              shadowColor: mulberryDark.withOpacity(0.45),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: isLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: cream,
                    ),
                  )
                : const Text(
                    'Sign In',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.1,
                    ),
                  ),
          ),
        ),
      ],
    ),
  );
}
          

  Widget buildFooterText() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Text(
        'Operational compliance • Smart inventory • Staff scheduling',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: mulberryDark.withOpacity(0.70),
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          height: 1.35,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenHeight < 740;

    return Scaffold(
      backgroundColor: cream,
      resizeToAvoidBottomInset: true,
      body: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: screenHeight,
          ),
          child: Stack(
            children: [
              ClipPath(
                clipper: _WaveClipper(),
                child: Container(
                  height: isSmallScreen
                      ? screenHeight * 0.44
                      : screenHeight * 0.48,
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        mulberryDark,
                        mulberry,
                        mulberryLight,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    screenWidth < 390 ? 18 : 24,
                    0,
                    screenWidth < 390 ? 18 : 24,
                    24,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(height: isSmallScreen ? 18 : 26),
                      Center(
                        child: buildLogo(),
                      ),
                      const SizedBox(height: 15),
                      const Center(
                        child: Text(
                          'BistroLog',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Georgia',
                            fontSize: 35,
                            fontWeight: FontWeight.bold,
                            color: cream,
                            letterSpacing: 2.2,
                          ),
                        ),
                      ),
                      const SizedBox(height: 5),
                      const Center(
                        child: Text(
                          'Cafe Management System',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            color: creamDark,
                            letterSpacing: 1.4,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      SizedBox(height: isSmallScreen ? 24 : 30),
                      Center(
                        child: buildLoginCard(),
                      ),
                      const SizedBox(height: 22),
                      buildFooterText(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();

    path.lineTo(0, size.height - 58);

    path.quadraticBezierTo(
      size.width * 0.24,
      size.height - 10,
      size.width * 0.50,
      size.height - 42,
    );

    path.quadraticBezierTo(
      size.width * 0.76,
      size.height - 75,
      size.width,
      size.height - 24,
    );

    path.lineTo(size.width, 0);
    path.close();

    return path;
  }

  @override
  bool shouldReclip(_WaveClipper oldClipper) {
    return false;
  }
}