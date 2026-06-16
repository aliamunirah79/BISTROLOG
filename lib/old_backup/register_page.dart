import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  String selectedRole = "STAFF";
  bool loading = false;
  bool _obscurePassword = true;

  static const Color mulberry = Color(0xFF6D2B50);
  static const Color mulberryDark = Color(0xFF4A1A35);
  static const Color mulberryLight = Color(0xFF8B3D68);
  static const Color cream = Color(0xFFF5ECD7);
  static const Color creamDark = Color(0xFFE8D5B5);

  Future<void> register() async {
    setState(() => loading = true);

    try {
      final response = await Supabase.instance.client.auth.signUp(
        email: emailController.text.trim(),
        password: passwordController.text,
      );

      final user = response.user;

      if (user != null) {
        await Supabase.instance.client.from('profiles').insert({
          'id': user.id,
          'role': selectedRole,
        });

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Registration successful"),
          ),
        );

        Navigator.pop(context);
      }
    } on AuthApiException catch (e) {
      _showSnack("Auth error: ${e.message}");
    } on PostgrestException catch (e) {
      _showSnack("Database error: ${e.message}");
    } catch (e) {
      _showSnack("Unexpected error: $e");
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: const TextStyle(
            color: cream,
            fontFamily: 'Georgia',
          ),
        ),
        backgroundColor: mulberryDark,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
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
                  padding: const EdgeInsets.fromLTRB(32, 0, 32, 24),
                  child: Column(
                    children: [
                      const SizedBox(height: 36),

                      // Logo
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
                                Icons.person_add_alt_1,
                                size: 50,
                                color: mulberry,
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 14),

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
                        'Create New Account',
                        style: TextStyle(
                          fontSize: 12,
                          color: creamDark,
                          letterSpacing: 1.5,
                        ),
                      ),

                      const SizedBox(height: 36),

                      // Register Card
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
                        padding: const EdgeInsets.fromLTRB(
                          28,
                          28,
                          28,
                          20,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              'Register',
                              style: TextStyle(
                                fontFamily: 'Georgia',
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: mulberryDark,
                              ),
                            ),

                            const SizedBox(height: 4),

                            const Text(
                              'Create your account',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey,
                              ),
                            ),

                            const SizedBox(height: 24),

                            _buildTextField(
                              controller: emailController,
                              label: 'Email',
                              icon: Icons.email_outlined,
                              keyboardType:
                                  TextInputType.emailAddress,
                            ),

                            const SizedBox(height: 16),

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
                                ),
                                onPressed: () {
                                  setState(() {
                                    _obscurePassword =
                                        !_obscurePassword;
                                  });
                                },
                              ),
                            ),

                            const SizedBox(height: 16),

                            DropdownButtonFormField<String>(
                              value: selectedRole,
                              decoration: InputDecoration(
                                labelText: "Role",
                                labelStyle: const TextStyle(
                                  color: Colors.grey,
                                ),
                                prefixIcon: const Icon(
                                  Icons.badge_outlined,
                                  color: mulberry,
                                ),
                                filled: true,
                                fillColor: cream,
                                enabledBorder: OutlineInputBorder(
                                  borderRadius:
                                      BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: creamDark,
                                    width: 1.5,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius:
                                      BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: mulberry,
                                    width: 2,
                                  ),
                                ),
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: "STAFF",
                                  child: Text("Staff"),
                                ),
                                DropdownMenuItem(
                                  value: "SUPERVISOR",
                                  child: Text("Supervisor"),
                                ),
                                DropdownMenuItem(
                                  value: "MANAGER",
                                  child: Text("Manager"),
                                ),
                              ],
                              onChanged: (value) {
                                setState(() {
                                  selectedRole = value!;
                                });
                              },
                            ),

                            const SizedBox(height: 24),

                            SizedBox(
                              height: 52,
                              child: ElevatedButton(
                                onPressed: loading ? null : register,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: mulberry,
                                  foregroundColor: cream,
                                  disabledBackgroundColor:
                                      mulberry.withOpacity(0.45),
                                  shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(14),
                                  ),
                                  elevation: 4,
                                ),
                                child: loading
                                    ? const SizedBox(
                                        height: 22,
                                        width: 22,
                                        child:
                                            CircularProgressIndicator(
                                          color: cream,
                                          strokeWidth: 2.5,
                                        ),
                                      )
                                    : const Text(
                                        'Register',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight:
                                              FontWeight.bold,
                                          letterSpacing: 1.2,
                                        ),
                                      ),
                              ),
                            ),

                            const SizedBox(height: 16),

                            Row(
                              children: [
                                Expanded(
                                  child: Divider(
                                    color: creamDark,
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                  ),
                                  child: Text(
                                    'or',
                                    style: TextStyle(
                                      color:
                                          Colors.grey.shade400,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Divider(
                                    color: creamDark,
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 12),

                            Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.center,
                              children: [
                                const Text(
                                  "Already have an account?",
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 13,
                                  ),
                                ),
                                TextButton(
                                  onPressed: () {
                                    Navigator.pop(context);
                                  },
                                  style: TextButton.styleFrom(
                                    foregroundColor: mulberry,
                                    padding:
                                        const EdgeInsets.only(
                                      left: 4,
                                    ),
                                  ),
                                  child: const Text(
                                    'Login',
                                    style: TextStyle(
                                      fontWeight:
                                          FontWeight.bold,
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
      style: const TextStyle(
        fontSize: 15,
        color: mulberryDark,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(
          color: Colors.grey,
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
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: creamDark,
            width: 1.5,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: mulberry,
            width: 2,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
    );
  }
}

class _WaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();

    path.lineTo(0, size.height - 60);

    path.quadraticBezierTo(
      size.width * 0.25,
      size.height,
      size.width * 0.5,
      size.height - 40,
    );

    path.quadraticBezierTo(
      size.width * 0.75,
      size.height - 80,
      size.width,
      size.height - 20,
    );

    path.lineTo(size.width, 0);
    path.close();

    return path;
  }

  @override
  bool shouldReclip(_WaveClipper oldClipper) => false;
}