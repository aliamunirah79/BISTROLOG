import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/login_page.dart';
import '../common/profile_page.dart';
import '../common/notification_page.dart';
import '../common/inventory_page.dart';
import '../common/history_log_page.dart';
import '../common/stock_adjustment_page.dart';
import '../common/review_stock_count_page.dart';
import '../common/work_schedule_page.dart';

import 'review_checklist_page.dart';
import 'manage_recipe_page.dart';
import 'manage_inventory_item_page.dart';
import 'reports_analytics_page.dart';
import 'manage_staff_page.dart';

class ManagerHome extends StatefulWidget {
  final String fullName;

  const ManagerHome({
    super.key,
    required this.fullName,
  });

  @override
  State<ManagerHome> createState() => _ManagerHomeState();
}

class _ManagerHomeState extends State<ManagerHome> {
  final supabase = Supabase.instance.client;

  int currentIndex = 0;

  List<Map<String, dynamic>> todaySchedules = [];
  bool isScheduleLoading = true;

  static const Color mulberry = Color(0xFF6D2B50);
  static const Color mulberryDark = Color(0xFF4A1A35);
  static const Color mulberryLight = Color(0xFF8B3D68);
  static const Color cream = Color(0xFFF5ECD7);
  static const Color creamDark = Color(0xFFE8D5B5);
  static const Color softWhite = Color(0xFFFFFCF7);

  @override
  void initState() {
    super.initState();
    loadTodaySchedule();
  }

  String get todayText {
    return DateTime.now().toIso8601String().substring(0, 10);
  }

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

  Future<void> loadTodaySchedule() async {
    if (mounted) {
      setState(() {
        isScheduleLoading = true;
      });
    }

    try {
      final response = await supabase
          .from('work_schedules')
          .select('''
            schedule_id,
            staff_id,
            schedule_date,
            shift_type,
            duty_type,
            status,
            notes,
            profiles:staff_id (
              id,
              full_name,
              role,
              avatar_url
            )
          ''')
          .eq('schedule_date', todayText)
          .order('shift_type', ascending: true);

      if (!mounted) return;

      setState(() {
        todaySchedules = List<Map<String, dynamic>>.from(response);
        isScheduleLoading = false;
      });
    } catch (e) {
      debugPrint('Failed to load schedule overview: $e');

      if (!mounted) return;

      setState(() {
        isScheduleLoading = false;
      });
    }
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

  String formatValue(String value) {
    final cleaned = value.trim();

    if (cleaned.isEmpty) {
      return '-';
    }

    return cleaned
        .replaceAll('_', ' ')
        .split(' ')
        .where((part) => part.trim().isNotEmpty)
        .map((part) => part[0].toUpperCase() + part.substring(1))
        .join(' ');
  }

  Map<String, dynamic>? getScheduleProfile(Map<String, dynamic> schedule) {
    final profile = schedule['profiles'];

    if (profile is Map<String, dynamic>) {
      return profile;
    }

    if (profile is Map) {
      return Map<String, dynamic>.from(profile);
    }

    return null;
  }

  String getStaffName(Map<String, dynamic> schedule) {
    final profile = getScheduleProfile(schedule);

    if (profile != null && profile['full_name'] != null) {
      final name = profile['full_name'].toString().trim();

      if (name.isNotEmpty) {
        return name;
      }
    }

    return 'Assigned Staff';
  }

  String getStaffRole(Map<String, dynamic> schedule) {
    final profile = getScheduleProfile(schedule);

    if (profile != null && profile['role'] != null) {
      return formatValue(profile['role'].toString());
    }

    return 'Staff';
  }

  String getStaffAvatarUrl(Map<String, dynamic> schedule) {
    final profile = getScheduleProfile(schedule);

    if (profile != null && profile['avatar_url'] != null) {
      return profile['avatar_url'].toString().trim();
    }

    return '';
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
        return 'Manager Dashboard';
      case 1:
        return 'Manage Recipes';
      case 2:
        return 'Manage Staff';
      case 3:
        return 'Inventory';
      case 4:
        return 'Profile';
      default:
        return 'Manager Dashboard';
    }
  }

