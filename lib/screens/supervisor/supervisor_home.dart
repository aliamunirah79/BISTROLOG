import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/login_page.dart';
import '../common/recipe_vault_page.dart';
import '../common/cleaning_checklist_page.dart';
import '../common/profile_page.dart';
import '../common/notification_page.dart';
import '../common/inventory_page.dart';
import '../common/history_log_page.dart';
import '../common/daily_stock_count_page.dart';
import '../common/stock_adjustment_page.dart';
import '../common/work_schedule_page.dart';
import '../common/review_stock_count_page.dart';

class SupervisorHome extends StatefulWidget {
  final String fullName;

  const SupervisorHome({
    super.key,
    required this.fullName,
  });

  @override
  State<SupervisorHome> createState() => _SupervisorHomeState();
}

class _SupervisorHomeState extends State<SupervisorHome> {
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
      debugPrint('Failed to load supervisor schedule: $e');

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
        return 'Supervisor Dashboard';
      case 1:
        return 'Cleaning Checklist';
      case 2:
        return 'Daily Stock Count';
      case 3:
        return 'Inventory';
      case 4:
        return 'Profile';
      default:
        return 'Supervisor Dashboard';
    }
  }

  String getPageSubtitle() {
    switch (currentIndex) {
      case 0:
        return 'Monitor schedule, stock and daily operations';
      case 1:
        return 'Opening, closing and weekly tasks';
      case 2:
        return 'Submit daily stock count';
      case 3:
        return 'Current stock and movement history';
      case 4:
        return 'Your supervisor profile';
      default:
        return 'Monitor schedule, stock and daily operations';
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
                  'Monitor today schedule, stock count and operation tasks.',
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
        return const CleaningChecklistPage(showAppBar: false);
      case 2:
        return const DailyStockCountPage(showAppBar: false);
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
            title: 'Today Schedule',
            subtitle: 'Your assigned shift and duty for today',
          ),
          const SizedBox(height: 12),
          buildScheduleSection(),
          const SizedBox(height: 20),
          buildSectionTitle(
            title: 'Supervisor Modules',
            subtitle: 'Grouped tools for easier navigation',
          ),
          const SizedBox(height: 12),
          buildHomeMenuCard(
            icon: Icons.checklist_rounded,
            title: 'Checklist Operations',
            subtitle: 'Update cleaning tasks and view SOP references',
            color: mulberry,
            onTap: openChecklistOperations,
          ),
          buildHomeMenuCard(
            icon: Icons.inventory_2_rounded,
            title: 'Stock Operations',
            subtitle: 'Submit stock count, adjust stock and review records',
            color: Colors.orange,
            onTap: openStockOperations,
          ),
          buildHomeMenuCard(
            icon: Icons.event_note_rounded,
            title: 'Schedule & SOP',
            subtitle: 'View work schedule and operation standards',
            color: Colors.indigo,
            onTap: openScheduleAndSop,
          ),
        ],
      ),
    );
  }

  void openChecklistOperations() {
    openPage(
      SupervisorModulePage(
        title: 'Checklist Operations',
        subtitle: 'Update cleaning checklist and access operation SOP',
        icon: Icons.checklist_rounded,
        color: mulberry,
        items: [
          SupervisorModuleItem(
            icon: Icons.checklist_rounded,
            title: 'Cleaning Checklist',
            subtitle: 'Update opening, closing and weekly cleaning tasks',
            color: mulberry,
            useBottomTabIndex: 1,
          ),
          SupervisorModuleItem(
            icon: Icons.menu_book_rounded,
            title: 'SOP',
            subtitle: 'View cafe operation guide and recipe standard',
            color: Colors.blue,
            page: const RecipeVaultPage(),
          ),
        ],
        onOpenBottomTab: (index) {
          Navigator.pop(context);
          setState(() {
            currentIndex = index;
          });
        },
      ),
    );
  }

  void openStockOperations() {
    openPage(
      SupervisorModulePage(
        title: 'Stock Operations',
        subtitle: 'Manage daily stock count, adjustment and inventory records',
        icon: Icons.inventory_2_rounded,
        color: Colors.orange,
        items: [
          SupervisorModuleItem(
            icon: Icons.fact_check_rounded,
            title: 'Daily Stock Count',
            subtitle: 'Submit opening and closing stock count',
            color: Colors.green,
            useBottomTabIndex: 2,
          ),
          SupervisorModuleItem(
            icon: Icons.inventory_2_rounded,
            title: 'Inventory',
            subtitle: 'View current stock level and stock availability',
            color: Colors.orange,
            useBottomTabIndex: 3,
          ),
          SupervisorModuleItem(
            icon: Icons.qr_code_scanner_rounded,
            title: 'Stock Adjustment',
            subtitle: 'Scan barcode, add stock and correct stock quantity',
            color: Colors.deepOrange,
            page: const StockAdjustmentPage(),
          ),
          SupervisorModuleItem(
            icon: Icons.verified_rounded,
            title: 'Review Stock Count',
            subtitle: 'Review submitted stock usage and deduction records',
            color: Colors.teal,
            page: const ReviewStockCountPage(),
          ),
          SupervisorModuleItem(
            icon: Icons.history_rounded,
            title: 'History Log',
            subtitle: 'View inventory changes and stock movements',
            color: Colors.blueGrey,
            page: const HistoryLogPage(),
          ),
        ],
        onOpenBottomTab: (index) {
          Navigator.pop(context);
          setState(() {
            currentIndex = index;
          });
        },
      ),
    );
  }

  void openScheduleAndSop() {
    openPage(
      SupervisorModulePage(
        title: 'Schedule & SOP',
        subtitle: 'Access schedule and operation reference pages',
        icon: Icons.event_note_rounded,
        color: Colors.indigo,
        items: [
          SupervisorModuleItem(
            icon: Icons.calendar_month_rounded,
            title: 'Work Schedule',
            subtitle: 'View or assign staff duty schedule',
            color: Colors.indigo,
            page: const WorkSchedulePage(),
          ),
          SupervisorModuleItem(
            icon: Icons.menu_book_rounded,
            title: 'SOP',
            subtitle: 'View cafe operation guide and recipe standard',
            color: Colors.blue,
            page: const RecipeVaultPage(),
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
        title: 'No schedule assigned today',
        subtitle: 'Open Work Schedule to view or assign today duty.',
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
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: mulberry.withOpacity(0.10),
                child: const Icon(
                  Icons.event_available,
                  color: mulberry,
                ),
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
              buildMiniBadge(
                getStatusText(schedule),
                mulberry,
              ),
            ],
          ),
          const SizedBox(height: 13),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              buildInfoChip(
                Icons.assignment,
                'Duty: ${getDutyText(schedule)}',
              ),
              if ((schedule['notes'] ?? '').toString().trim().isNotEmpty)
                buildInfoChip(
                  Icons.notes,
                  schedule['notes'].toString(),
                ),
            ],
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
                          'Supervisor',
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
                    icon: Icons.checklist_rounded,
                    title: 'Checklist Operations',
                    onTap: () {
                      Navigator.pop(context);
                      openChecklistOperations();
                    },
                  ),
                  buildDrawerItem(
                    icon: Icons.inventory_2_rounded,
                    title: 'Stock Operations',
                    onTap: () {
                      Navigator.pop(context);
                      openStockOperations();
                    },
                  ),
                  buildDrawerItem(
                    icon: Icons.event_note_rounded,
                    title: 'Schedule & SOP',
                    onTap: () {
                      Navigator.pop(context);
                      openScheduleAndSop();
                    },
                  ),
                  const Divider(height: 22),
                  buildDrawerItem(
                    icon: Icons.checklist,
                    title: 'Cleaning Checklist',
                    onTap: () {
                      Navigator.pop(context);
                      setState(() {
                        currentIndex = 1;
                      });
                    },
                  ),
                  buildDrawerItem(
                    icon: Icons.fact_check,
                    title: 'Daily Stock Count',
                    onTap: () {
                      Navigator.pop(context);
                      setState(() {
                        currentIndex = 2;
                      });
                    },
                  ),
                  buildDrawerItem(
                    icon: Icons.inventory,
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
              icon: Icons.checklist,
              label: 'Checklist',
            ),
            buildNavItem(
              icon: Icons.fact_check,
              label: 'Stock',
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

class SupervisorModuleItem {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final Widget? page;
  final int? useBottomTabIndex;

  const SupervisorModuleItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    this.page,
    this.useBottomTabIndex,
  });
}

