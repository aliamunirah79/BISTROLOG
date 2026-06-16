import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'task_page.dart';
import 'recipe_vault.dart';
import 'stock_in_page.dart';
import 'stock_take_page.dart';
import 'profile_page.dart';

class SupervisorHome extends StatefulWidget {
  const SupervisorHome({super.key});

  @override
  State<SupervisorHome> createState() => _SupervisorHomeState();
}

class _SupervisorHomeState extends State<SupervisorHome> {
  final supabase = Supabase.instance.client;

  static const Color mulberry = Color(0xFF6D2B50);
  static const Color mulberryDark = Color(0xFF4A1A35);
  static const Color mulberryLight = Color(0xFF8B3D68);
  static const Color cream = Color(0xFFF5ECD7);
  static const Color creamDark = Color(0xFFE8D5B5);

  int _currentIndex = 0;

  String fullName = '';
  int pendingTasks = 0;
  int completedToday = 0;
  int lowStockCount = 0;

  @override
  void initState() {
    super.initState();
    loadUserName();
    loadMetrics();
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
      debugPrint('Load supervisor name error: $e');
    }
  }

  Future<void> loadMetrics() async {
    int pending = 0;
    int completed = 0;
    int lowStock = 0;

    try {
      final taskData = await supabase
          .from('task')
          .select('task_id, parent_task_id, done, completed_at');

      final tasks = List<Map<String, dynamic>>.from(taskData);

      // Kira subtask sahaja. Parent seperti Opening/Closing/Weekly Cleaning tidak dikira.
      final childTasks = tasks.where((task) {
        return task['parent_task_id'] != null;
      }).toList();

      pending = childTasks.where((task) {
        return task['done'] != true;
      }).length;

      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final tomorrowStart = todayStart.add(const Duration(days: 1));

      completed = childTasks.where((task) {
        if (task['done'] != true) return false;

        final completedAtValue = task['completed_at'];
        if (completedAtValue == null) return false;

        try {
          final completedAt =
              DateTime.parse(completedAtValue.toString()).toLocal();

          return completedAt.isAtSameMomentAs(todayStart) ||
              (completedAt.isAfter(todayStart) &&
                  completedAt.isBefore(tomorrowStart));
        } catch (e) {
          debugPrint('Completed date parse error: $e');
          return false;
        }
      }).length;
    } catch (e) {
      debugPrint('Supervisor task metrics error: $e');
    }

    try {
      final productData = await supabase
          .from('product')
          .select('product_id, current_stock, min_threshold');

      final products = List<Map<String, dynamic>>.from(productData);

      lowStock = products.where((item) {
        final currentStock =
            double.tryParse((item['current_stock'] ?? 0).toString()) ?? 0;
        final minThreshold =
            double.tryParse((item['min_threshold'] ?? 0).toString()) ?? 0;

        return minThreshold > 0 && currentStock <= minThreshold;
      }).length;
    } catch (e) {
      debugPrint('Supervisor low stock metrics error: $e');
    }

    if (!mounted) return;

    setState(() {
      pendingTasks = pending;
      completedToday = completed;
      lowStockCount = lowStock;
    });
  }

  Future<void> refreshAll() async {
    await loadUserName();
    await loadMetrics();
  }

  Future<bool> _onWillPop() async {
    if (_currentIndex != 0) {
      setState(() {
        _currentIndex = 0;
      });

      await refreshAll();
      return false;
    }

    return true;
  }

  bool get _showHomeHeader {
    // Task dan Notification sahaja tunjuk welcome header.
    // Recipe, Stock In, Stock Take, Profile guna layout sendiri.
    return _currentIndex == 0 || _currentIndex == 4;
  }

  Widget _currentPage() {
    switch (_currentIndex) {
      case 0:
        return TaskPage(
          onTaskUpdated: refreshAll,
        );
      case 1:
        return const RecipeVault();
      case 2:
        return const StockInPage();
      case 3:
        return const StockTakePage();
      case 4:
        return _buildNotificationPage();
      case 5:
        return const ProfilePage();
      default:
        return TaskPage(
          onTaskUpdated: refreshAll,
        );
    }
  }

  Widget _buildHeader() {
    final displayName = fullName.isEmpty ? 'Supervisor' : fullName;

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
      child: Column(
        children: [
          Row(
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
                        decoration: TextDecoration.none,
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
                        decoration: TextDecoration.none,
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
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _summaryCard(
                  title: 'Pending Daily',
                  value: pendingTasks.toString(),
                  icon: Icons.assignment_late_outlined,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _summaryCard(
                  title: 'Completed Today',
                  value: completedToday.toString(),
                  icon: Icons.task_alt_outlined,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _summaryCard(
                  title: 'Low Stock',
                  value: lowStockCount.toString(),
                  icon: Icons.warning_amber_rounded,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryCard({
    required String title,
    required String value,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.14),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.18)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: cream.withOpacity(0.16),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: cream,
              size: 18,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: cream,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              decoration: TextDecoration.none,
            ),
          ),
          Text(
            title,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: cream,
              fontSize: 11,
              fontWeight: FontWeight.w500,
              decoration: TextDecoration.none,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationPage() {
    final hasNotifications = pendingTasks > 0 || lowStockCount > 0;

    return RefreshIndicator(
      onRefresh: refreshAll,
      color: mulberry,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Notifications',
            style: TextStyle(
              fontFamily: 'Georgia',
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: mulberryDark,
              decoration: TextDecoration.none,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Task and inventory alerts will appear here.',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade700,
              decoration: TextDecoration.none,
            ),
          ),
          const SizedBox(height: 18),
          if (!hasNotifications)
            _notificationCard(
              icon: Icons.notifications_none,
              title: 'No notifications',
              subtitle: 'Everything looks good.',
              color: Colors.grey,
            )
          else ...[
            if (pendingTasks > 0)
              _notificationCard(
                icon: Icons.assignment_late_outlined,
                title: '$pendingTasks pending task(s)',
                subtitle: 'Some tasks are not completed yet.',
                color: mulberry,
              ),
            if (lowStockCount > 0)
              _notificationCard(
                icon: Icons.warning_amber_rounded,
                title: '$lowStockCount low stock item(s)',
                subtitle: 'Some products are below minimum threshold.',
                color: Colors.red,
              ),
          ],
        ],
      ),
    );
  }

  Widget _notificationCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
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
          Icon(icon, color: color),
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
                    decoration: TextDecoration.none,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontSize: 12,
                    decoration: TextDecoration.none,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  BottomNavigationBarItem _navItem({
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
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: cream,
        body: SafeArea(
          child: Column(
            children: [
              if (_showHomeHeader) _buildHeader(),
              Expanded(
                child: _currentPage(),
              ),
            ],
          ),
        ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _currentIndex,
          type: BottomNavigationBarType.fixed,
          backgroundColor: cream,
          selectedItemColor: mulberry,
          unselectedItemColor: Colors.grey.shade600,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });

            refreshAll();
          },
          items: [
            _navItem(icon: Icons.check_box, label: 'Task'),
            _navItem(icon: Icons.menu_book, label: 'Recipe'),
            _navItem(icon: Icons.add_box_outlined, label: 'Stock In'),
            _navItem(icon: Icons.inventory_2_outlined, label: 'Stock Take'),
            _navItem(icon: Icons.notifications, label: 'Noti'),
            _navItem(icon: Icons.person, label: 'Profile'),
          ],
        ),
      ),
    );
  }
}