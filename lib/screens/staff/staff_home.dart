import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../common/recipe_vault_page.dart';
import '../auth/login_page.dart';
import '../common/cleaning_checklist_page.dart';
import '../common/profile_page.dart';
import '../common/notification_page.dart';
import '../common/inventory_page.dart';
import '../common/history_log_page.dart';
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

  List<Map<String, dynamic>> todaySchedules = [];
  bool isScheduleLoading = true;

  @override
  void initState() {
    super.initState();
    profileName = widget.fullName;
    loadProfileSummary();
    loadTodaySchedule();
  }

  String get todayText => DateTime.now().toIso8601String().substring(0, 10);

  Stream<List<Map<String, dynamic>>> getUnreadNotificationStream() {
    final user = supabase.auth.currentUser;

    if (user == null) {
      return const Stream.empty();
    }

    return supabase
        .from('notifications')
        .stream(primaryKey: ['notification_id'])
        .eq('user_id', user.id)
        .map((rows) {
          return rows.where((notification) {
            return notification['is_read'] == false;
          }).toList();
        });
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

  Future<void> loadTodaySchedule() async {
    final user = supabase.auth.currentUser;

    if (user == null) return;

    if (mounted) {
      setState(() {
        isScheduleLoading = true;
      });
    }

    try {
      final response = await supabase
          .from('work_schedules')
          .select()
          .eq('staff_id', user.id)
          .eq('schedule_date', todayText)
          .order('shift_type', ascending: true);

      if (!mounted) return;

      setState(() {
        todaySchedules = List<Map<String, dynamic>>.from(response);
        isScheduleLoading = false;
      });
    } catch (e) {
      debugPrint('Failed to load today schedule: $e');
      if (!mounted) return;
      setState(() {
        isScheduleLoading = false;
      });
    }
  }

  Future<void> refreshHome() async {
    await Future.wait([
      loadProfileSummary(),
      loadTodaySchedule(),
    ]);
  }

  Future<void> logout(BuildContext context) async {
    await supabase.auth.signOut();

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
    ).then((_) => refreshHome());
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
    if (role.trim().isEmpty) return 'Staff';
    return role[0].toUpperCase() + role.substring(1);
  }

  String formatValue(String value) {
    return value
        .replaceAll('_', ' ')
        .split(' ')
        .where((part) => part.trim().isNotEmpty)
        .map((part) => part[0].toUpperCase() + part.substring(1))
        .join(' ');
  }

  String getShiftText(Map<String, dynamic> schedule) {
    return formatValue((schedule['shift_type'] ?? 'shift').toString());
  }

  String getDutyText(Map<String, dynamic> schedule) {
    return formatValue((schedule['duty_type'] ?? 'general operation').toString());
  }

  String getStatusText(Map<String, dynamic> schedule) {
    return formatValue((schedule['status'] ?? 'assigned').toString());
  }

  String getPageTitle() {
    switch (currentIndex) {
      case 0:
        return 'Staff Dashboard';
      case 1:
        return 'SOP';
      case 2:
        return 'Daily Stock Count';
      case 3:
        return 'Profile';
      default:
        return 'Staff Dashboard';
    }
  }

  String getPageSubtitle() {
    switch (currentIndex) {
      case 0:
        return 'View schedule, complete checklist and count stock';
      case 1:
        return 'View cafe operation guide and recipe standard';
      case 2:
        return 'Submit opening and closing stock count';
      case 3:
        return 'Your staff profile';
      default:
        return 'View schedule, complete checklist and count stock';
    }
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

  Widget buildProfileAvatar({double radius = 38}) {
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

  Widget buildNotificationButton() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: getUnreadNotificationStream(),
      builder: (context, snapshot) {
        final unreadCount = snapshot.data?.length ?? 0;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              tooltip: 'Notifications',
              onPressed: () {
                openPage(const NotificationPage());
              },
              icon: const Icon(
                Icons.notifications_outlined,
                color: cream,
              ),
            ),
            if (unreadCount > 0)
              Positioned(
                right: 10,
                top: 9,
                child: Container(
                  height: 10,
                  width: 10,
                  decoration: BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: cream,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget buildHeader() {
    final bool isHomePage = currentIndex == 0;

    return Container(
      width: double.infinity,
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
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            10,
            16,
            isHomePage ? 24 : 16,
          ),
          child: Column(
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      onPressed: () {
                        scaffoldKey.currentState?.openDrawer();
                      },
                      icon: const Icon(
                        Icons.menu,
                        color: cream,
                      ),
                    ),
                  ),
                  buildLogo(
                    size: isHomePage ? 64 : 50,
                    scale: 1.55,
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: buildNotificationButton(),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (isHomePage) ...[
                Text(
                  'Welcome, $displayName',
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: cream,
                    fontFamily: 'Georgia',
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'View today schedule, complete checklist and count stock.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: creamDark,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    height: 1.3,
                  ),
                ),
              ] else ...[
                Text(
                  getPageTitle(),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: cream,
                    fontFamily: 'Georgia',
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  getPageSubtitle(),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: creamDark,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
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
              icon: Icons.menu_book,
              title: 'SOP',
              onTap: () {
                Navigator.pop(context);
                setState(() {
                  currentIndex = 1;
                });
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
            buildDrawerItem(
              icon: Icons.history,
              title: 'History Log',
              onTap: () {
                Navigator.pop(context);
                openPage(const HistoryLogPage());
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
      leading: CircleAvatar(
        radius: 18,
        backgroundColor: mulberry.withOpacity(0.10),
        child: Icon(
          icon,
          color: mulberry,
          size: 20,
        ),
      ),
      title: Text(
        title,
        style: const TextStyle(
          color: mulberryDark,
          fontWeight: FontWeight.w700,
        ),
      ),
      trailing: Icon(
        Icons.chevron_right,
        color: Colors.grey.shade500,
      ),
      onTap: onTap,
    );
  }

  Widget buildHomeDashboard() {
    return RefreshIndicator(
      color: mulberry,
      onRefresh: refreshHome,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 95),
        children: [
          buildSectionTitle(
            title: 'Today Schedule',
            subtitle: 'Your assigned shift and duty for today',
          ),
          const SizedBox(height: 12),
          buildScheduleSection(),
          const SizedBox(height: 20),
          buildSectionTitle(
            title: 'Operations',
            subtitle: 'Checklist, stock count and SOP reference',
          ),
          const SizedBox(height: 12),
          buildHomeMenuCard(
            icon: Icons.checklist,
            title: 'Cleaning Checklist',
            subtitle: 'Update opening, closing and weekly tasks',
            color: mulberry,
            onTap: () {
              openPage(const CleaningChecklistPage());
            },
          ),
          buildHomeMenuCard(
            icon: Icons.fact_check,
            title: 'Daily Stock Count',
            subtitle: 'Submit opening and closing stock count',
            color: Colors.green,
            onTap: () {
              setState(() {
                currentIndex = 2;
              });
            },
          ),
          buildHomeMenuCard(
            icon: Icons.menu_book,
            title: 'SOP',
            subtitle: 'View cafe operation guide and recipe standard',
            color: Colors.orange,
            onTap: () {
              setState(() {
                currentIndex = 1;
              });
            },
          ),
          buildHomeMenuCard(
            icon: Icons.inventory_2,
            title: 'Inventory',
            subtitle: 'View current stock level and item details',
            color: Colors.blue,
            onTap: () {
              openPage(const InventoryPage());
            },
          ),
          buildHomeMenuCard(
            icon: Icons.history,
            title: 'History Log',
            subtitle: 'View inventory movement records',
            color: Colors.blueGrey,
            onTap: () {
              openPage(const HistoryLogPage());
            },
          ),
        ],
      ),
    );
  }

  Widget buildScheduleSection() {
    if (isScheduleLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(18),
          child: CircularProgressIndicator(color: mulberry),
        ),
      );
    }

    if (todaySchedules.isEmpty) {
      return buildEmptyScheduleCard(
        title: 'No schedule assigned today',
        subtitle: 'Please check with supervisor or manager if you are on duty.',
      );
    }

    return Column(
      children: todaySchedules.map(buildScheduleCard).toList(),
    );
  }

  Widget buildEmptyScheduleCard({required String title, required String subtitle}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: softWhite,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: creamDark.withOpacity(0.75)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: Colors.grey.withOpacity(0.12),
            child: const Icon(Icons.event_busy, color: Colors.grey),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: mulberryDark,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget buildScheduleCard(Map<String, dynamic> schedule) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: softWhite,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: creamDark.withOpacity(0.75)),
        boxShadow: [
          BoxShadow(
            color: mulberryDark.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: mulberry.withOpacity(0.10),
                child: const Icon(Icons.event_available, color: mulberry),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      getShiftText(schedule),
                      style: const TextStyle(
                        color: mulberryDark,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      todayText,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              buildMiniBadge(getStatusText(schedule), mulberry),
            ],
          ),
          const SizedBox(height: 13),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              buildInfoChip(Icons.assignment, 'Duty: ${getDutyText(schedule)}'),
              if ((schedule['notes'] ?? '').toString().trim().isNotEmpty)
                buildInfoChip(Icons.notes, schedule['notes'].toString()),
            ],
          ),
        ],
      ),
    );
  }

  Widget buildMiniBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget buildInfoChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: cream,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: creamDark.withOpacity(0.7)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: mulberry),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              text,
              style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildSectionTitle({required String title, required String subtitle}) {
    return Row(
      children: [
        Container(
          width: 5,
          height: 38,
          decoration: BoxDecoration(
            color: mulberry,
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: mulberryDark,
                  fontFamily: 'Georgia',
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget buildHomeMenuCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 13),
      decoration: BoxDecoration(
        color: softWhite,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: creamDark.withOpacity(0.75)),
        boxShadow: [
          BoxShadow(
            color: mulberryDark.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(14),
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.12),
          child: Icon(icon, color: color),
        ),
        title: Text(
          title,
          style: const TextStyle(
            color: mulberryDark,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(color: Colors.grey.shade600),
        ),
        trailing: Icon(
          Icons.arrow_forward_ios,
          size: 16,
          color: Colors.grey.shade500,
        ),
        onTap: onTap,
      ),
    );
  }

  Widget buildCurrentPage() {
    switch (currentIndex) {
      case 0:
        return buildHomeDashboard();
      case 1:
        return const RecipeVaultPage(showAppBar: false);
      case 2:
        return const DailyStockCountPage(showAppBar: false);
      case 3:
        return const ProfilePage(showAppBar: false);
      default:
        return buildHomeDashboard();
    }
  }

  BottomNavigationBarItem navItem({required IconData icon, required String label}) {
    return BottomNavigationBarItem(icon: Icon(icon), label: label);
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
          Expanded(child: buildCurrentPage()),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: softWhite,
          border: Border(
            top: BorderSide(color: creamDark.withOpacity(0.9), width: 1),
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
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
          onTap: (index) {
            setState(() {
              currentIndex = index;
            });
            refreshHome();
          },
          items: [
            navItem(icon: Icons.home_outlined, label: 'Home'),
            navItem(icon: Icons.menu_book, label: 'SOP'),
            navItem(icon: Icons.fact_check, label: 'Stock'),
            navItem(icon: Icons.person_outline, label: 'Profile'),
          ],
        ),
      ),
    );
  }
}
