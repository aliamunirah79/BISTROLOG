import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path/path.dart' as path;
import 'login.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final supabase = Supabase.instance.client;
  final picker = ImagePicker();

  static const Color mulberry = Color(0xFF6D2B50);
  static const Color mulberryDark = Color(0xFF4A1A35);
  static const Color mulberryLight = Color(0xFF8B3D68);
  static const Color cream = Color(0xFFF5ECD7);
  static const Color creamDark = Color(0xFFE8D5B5);

  String? avatarUrl;
  String fullName = "";
  String username = "";
  String role = "";
  String profileId = "";
  String email = "";
  String phone = "";
  String branch = "";
  String joinedAt = "";
  int? tasksCompleted;

  bool _editing = false;
  bool _loading = true;

  final _formKey = GlobalKey<FormState>();
  final _fullNameCtl = TextEditingController();
  final _usernameCtl = TextEditingController();
  final _phoneCtl = TextEditingController();
  final _branchCtl = TextEditingController();

  @override
  void initState() {
    super.initState();
    loadProfile();
  }

  @override
  void dispose() {
    _fullNameCtl.dispose();
    _usernameCtl.dispose();
    _phoneCtl.dispose();
    _branchCtl.dispose();
    super.dispose();
  }

  Future<void> loadProfile() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    try {
      final res = await supabase
          .from('profiles')
          .select()
          .eq('id', user.id)
          .single();

      if (!mounted) return;

      setState(() {
        fullName = res['full_name'] ?? '';
        username = res['username'] ?? '';
        role = res['role']?.toString() ?? '';
        avatarUrl = res['avatar_url'];
        profileId = res['profile_id'] ?? '';
        email = res['email'] ?? user.email ?? '';
        phone = res['phone'] ?? '';
        branch = res['branch'] ?? '';
        joinedAt = res['joined_at']?.toString() ?? '';

        _fullNameCtl.text = fullName;
        _usernameCtl.text = username;
        _phoneCtl.text = phone;
        _branchCtl.text = branch;
        _loading = false;
      });

      try {
        final tasksRes = await supabase
            .from('tasks')
            .select()
            .eq('completed_by', user.id)
            .eq('done', true);

        if (!mounted) return;

        if (tasksRes is List) {
          setState(() => tasksCompleted = tasksRes.length);
        }
      } catch (_) {
        if (!mounted) return;
        setState(() => tasksCompleted = null);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load profile: $e'),
          backgroundColor: mulberryDark,
        ),
      );
    }
  }

  Future<void> uploadImage() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final source = await showModalBottomSheet<ImageSource?>(
      context: context,
      backgroundColor: cream,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (c) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: mulberry),
              title: const Text('Take Photo'),
              onTap: () => Navigator.of(c).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: mulberry),
              title: const Text('Choose from Gallery'),
              onTap: () => Navigator.of(c).pop(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source == null) return;

    final picked = await picker.pickImage(source: source, imageQuality: 80);
    if (picked == null) return;

    try {
      final file = File(picked.path);
      final fileName = '${user.id}_${path.basename(picked.path)}';

      await supabase.storage.from('profile_images').upload(
            fileName,
            file,
            fileOptions: const FileOptions(upsert: true),
          );

      final imageUrl =
          supabase.storage.from('profile_images').getPublicUrl(fileName);

      await supabase.from('profiles').update({
        'avatar_url': imageUrl,
      }).eq('id', user.id);

      if (!mounted) return;

      setState(() {
        avatarUrl = imageUrl;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile picture updated')),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to upload image: $e'),
          backgroundColor: mulberryDark,
        ),
      );
    }
  }

  Future<void> saveProfileEdits() async {
    if (!_formKey.currentState!.validate()) return;

    final user = supabase.auth.currentUser;
    if (user == null) return;

    try {
      await supabase.from('profiles').update({
        'full_name': _fullNameCtl.text.trim(),
        'username': _usernameCtl.text.trim(),
        'phone': _phoneCtl.text.trim(),
        'branch': _branchCtl.text.trim(),
      }).eq('id', user.id);

      if (!mounted) return;

      setState(() {
        fullName = _fullNameCtl.text.trim();
        username = _usernameCtl.text.trim();
        phone = _phoneCtl.text.trim();
        branch = _branchCtl.text.trim();
        _editing = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated')),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update profile: $e'),
          backgroundColor: mulberryDark,
        ),
      );
    }
  }

  Future<void> sendPasswordReset() async {
    if (email.isEmpty) return;

    await supabase.auth.resetPasswordForEmail(email);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Password reset email sent')),
    );
  }

  Future<void> signOut() async {
  await supabase.auth.signOut();

  if (!mounted) return;

  Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => const LoginPage()),
    (route) => false,
  );
}

  Widget _buildProfileHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 26, 20, 34),
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
      child: Column(
        children: [
          Container(
            width: 82,
            height: 82,
            decoration: BoxDecoration(
              color: cream,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.14),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
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
                    size: 42,
                    color: mulberry,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'BistroLog',
            style: TextStyle(
              fontFamily: 'Georgia',
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: cream,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Profile',
            style: TextStyle(
              fontSize: 13,
              color: cream.withOpacity(0.9),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar() {
    return Transform.translate(
      offset: const Offset(0, -38),
      child: Stack(
        alignment: Alignment.bottomRight,
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: cream,
              boxShadow: [
                BoxShadow(
                  color: mulberryDark.withOpacity(0.18),
                  blurRadius: 16,
                  offset: const Offset(0, 7),
                ),
              ],
            ),
            child: CircleAvatar(
              radius: 58,
              backgroundColor: Colors.white,
              backgroundImage:
                  avatarUrl != null && avatarUrl!.isNotEmpty
                      ? NetworkImage(avatarUrl!)
                      : null,
              child: avatarUrl == null || avatarUrl!.isEmpty
                  ? const Icon(
                      Icons.person,
                      size: 58,
                      color: mulberry,
                    )
                  : null,
            ),
          ),
          GestureDetector(
            onTap: uploadImage,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: mulberry,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.edit,
                size: 18,
                color: cream,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade700,
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

  Widget _buildProfileInfoCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Profile Information',
            style: TextStyle(
              fontFamily: 'Georgia',
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: mulberryDark,
            ),
          ),
          const SizedBox(height: 14),
          _infoRow('Full Name', fullName),
          _infoRow('Username', username),
          _infoRow('Role', role),
          _infoRow('ID', profileId, bold: true),
          _infoRow('Email', email),
          _infoRow('Phone', phone),
          _infoRow('Branch', branch),
          if (tasksCompleted != null)
            _infoRow('Tasks', '${tasksCompleted!} completed'),
          if (joinedAt.isNotEmpty) _infoRow('Joined', joinedAt),
        ],
      ),
    );
  }

  Widget _buildEditForm() {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          if (_editing) ...[
            _inputField(
              controller: _fullNameCtl,
              label: 'Full name',
              icon: Icons.person_outline,
            ),
            const SizedBox(height: 10),
            _inputField(
              controller: _usernameCtl,
              label: 'Username',
              icon: Icons.alternate_email,
            ),
            const SizedBox(height: 10),
            _inputField(
              controller: _phoneCtl,
              label: 'Phone',
              icon: Icons.phone_outlined,
            ),
            const SizedBox(height: 10),
            _inputField(
              controller: _branchCtl,
              label: 'Branch',
              icon: Icons.storefront_outlined,
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: saveProfileEdits,
                icon: const Icon(Icons.save_outlined),
                label: const Text('Save Profile'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: mulberry,
                  foregroundColor: cream,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
            TextButton(
              onPressed: () => setState(() => _editing = false),
              child: const Text(
                'Cancel',
                style: TextStyle(color: mulberryDark),
              ),
            ),
          ] else ...[
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () => setState(() => _editing = true),
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Edit Profile'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: mulberry,
                  foregroundColor: cream,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              onPressed: sendPasswordReset,
              icon: const Icon(Icons.lock_reset_outlined),
              label: const Text('Reset Password'),
              style: OutlinedButton.styleFrom(
                foregroundColor: mulberry,
                side: const BorderSide(color: mulberry),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: signOut,
              icon: const Icon(Icons.logout),
              label: const Text('Sign Out'),
              style: ElevatedButton.styleFrom(
                backgroundColor: mulberryDark,
                foregroundColor: cream,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _inputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: mulberry),
        filled: true,
        fillColor: Colors.white,
        labelStyle: TextStyle(color: Colors.grey.shade700),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: creamDark),
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

@override
Widget build(BuildContext context) {
  if (_loading) {
    return const Scaffold(
      backgroundColor: cream,
      body: Center(
        child: CircularProgressIndicator(color: mulberry),
      ),
    );
  }

  return Scaffold(
    backgroundColor: cream,
    body: Container(
      color: cream,
      child: SingleChildScrollView(
        child: Column(
          children: [
            _buildProfileHeader(),
            _buildAvatar(),
            Transform.translate(
              offset: const Offset(0, -20),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                child: Column(
                  children: [
                    _buildProfileInfoCard(),
                    const SizedBox(height: 16),
                    _buildEditForm(),
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