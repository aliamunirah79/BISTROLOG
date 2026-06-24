import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../manager/manager_home.dart';
import '../supervisor/supervisor_home.dart';
import '../staff/staff_home.dart';

class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final supabase = Supabase.instance.client;

  final newPasswordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  bool isLoading = false;
  bool obscureNewPassword = true;
  bool obscureConfirmPassword = true;

  static const Color mulberry = Color(0xFF6D2B50);
  static const Color mulberryDark = Color(0xFF4A1A35);
  static const Color cream = Color(0xFFF5ECD7);
  static const Color creamDark = Color(0xFFE8D5B5);
  static const Color softWhite = Color(0xFFFFFCF7);

  @override
  void dispose() {
    newPasswordController.dispose();
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

  Future<void> updatePassword() async {
    final newPassword = newPasswordController.text.trim();
    final confirmPassword = confirmPasswordController.text.trim();

    if (newPassword.isEmpty || confirmPassword.isEmpty) {
      showMessage('Please enter and confirm your new password.');
      return;
    }

    if (newPassword != confirmPassword) {
      showMessage('Password and confirm password do not match.');
      return;
    }

    if (!isValidPassword(newPassword)) {
      showMessage(
        'Password must be at least 8 characters and include uppercase, lowercase, number and special character.',
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final user = supabase.auth.currentUser;

      if (user == null) {
        showMessage('Session expired. Please login again.');
        return;
      }

      await supabase.auth.updateUser(
        UserAttributes(
          password: newPassword,
        ),
      );

      await supabase.from('profiles').update({
        'must_change_password': false,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', user.id);

      final profile = await supabase
          .from('profiles')
          .select('role, full_name')
          .eq('id', user.id)
          .maybeSingle();

      if (profile == null) {
        await supabase.auth.signOut();
        showMessage('Profile not found. Please contact manager.');
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
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => StaffHome(fullName: fullName),
          ),
        );
      }
    } on AuthException catch (e) {
      showMessage(e.message);
    } catch (e) {
      showMessage('Failed to update password: $e');
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  void showMessage(String message) {
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
        backgroundColor: mulberryDark,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
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
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: mulberry),
        prefixIcon: const Icon(Icons.lock_outline, color: mulberry),
        suffixIcon: IconButton(
          icon: Icon(
            obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
            color: mulberry,
          ),
          onPressed: isLoading ? null : onToggle,
        ),
        filled: true,
        fillColor: cream,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: creamDark),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: mulberry, width: 1.8),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: cream,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(22),
            child: Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: softWhite,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: creamDark),
                boxShadow: [
                  BoxShadow(
                    color: mulberryDark.withOpacity(0.12),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(
                    Icons.password,
                    size: 54,
                    color: mulberry,
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Change Temporary Password',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Georgia',
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: mulberryDark,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your account was created by the manager. Please set a new password before using BISTROLOG.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      height: 1.35,
                      fontSize: 13.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                  buildPasswordField(
                    controller: newPasswordController,
                    label: 'New Password',
                    obscure: obscureNewPassword,
                    onToggle: () {
                      setState(() {
                        obscureNewPassword = !obscureNewPassword;
                      });
                    },
                  ),
                  const SizedBox(height: 14),
                  buildPasswordField(
                    controller: confirmPasswordController,
                    label: 'Confirm New Password',
                    obscure: obscureConfirmPassword,
                    onToggle: () {
                      setState(() {
                        obscureConfirmPassword = !obscureConfirmPassword;
                      });
                    },
                  ),
                  const SizedBox(height: 22),
                  SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: isLoading ? null : updatePassword,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: mulberry,
                        foregroundColor: cream,
                        disabledBackgroundColor: mulberry.withOpacity(0.45),
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
                              'Update Password',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}