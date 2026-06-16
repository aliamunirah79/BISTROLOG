import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../common/recipe_vault_page.dart';
import '../auth/login_page.dart';
import '../common/cleaning_checklist_page.dart';
import '../common/profile_page.dart';
import '../common/notification_page.dart';
import '../common/inventory_page.dart';
import '../common/daily_stock_count_page.dart';
import '../common/work_schedule_page.dart';

class StaffHome extends StatefulWidget {
  final String fullName;

  const StaffHome({
    super.key,
    required this.fullName,
  });

  @override
  State<StaffHome> createState() => _StaffHomeState();
}

class _StaffHomeState extends State<StaffHome> {
  final supabase = Supabase.instance.client;
  final GlobalKey<ScaffoldState> scaffoldKey = GlobalKey<ScaffoldState>();

  static const Color mulberry = Color(0xFF6D2B50);
  static const Color mulberryDark = Color(0xFF4A1A35);
  static const Color mulberryLight = Color(0xFF8B3D68);
  static const Color cream = Color(0xFFF5ECD7);
  static const Color creamDark = Color(0xFFE8D5B5);
  static const Color softWhite = Color(0xFFFFFCF7);

  int currentIndex = 0;

  String profileName = '';
  String profileRole = 'staff';
  String? avatarUrl;

  @override
  void initState() {
    super.initState();
    profileName = widget.fullName;
    loadProfileSummary();
  }

  Future<void> loadProfileSummary() async {
    final user = supabase.auth.currentUser;

    if (user == null) return;

    try {
      final profile = await supabase
          .from('profiles')
          .select('full_name, role, avatar_url')
          .eq('id', user.id)
          .maybeSingle();

      if (!mounted || profile == null) return;

      setState(() {
        profileName = (profile['full_name'] ?? widget.fullName).toString();
        profileRole = (profile['role'] ?? 'staff').toString();
        avatarUrl = profile['avatar_url']?.toString();
      });
    } catch (e) {
      debugPrint('Failed to load staff profile summary: $e');
    }
  }

