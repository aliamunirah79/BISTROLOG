import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/login_page.dart';

class ProfilePage extends StatefulWidget {
  final bool showAppBar;

  const ProfilePage({
    super.key,
    this.showAppBar = true,
  });

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final supabase = Supabase.instance.client;
  final picker = ImagePicker();

  final formKey = GlobalKey<FormState>();

  final fullNameController = TextEditingController();
  final usernameController = TextEditingController();
  final phoneController = TextEditingController();
  final branchController = TextEditingController();
  final departmentController = TextEditingController();

  bool isLoading = true;
  bool isEditing = false;
  bool isUploadingImage = false;
  bool isSaving = false;

  String? avatarUrl;
  String fullName = '';
  String username = '';
  String role = '';
  String profileId = '';
  String email = '';
  String phone = '';
  String branch = '';
  String department = '';
  String joinedAt = '';

  static const Color mulberry = Color(0xFF6D2B50);
  static const Color mulberryDark = Color(0xFF4A1A35);
  static const Color mulberryLight = Color(0xFF8B3D68);
  static const Color cream = Color(0xFFF5ECD7);
  static const Color creamDark = Color(0xFFE8D5B5);
  static const Color softWhite = Color(0xFFFFFCF7);

  @override
  void initState() {
    super.initState();
    loadProfile();
  }

  @override
  void dispose() {
    fullNameController.dispose();
    usernameController.dispose();
    phoneController.dispose();
    branchController.dispose();
    departmentController.dispose();
    super.dispose();
  }

  Future<void> loadProfile() async {
    if (!mounted) return;

    setState(() {
      isLoading = true;
    });

    try {
      final user = supabase.auth.currentUser;

      if (user == null) {
        throw Exception('User not logged in.');
      }

      final profile = await supabase
          .from('profiles')
          .select()
          .eq('id', user.id)
          .single();

      if (!mounted) return;

      setState(() {
        avatarUrl = profile['avatar_url'];
        fullName = profile['full_name'] ?? '';
        username = profile['username'] ?? '';
        role = profile['role']?.toString() ?? '';
        profileId = profile['profile_id'] ?? '';
        email = profile['email'] ?? user.email ?? '';
        phone = profile['phone'] ?? '';
        branch = profile['branch'] ?? '';
        department = profile['department'] ?? '';
        joinedAt = profile['joined_at']?.toString() ?? '';

        fullNameController.text = fullName;
        usernameController.text = username;
        phoneController.text = phone;
        branchController.text = branch;
        departmentController.text = department;

        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
      });

      showMessage('Failed to load profile: $e', isError: true);
    }
  }

  Future<void> pickAndUploadImage() async {
    try {
      final user = supabase.auth.currentUser;

      if (user == null) {
        throw Exception('User not logged in.');
      }

      final source = await showModalBottomSheet<ImageSource>(
        context: context,
        backgroundColor: cream,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(22),
          ),
        ),
        builder: (context) {
          return SafeArea(
            child: Wrap(
              children: [
                ListTile(
                  leading: const Icon(
                    Icons.camera_alt,
                    color: mulberry,
                  ),
                  title: const Text(
                    'Take Photo',
                    style: TextStyle(
                      color: mulberryDark,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context, ImageSource.camera);
                  },
                ),
                ListTile(
                  leading: const Icon(
                    Icons.photo_library,
                    color: mulberry,
                  ),
                  title: const Text(
                    'Choose from Gallery',
                    style: TextStyle(
                      color: mulberryDark,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context, ImageSource.gallery);
                  },
                ),
              ],
            ),
          );
        },
      );

      if (source == null) return;

      final pickedImage = await picker.pickImage(
        source: source,
        imageQuality: 75,
        maxWidth: 1000,
      );

      if (pickedImage == null) return;

      setState(() {
        isUploadingImage = true;
      });

      final file = File(pickedImage.path);
      final fileName = '${user.id}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final filePath = 'avatars/$fileName';

      await supabase.storage.from('profile_images').upload(
            filePath,
            file,
            fileOptions: const FileOptions(
              upsert: true,
              contentType: 'image/jpeg',
            ),
          );

      final imageUrl =
          supabase.storage.from('profile_images').getPublicUrl(filePath);

      await supabase.from('profiles').update({
        'avatar_url': imageUrl,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', user.id);

      if (!mounted) return;

      setState(() {
        avatarUrl = imageUrl;
        isUploadingImage = false;
      });

      showMessage('Profile picture updated.');
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isUploadingImage = false;
      });

