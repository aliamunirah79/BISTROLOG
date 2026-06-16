import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'task_approval_page.dart';
import 'profile_page.dart';
import 'staff_list.dart';
import 'reports_page.dart';
import 'recipe_vault.dart';
import 'stock_in_page.dart';
import 'stock_take_page.dart';

class ManagerHome extends StatefulWidget {
  const ManagerHome({super.key});

  @override
  State<ManagerHome> createState() => _ManagerHomeState();
}

class _ManagerHomeState extends State<ManagerHome> {
  final supabase = Supabase.instance.client;

  static const Color mulberry = Color(0xFF6D2B50);
  static const Color mulberryDark = Color(0xFF4A1A35);
  static const Color mulberryLight = Color(0xFF8B3D68);
  static const Color cream = Color(0xFFF5ECD7);
  static const Color creamDark = Color(0xFFE8D5B5);

  int _currentIndex = 0;

  String fullName = '';
  int pendingCount = 0;
  int completedCount = 0;
  int staffCount = 0;
  int recipesCount = 0;
  int lowStockCount = 0;
  int totalProducts = 0;
  int stockInToday = 0;
  int stockTakeToday = 0;

  @override
  void initState() {
    super.initState();
    loadMetrics();
    loadUserName();
  }

  Future<void> refreshAll() async {
    await loadUserName();
    await loadMetrics();
  }