class SupervisorModulePage extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final List<SupervisorModuleItem> items;
  final void Function(int index)? onOpenBottomTab;

  const SupervisorModulePage({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.items,
    this.onOpenBottomTab,
  });

  static const Color mulberry = Color(0xFF6D2B50);
  static const Color mulberryDark = Color(0xFF4A1A35);
  static const Color cream = Color(0xFFF5ECD7);
  static const Color creamDark = Color(0xFFE8D5B5);
  static const Color softWhite = Color(0xFFFFFCF7);

  void openItem(BuildContext context, SupervisorModuleItem item) {
    if (item.useBottomTabIndex != null) {
      onOpenBottomTab?.call(item.useBottomTabIndex!);
      return;
    }

    if (item.page == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => item.page!),
    );
  }

  Widget buildHeader() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withOpacity(0.95),
            mulberry,
            mulberryDark,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: mulberryDark.withOpacity(0.16),
            blurRadius: 16,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 27,
            backgroundColor: cream.withOpacity(0.18),
            child: Icon(
              icon,
              color: cream,
              size: 30,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: cream,
                    fontFamily: 'Georgia',
                    fontSize: 21,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: creamDark,
                    fontWeight: FontWeight.w600,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget buildModuleCard(BuildContext context, SupervisorModuleItem item) {
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
          backgroundColor: item.color.withOpacity(0.12),
          child: Icon(
            item.icon,
            color: item.color,
          ),
        ),
        title: Text(
          item.title,
          style: const TextStyle(
            color: mulberryDark,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          item.subtitle,
          style: TextStyle(
            color: Colors.grey.shade600,
          ),
        ),
        trailing: Icon(
          Icons.arrow_forward_ios,
          size: 16,
          color: Colors.grey.shade500,
        ),
        onTap: () => openItem(context, item),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: cream,
      appBar: AppBar(
        backgroundColor: mulberry,
        foregroundColor: cream,
        elevation: 0,
        centerTitle: true,
        title: Text(
          title,
          style: const TextStyle(
            color: cream,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          buildHeader(),
          const SizedBox(height: 16),
          ...items.map((item) => buildModuleCard(context, item)),
        ],
      ),
    );
  }
}