      showMessage('Failed to upload profile picture: $e', isError: true);
    }
  }

  Future<void> saveProfile() async {
    if (!formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      isSaving = true;
    });

    try {
      final user = supabase.auth.currentUser;

      if (user == null) {
        throw Exception('User not logged in.');
      }

      await supabase.from('profiles').update({
        'full_name': fullNameController.text.trim(),
        'username': usernameController.text.trim(),
        'phone': phoneController.text.trim(),
        'branch': branchController.text.trim(),
        'department': departmentController.text.trim(),
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', user.id);

      if (!mounted) return;

      setState(() {
        fullName = fullNameController.text.trim();
        username = usernameController.text.trim();
        phone = phoneController.text.trim();
        branch = branchController.text.trim();
        department = departmentController.text.trim();
        isEditing = false;
        isSaving = false;
      });

      showMessage('Profile updated successfully.');
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isSaving = false;
      });

      showMessage('Failed to update profile: $e', isError: true);
    }
  }

  Future<void> sendPasswordReset() async {
    try {
      if (email.isEmpty) {
        showMessage('Email not found.', isError: true);
        return;
      }

      await supabase.auth.resetPasswordForEmail(email);

      showMessage('Password reset email sent.');
    } catch (e) {
      showMessage('Failed to send reset email: $e', isError: true);
    }
  }

  Future<void> signOut() async {
    await supabase.auth.signOut();

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => const LoginPage(),
      ),
      (route) => false,
    );
  }

  Color getRoleColor() {
    if (role == 'manager') {
      return mulberry;
    } else if (role == 'supervisor') {
      return Colors.indigo;
    } else {
      return Colors.teal;
    }
  }

  String formatRole(String value) {
    if (value.trim().isEmpty) {
      return 'STAFF';
    }

    return value.toUpperCase();
  }

  Widget buildHeader() {
    if (!widget.showAppBar) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 26, 20, 58),
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
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: const Column(
        children: [
          Text(
            'BISTROLOG',
            style: TextStyle(
              color: cream,
              fontFamily: 'Georgia',
              fontSize: 27,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Profile Management',
            style: TextStyle(
              color: creamDark,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget buildAvatar() {
    final embedded = !widget.showAppBar;

    return Transform.translate(
      offset: Offset(0, embedded ? 0 : -50),
      child: Padding(
        padding: EdgeInsets.only(top: embedded ? 18 : 0),
        child: Column(
          children: [
            Stack(
              alignment: Alignment.bottomRight,
              children: [
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: softWhite,
                    boxShadow: [
                      BoxShadow(
                        color: mulberryDark.withOpacity(0.14),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: CircleAvatar(
                    radius: embedded ? 52 : 58,
                    backgroundColor: creamDark.withOpacity(0.7),
                    backgroundImage: avatarUrl != null && avatarUrl!.isNotEmpty
                        ? NetworkImage(avatarUrl!)
                        : null,
                    child: avatarUrl == null || avatarUrl!.isEmpty
                        ? Icon(
                            Icons.person,
                            size: embedded ? 50 : 58,
                            color: mulberry,
                          )
                        : null,
                  ),
                ),
                GestureDetector(
                  onTap: isUploadingImage ? null : pickAndUploadImage,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: const BoxDecoration(
                      color: mulberry,
                      shape: BoxShape.circle,
                    ),
                    child: isUploadingImage
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: cream,
                            ),
                          )
                        : const Icon(
                            Icons.camera_alt,
                            size: 20,
                            color: cream,
                          ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              fullName.isEmpty ? 'No Name' : fullName,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: mulberryDark,
                fontFamily: 'Georgia',
                fontWeight: FontWeight.bold,
                fontSize: 23,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 13,
                vertical: 5,
              ),
              decoration: BoxDecoration(
                color: getRoleColor().withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                formatRole(role),
                style: TextStyle(
                  color: getRoleColor(),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildInfoCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: softWhite,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: creamDark.withOpacity(0.75),
        ),
        boxShadow: [
          BoxShadow(
            color: mulberryDark.withOpacity(0.05),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Profile Information',
            style: TextStyle(
              color: mulberryDark,
              fontFamily: 'Georgia',
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 16),
          buildInfoRow('Profile ID', profileId, bold: true),
          buildInfoRow('Username', username),
          buildInfoRow('Email', email),
          buildInfoRow('Phone', phone),
          buildInfoRow('Branch', branch),
          buildInfoRow('Department', department),
          buildInfoRow('Joined', joinedAt),
        ],
      ),
    );
  }

  Widget buildInfoRow(
    String label,
    String value, {
    bool bold = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 105,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '-' : value,
              style: TextStyle(
                color: mulberryDark,
                fontSize: 14,
                fontWeight: bold ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildEditForm() {
    return Form(
      key: formKey,
      child: Column(
        children: [
          if (isEditing) ...[
            buildInputField(
              controller: fullNameController,
              label: 'Full Name',
              icon: Icons.person_outline,
            ),
            buildInputField(
              controller: usernameController,
              label: 'Username',
              icon: Icons.alternate_email,
            ),
            buildInputField(
              controller: phoneController,
              label: 'Phone',
              icon: Icons.phone_outlined,
              requiredField: false,
            ),
            buildInputField(
              controller: branchController,
              label: 'Branch',
              icon: Icons.storefront_outlined,
              requiredField: false,
            ),
            buildInputField(
              controller: departmentController,
              label: 'Department',
              icon: Icons.badge_outlined,
              requiredField: false,
            ),
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: isSaving ? null : saveProfile,
                icon: isSaving
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: cream,
                        ),
                      )
                    : const Icon(Icons.save),
                label: Text(isSaving ? 'Saving...' : 'Save Profile'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: mulberry,
                  foregroundColor: cream,
                  disabledBackgroundColor: mulberry.withOpacity(0.45),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
              ),
            ),
            TextButton(
              onPressed: isSaving
                  ? null
                  : () {
                      setState(() {
                        isEditing = false;
                        fullNameController.text = fullName;
                        usernameController.text = username;
                        phoneController.text = phone;
                        branchController.text = branch;
                        departmentController.text = department;
                      });
                    },
              style: TextButton.styleFrom(
                foregroundColor: mulberry,
              ),
              child: const Text(
                'Cancel',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ] else ...[
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    isEditing = true;
                  });
                },
                icon: const Icon(Icons.edit),
                label: const Text('Edit Profile'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: mulberry,
                  foregroundColor: cream,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: OutlinedButton.icon(
              onPressed: sendPasswordReset,
              icon: const Icon(Icons.lock_reset),
              label: const Text('Reset Password'),
              style: OutlinedButton.styleFrom(
                foregroundColor: mulberry,
                side: const BorderSide(color: mulberry),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: signOut,
              icon: const Icon(Icons.logout),
              label: const Text('Sign Out'),
              style: ElevatedButton.styleFrom(
                backgroundColor: mulberryDark,
                foregroundColor: cream,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildInputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool requiredField = true,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 13),
      child: TextFormField(
        controller: controller,
        validator: requiredField
            ? (value) {
                if (value == null || value.trim().isEmpty) {
                  return '$label is required';
                }
                return null;
              }
            : null,
        style: const TextStyle(
          color: mulberryDark,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(
            color: Colors.grey.shade700,
          ),
          prefixIcon: Icon(
            icon,
            color: mulberry,
          ),
          filled: true,
          fillColor: softWhite,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide(
              color: creamDark.withOpacity(0.85),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: const BorderSide(
              color: mulberry,
              width: 1.8,
            ),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: const BorderSide(
              color: Colors.red,
            ),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: const BorderSide(
              color: Colors.red,
              width: 1.8,
            ),
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

  Widget buildProfileContent() {
    final embedded = !widget.showAppBar;

    return RefreshIndicator(
      color: mulberry,
      onRefresh: loadProfile,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          children: [
            if (!embedded) buildHeader(),
            buildAvatar(),
            Padding(
              padding: EdgeInsets.fromLTRB(
                18,
                embedded ? 18 : 0,
                18,
                28,
              ),
              child: Column(
                children: [
                  buildInfoCard(),
                  const SizedBox(height: 16),
                  buildEditForm(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        backgroundColor: cream,
        appBar: widget.showAppBar
            ? AppBar(
                title: const Text(
                  'Profile',
                  style: TextStyle(
                    color: cream,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                centerTitle: true,
                backgroundColor: mulberry,
                foregroundColor: cream,
                elevation: 0,
              )
            : null,
        body: const Center(
          child: CircularProgressIndicator(
            color: mulberry,
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: cream,
      appBar: widget.showAppBar
          ? AppBar(
              title: const Text(
                'Profile',
                style: TextStyle(
                  color: cream,
                  fontWeight: FontWeight.bold,
                ),
              ),
              centerTitle: true,
              backgroundColor: mulberry,
              foregroundColor: cream,
              elevation: 0,
            )
          : null,
      body: buildProfileContent(),
    );
  }
}