  Future<void> loadUserName() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    try {
      final profile = await supabase
          .from('profiles')
          .select('full_name, username')
          .eq('id', user.id)
          .maybeSingle();

      if (!mounted) return;

      setState(() {
        fullName = profile?['full_name']?.toString().trim().isNotEmpty == true
            ? profile!['full_name'].toString()
            : profile?['username']?.toString() ?? '';
      });
    } catch (e) {
      debugPrint('Load manager name error: $e');
      if (!mounted) return;
      setState(() => fullName = '');
    }
  }

  Future<void> loadMetrics() async {
    try {
      int pendingC = 0;
      int completedC = 0;
      int staffC = 0;
      int recipesC = 0;
      int lowStockC = 0;
      int totalProductC = 0;

      // Pending Tasks dan Completed Today ikut DAILY TASK sahaja.
      // Parent task seperti Opening/Closing tidak dikira sebagai task.
      // Weekly task juga tidak dikira dalam Pending Tasks dashboard manager.
      try {
        final taskData = await supabase
            .from('task')
            .select('task_id, parent_task_id, frequency, done, completed_at');

        final tasks = List<Map<String, dynamic>>.from(taskData);

        final parentTasks = tasks.where((task) {
          return task['parent_task_id'] == null;
        }).toList();

        final dailyParentIds = parentTasks.where((task) {
          return (task['frequency'] ?? '').toString().toUpperCase() == 'DAILY';
        }).map((task) {
          return task['task_id'];
        }).toSet();

        final dailyChildTasks = tasks.where((task) {
          return task['parent_task_id'] != null &&
              dailyParentIds.contains(task['parent_task_id']);
        }).toList();

        pendingC = dailyChildTasks.where((task) {
          return task['done'] != true;
        }).length;

        final now = DateTime.now();
        final todayStart = DateTime(now.year, now.month, now.day);
        final tomorrowStart = todayStart.add(const Duration(days: 1));

        completedC = dailyChildTasks.where((task) {
          if (task['done'] != true) return false;

          final completedAtValue = task['completed_at'];
          if (completedAtValue == null) return false;

          try {
            final completedAt =
                DateTime.parse(completedAtValue.toString()).toLocal();

            return completedAt.isAtSameMomentAs(todayStart) ||
                (completedAt.isAfter(todayStart) &&
                    completedAt.isBefore(tomorrowStart));
          } catch (_) {
            return false;
          }
        }).length;
      } catch (e) {
        debugPrint('Manager task metrics error: $e');
        pendingC = 0;
        completedC = 0;
      }

      // Staff count
      // Use Dart filtering because role may be STAFF, staff, Staff, etc.
      try {
        final users = await supabase.from('profiles').select('id, role');

        final userList = List<Map<String, dynamic>>.from(users);

        staffC = userList.where((u) {
          final role = (u['role'] ?? '').toString().toUpperCase();
          return role == 'STAFF';
        }).length;
      } catch (_) {
        staffC = 0;
      }

      // Recipes count
      try {
        final recipes = await supabase.from('recipe').select('recipe_id');

        recipesC = (recipes as List).length;
      } catch (_) {
        recipesC = 0;
      }

      // Product and low stock count
      try {
        final products = await supabase
            .from('product')
            .select('product_id, current_stock, min_threshold');

        final productList = List<Map<String, dynamic>>.from(products);
        totalProductC = productList.length;

        lowStockC = productList.where((item) {
          final currentStock =
              int.tryParse((item['current_stock'] ?? 0).toString()) ?? 0;
          final minThreshold =
              int.tryParse((item['min_threshold'] ?? 0).toString()) ?? 0;

          return minThreshold > 0 && currentStock <= minThreshold;
        }).length;
      } catch (_) {
        lowStockC = 0;
        totalProductC = 0;
      }

      if (!mounted) return;

      setState(() {
        pendingCount = pendingC;
        completedCount = completedC;
        staffCount = staffC;
        recipesCount = recipesC;
        lowStockCount = lowStockC;
        totalProducts = totalProductC;
      });
    } catch (e) {
      debugPrint('Manager metrics load error: $e');
    }
  }

  void _openPage(Widget page) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => page),
    ).then((_) => loadMetrics());
  }

  Widget _kpiCard({
    required String title,
    required String value,
    required IconData icon,
    Color iconColor = mulberry,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
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
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: mulberryDark,
                  ),
                ),
                Text(
                  title,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _notificationItem(String text, {Color color = Colors.red}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(Icons.circle, size: 8, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: creamDark),
          boxShadow: [
            BoxShadow(
              color: mulberryDark.withOpacity(0.04),
              blurRadius: 12,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: mulberry),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: mulberryDark,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    final displayName = fullName.isEmpty ? 'Manager' : fullName;

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
          Container(
            width: 58,
            height: 58,
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
                padding: const EdgeInsets.all(10),
                child: Image.asset(
                  'logo.png',
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.restaurant,
                    size: 30,
                    color: mulberry,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'BistroLog',
                  style: TextStyle(
                    fontFamily: 'Georgia',
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: cream,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Welcome, $displayName',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    color: cream,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: refreshAll,
            icon: const Icon(Icons.refresh, color: cream),
            tooltip: 'Refresh',
          ),
        ],
      ),
    );
  }

  Widget _dashboardPage() {
    return RefreshIndicator(
      onRefresh: loadMetrics,
      color: mulberry,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Manager Dashboard',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: mulberryDark,
              fontFamily: 'Georgia',
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Monitor approvals, inventory, menu updates, and reports.',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _kpiCard(
                  title: 'Pending Tasks',
                  value: pendingCount.toString(),
                  icon: Icons.hourglass_bottom,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _kpiCard(
                  title: 'Staff',
                  value: staffCount.toString(),
                  icon: Icons.people,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _kpiCard(
                  title: 'Inventory Alerts',
                  value: lowStockCount.toString(),
                  icon: Icons.warning_amber_rounded,
                  iconColor: Colors.red,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _kpiCard(
                  title: 'Products',
                  value: totalProducts.toString(),
                  icon: Icons.inventory_2_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Text(
            'Notifications',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: mulberryDark,
            ),
          ),
          const SizedBox(height: 10),
          if (pendingCount > 0)
            _notificationItem('$pendingCount daily tasks pending'),
          if (lowStockCount > 0)
            _notificationItem('$lowStockCount products are low in stock'),
          if (completedCount > 0)
            _notificationItem(
              '$completedCount daily tasks completed today',
              color: Colors.green,
            ),
          if (pendingCount == 0 &&
              lowStockCount == 0 &&
              stockInToday == 0 &&
              stockTakeToday == 0 &&
              completedCount == 0)
            const Text('No notifications 🎉'),
          const SizedBox(height: 20),
          const Text(
            'Quick Actions',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: mulberryDark,
            ),
          ),
          const SizedBox(height: 10),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.35,
            children: [
              _actionButton(
                label: 'Task Review',
                icon: Icons.fact_check_outlined,
                onTap: () {
                  _openPage(const TaskApprovalPage());
                },
              ),
              _actionButton(
                label: 'Stock In',
                icon: Icons.add_box_outlined,
                onTap: () {
                  _openPage(const StockInPage());
                },
              ),
              _actionButton(
                label: 'Stock Take',
                icon: Icons.inventory_2_outlined,
                onTap: () {
                  _openPage(const StockTakePage());
                },
              ),
              _actionButton(
                label: 'Reports',
                icon: Icons.bar_chart,
                onTap: () {
                  _openPage(const ReportsPage());
                },
              ),
              _actionButton(
                label: 'Menu Update',
                icon: Icons.restaurant_menu,
                onTap: () {
                  _openPage(RecipeVault());
                },
              ),
              _actionButton(
                label: 'Staff',
                icon: Icons.people_alt_outlined,
                onTap: () {
                  _openPage(const StaffList());
                },
              ),
              _actionButton(
                label: 'Profile',
                icon: Icons.person_outline,
                onTap: () {
                  _openPage(const ProfilePage());
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _handleBottomNavigation(int index) {
    setState(() => _currentIndex = index);

    if (index == 0) {
      loadMetrics();
    } else if (index == 1) {
      _openPage(const StaffList());
    } else if (index == 2) {
      _openPage(const StockInPage());
    } else if (index == 3) {
      _openPage(const StockTakePage());
    } else if (index == 4) {
      _openPage(const ReportsPage());
    } else if (index == 5) {
      _openPage(const ProfilePage());
    }

    Future.delayed(const Duration(milliseconds: 250), () {
      if (mounted) {
        setState(() => _currentIndex = 0);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: cream,
      body: SafeArea(
        child: Column(
          children: [
            _header(),
            Expanded(
              child: Container(
                color: cream,
                child: _dashboardPage(),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: cream,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: _handleBottomNavigation,
          type: BottomNavigationBarType.fixed,
          backgroundColor: cream,
          selectedItemColor: mulberry,
          unselectedItemColor: Colors.grey.shade600,
          showUnselectedLabels: true,
          elevation: 0,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.dashboard),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.people),
              label: 'Staff',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.add_box_outlined),
              label: 'Stock In',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.inventory_2_outlined),
              label: 'Stock Take',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.bar_chart),
              label: 'Reports',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}