  Future<void> logout(BuildContext context) async {
    await Supabase.instance.client.auth.signOut();

    if (!context.mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }

  void openPage(Widget page) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => page,
      ),
    ).then((_) => loadProfileSummary());
  }

  String get displayName {
    if (profileName.trim().isNotEmpty) {
      return profileName.trim();
    }

    if (widget.fullName.trim().isNotEmpty) {
      return widget.fullName.trim();
    }

    return 'Staff';
  }

  String formatRole(String role) {
    if (role.trim().isEmpty) {
      return 'Staff';
    }

    return role[0].toUpperCase() + role.substring(1);
  }

  Widget buildLogo({
    double size = 48,
    double scale = 1.55,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFFF8F1E6),
        border: Border.all(
          color: Colors.white.withOpacity(0.86),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: mulberryDark.withOpacity(0.24),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipOval(
        child: Transform.scale(
          scale: scale,
          child: Image.asset(
            'logo.png',
            fit: BoxFit.cover,
            alignment: Alignment.center,
            errorBuilder: (context, error, stackTrace) {
              return const Icon(
                Icons.local_cafe,
                color: mulberry,
                size: 24,
              );
            },
          ),
        ),
      ),
    );
  }

  Widget buildProfileAvatar({
    double radius = 38,
  }) {
    final hasAvatar = avatarUrl != null && avatarUrl!.trim().isNotEmpty;

    return CircleAvatar(
      radius: radius,
      backgroundColor: cream,
      backgroundImage: hasAvatar ? NetworkImage(avatarUrl!) : null,
      child: hasAvatar
          ? null
          : Icon(
              Icons.person,
              color: mulberry,
              size: radius,
            ),
    );
  }

  Widget buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            mulberryDark,
            mulberry,
            mulberryLight,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
        boxShadow: [
          BoxShadow(
            color: mulberryDark.withOpacity(0.23),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: () {
                    scaffoldKey.currentState?.openDrawer();
                  },
                  icon: const Icon(
                    Icons.menu,
                    color: cream,
                    size: 28,
                  ),
                ),
                Expanded(
                  child: Center(
                    child: buildLogo(
                      size: 48,
                      scale: 1.55,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () {
                    openPage(const NotificationPage());
                  },
                  icon: const Icon(
                    Icons.notifications_outlined,
                    color: cream,
                    size: 27,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Hello,',
                style: TextStyle(
                  color: cream.withOpacity(0.88),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                displayName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: cream,
                  fontFamily: 'Georgia',
                  fontSize: 25,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'View schedule, complete checklist, count stock and access cafe recipes.',
                style: TextStyle(
                  color: creamDark,
                  fontSize: 12.5,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildDrawer() {
    return Drawer(
      backgroundColor: cream,
      child: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 22),
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
              child: Column(
                children: [
                  buildProfileAvatar(radius: 42),
                  const SizedBox(height: 12),
                  Text(
                    displayName,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: cream,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: cream.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      formatRole(profileRole),
                      style: const TextStyle(
                        color: cream,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        openPage(const ProfilePage());
                      },
                      icon: const Icon(Icons.person_outline),
                      label: const Text('Go to Profile'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: cream,
                        side: BorderSide(
                          color: cream.withOpacity(0.65),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            buildDrawerItem(
              icon: Icons.home_outlined,
              title: 'Home Dashboard',
              onTap: () {
                Navigator.pop(context);
                setState(() {
                  currentIndex = 0;
                });
              },
            ),
            buildDrawerItem(
              icon: Icons.calendar_month,
              title: 'My Schedule',
              onTap: () {
                Navigator.pop(context);
                openPage(const WorkSchedulePage());
              },
            ),
            buildDrawerItem(
              icon: Icons.checklist,
              title: 'Cleaning Checklist',
              onTap: () {
                Navigator.pop(context);
                openPage(const CleaningChecklistPage());
              },
            ),
            buildDrawerItem(
              icon: Icons.fact_check,
              title: 'Daily Stock Count',
              onTap: () {
                Navigator.pop(context);
                openPage(const DailyStockCountPage());
              },
            ),
            buildDrawerItem(
              icon: Icons.restaurant_menu,
              title: 'Recipe',
              onTap: () {
                Navigator.pop(context);
                openPage(const RecipeVaultPage());
              },
            ),
            buildDrawerItem(
              icon: Icons.inventory_2,
              title: 'Inventory',
              onTap: () {
                Navigator.pop(context);
                openPage(const InventoryPage());
              },
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: () => logout(context),
                  icon: const Icon(Icons.logout),
                  label: const Text(
                    'Sign Out',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: mulberry,
                    foregroundColor: cream,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildDrawerItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: mulberry,
      ),
      title: Text(
        title,
        style: const TextStyle(
          color: mulberryDark,
          fontWeight: FontWeight.w600,
        ),
      ),
      onTap: onTap,
    );
  }

  Widget menuCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: softWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: creamDark.withOpacity(0.70),
        ),
        boxShadow: [
          BoxShadow(
            color: mulberryDark.withOpacity(0.06),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.fromLTRB(16, 13, 14, 13),
        leading: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: mulberry.withOpacity(0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: mulberry,
          ),
        ),
        title: Text(
          title,
          style: const TextStyle(
            color: mulberryDark,
            fontWeight: FontWeight.bold,
            fontSize: 15.5,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 3),
          child: Text(
            subtitle,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 12.5,
              height: 1.25,
            ),
          ),
        ),
        trailing: const Icon(
          Icons.arrow_forward_ios,
          size: 16,
          color: mulberry,
        ),
        onTap: onTap,
      ),
    );
  }

  Widget buildHomeDashboard() {
    return RefreshIndicator(
      color: mulberry,
      onRefresh: loadProfileSummary,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 95),
        children: [
          menuCard(
            icon: Icons.calendar_month,
            title: 'My Schedule',
            subtitle: 'View today duty and assigned shift',
            onTap: () {
              openPage(const WorkSchedulePage());
            },
          ),
          menuCard(
            icon: Icons.checklist,
            title: 'Cleaning Checklist',
            subtitle: 'Update opening, closing and weekly tasks',
            onTap: () {
              openPage(const CleaningChecklistPage());
            },
          ),
          menuCard(
            icon: Icons.fact_check,
            title: 'Daily Stock Count',
            subtitle: 'Submit opening and closing stock count',
            onTap: () {
              openPage(const DailyStockCountPage());
            },
          ),
          menuCard(
            icon: Icons.restaurant_menu,
            title: 'Recipe',
            subtitle: 'View cafe menu recipes',
            onTap: () {
              openPage(const RecipeVaultPage());
            },
          ),
        ],
      ),
    );
  }

  Widget buildCurrentPage() {
    switch (currentIndex) {
      case 0:
        return buildHomeDashboard();
      case 1:
        return const RecipeVaultPage();
      case 2:
        return const DailyStockCountPage();
      case 3:
        return const ProfilePage();
      default:
        return buildHomeDashboard();
    }
  }

  BottomNavigationBarItem navItem({
    required IconData icon,
    required String label,
  }) {
    return BottomNavigationBarItem(
      icon: Icon(icon),
      label: label,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: scaffoldKey,
      backgroundColor: cream,
      drawer: buildDrawer(),
      body: Column(
        children: [
          buildHeader(),
          Expanded(
            child: buildCurrentPage(),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: softWhite,
          border: Border(
            top: BorderSide(
              color: creamDark.withOpacity(0.9),
              width: 1,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: mulberryDark.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: currentIndex,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          backgroundColor: softWhite,
          selectedItemColor: mulberry,
          unselectedItemColor: Colors.grey.shade600,
          selectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
          unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 12,
          ),
          onTap: (index) {
            setState(() {
              currentIndex = index;
            });

            loadProfileSummary();
          },
          items: [
            navItem(
              icon: Icons.home_outlined,
              label: 'Home',
            ),
            navItem(
              icon: Icons.restaurant_menu,
              label: 'Recipe',
            ),
            navItem(
              icon: Icons.fact_check,
              label: 'Stock',
            ),
            navItem(
              icon: Icons.person_outline,
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}