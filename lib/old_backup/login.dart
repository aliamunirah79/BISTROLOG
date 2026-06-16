import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'staff_home.dart';
import 'supervisor_home.dart';
import 'manager_home.dart';
import 'register_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  bool loading = false;
  bool _obscurePassword = true;

  static const Color mulberry     = Color(0xFF6D2B50);
  static const Color mulberryDark = Color(0xFF4A1A35);
  static const Color mulberryLight= Color(0xFF8B3D68);
  static const Color cream        = Color(0xFFF5ECD7);
  static const Color creamDark    = Color(0xFFE8D5B5);

  void login() async {
    setState(() => loading = true);
    try {
      final response = await Supabase.instance.client.auth.signInWithPassword(
        email: emailController.text.trim(),
        password: passwordController.text,
      );

      final user = response.user;
      if (user == null) {
        _showSnack('Login failed: no user returned');
        return;
      }

      final profile = await Supabase.instance.client
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      if (profile == null) {
        _showSnack('Profile not found for this user');
        return;
      }

      final role = profile['role'].toString().toLowerCase();

      if (role == 'staff') {
        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (_) => const StaffHome()));
      } else if (role == 'supervisor') {
        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (_) => const SupervisorHome()));
      } else if (role == 'manager') {
        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (_) => const ManagerHome()));
      } else {
        _showSnack('Unknown role: $role');
      }
    } on AuthApiException catch (e) {
      _showSnack('Login error: ${e.message}');
    } on PostgrestException catch (e) {
      _showSnack('Database error: ${e.message}');
    } catch (e) {
      _showSnack('Unexpected error: $e');
    } finally {
      setState(() => loading = false);
    }
  }

  Future<void> resetPassword() async {
    if (emailController.text.isEmpty) {
      _showSnack('Enter your email first');
      return;
    }
    try {
      await Supabase.instance.client.auth
          .resetPasswordForEmail(emailController.text.trim());
      _showSnack('Password reset email sent');
    } on AuthApiException catch (e) {
      _showSnack('Error: ${e.message}');
    } catch (e) {
      _showSnack('Unexpected error: $e');
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg,
            style: const TextStyle(color: cream, fontFamily: 'Georgia')),
        backgroundColor: mulberryDark,
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

@override
Widget build(BuildContext context) {
  final screenHeight = MediaQuery.of(context).size.height;

  return Scaffold(
    backgroundColor: cream,
    resizeToAvoidBottomInset: true,
    body: SingleChildScrollView(
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: screenHeight),
        child: Stack(
          children: [
            ClipPath(
              clipper: _WaveClipper(),
              child: Container(
                height: screenHeight * 0.48,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [mulberryDark, mulberry, mulberryLight],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
            ),

              // ── main content ──────────────────────────────
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(32, 0, 32, 24),
                  child: Column(
                    children: [
                      const SizedBox(height: 36),

                      // logo circle
                      Container(
                        width: 110,
                        height: 110,
                        decoration: BoxDecoration(
                          color: cream,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: mulberryDark.withOpacity(0.4),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Image.asset(
                              'logo.png',
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => const Icon(
                                Icons.restaurant,
                                size: 50,
                                color: mulberry,
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 14),

                      // app name
                      const Text(
                        'BistroLog',
                        style: TextStyle(
                          fontFamily: 'Georgia',
                          fontSize: 34,
                          fontWeight: FontWeight.bold,
                          color: cream,
                          letterSpacing: 2.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Cafe Management System',
                        style: TextStyle(
                          fontSize: 12,
                          color: creamDark,
                          letterSpacing: 1.5,
                        ),
                      ),

                      const SizedBox(height: 36),

                      // ── login card ────────────────────────
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: mulberryDark.withOpacity(0.15),
                              blurRadius: 30,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.fromLTRB(28, 28, 28, 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // card heading
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
                            const Text(
                              'Sign in to your account',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey,
                              ),
                            ),

                            const SizedBox(height: 24),

                            // email
                            _buildTextField(
                              controller: emailController,
                              label: 'Email',
                              icon: Icons.email_outlined,
                              keyboardType: TextInputType.emailAddress,
                            ),

                            const SizedBox(height: 16),

                            // password
                            _buildTextField(
                              controller: passwordController,
                              label: 'Password',
                              icon: Icons.lock_outline,
                              obscure: _obscurePassword,
                              suffix: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                  color: mulberry,
                                  size: 20,
                                ),
                                onPressed: () => setState(() =>
                                    _obscurePassword = !_obscurePassword),
                              ),
                            ),

                            // forgot password
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: resetPassword,
                                style: TextButton.styleFrom(
                                    foregroundColor: mulberry,
                                    padding: EdgeInsets.zero,
                                    minimumSize: const Size(0, 36)),
                                child: const Text(
                                  'Forgot password?',
                                  style: TextStyle(fontSize: 13),
                                ),
                              ),
                            ),

                            const SizedBox(height: 4),

                            // sign in button
                            SizedBox(
                              height: 52,
                              child: ElevatedButton(
                                onPressed: loading ? null : login,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: mulberry,
                                  foregroundColor: cream,
                                  disabledBackgroundColor:
                                      mulberry.withOpacity(0.45),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  elevation: 4,
                                  shadowColor:
                                      mulberryDark.withOpacity(0.5),
                                ),
                                child: loading
                                    ? const SizedBox(
                                        height: 22,
                                        width: 22,
                                        child: CircularProgressIndicator(
                                          color: cream,
                                          strokeWidth: 2.5,
                                        ),
                                      )
                                    : const Text(
                                        'Sign In',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 1.2,
                                        ),
                                      ),
                              ),
                            ),

                            const SizedBox(height: 16),

                            // divider
                            Row(
                              children: [
                                Expanded(
                                    child: Divider(color: creamDark)),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12),
                                  child: Text('or',
                                      style: TextStyle(
                                          color: Colors.grey.shade400,
                                          fontSize: 13)),
                                ),
                                Expanded(
                                    child: Divider(color: creamDark)),
                              ],
                            ),

                            const SizedBox(height: 12),

                            // register row
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text(
                                  "Don't have an account?",
                                  style: TextStyle(
                                      color: Colors.grey, fontSize: 13),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) =>
                                            const RegisterPage()),
                                  ),
                                  style: TextButton.styleFrom(
                                    foregroundColor: mulberry,
                                    padding: const EdgeInsets.only(left: 4),
                                    minimumSize: const Size(0, 36),
                                  ),
                                  child: const Text(
                                    'Register',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
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

  Widget _buildTextField({
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
      style: const TextStyle(fontSize: 15, color: mulberryDark),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.grey, fontSize: 14),
        prefixIcon: Icon(icon, color: mulberry, size: 20),
        suffixIcon: suffix,
        filled: true,
        fillColor: cream,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: creamDark, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: mulberry, width: 2),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}

// ── wave clipper ──────────────────────────────────────────────
class _WaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(0, size.height - 60);
    path.quadraticBezierTo(
      size.width * 0.25, size.height,
      size.width * 0.5, size.height - 40,
    );
    path.quadraticBezierTo(
      size.width * 0.75, size.height - 80,
      size.width, size.height - 20,
    );
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(_WaveClipper old) => false;
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('Logged In')),
    );
  }
}