import 'dart:math';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ManageStaffPage extends StatefulWidget {
  final bool showAppBar;

  const ManageStaffPage({
    super.key,
    this.showAppBar = true,
  });

  @override
  State<ManageStaffPage> createState() => _ManageStaffPageState();
}

class _ManageStaffPageState extends State<ManageStaffPage> {
  final supabase = Supabase.instance.client;

  bool isLoading = true;
  String searchQuery = '';
  String selectedRole = 'All';
  String selectedStatus = 'All';

  List<Map<String, dynamic>> staffList = [];

  static const Color mulberry = Color(0xFF6D2B50);
  static const Color mulberryDark = Color(0xFF4A1A35);
  static const Color mulberryLight = Color(0xFF8B3D68);
  static const Color cream = Color(0xFFF5ECD7);
  static const Color creamDark = Color(0xFFE8D5B5);
  static const Color softWhite = Color(0xFFFFFCF7);

  @override
  void initState() {
    super.initState();
    loadStaff();
  }

  Future<void> loadStaff() async {
    if (!mounted) return;

    setState(() {
      isLoading = true;
    });

    try {
      final response = await supabase.from('profiles').select();
      final list = List<Map<String, dynamic>>.from(response);

      list.sort((a, b) {
        int rolePriority(String role) {
          switch (role) {
            case 'manager':
              return 0;
            case 'supervisor':
              return 1;
            case 'staff':
              return 2;
            default:
              return 3;
          }
        }

        final roleA = rolePriority(getRole(a));
        final roleB = rolePriority(getRole(b));

        if (roleA != roleB) return roleA.compareTo(roleB);

        return getFullName(a)
            .toLowerCase()
            .compareTo(getFullName(b).toLowerCase());
      });

      if (!mounted) return;

      setState(() {
        staffList = list;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
      });

      showMessage('Failed to load staff list: $e', isError: true);
    }
  }

  String get currentUserId => supabase.auth.currentUser?.id ?? '';

  bool isCurrentUser(Map<String, dynamic> staff) {
    return staff['id']?.toString() == currentUserId;
  }

  String getFullName(Map<String, dynamic> staff) {
    return (staff['full_name'] ?? 'Unnamed Staff').toString();
  }

  String getUsername(Map<String, dynamic> staff) {
    return (staff['username'] ?? '-').toString();
  }

  String getEmail(Map<String, dynamic> staff) {
    final value = staff['email'];
    if (value == null || value.toString().trim().isEmpty) return '-';
    return value.toString();
  }

  String getPhone(Map<String, dynamic> staff) {
    final value = staff['phone'];
    if (value == null || value.toString().trim().isEmpty) return '-';
    return value.toString();
  }

  String getBranch(Map<String, dynamic> staff) {
    final value = staff['branch'];
    if (value == null || value.toString().trim().isEmpty) return '-';
    return value.toString();
  }

  String getDepartment(Map<String, dynamic> staff) {
    final value = staff['department'];
    if (value == null || value.toString().trim().isEmpty) return '-';
    return value.toString();
  }

  String getRole(Map<String, dynamic> staff) {
    return (staff['role'] ?? 'staff').toString();
  }

  String getProfileId(Map<String, dynamic> staff) {
    return (staff['profile_id'] ?? '-').toString();
  }

  String getAvatarUrl(Map<String, dynamic> staff) {
    final value = staff['avatar_url'];
    if (value == null || value.toString().trim().isEmpty) return '';
    return value.toString();
  }

  bool isActiveStaff(Map<String, dynamic> staff) {
    final isActive = staff['is_active'];
    if (isActive == null) return true;
    return isActive == true;
  }

  String formatRole(String role) {
    if (role.isEmpty) return 'Staff';
    return role[0].toUpperCase() + role.substring(1);
  }

