import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'login_page.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final supabase = Supabase.instance.client;

  final fullNameController = TextEditingController();
  final usernameController = TextEditingController();
  final emailController = TextEditingController();
  final phoneController = TextEditingController();
  final branchController = TextEditingController();
  final departmentController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  bool isLoading = false;
  bool obscurePassword = true;
  bool obscureConfirmPassword = true;

  static const Color mulberry = Color(0xFF6D2B50);
  static const Color mulberryDark = Color(0xFF4A1A35);
  static const Color mulberryLight = Color(0xFF8B3D68);
  static const Color cream = Color(0xFFF5ECD7);
  static const Color creamDark = Color(0xFFE8D5B5);
  static const Color softWhite = Color(0xFFFFFCF7);

  @override
  void dispose() {
    fullNameController.dispose();
    usernameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    branchController.dispose();
    departmentController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  bool isValidPassword(String password) {
    final hasUppercase = password.contains(RegExp(r'[A-Z]'));
    final hasLowercase = password.contains(RegExp(r'[a-z]'));
    final hasNumber = password.contains(RegExp(r'[0-9]'));
    final hasSpecial =
        password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>_\-+=]'));

    return password.length >= 8 &&
        hasUppercase &&
        hasLowercase &&
        hasNumber &&
        hasSpecial;
  }

  Future<void> registerUser() async {
    final fullName = fullNameController.text.trim();
    final username = usernameController.text.trim();
    final email = emailController.text.trim();
    final phone = phoneController.text.trim();
    final branch = branchController.text.trim();
    final department = departmentController.text.trim();
    final password = passwordController.text.trim();
    final confirmPassword = confirmPasswordController.text.trim();

    if (fullName.isEmpty ||
        username.isEmpty ||
        email.isEmpty ||
        password.isEmpty ||
        confirmPassword.isEmpty) {
      showMessage('Please fill in all required fields.', isError: true);
      return;
    }

    if (!email.contains('@')) {
      showMessage('Please enter a valid email address.', isError: true);
      return;
    }

    if (password != confirmPassword) {
      showMessage('Password and confirm password do not match.', isError: true);
      return;
    }

    if (!isValidPassword(password)) {
      showMessage(
        'Password must be at least 8 characters and include uppercase, lowercase, number and special character.',
        isError: true,
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final usernameCheck = await supabase
          .from('profiles')
          .select('id')
          .eq('username', username)
          .maybeSingle();

      if (usernameCheck != null) {
        showMessage(
          'Username already exists. Please use another username.',
          isError: true,
        );
        return;
      }

      final authResponse = await supabase.auth.signUp(
        email: email,
        password: password,
      );

      final user = authResponse.user;

      if (user == null) {
        showMessage(
          'Registration submitted. Please check your email to confirm your account.',
        );
        return;
      }

      await supabase.from('profiles').insert({
        'id': user.id,
        'username': username,
        'full_name': fullName,
        'role': 'staff',
        'email': email,
        'phone': phone.isEmpty ? null : phone,
        'branch': branch.isEmpty ? null : branch,
        'department': department.isEmpty ? null : department,
        'joined_at': DateTime.now().toIso8601String().substring(0, 10),
        'is_active': true,
        'staff_status': 'active',
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      await supabase.auth.signOut();

      if (!mounted) return;

      showMessage(
        'Registration successful. Please login as staff.',
        isError: false,
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const LoginPage(),
        ),
      );
    } on AuthException catch (e) {
      showMessage(e.message, isError: true);
    } catch (e) {
      showMessage('Registration failed: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Widget buildLogo() {
    return Container(
      width: 96,
      height: 96,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFFF8F1E6),
        border: Border.all(
          color: Colors.white.withOpacity(0.88),
          width: 2.8,
        ),
        boxShadow: [
          BoxShadow(
            color: mulberryDark.withOpacity(0.30),
            blurRadius: 18,
            offset: const Offset(0, 8),
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
                Icons.person_add,
                size: 42,
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
    TextInputType? keyboardType,
    bool requiredField = false,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      enabled: !isLoading,
      style: const TextStyle(
        color: mulberryDark,
        fontSize: 14.5,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        labelText: requiredField ? '$label *' : label,
        labelStyle: TextStyle(
          color: Colors.grey.shade700,
          fontSize: 14,
        ),
        prefixIcon: Icon(
          icon,
          color: mulberry,
          size: 20,
        ),
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
          vertical: 15,
        ),
      ),
    );
  }

  Widget buildPasswordField({
    required TextEditingController controller,
    required String label,
    required bool obscure,
    required VoidCallback onToggle,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      enabled: !isLoading,
      style: const TextStyle(
        color: mulberryDark,
        fontSize: 14.5,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        labelText: '$label *',
        labelStyle: TextStyle(
          color: Colors.grey.shade700,
          fontSize: 14,
        ),
        prefixIcon: const Icon(
          Icons.lock_outline,
          color: mulberry,
          size: 20,
        ),
        suffixIcon: IconButton(
          onPressed: isLoading ? null : onToggle,
          icon: Icon(
            obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
            color: mulberry,
            size: 20,
          ),
        ),
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
          vertical: 15,
        ),
      ),
    );
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

  Widget buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 24),
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
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(34),
          bottomRight: Radius.circular(34),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: isLoading
                      ? null
                      : () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const LoginPage(),
                            ),
                          );
                        },
                  icon: const Icon(
                    Icons.arrow_back,
                    color: cream,
                  ),
                ),
                const Expanded(
                  child: Text(
                    'Register Staff',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: cream,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
                const SizedBox(width: 48),
              ],
            ),
            const SizedBox(height: 8),
            buildLogo(),
            const SizedBox(height: 12),
            const Text(
              'BistroLog',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Georgia',
                fontSize: 30,
                fontWeight: FontWeight.bold,
                color: cream,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Create your staff account',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: creamDark,
                fontSize: 12.5,
                letterSpacing: 1.1,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildRegisterCard() {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 460),
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 20),
      decoration: BoxDecoration(
        color: softWhite,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: creamDark.withOpacity(0.65),
        ),
        boxShadow: [
          BoxShadow(
            color: mulberryDark.withOpacity(0.14),
            blurRadius: 26,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            'Create Staff Account',
            style: TextStyle(
              fontFamily: 'Georgia',
              fontSize: 23,
              fontWeight: FontWeight.bold,
              color: mulberryDark,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Default role: Staff. Manager can update role later.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 13,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 24),
          buildTextField(
            controller: fullNameController,
            label: 'Full Name',
            icon: Icons.badge,
            requiredField: true,
          ),
          const SizedBox(height: 14),
          buildTextField(
            controller: usernameController,
            label: 'Username',
            icon: Icons.alternate_email,
            requiredField: true,
          ),
          const SizedBox(height: 14),
          buildTextField(
            controller: emailController,
            label: 'Email',
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            requiredField: true,
          ),
          const SizedBox(height: 14),
          buildTextField(
            controller: phoneController,
            label: 'Phone',
            icon: Icons.phone,
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 14),
          buildTextField(
            controller: branchController,
            label: 'Branch',
            icon: Icons.store,
          ),
          const SizedBox(height: 14),
          buildTextField(
            controller: departmentController,
            label: 'Department',
            icon: Icons.apartment,
          ),
          const SizedBox(height: 14),
          buildPasswordField(
            controller: passwordController,
            label: 'Password',
            obscure: obscurePassword,
            onToggle: () {
              setState(() {
                obscurePassword = !obscurePassword;
              });
            },
          ),
          const SizedBox(height: 14),
          buildPasswordField(
            controller: confirmPasswordController,
            label: 'Confirm Password',
            obscure: obscureConfirmPassword,
            onToggle: () {
              setState(() {
                obscureConfirmPassword = !obscureConfirmPassword;
              });
            },
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cream,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: creamDark,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.info_outline,
                  color: mulberry,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Password must include uppercase, lowercase, number and special character.',
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontSize: 11.5,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: isLoading ? null : registerUser,
              icon: isLoading
                  ? const SizedBox(
                      width: 19,
                      height: 19,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: cream,
                      ),
                    )
                  : const Icon(Icons.person_add),
              label: Text(
                isLoading ? 'Registering...' : 'Register',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
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
            ),
          ),
          const SizedBox(height: 14),
          TextButton(
            onPressed: isLoading
                ? null
                : () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const LoginPage(),
                      ),
                    );
                  },
            style: TextButton.styleFrom(
              foregroundColor: mulberry,
            ),
            child: const Text(
              'Already have an account? Login',
              style: TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: cream,
      body: Column(
        children: [
          buildHeader(),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                screenWidth < 390 ? 18 : 24,
                22,
                screenWidth < 390 ? 18 : 24,
                28,
              ),
              child: Center(
                child: buildRegisterCard(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}