  String getPageSubtitle() {
    switch (currentIndex) {
      case 0:
        return 'Overview of cafe operations';
      case 1:
        return 'Recipe control and cafe menu';
      case 2:
        return 'Staff roles and profile status';
      case 3:
        return 'Stock level and movement history';
      case 4:
        return 'Your manager profile';
      default:
        return 'Overview of cafe operations';
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

  Widget buildTopHeader() {
    final isHome = currentIndex == 0;

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
            isHome ? 24 : 16,
          ),
          child: Column(
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Builder(
                      builder: (context) {
                        return IconButton(
                          onPressed: () {
                            Scaffold.of(context).openDrawer();
                          },
                          icon: const Icon(
                            Icons.menu,
                            color: cream,
                          ),
                        );
                      },
                    ),
                  ),
                  buildLogo(size: isHome ? 64 : 50),
                  Align(
                    alignment: Alignment.centerRight,
                    child: buildNotificationButton(),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (isHome) ...[
                Text(
                  'Welcome, ${widget.fullName}',
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
                  'Monitor schedule, staff, inventory and cafe operations.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: creamDark,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
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

  Widget buildCurrentPage() {
    switch (currentIndex) {
      case 0:
        return buildHomeDashboard();
      case 1:
        return const ManageRecipePage(showAppBar: false);
      case 2:
        return const ManageStaffPage(showAppBar: false);
      case 3:
        return const InventoryPage(showAppBar: false);
      case 4:
        return const ProfilePage(showAppBar: false);
      default:
        return buildHomeDashboard();
    }
  }

  Widget buildHomeDashboard() {
    return RefreshIndicator(
      color: mulberry,
      onRefresh: loadTodaySchedule,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 90),
        children: [
          buildSectionTitle(
            title: 'Today Schedule Overview',
            subtitle: 'Staff on duty and assigned operation duties',
          ),
          const SizedBox(height: 12),
          buildScheduleSection(),
          const SizedBox(height: 20),
          buildSectionTitle(
            title: 'Operations',
            subtitle: 'Review, schedule and reporting tools',
          ),
          const SizedBox(height: 12),
          buildHomeMenuCard(
            icon: Icons.calendar_month,
            title: 'Work Schedule',
            subtitle: 'Assign staff shift and duty rotation',
            color: Colors.blue,
            onTap: () {
              openPage(const WorkSchedulePage());
            },
          ),
          buildHomeMenuCard(
            icon: Icons.people,
            title: 'Manage Staff',
            subtitle: 'Activate, edit and manage staff profile',
            color: Colors.teal,
            onTap: () {
              setState(() {
                currentIndex = 2;
              });
            },
          ),
          buildHomeMenuCard(
            icon: Icons.restaurant_menu,
            title: 'Manage Recipes',
            subtitle: 'Add, update and manage recipe standard',
            color: Colors.green,
            onTap: () {
              setState(() {
                currentIndex = 1;
              });
            },
          ),
          buildHomeMenuCard(
            icon: Icons.edit_note,
            title: 'Manage Inventory Items',
            subtitle: 'Register item, barcode and minimum stock',
            color: mulberry,
            onTap: () {
              openPage(const ManageInventoryItemPage());
            },
          ),
          buildHomeMenuCard(
            icon: Icons.checklist,
            title: 'Review Checklist',
            subtitle: 'Approve or reject submitted cleaning tasks',
            color: Colors.indigo,
            onTap: () {
              openPage(const ReviewChecklistPage());
            },
          ),
          buildHomeMenuCard(
            icon: Icons.verified,
            title: 'Review Stock Count',
            subtitle: 'Review daily stock usage and deduction',
            color: Colors.green,
            onTap: () {
              openPage(const ReviewStockCountPage());
            },
          ),
          buildHomeMenuCard(
            icon: Icons.qr_code_scanner,
            title: 'Stock Adjustment',
            subtitle: 'Add stock, correct stock and record movements',
            color: Colors.orange,
            onTap: () {
              openPage(const StockAdjustmentPage());
            },
          ),
          buildHomeMenuCard(
            icon: Icons.history,
            title: 'History Log',
            subtitle: 'View inventory changes and stock movements',
            color: Colors.blueGrey,
            onTap: () {
              openPage(const HistoryLogPage());
            },
          ),
          buildHomeMenuCard(
            icon: Icons.bar_chart,
            title: 'Reports & Analytics',
            subtitle: 'View checklist and inventory reports',
            color: Colors.deepPurple,
            onTap: () {
              openPage(const ReportsAnalyticsPage());
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
          child: CircularProgressIndicator(
            color: mulberry,
          ),
        ),
      );
    }

    if (todaySchedules.isEmpty) {
      return buildEmptyScheduleCard(
        title: 'No schedule generated today',
        subtitle: 'Use Work Schedule to assign staff duty rotation.',
      );
    }

    return Column(
      children: todaySchedules.map(buildScheduleCard).toList(),
    );
  }

  Widget buildEmptyScheduleCard({
    required String title,
    required String subtitle,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: softWhite,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: creamDark.withOpacity(0.75),
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: Colors.grey.withOpacity(0.12),
            child: const Icon(
              Icons.event_busy,
              color: Colors.grey,
            ),
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
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget buildScheduleCard(Map<String, dynamic> schedule) {
    final avatarUrl = getStaffAvatarUrl(schedule);
    final hasAvatar = avatarUrl.trim().isNotEmpty;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: softWhite,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: creamDark.withOpacity(0.75),
        ),
        boxShadow: [
          BoxShadow(
            color: mulberryDark.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 25,
            backgroundColor: creamDark,
            backgroundImage: hasAvatar ? NetworkImage(avatarUrl) : null,
            child: hasAvatar
                ? null
                : const Icon(
                    Icons.person,
                    color: mulberry,
                  ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  getStaffName(schedule),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: mulberryDark,
                    fontWeight: FontWeight.bold,
                    fontSize: 15.8,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  getStaffRole(schedule),
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 9),
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: [
                    buildScheduleBadge(
                      icon: Icons.access_time,
                      text: getShiftText(schedule),
                      color: Colors.blue,
                    ),
                    buildScheduleBadge(
                      icon: Icons.assignment,
                      text: getDutyText(schedule),
                      color: mulberry,
                    ),
                    buildScheduleBadge(
                      icon: Icons.check_circle,
                      text: getStatusText(schedule),
                      color: Colors.green,
                    ),
                    if ((schedule['notes'] ?? '').toString().trim().isNotEmpty)
                      buildScheduleBadge(
                        icon: Icons.notes,
                        text: schedule['notes'].toString(),
                        color: Colors.orange,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget buildScheduleBadge({
    required IconData icon,
    required String text,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 13,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 10.8,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget buildMiniBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 5,
      ),
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
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: cream,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: creamDark.withOpacity(0.7),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: mulberry,
          ),
          const SizedBox(width: 5),
          Text(
            text,
            style: TextStyle(
              color: Colors.grey.shade700,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget buildSectionTitle({
    required String title,
    required String subtitle,
  }) {
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
        border: Border.all(
          color: creamDark.withOpacity(0.75),
        ),
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
          child: Icon(
            icon,
            color: color,
          ),
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
          style: TextStyle(
            color: Colors.grey.shade600,
          ),
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

  void openPage(Widget page) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => page),
    ).then((_) => loadTodaySchedule());
  }

  Widget buildDrawer() {
    return Drawer(
      backgroundColor: cream,
      child: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
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
              child: Row(
                children: [
                  buildLogo(size: 54),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'BISTROLOG',
                          style: TextStyle(
                            color: cream,
                            fontFamily: 'Georgia',
                            fontSize: 19,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.fullName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: creamDark,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Manager',
                          style: TextStyle(
                            color: creamDark,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 10),
                children: [
                  buildDrawerItem(
                    icon: Icons.home,
                    title: 'Home',
                    onTap: () {
                      Navigator.pop(context);
                      setState(() {
                        currentIndex = 0;
                      });
                    },
                  ),
                  buildDrawerItem(
                    icon: Icons.restaurant_menu,
                    title: 'Manage Recipes',
                    onTap: () {
                      Navigator.pop(context);
                      setState(() {
                        currentIndex = 1;
                      });
                    },
                  ),
                  buildDrawerItem(
                    icon: Icons.people,
                    title: 'Manage Staff',
                    onTap: () {
                      Navigator.pop(context);
                      setState(() {
                        currentIndex = 2;
                      });
                    },
                  ),
                  buildDrawerItem(
                    icon: Icons.inventory_2,
                    title: 'Inventory',
                    onTap: () {
                      Navigator.pop(context);
                      setState(() {
                        currentIndex = 3;
                      });
                    },
                  ),
                  buildDrawerItem(
                    icon: Icons.person,
                    title: 'Profile',
                    onTap: () {
                      Navigator.pop(context);
                      setState(() {
                        currentIndex = 4;
                      });
                    },
                  ),
                  const Divider(height: 22),
                  buildDrawerItem(
                    icon: Icons.calendar_month,
                    title: 'Work Schedule',
                    onTap: () {
                      Navigator.pop(context);
                      openPage(const WorkSchedulePage());
                    },
                  ),
                  buildDrawerItem(
                    icon: Icons.checklist,
                    title: 'Review Checklist',
                    onTap: () {
                      Navigator.pop(context);
                      openPage(const ReviewChecklistPage());
                    },
                  ),
                  buildDrawerItem(
                    icon: Icons.verified,
                    title: 'Review Stock Count',
                    onTap: () {
                      Navigator.pop(context);
                      openPage(const ReviewStockCountPage());
                    },
                  ),
                  buildDrawerItem(
                    icon: Icons.edit_note,
                    title: 'Manage Inventory Items',
                    onTap: () {
                      Navigator.pop(context);
                      openPage(const ManageInventoryItemPage());
                    },
                  ),
                  buildDrawerItem(
                    icon: Icons.qr_code_scanner,
                    title: 'Stock Adjustment',
                    onTap: () {
                      Navigator.pop(context);
                      openPage(const StockAdjustmentPage());
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
                  buildDrawerItem(
                    icon: Icons.bar_chart,
                    title: 'Reports & Analytics',
                    onTap: () {
                      Navigator.pop(context);
                      openPage(const ReportsAnalyticsPage());
                    },
                  ),
                  buildDrawerItem(
                    icon: Icons.notifications,
                    title: 'Notifications',
                    onTap: () {
                      Navigator.pop(context);
                      openPage(const NotificationPage());
                    },
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => logout(context),
                  icon: const Icon(Icons.logout),
                  label: const Text('Logout'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
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

  BottomNavigationBarItem buildNavItem({
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
      backgroundColor: cream,
      drawer: buildDrawer(),
      body: Column(
        children: [
          buildTopHeader(),
          Expanded(
            child: buildCurrentPage(),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: softWhite,
          boxShadow: [
            BoxShadow(
              color: mulberryDark.withOpacity(0.10),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: currentIndex,
          onTap: (index) {
            setState(() {
              currentIndex = index;
            });

            loadTodaySchedule();
          },
          type: BottomNavigationBarType.fixed,
          backgroundColor: softWhite,
          selectedItemColor: mulberry,
          unselectedItemColor: Colors.grey.shade500,
          selectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
          unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 11,
          ),
          elevation: 0,
          items: [
            buildNavItem(
              icon: Icons.home_rounded,
              label: 'Home',
            ),
            buildNavItem(
              icon: Icons.restaurant_menu,
              label: 'Recipe',
            ),
            buildNavItem(
              icon: Icons.people,
              label: 'Staff',
            ),
            buildNavItem(
              icon: Icons.inventory_2,
              label: 'Inventory',
            ),
            buildNavItem(
              icon: Icons.person,
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}