  Color getRoleColor(String role) {
    switch (role) {
      case 'manager':
        return mulberry;
      case 'supervisor':
        return Colors.blue;
      case 'staff':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  List<Map<String, dynamic>> getFilteredStaff() {
    List<Map<String, dynamic>> filtered = staffList;

    if (selectedRole != 'All') {
      filtered = filtered
          .where((staff) => getRole(staff) == selectedRole.toLowerCase())
          .toList();
    }

    if (selectedStatus != 'All') {
      filtered = filtered.where((staff) {
        final active = isActiveStaff(staff);
        return selectedStatus == 'Active' ? active : !active;
      }).toList();
    }

    if (searchQuery.trim().isNotEmpty) {
      final query = searchQuery.toLowerCase();

      filtered = filtered.where((staff) {
        final name = getFullName(staff).toLowerCase();
        final username = getUsername(staff).toLowerCase();
        final email = getEmail(staff).toLowerCase();
        final profileId = getProfileId(staff).toLowerCase();
        final phone = getPhone(staff).toLowerCase();
        final role = getRole(staff).toLowerCase();

        return name.contains(query) ||
            username.contains(query) ||
            email.contains(query) ||
            profileId.contains(query) ||
            phone.contains(query) ||
            role.contains(query);
      }).toList();
    }

    return filtered;
  }

  int get totalStaff => staffList.length;
  int get activeStaff => staffList.where(isActiveStaff).length;
  int get inactiveStaff =>
      staffList.where((staff) => !isActiveStaff(staff)).length;
  int get supervisorCount =>
      staffList.where((staff) => getRole(staff) == 'supervisor').length;

  String generateTemporaryPassword() {
    final random = Random.secure();
    final number = 10000 + random.nextInt(90000);
    return 'Bistro@$number';
  }

  Future<bool> createStaffAccount({
    required String fullName,
    required String username,
    required String email,
    required String temporaryPassword,
    required String role,
    String? phone,
    String? branch,
    String? department,
  }) async {
    try {
      final response = await supabase.functions.invoke(
        'create-staff-user',
        body: {
          'full_name': fullName,
          'username': username,
          'email': email,
          'password': temporaryPassword,
          'role': role,
          'phone': phone,
          'branch': branch,
          'department': department,
        },
      );

      if (response.data is Map && response.data['error'] != null) {
        showMessage(response.data['error'].toString(), isError: true);
        return false;
      }

      await loadStaff();
      return true;
    } catch (e) {
      showMessage(
        'Failed to create staff account. Supabase Edge Function may not be ready yet: $e',
        isError: true,
      );
      return false;
    }
  }

  Future<void> showTemporaryPasswordDialog({
    required String email,
    required String temporaryPassword,
  }) async {
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: softWhite,
          title: const Text(
            'Account Created',
            style: TextStyle(
              color: mulberryDark,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Give this login detail to the staff. The staff must change this password after first login.',
                style: TextStyle(
                  color: Colors.grey.shade800,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 14),
              buildCredentialBox('Email', email),
              const SizedBox(height: 10),
              buildCredentialBox('Temporary Password', temporaryPassword),
              const SizedBox(height: 10),
              Text(
                'Please save or copy this password now. It will not be shown again.',
                style: TextStyle(
                  color: Colors.red.shade700,
                  fontWeight: FontWeight.w600,
                  fontSize: 12.5,
                ),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext),
              style: ElevatedButton.styleFrom(
                backgroundColor: mulberry,
                foregroundColor: cream,
              ),
              child: const Text('I Understand'),
            ),
          ],
        );
      },
    );
  }

  Widget buildCredentialBox(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cream,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: creamDark),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          SelectableText(
            value,
            style: const TextStyle(
              color: mulberryDark,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> updateStaffStatus(Map<String, dynamic> staff, bool active) async {
    if (isCurrentUser(staff)) {
      showMessage(
        'You cannot deactivate or reactivate your own manager account from Manage Staff.',
        isError: true,
      );
      return;
    }

    try {
      await supabase.from('profiles').update({
        'is_active': active,
        'staff_status': active ? 'active' : 'inactive',
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', staff['id']);

      showMessage(
        active
            ? 'Account activated successfully.'
            : 'Account deactivated successfully.',
      );

      await loadStaff();
    } catch (e) {
      showMessage('Failed to update staff status: $e', isError: true);
    }
  }

  Future<bool> confirmStatusChange(
    Map<String, dynamic> staff,
    bool active,
  ) async {
    if (isCurrentUser(staff)) {
      showMessage(
        'This is your current account. Action blocked for safety.',
        isError: true,
      );
      return false;
    }

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: softWhite,
          title: Text(
            active ? 'Activate Account?' : 'Deactivate Account?',
            style: const TextStyle(
              color: mulberryDark,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            active
                ? 'Activate ${getFullName(staff)} account?'
                : 'Deactivate ${getFullName(staff)} account? This user should not be able to continue normal access.',
            style: TextStyle(color: Colors.grey.shade800, height: 1.35),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              style: TextButton.styleFrom(foregroundColor: mulberry),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: active ? Colors.green : Colors.red,
                foregroundColor: Colors.white,
              ),
              child: Text(active ? 'Activate' : 'Deactivate'),
            ),
          ],
        );
      },
    );

    return result == true;
  }

  Future<void> showCreateStaffSheet() async {
    final fullNameController = TextEditingController();
    final usernameController = TextEditingController();
    final emailController = TextEditingController();
    final phoneController = TextEditingController();
    final branchController = TextEditingController();
    final departmentController = TextEditingController();

    String selectedCreateRole = 'staff';
    bool isSaving = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: softWhite,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (bottomSheetContext) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(bottomSheetContext).viewInsets.bottom,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: StatefulBuilder(
                builder: (context, setModalState) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Center(
                        child: CircleAvatar(
                          radius: 40,
                          backgroundColor: cream,
                          child: Icon(
                            Icons.person_add,
                            color: mulberry,
                            size: 40,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Center(
                        child: Text(
                          'Create Staff Account',
                          style: TextStyle(
                            color: mulberryDark,
                            fontFamily: 'Georgia',
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: cream,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: creamDark),
                        ),
                        child: Text(
                          'The system will auto-generate a temporary password. The staff must change it after first login.',
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.w600,
                            height: 1.3,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      buildTextField(
                        controller: fullNameController,
                        label: 'Full Name',
                        icon: Icons.badge,
                      ),
                      const SizedBox(height: 12),
                      buildTextField(
                        controller: usernameController,
                        label: 'Username',
                        icon: Icons.alternate_email,
                      ),
                      const SizedBox(height: 12),
                      buildTextField(
                        controller: emailController,
                        label: 'Email',
                        icon: Icons.email,
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 12),
                      buildTextField(
                        controller: phoneController,
                        label: 'Phone',
                        icon: Icons.phone,
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 12),
                      buildTextField(
                        controller: branchController,
                        label: 'Branch',
                        icon: Icons.store,
                      ),
                      const SizedBox(height: 12),
                      buildTextField(
                        controller: departmentController,
                        label: 'Department',
                        icon: Icons.apartment,
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: selectedCreateRole,
                        dropdownColor: softWhite,
                        decoration: buildInputDecoration(
                          label: 'Role',
                          icon: Icons.admin_panel_settings,
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
                          DropdownMenuItem(
                            value: 'manager',
                            child: Text('Manager'),
                          ),
                        ],
                        onChanged: isSaving
                            ? null
                            : (value) {
                                if (value == null) return;
                                setModalState(() {
                                  selectedCreateRole = value;
                                });
                              },
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton.icon(
                          onPressed: isSaving
                              ? null
                              : () async {
                                  final fullName =
                                      fullNameController.text.trim();
                                  final username =
                                      usernameController.text.trim();
                                  final email = emailController.text.trim();

                                  if (fullName.isEmpty ||
                                      username.isEmpty ||
                                      email.isEmpty) {
                                    showMessage(
                                      'Full name, username and email are required.',
                                      isError: true,
                                    );
                                    return;
                                  }

                                  if (!email.contains('@')) {
                                    showMessage(
                                      'Please enter a valid email address.',
                                      isError: true,
                                    );
                                    return;
                                  }

                                  final temporaryPassword =
                                      generateTemporaryPassword();

                                  setModalState(() {
                                    isSaving = true;
                                  });

                                  final created = await createStaffAccount(
                                    fullName: fullName,
                                    username: username,
                                    email: email,
                                    temporaryPassword: temporaryPassword,
                                    role: selectedCreateRole,
                                    phone: phoneController.text.trim().isEmpty
                                        ? null
                                        : phoneController.text.trim(),
                                    branch:
                                        branchController.text.trim().isEmpty
                                            ? null
                                            : branchController.text.trim(),
                                    department: departmentController.text
                                            .trim()
                                            .isEmpty
                                        ? null
                                        : departmentController.text.trim(),
                                  );

                                  if (!mounted) return;

                                  if (created) {
                                    Navigator.pop(bottomSheetContext);

                                    await showTemporaryPasswordDialog(
                                      email: email,
                                      temporaryPassword: temporaryPassword,
                                    );
                                  } else {
                                    setModalState(() {
                                      isSaving = false;
                                    });
                                  }
                                },
                          icon: isSaving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: cream,
                                  ),
                                )
                              : const Icon(Icons.person_add),
                          label: Text(
                            isSaving ? 'Creating...' : 'Create Account',
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: mulberry,
                            foregroundColor: cream,
                            disabledBackgroundColor:
                                mulberry.withOpacity(0.45),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        );
      },
    );

    fullNameController.dispose();
    usernameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    branchController.dispose();
    departmentController.dispose();
  }

  Future<void> showEditStaffSheet(Map<String, dynamic> staff) async {
    final isSelf = isCurrentUser(staff);

    final fullNameController =
        TextEditingController(text: getFullName(staff));
    final usernameController =
        TextEditingController(text: getUsername(staff));
    final emailController = TextEditingController(
      text: getEmail(staff) == '-' ? '' : getEmail(staff),
    );
    final phoneController = TextEditingController(
      text: getPhone(staff) == '-' ? '' : getPhone(staff),
    );
    final branchController = TextEditingController(
      text: getBranch(staff) == '-' ? '' : getBranch(staff),
    );
    final departmentController = TextEditingController(
      text: getDepartment(staff) == '-' ? '' : getDepartment(staff),
    );

    String selectedEditRole = getRole(staff);

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: softWhite,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (bottomSheetContext) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(bottomSheetContext).viewInsets.bottom,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: StatefulBuilder(
                builder: (context, setModalState) {
                  final avatarUrl = getAvatarUrl(staff);

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: CircleAvatar(
                          radius: 40,
                          backgroundColor: cream,
                          backgroundImage: avatarUrl.isNotEmpty
                              ? NetworkImage(avatarUrl)
                              : null,
                          child: avatarUrl.isEmpty
                              ? const Icon(
                                  Icons.person,
                                  color: mulberry,
                                  size: 40,
                                )
                              : null,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Center(
                        child: Text(
                          isSelf
                              ? 'Edit My Manager Profile'
                              : 'Edit Staff Profile',
                          style: const TextStyle(
                            color: mulberryDark,
                            fontFamily: 'Georgia',
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (isSelf) ...[
                        const SizedBox(height: 10),
                        buildSelfProtectionNotice(),
                      ],
                      const SizedBox(height: 20),
                      buildTextField(
                        controller: fullNameController,
                        label: 'Full Name',
                        icon: Icons.badge,
                      ),
                      const SizedBox(height: 12),
                      buildTextField(
                        controller: usernameController,
                        label: 'Username',
                        icon: Icons.alternate_email,
                      ),
                      const SizedBox(height: 12),
                      buildTextField(
                        controller: emailController,
                        label: 'Email',
                        icon: Icons.email,
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 12),
                      buildTextField(
                        controller: phoneController,
                        label: 'Phone',
                        icon: Icons.phone,
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 12),
                      buildTextField(
                        controller: branchController,
                        label: 'Branch',
                        icon: Icons.store,
                      ),
                      const SizedBox(height: 12),
                      buildTextField(
                        controller: departmentController,
                        label: 'Department',
                        icon: Icons.apartment,
                      ),
                      const SizedBox(height: 12),
                      if (isSelf)
                        buildLockedRoleBox(selectedEditRole)
                      else
                        DropdownButtonFormField<String>(
                          value: selectedEditRole,
                          dropdownColor: softWhite,
                          decoration: buildInputDecoration(
                            label: 'Role',
                            icon: Icons.admin_panel_settings,
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
                            DropdownMenuItem(
                              value: 'manager',
                              child: Text('Manager'),
                            ),
                          ],
                          onChanged: (value) {
                            if (value == null) return;
                            setModalState(() {
                              selectedEditRole = value;
                            });
                          },
                        ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            final fullName =
                                fullNameController.text.trim();
                            final username =
                                usernameController.text.trim();

                            if (fullName.isEmpty || username.isEmpty) {
                              showMessage(
                                'Full name and username are required.',
                                isError: true,
                              );
                              return;
                            }

                            try {
                              await supabase.from('profiles').update({
                                'full_name': fullName,
                                'username': username,
                                'email':
                                    emailController.text.trim().isEmpty
                                        ? null
                                        : emailController.text.trim(),
                                'phone':
                                    phoneController.text.trim().isEmpty
                                        ? null
                                        : phoneController.text.trim(),
                                'branch':
                                    branchController.text.trim().isEmpty
                                        ? null
                                        : branchController.text.trim(),
                                'department':
                                    departmentController.text.trim().isEmpty
                                        ? null
                                        : departmentController.text.trim(),
                                if (!isSelf) 'role': selectedEditRole,
                                'updated_at':
                                    DateTime.now().toIso8601String(),
                              }).eq('id', staff['id']);

                              if (!mounted) return;

                              Navigator.pop(bottomSheetContext);
                              showMessage('Profile updated successfully.');
                              await loadStaff();
                            } catch (e) {
                              showMessage(
                                'Failed to update profile: $e',
                                isError: true,
                              );
                            }
                          },
                          icon: const Icon(Icons.save),
                          label: const Text('Save Changes'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: mulberry,
                            foregroundColor: cream,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        );
      },
    );

    fullNameController.dispose();
    usernameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    branchController.dispose();
    departmentController.dispose();
  }

  Widget buildSelfProtectionNotice() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Text(
        'Current Account: role and deactivate action are locked so you cannot disable your own manager account.',
        style: TextStyle(
          color: Colors.orange.shade900,
          fontWeight: FontWeight.w600,
          height: 1.3,
        ),
      ),
    );
  }

  Widget buildLockedRoleBox(String role) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cream,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: creamDark),
      ),
      child: Row(
        children: [
          const Icon(Icons.lock, color: mulberry),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Role locked: ${formatRole(role)}',
              style: const TextStyle(
                color: mulberryDark,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: buildInputDecoration(label: label, icon: icon),
      style: const TextStyle(color: mulberryDark),
    );
  }

  InputDecoration buildInputDecoration({
    required String label,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: mulberry),
      prefixIcon: Icon(icon, color: mulberry),
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
    );
  }

  void showStaffDetail(Map<String, dynamic> staff) {
    final active = isActiveStaff(staff);
    final role = getRole(staff);
    final isSelf = isCurrentUser(staff);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: cream,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (bottomSheetContext) {
        final avatarUrl = getAvatarUrl(staff);

        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: CircleAvatar(
                    radius: 45,
                    backgroundColor: softWhite,
                    backgroundImage:
                        avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
                    child: avatarUrl.isEmpty
                        ? const Icon(
                            Icons.person,
                            color: mulberry,
                            size: 45,
                          )
                        : null,
                  ),
                ),
                const SizedBox(height: 12),
                Center(
                  child: Text(
                    getFullName(staff),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: mulberryDark,
                      fontFamily: 'Georgia',
                      fontSize: 23,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Center(
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      buildStatusBadge(
                        active ? 'ACTIVE' : 'INACTIVE',
                        active ? Colors.green : Colors.red,
                      ),
                      buildStatusBadge(
                        formatRole(role).toUpperCase(),
                        getRoleColor(role),
                      ),
                      if (isSelf)
                        buildStatusBadge('CURRENT ACCOUNT', Colors.orange),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                buildDetailRow(Icons.badge, 'Profile ID', getProfileId(staff)),
                buildDetailRow(
                  Icons.alternate_email,
                  'Username',
                  getUsername(staff),
                ),
                buildDetailRow(Icons.email, 'Email', getEmail(staff)),
                buildDetailRow(Icons.phone, 'Phone', getPhone(staff)),
                buildDetailRow(Icons.store, 'Branch', getBranch(staff)),
                buildDetailRow(
                  Icons.apartment,
                  'Department',
                  getDepartment(staff),
                ),
                if (isSelf) ...[
                  const SizedBox(height: 10),
                  buildSelfProtectionNotice(),
                ],
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(bottomSheetContext);
                          showEditStaffSheet(staff);
                        },
                        icon: const Icon(Icons.edit),
                        label: const Text('Edit'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: mulberry,
                          side: const BorderSide(color: mulberry),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: isSelf
                            ? null
                            : () async {
                                Navigator.pop(bottomSheetContext);
                                final confirm = await confirmStatusChange(
                                  staff,
                                  !active,
                                );
                                if (confirm) {
                                  await updateStaffStatus(staff, !active);
                                }
                              },
                        icon: Icon(
                          active ? Icons.block : Icons.check_circle,
                        ),
                        label: Text(active ? 'Deactivate' : 'Activate'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              active ? Colors.red : Colors.green,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: Colors.grey.shade400,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget buildStatusBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 11.5,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget buildDetailRow(IconData icon, String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: softWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: creamDark.withOpacity(0.75)),
      ),
      child: Row(
        children: [
          Icon(icon, color: mulberry, size: 20),
          const SizedBox(width: 10),
          SizedBox(
            width: 95,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: mulberryDark,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildHeader() {
    if (!widget.showAppBar) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [mulberryDark, mulberry, mulberryLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: mulberryDark.withOpacity(0.16),
            blurRadius: 16,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: const Row(
        children: [
          CircleAvatar(
            radius: 27,
            backgroundColor: Color(0x33F5ECD7),
            child: Icon(Icons.people, color: cream, size: 30),
          ),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Manage Staff',
                  style: TextStyle(
                    color: cream,
                    fontFamily: 'Georgia',
                    fontSize: 21,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  'Manage staff login accounts, roles and account status.',
                  style: TextStyle(
                    color: creamDark,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget buildSummaryCards() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 2.1,
      children: [
        buildSummaryCard(
          'Total',
          totalStaff.toString(),
          Icons.people,
          mulberry,
        ),
        buildSummaryCard(
          'Active',
          activeStaff.toString(),
          Icons.check_circle,
          Colors.green,
        ),
        buildSummaryCard(
          'Inactive',
          inactiveStaff.toString(),
          Icons.block,
          Colors.red,
        ),
        buildSummaryCard(
          'Supervisor',
          supervisorCount.toString(),
          Icons.admin_panel_settings,
          Colors.blue,
        ),
      ],
    );
  }

  Widget buildSummaryCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: softWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: creamDark.withOpacity(0.75)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: color.withOpacity(0.12),
            child: Icon(icon, color: color, size: 19),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    color: mulberryDark,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget buildSearchAndFilters() {
    return Column(
      children: [
        TextField(
          onChanged: (value) => setState(() => searchQuery = value),
          decoration: InputDecoration(
            hintText: 'Search staff, username, email or role...',
            prefixIcon: const Icon(Icons.search, color: mulberry),
            filled: true,
            fillColor: softWhite,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: creamDark.withOpacity(0.85)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: mulberry, width: 1.8),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: buildDropdown(
                value: selectedRole,
                items: const ['All', 'Manager', 'Supervisor', 'Staff'],
                onChanged: (value) =>
                    setState(() => selectedRole = value ?? 'All'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: buildDropdown(
                value: selectedStatus,
                items: const ['All', 'Active', 'Inactive'],
                onChanged: (value) =>
                    setState(() => selectedStatus = value ?? 'All'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget buildDropdown({
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      dropdownColor: softWhite,
      decoration: InputDecoration(
        filled: true,
        fillColor: softWhite,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: creamDark.withOpacity(0.85)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: mulberry),
        ),
      ),
      items: items
          .map(
            (item) => DropdownMenuItem(
              value: item,
              child: Text(item),
            ),
          )
          .toList(),
      onChanged: onChanged,
    );
  }

  Widget buildStaffCard(Map<String, dynamic> staff) {
    final active = isActiveStaff(staff);
    final role = getRole(staff);
    final avatarUrl = getAvatarUrl(staff);
    final isSelf = isCurrentUser(staff);

    return Container(
      margin: const EdgeInsets.only(bottom: 13),
      decoration: BoxDecoration(
        color: softWhite,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isSelf ? Colors.orange.shade200 : creamDark.withOpacity(0.75),
        ),
        boxShadow: [
          BoxShadow(
            color: mulberryDark.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => showStaffDetail(staff),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              CircleAvatar(
                radius: 27,
                backgroundColor: cream,
                backgroundImage:
                    avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
                child: avatarUrl.isEmpty
                    ? const Icon(Icons.person, color: mulberry)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            getFullName(staff),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: mulberryDark,
                              fontWeight: FontWeight.bold,
                              fontSize: 15.5,
                            ),
                          ),
                        ),
                        if (isSelf) buildStatusBadge('YOU', Colors.orange),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '@${getUsername(staff)}',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 7,
                      runSpacing: 7,
                      children: [
                        buildStatusBadge(formatRole(role), getRoleColor(role)),
                        buildStatusBadge(
                          active ? 'Active' : 'Inactive',
                          active ? Colors.green : Colors.red,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                color: softWhite,
                onSelected: (value) async {
                  if (value == 'view') {
                    showStaffDetail(staff);
                  } else if (value == 'edit') {
                    showEditStaffSheet(staff);
                  } else if (value == 'toggle') {
                    final confirm =
                        await confirmStatusChange(staff, !active);
                    if (confirm) await updateStaffStatus(staff, !active);
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'view',
                    child: Text('View details'),
                  ),
                  const PopupMenuItem(
                    value: 'edit',
                    child: Text('Edit profile'),
                  ),
                  if (!isSelf)
                    PopupMenuItem(
                      value: 'toggle',
                      child: Text(
                        active ? 'Deactivate' : 'Activate',
                        style: TextStyle(
                          color: active ? Colors.red : Colors.green,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.only(top: 80),
      child: Center(
        child: Text(
          'No staff found.',
          style: TextStyle(
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  void showMessage(String message, {bool isError = false}) {
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

  @override
  Widget build(BuildContext context) {
    final filteredStaff = getFilteredStaff();

    return Scaffold(
      backgroundColor: cream,
      appBar: widget.showAppBar
          ? AppBar(
              title: const Text(
                'Manage Staff',
                style: TextStyle(
                  color: cream,
                  fontWeight: FontWeight.bold,
                ),
              ),
              centerTitle: true,
              backgroundColor: mulberry,
              foregroundColor: cream,
              elevation: 0,
              actions: [
                IconButton(
                  onPressed: loadStaff,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            )
          : null,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: showCreateStaffSheet,
        backgroundColor: mulberry,
        foregroundColor: cream,
        icon: const Icon(Icons.person_add),
        label: const Text('Create Staff'),
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(color: mulberry),
            )
          : RefreshIndicator(
              color: mulberry,
              onRefresh: loadStaff,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 90),
                children: [
                  buildHeader(),
                  if (widget.showAppBar) const SizedBox(height: 14),
                  buildSummaryCards(),
                  const SizedBox(height: 14),
                  buildSearchAndFilters(),
                  const SizedBox(height: 16),
                  if (filteredStaff.isEmpty)
                    buildEmptyState()
                  else
                    ...filteredStaff.map(buildStaffCard),
                ],
              ),
            ),
    );
  }
}