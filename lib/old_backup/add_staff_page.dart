import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AddStaffPage extends StatefulWidget {
  const AddStaffPage({super.key});

  @override
  State<AddStaffPage> createState() => _AddStaffPageState();
}

class _AddStaffPageState extends State<AddStaffPage> {
  final supabase = Supabase.instance.client;

  final _formKey = GlobalKey<FormState>();
  final TextEditingController fullNameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController tempPasswordController = TextEditingController();

  String selectedRole = 'staff';
  bool loading = false;

  static const Color mulberry = Color(0xFF6D2B50);
  static const Color mulberryDark = Color(0xFF4A1A35);
  static const Color mulberryLight = Color(0xFF8B3D68);
  static const Color cream = Color(0xFFF5ECD7);
  static const Color creamDark = Color(0xFFE8D5B5);

  @override
  void dispose() {
    fullNameController.dispose();
    emailController.dispose();
    tempPasswordController.dispose();
    super.dispose();
  }

  Future<void> submitInvite() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => loading = true);

    try {
      final res = await supabase.functions.invoke(
        'invite_staff',
        body: {
          'full_name': fullNameController.text.trim(),
          'email': emailController.text.trim(),
          'role': selectedRole,
          'temp_password': tempPasswordController.text.trim().isEmpty
              ? null
              : tempPasswordController.text.trim(),
        },
      );

      if (res.status != 200) {
        throw Exception(res.data.toString());
      }

      fullNameController.clear();
      emailController.clear();
      tempPasswordController.clear();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Staff invite sent successfully.'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: mulberryDark,
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to add staff: $e'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: mulberry),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: creamDark),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: creamDark),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
        borderSide: BorderSide(color: mulberry, width: 2),
      ),
    );
  }

  Widget _sectionTitle(String title, {String? subtitle}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: mulberryDark,
            fontFamily: 'Georgia',
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade700,
            ),
          ),
        ],
      ],
    );
  }

  Widget _infoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            mulberryDark.withOpacity(0.95),
            mulberry,
            mulberryLight,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: mulberryDark.withOpacity(0.16),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: cream.withOpacity(0.16),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.badge_outlined,
              color: cream,
              size: 30,
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Manager Access Only',
                  style: TextStyle(
                    color: cream,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Create staff or supervisor accounts securely using an invite flow.',
                  style: TextStyle(
                    color: cream,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: cream,
      appBar: AppBar(
        title: const Text('Add Staff'),
        centerTitle: true,
        backgroundColor: mulberryDark,
        foregroundColor: cream,
        elevation: 0,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _infoCard(),
            const SizedBox(height: 20),

            _sectionTitle(
              'New Staff Form',
              subtitle: 'Fill in the details below to send an invite.',
            ),
            const SizedBox(height: 14),

            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: creamDark),
                boxShadow: [
                  BoxShadow(
                    color: mulberryDark.withOpacity(0.05),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: fullNameController,
                      decoration: _inputDecoration(
                        label: 'Full Name',
                        icon: Icons.person_outline,
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter full name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),

                    TextFormField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: _inputDecoration(
                        label: 'Email Address',
                        icon: Icons.email_outlined,
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter email';
                        }
                        if (!value.contains('@')) {
                          return 'Please enter a valid email';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),

                    DropdownButtonFormField<String>(
                      value: selectedRole,
                      decoration: _inputDecoration(
                        label: 'Role',
                        icon: Icons.manage_accounts_outlined,
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'staff',
                          child: Text('Staff'),
                        ),
                        DropdownMenuItem(
                          value: 'supervisor',
                          child: Text('Supervisor'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => selectedRole = value);
                        }
                      },
                    ),
                    const SizedBox(height: 14),

                    TextFormField(
                      controller: tempPasswordController,
                      obscureText: true,
                      decoration: _inputDecoration(
                        label: 'Temporary Password',
                        icon: Icons.lock_outline,
                      ).copyWith(
                        hintText: 'Optional if using invite email',
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Leave blank if you want the system to send an invite email.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 18),

                    SizedBox(
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: loading ? null : submitInvite,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: mulberry,
                          foregroundColor: cream,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        icon: loading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: cream,
                                ),
                              )
                            : const Icon(Icons.send_outlined),
                        label: Text(
                          loading ? 'Sending Invite...' : 'Send Invite',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 18),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: creamDark),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Notes',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: mulberryDark,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '• Only managers should access this page.\n'
                    '• The invite should be handled by a secure Edge Function.\n'
                    '• Staff will be added to the profiles table with the selected role.',
                    style: TextStyle(
                      height: 1.5,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}