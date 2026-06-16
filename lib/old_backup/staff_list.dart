import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class StaffList extends StatefulWidget {
  const StaffList({super.key});

  @override
  State<StaffList> createState() => _StaffListState();
}

class _StaffListState extends State<StaffList> {
  final supabase = Supabase.instance.client;

  static const Color mulberry = Color(0xFF6D2B50);
  static const Color mulberryDark = Color(0xFF4A1A35);
  static const Color mulberryLight = Color(0xFF8B3D68);
  static const Color cream = Color(0xFFF5ECD7);
  static const Color creamDark = Color(0xFFE8D5B5);

  static const String staffTable = 'profiles';

  bool loading = true;
  List<Map<String, dynamic>> staffList = [];

  @override
  void initState() {
    super.initState();
    loadStaff();
  }

  Future<void> loadStaff() async {
    setState(() => loading = true);

    try {
      final data = await supabase
          .from(staffTable)
          .select()
          .order('full_name', ascending: true);

      if (!mounted) return;

      setState(() {
        staffList = List<Map<String, dynamic>>.from(data);
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        staffList = [];
        loading = false;
      });

      _showSnack('Failed to load staff: $e');
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: mulberryDark,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  String _formatRole(String role) {
    if (role.isEmpty) return '-';
    return role.toUpperCase();
  }

  Color _roleColor(String role) {
    final r = role.toUpperCase();

    if (r == 'MANAGER') return mulberryDark;
    if (r == 'SUPERVISOR') return mulberry;
    if (r == 'STAFF') return mulberryLight;

    return Colors.grey;
  }

  Widget _header() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [mulberryDark, mulberry, mulberryLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
        boxShadow: [
          BoxShadow(
            color: mulberryDark.withOpacity(0.22),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back, color: cream),
          ),
          const SizedBox(width: 6),
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: cream,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.12),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipOval(
              child: Padding(
                padding: const EdgeInsets.all(9),
                child: Image.asset(
                  'logo.png',
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.restaurant,
                    size: 28,
                    color: mulberry,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Staff Management',
                  style: TextStyle(
                    fontFamily: 'Georgia',
                    fontSize: 21,
                    fontWeight: FontWeight.bold,
                    color: cream,
                    letterSpacing: 0.6,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'View and manage employee details',
                  style: TextStyle(
                    fontSize: 13,
                    color: cream,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: loadStaff,
            icon: const Icon(Icons.refresh, color: cream),
            tooltip: 'Refresh',
          ),
        ],
      ),
    );
  }

  Widget _summaryCard() {
    final staffCount = staffList
        .where((s) => (s['role'] ?? '').toString().toUpperCase() == 'STAFF')
        .length;

    final supervisorCount = staffList
        .where((s) => (s['role'] ?? '').toString().toUpperCase() == 'SUPERVISOR')
        .length;

    final managerCount = staffList
        .where((s) => (s['role'] ?? '').toString().toUpperCase() == 'MANAGER')
        .length;

    return Row(
      children: [
        Expanded(
          child: _miniCard(
            title: 'Total Users',
            value: staffList.length.toString(),
            icon: Icons.people_alt_outlined,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _miniCard(
            title: 'Staff',
            value: staffCount.toString(),
            icon: Icons.badge_outlined,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _miniCard(
            title: 'Supervisor',
            value: supervisorCount.toString(),
            icon: Icons.supervisor_account_outlined,
          ),
        ),
      ],
    );
  }

  Widget _miniCard({
    required String title,
    required String value,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: creamDark),
        boxShadow: [
          BoxShadow(
            color: mulberryDark.withOpacity(0.06),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: mulberry, size: 22),
          const SizedBox(height: 7),
          Text(
            value,
            style: const TextStyle(
              color: mulberryDark,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey.shade700,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _staffCard(Map<String, dynamic> staff) {
    final fullName = (staff['full_name'] ?? 'No Name').toString();
    final username = (staff['username'] ?? '-').toString();
    final role = (staff['role'] ?? '').toString();
    final email = (staff['email'] ?? '-').toString();
    final phone = (staff['phone'] ?? '-').toString();
    final branch = (staff['branch'] ?? '-').toString();
    final department = (staff['department'] ?? '-').toString();
    final profileId = (staff['profile_id'] ?? '-').toString();
    final avatarUrl = staff['avatar_url']?.toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 13),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: creamDark),
        boxShadow: [
          BoxShadow(
            color: mulberryDark.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: cream,
            backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
                ? NetworkImage(avatarUrl)
                : null,
            child: avatarUrl == null || avatarUrl.isEmpty
                ? const Icon(Icons.person, color: mulberry, size: 28)
                : null,
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fullName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: mulberryDark,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '@$username',
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 5,
                  children: [
                    _infoChip(_formatRole(role), _roleColor(role)),
                    _infoChip(profileId, mulberry),
                    if (branch != '-') _infoChip(branch, mulberryLight),
                    if (department != '-') _infoChip(department, mulberryLight),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontSize: 12,
                  ),
                ),
                if (phone != '-')
                  Text(
                    phone,
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
          Column(
            children: [
              IconButton(
                onPressed: () => _showEditDialog(staff),
                icon: const Icon(Icons.edit_outlined, color: mulberry),
                tooltip: 'Edit staff',
              ),
              IconButton(
                onPressed: () => _confirmDeleteStaff(staff),
                icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                tooltip: 'Delete staff',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.18)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _dialogInput({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: mulberry),
        filled: true,
        fillColor: Colors.white,
        labelStyle: TextStyle(color: Colors.grey.shade700),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: creamDark),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: mulberry),
        ),
      ),
    );
  }

  Widget _passwordInput({
    required TextEditingController controller,
    required bool hidePassword,
    required VoidCallback onToggle,
  }) {
    return TextField(
      controller: controller,
      obscureText: hidePassword,
      decoration: InputDecoration(
        labelText: 'Temporary Password',
        prefixIcon: const Icon(Icons.lock_outline, color: mulberry),
        suffixIcon: IconButton(
          icon: Icon(
            hidePassword
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
            color: mulberry,
          ),
          onPressed: onToggle,
        ),
        filled: true,
        fillColor: Colors.white,
        labelStyle: TextStyle(color: Colors.grey.shade700),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: creamDark),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: mulberry),
        ),
      ),
    );
  }

  Future<void> _showAddDialog() async {
    final fullNameCtl = TextEditingController();
    final usernameCtl = TextEditingController();
    final emailCtl = TextEditingController();
    final passwordCtl = TextEditingController();
    final phoneCtl = TextEditingController();
    final branchCtl = TextEditingController();
    final departmentCtl = TextEditingController();

    String selectedRole = 'STAFF';
    bool hidePassword = true;

    final allowedRoles = ['STAFF', 'SUPERVISOR', 'MANAGER'];

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: cream,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: const Text(
                'Add New Staff',
                style: TextStyle(
                  color: mulberryDark,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Georgia',
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _dialogInput(
                      controller: fullNameCtl,
                      label: 'Full Name',
                      icon: Icons.person_outline,
                    ),
                    const SizedBox(height: 10),
                    _dialogInput(
                      controller: usernameCtl,
                      label: 'Username',
                      icon: Icons.alternate_email,
                    ),
                    const SizedBox(height: 10),
                    _dialogInput(
                      controller: emailCtl,
                      label: 'Email',
                      icon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 10),
                    _passwordInput(
                      controller: passwordCtl,
                      hidePassword: hidePassword,
                      onToggle: () {
                        setDialogState(() {
                          hidePassword = !hidePassword;
                        });
                      },
                    ),
                    const SizedBox(height: 10),
                    _dialogInput(
                      controller: phoneCtl,
                      label: 'Phone',
                      icon: Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 10),
                    _dialogInput(
                      controller: branchCtl,
                      label: 'Branch',
                      icon: Icons.storefront_outlined,
                    ),
                    const SizedBox(height: 10),
                    _dialogInput(
                      controller: departmentCtl,
                      label: 'Department',
                      icon: Icons.business_outlined,
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: selectedRole,
                      decoration: InputDecoration(
                        labelText: 'Role',
                        prefixIcon: const Icon(
                          Icons.admin_panel_settings_outlined,
                          color: mulberry,
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: creamDark),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: mulberry),
                        ),
                      ),
                      items: allowedRoles.map((role) {
                        return DropdownMenuItem<String>(
                          value: role,
                          child: Text(role),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setDialogState(() {
                          selectedRole = value;
                        });
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: mulberryDark),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () async {
                    final success = await _addStaff(
                      fullName: fullNameCtl.text.trim(),
                      username: usernameCtl.text.trim(),
                      email: emailCtl.text.trim(),
                      password: passwordCtl.text.trim(),
                      phone: phoneCtl.text.trim(),
                      branch: branchCtl.text.trim(),
                      department: departmentCtl.text.trim(),
                      role: selectedRole,
                    );

                    if (success && mounted) {
                      Navigator.pop(dialogContext);
                    }
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Add'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: mulberry,
                    foregroundColor: cream,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    fullNameCtl.dispose();
    usernameCtl.dispose();
    emailCtl.dispose();
    passwordCtl.dispose();
    phoneCtl.dispose();
    branchCtl.dispose();
    departmentCtl.dispose();
  }

  Future<bool> _addStaff({
    required String fullName,
    required String username,
    required String email,
    required String password,
    required String phone,
    required String branch,
    required String department,
    required String role,
  }) async {
    if (fullName.isEmpty ||
        username.isEmpty ||
        email.isEmpty ||
        password.isEmpty) {
      _showSnack('Full name, username, email and password are required.');
      return false;
    }

    if (!email.contains('@')) {
      _showSnack('Please enter a valid email address.');
      return false;
    }

    if (password.length < 6) {
      _showSnack('Password must be at least 6 characters.');
      return false;
    }

    final currentSession = supabase.auth.currentSession;
    final currentRefreshToken = currentSession?.refreshToken;

    try {
      final authResponse = await supabase.auth.signUp(
        email: email,
        password: password,
      );

      final newUser = authResponse.user;

      if (newUser == null) {
        _showSnack(
          'Failed to create staff auth account. Please disable email confirmation for testing.',
        );
        return false;
      }

      await supabase.from(staffTable).upsert(
        {
          'id': newUser.id,
          'username': username,
          'full_name': fullName,
          'role': role,
          'department': department.isEmpty ? null : department,
          'avatar_url': null,
          'email': email,
          'phone': phone.isEmpty ? null : phone,
          'branch': branch.isEmpty ? null : branch,
          'joined_at': DateTime.now().toIso8601String(),
        },
        onConflict: 'id',
      );

      if (currentRefreshToken != null && currentRefreshToken.isNotEmpty) {
        try {
          await supabase.auth.setSession(currentRefreshToken);
        } catch (_) {}
      }

      _showSnack('New staff account created successfully.');
      await loadStaff();
      return true;
    } on AuthException catch (e) {
      _showSnack('Auth error: ${e.message}');
      return false;
    } on PostgrestException catch (e) {
      _showSnack('Database error: ${e.message}');
      return false;
    } catch (e) {
      _showSnack('Failed to add staff: $e');
      return false;
    }
  }

  Future<void> _showEditDialog(Map<String, dynamic> staff) async {
    final fullNameCtl =
        TextEditingController(text: (staff['full_name'] ?? '').toString());
    final usernameCtl =
        TextEditingController(text: (staff['username'] ?? '').toString());
    final emailCtl =
        TextEditingController(text: (staff['email'] ?? '').toString());
    final phoneCtl =
        TextEditingController(text: (staff['phone'] ?? '').toString());
    final branchCtl =
        TextEditingController(text: (staff['branch'] ?? '').toString());
    final departmentCtl =
        TextEditingController(text: (staff['department'] ?? '').toString());

    String selectedRole = (staff['role'] ?? 'STAFF').toString().toUpperCase();
    final allowedRoles = ['STAFF', 'SUPERVISOR', 'MANAGER'];

    if (!allowedRoles.contains(selectedRole)) {
      selectedRole = 'STAFF';
    }

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: cream,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: const Text(
                'Edit Employee',
                style: TextStyle(
                  color: mulberryDark,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Georgia',
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _dialogInput(
                      controller: fullNameCtl,
                      label: 'Full Name',
                      icon: Icons.person_outline,
                    ),
                    const SizedBox(height: 10),
                    _dialogInput(
                      controller: usernameCtl,
                      label: 'Username',
                      icon: Icons.alternate_email,
                    ),
                    const SizedBox(height: 10),
                    _dialogInput(
                      controller: emailCtl,
                      label: 'Email',
                      icon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 10),
                    _dialogInput(
                      controller: phoneCtl,
                      label: 'Phone',
                      icon: Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 10),
                    _dialogInput(
                      controller: branchCtl,
                      label: 'Branch',
                      icon: Icons.storefront_outlined,
                    ),
                    const SizedBox(height: 10),
                    _dialogInput(
                      controller: departmentCtl,
                      label: 'Department',
                      icon: Icons.business_outlined,
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: selectedRole,
                      decoration: InputDecoration(
                        labelText: 'Role',
                        prefixIcon: const Icon(
                          Icons.admin_panel_settings_outlined,
                          color: mulberry,
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: creamDark),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: mulberry),
                        ),
                      ),
                      items: allowedRoles.map((role) {
                        return DropdownMenuItem<String>(
                          value: role,
                          child: Text(role),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setDialogState(() {
                          selectedRole = value;
                        });
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: mulberryDark),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () async {
                    final success = await _updateStaff(
                      staffId: staff['id'],
                      fullName: fullNameCtl.text.trim(),
                      username: usernameCtl.text.trim(),
                      email: emailCtl.text.trim(),
                      phone: phoneCtl.text.trim(),
                      branch: branchCtl.text.trim(),
                      department: departmentCtl.text.trim(),
                      role: selectedRole,
                    );

                    if (success && mounted) {
                      Navigator.pop(dialogContext);
                    }
                  },
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Save'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: mulberry,
                    foregroundColor: cream,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    fullNameCtl.dispose();
    usernameCtl.dispose();
    emailCtl.dispose();
    phoneCtl.dispose();
    branchCtl.dispose();
    departmentCtl.dispose();
  }

  Future<bool> _updateStaff({
    required dynamic staffId,
    required String fullName,
    required String username,
    required String email,
    required String phone,
    required String branch,
    required String department,
    required String role,
  }) async {
    if (staffId == null) {
      _showSnack('Invalid staff ID.');
      return false;
    }

    if (fullName.isEmpty || username.isEmpty || email.isEmpty) {
      _showSnack('Full name, username and email are required.');
      return false;
    }

    if (!email.contains('@')) {
      _showSnack('Please enter a valid email address.');
      return false;
    }

    try {
      await supabase.from(staffTable).update({
        'full_name': fullName,
        'username': username,
        'email': email,
        'phone': phone.isEmpty ? null : phone,
        'branch': branch.isEmpty ? null : branch,
        'department': department.isEmpty ? null : department,
        'role': role,
      }).eq('id', staffId);

      _showSnack('Employee information updated.');
      await loadStaff();
      return true;
    } on PostgrestException catch (e) {
      _showSnack('Database error: ${e.message}');
      return false;
    } catch (e) {
      _showSnack('Failed to update employee: $e');
      return false;
    }
  }

  Future<void> _confirmDeleteStaff(Map<String, dynamic> staff) async {
    final fullName = (staff['full_name'] ?? 'this employee').toString();

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: cream,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Delete Staff?',
            style: TextStyle(
              color: mulberryDark,
              fontWeight: FontWeight.bold,
              fontFamily: 'Georgia',
            ),
          ),
          content: Text(
            'Are you sure you want to delete $fullName? This will delete the profile record only.',
            style: TextStyle(color: Colors.grey.shade800),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text(
                'Cancel',
                style: TextStyle(color: mulberryDark),
              ),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                Navigator.pop(dialogContext);
                await _deleteStaff(staff['id']);
              },
              icon: const Icon(Icons.delete_outline),
              label: const Text('Delete'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteStaff(dynamic staffId) async {
    if (staffId == null) {
      _showSnack('Invalid staff ID.');
      return;
    }

    try {
      await supabase.from(staffTable).delete().eq('id', staffId);

      _showSnack('Staff profile deleted successfully.');
      await loadStaff();
    } on PostgrestException catch (e) {
      _showSnack('Database error: ${e.message}');
    } catch (e) {
      _showSnack('Failed to delete staff: $e');
    }
  }

  Widget _emptyState() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: creamDark),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.people_outline,
            size: 44,
            color: mulberry,
          ),
          const SizedBox(height: 10),
          const Text(
            'No employee records found.',
            style: TextStyle(
              color: mulberryDark,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Tap Add Staff to create a new employee account.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade700),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: cream,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddDialog,
        backgroundColor: mulberry,
        foregroundColor: cream,
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text(
          'Add Staff',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            _header(),
            Expanded(
              child: RefreshIndicator(
                color: mulberry,
                onRefresh: loadStaff,
                child: loading
                    ? const Center(
                        child: CircularProgressIndicator(color: mulberry),
                      )
                    : ListView(
                        padding: const EdgeInsets.all(20),
                        children: [
                          Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  'Employees',
                                  style: TextStyle(
                                    fontFamily: 'Georgia',
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: mulberryDark,
                                  ),
                                ),
                              ),
                              ElevatedButton.icon(
                                onPressed: _showAddDialog,
                                icon: const Icon(Icons.add, size: 18),
                                label: const Text('Add'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: mulberry,
                                  foregroundColor: cream,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Manage employee information and access roles.',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          const SizedBox(height: 18),
                          _summaryCard(),
                          const SizedBox(height: 18),
                          if (staffList.isEmpty)
                            _emptyState()
                          else
                            ...staffList.map(_staffCard),
                          const SizedBox(height: 80),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}