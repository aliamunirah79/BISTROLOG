import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'cleaning_checklist_page.dart';
import 'inventory_page.dart';
import 'review_stock_count_page.dart';
import '../manager/review_checklist_page.dart';

enum NotificationDateFilter {
  all,
  today,
  last7Days,
  older,
}

class NotificationPage extends StatefulWidget {
  final bool showAppBar;

  const NotificationPage({
    super.key,
    this.showAppBar = true,
  });

  @override
  State<NotificationPage> createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage> {
  final supabase = Supabase.instance.client;

  bool showUnreadOnly = false;
  NotificationDateFilter selectedDateFilter = NotificationDateFilter.all;

  static const Color mulberry = Color(0xFF6D2B50);
  static const Color mulberryDark = Color(0xFF4A1A35);
  static const Color mulberryLight = Color(0xFF8B3D68);
  static const Color cream = Color(0xFFF5ECD7);
  static const Color creamDark = Color(0xFFE8D5B5);
  static const Color softWhite = Color(0xFFFFFCF7);

  Stream<List<Map<String, dynamic>>> getNotificationStream() {
    final user = supabase.auth.currentUser;

    if (user == null) {
      return const Stream.empty();
    }

    return supabase
        .from('notifications')
        .stream(primaryKey: ['notification_id'])
        .eq('user_id', user.id)
        .order('created_at', ascending: false);
  }

  Future<void> markAsRead(Map<String, dynamic> notification) async {
    if (notification['is_read'] == true) {
      return;
    }

    try {
      await supabase.from('notifications').update({
        'is_read': true,
      }).eq('notification_id', notification['notification_id']);
    } catch (e) {
      showMessage('Failed to mark as read: $e', isError: true);
    }
  }

  Future<void> markAsUnread(Map<String, dynamic> notification) async {
    try {
      await supabase.from('notifications').update({
        'is_read': false,
      }).eq('notification_id', notification['notification_id']);

      showMessage('Notification marked as unread.');
    } catch (e) {
      showMessage('Failed to mark as unread: $e', isError: true);
    }
  }

  Future<void> markAllAsRead() async {
    try {
      final user = supabase.auth.currentUser;

      if (user == null) {
        throw Exception('User not logged in.');
      }

      await supabase
          .from('notifications')
          .update({'is_read': true})
          .eq('user_id', user.id)
          .eq('is_read', false);

      showMessage('All notifications marked as read.');
    } catch (e) {
      showMessage('Failed to mark all as read: $e', isError: true);
    }
  }

  Future<void> deleteNotification(Map<String, dynamic> notification) async {
    try {
      await supabase
          .from('notifications')
          .delete()
          .eq('notification_id', notification['notification_id']);

      showMessage('Notification deleted.');
    } catch (e) {
      showMessage('Failed to delete notification: $e', isError: true);
    }
  }

  Future<bool> confirmDeleteNotification() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: softWhite,
          title: const Text(
            'Delete Notification?',
            style: TextStyle(
              color: mulberryDark,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            'Are you sure you want to delete this notification?',
            style: TextStyle(
              color: Colors.grey.shade800,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              style: TextButton.styleFrom(
                foregroundColor: mulberry,
              ),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    return result == true;
  }

  Future<void> handleNotificationTap(
    Map<String, dynamic> notification,
  ) async {
    await markAsRead(notification);

    final type = notification['type']?.toString().toLowerCase() ?? '';
    final title = notification['title']?.toString().toLowerCase() ?? '';
    final message = notification['message']?.toString().toLowerCase() ?? '';
    final targetPage =
        notification['target_page']?.toString().toLowerCase() ?? '';

    if (!mounted) return;

    if (targetPage == 'cleaning_checklist' ||
        (type == 'checklist' && title.contains('rejected')) ||
        title.contains('cleaning reminder') ||
        title.contains('daily checklist') ||
        title.contains('weekly cleaning')) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const CleaningChecklistPage(),
        ),
      );
      return;
    }

    if (targetPage == 'review_checklist' ||
        (type == 'checklist' &&
            (title.contains('pending review') ||
                title.contains('checklist pending')))) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const ReviewChecklistPage(),
        ),
      );
      return;
    }

    if (targetPage == 'review_stock_count' ||
        (type == 'stock_count' &&
            (title.contains('pending review') ||
                title.contains('waiting for approval')))) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const ReviewStockCountPage(),
        ),
      );
      return;
    }

    if (targetPage == 'inventory' ||
        targetPage == 'low_stock' ||
        targetPage == 'stock_count_approved' ||
        type == 'inventory' ||
        title.contains('low stock') ||
        title.contains('stock count approved') ||
        title.contains('stock approved') ||
        title.contains('approved stock count') ||
        title.contains('inventory updated') ||
        message.contains('stock count approved') ||
        message.contains('inventory has been updated')) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const InventoryPage(),
        ),
      );
      return;
    }

    showMessage('No linked page for this notification yet.');
  }

  IconData getNotificationIcon(String? type) {
    if (type == 'checklist') {
      return Icons.checklist;
    } else if (type == 'inventory') {
      return Icons.inventory_2;
    } else if (type == 'stock_count') {
      return Icons.fact_check;
    } else if (type == 'schedule') {
      return Icons.calendar_month;
    } else if (type == 'recipe') {
      return Icons.restaurant_menu;
    } else if (type == 'profile') {
      return Icons.person;
    } else if (type == 'report') {
      return Icons.bar_chart;
    } else {
      return Icons.notifications;
    }
  }

  Color getNotificationColor(String? type) {
    if (type == 'checklist') {
      return mulberry;
    } else if (type == 'inventory') {
      return Colors.orange;
    } else if (type == 'stock_count') {
      return Colors.green;
    } else if (type == 'schedule') {
      return Colors.blue;
    } else if (type == 'recipe') {
      return Colors.green;
    } else if (type == 'profile') {
      return Colors.blue;
    } else if (type == 'report') {
      return Colors.indigo;
    } else {
      return Colors.grey;
    }
  }

  DateTime? parseNotificationDate(dynamic value) {
    if (value == null) {
      return null;
    }

    try {
      return DateTime.parse(value.toString()).toLocal();
    } catch (_) {
      return null;
    }
  }

  bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  bool matchDateFilter(Map<String, dynamic> notification) {
    if (selectedDateFilter == NotificationDateFilter.all) {
      return true;
    }

    final createdAt = parseNotificationDate(notification['created_at']);

    if (createdAt == null) {
      return selectedDateFilter == NotificationDateFilter.older;
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final notificationDay = DateTime(
      createdAt.year,
      createdAt.month,
      createdAt.day,
    );

    final diffDays = today.difference(notificationDay).inDays;

    switch (selectedDateFilter) {
      case NotificationDateFilter.today:
        return isSameDay(createdAt, now);

      case NotificationDateFilter.last7Days:
        return diffDays >= 1 && diffDays <= 7;

      case NotificationDateFilter.older:
        return diffDays > 7;

      case NotificationDateFilter.all:
        return true;
    }
  }

  String formatDate(dynamic value) {
    if (value == null) {
      return '-';
    }

    try {
      final date = DateTime.parse(value.toString()).toLocal();

      final day = date.day.toString().padLeft(2, '0');
      final month = date.month.toString().padLeft(2, '0');
      final year = date.year.toString();

      final hour = date.hour.toString().padLeft(2, '0');
      final minute = date.minute.toString().padLeft(2, '0');

      return '$day/$month/$year $hour:$minute';
    } catch (_) {
      return value.toString();
    }
  }

  Widget buildHeader(int unreadCount) {
    return Container(
      padding: const EdgeInsets.all(18),
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
        borderRadius: BorderRadius.circular(22),
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
          Stack(
            children: [
              CircleAvatar(
                backgroundColor: cream.withOpacity(0.18),
                child: const Icon(
                  Icons.notifications,
                  color: cream,
                ),
              ),
              if (unreadCount > 0)
                Positioned(
                  right: 1,
                  top: 1,
                  child: Container(
                    height: 11,
                    width: 11,
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Notifications',
                  style: TextStyle(
                    color: cream,
                    fontFamily: 'Georgia',
                    fontSize: 21,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  unreadCount == 0
                      ? 'No unread notifications'
                      : '$unreadCount unread notification(s)',
                  style: const TextStyle(
                    color: creamDark,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          if (unreadCount > 0)
            TextButton(
              onPressed: markAllAsRead,
              style: TextButton.styleFrom(
                foregroundColor: cream,
              ),
              child: const Text(
                'Read All',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget buildToggle(int unreadCount) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: creamDark.withOpacity(0.65),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Expanded(
            child: buildToggleButton(
              label: 'All',
              selected: !showUnreadOnly,
              hasDot: false,
              onTap: () {
                setState(() {
                  showUnreadOnly = false;
                });
              },
            ),
          ),
          Expanded(
            child: buildToggleButton(
              label: 'Unread',
              selected: showUnreadOnly,
              hasDot: unreadCount > 0,
              onTap: () {
                setState(() {
                  showUnreadOnly = true;
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget buildToggleButton({
    required String label,
    required bool selected,
    required bool hasDot,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(15),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? mulberry : Colors.transparent,
          borderRadius: BorderRadius.circular(15),
        ),
        child: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: selected ? cream : mulberry,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (hasDot) ...[
                const SizedBox(width: 6),
                Container(
                  height: 8,
                  width: 8,
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget buildDateFilterChips() {
    return SizedBox(
      height: 38,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          buildDateChip(
            label: 'All',
            filter: NotificationDateFilter.all,
          ),
          buildDateChip(
            label: 'Today',
            filter: NotificationDateFilter.today,
          ),
          buildDateChip(
            label: 'Last 7 Days',
            filter: NotificationDateFilter.last7Days,
          ),
          buildDateChip(
            label: 'Older',
            filter: NotificationDateFilter.older,
          ),
        ],
      ),
    );
  }

  Widget buildDateChip({
    required String label,
    required NotificationDateFilter filter,
  }) {
    final selected = selectedDateFilter == filter;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        selectedColor: mulberry,
        backgroundColor: softWhite,
        side: BorderSide(
          color: selected ? mulberry : creamDark,
        ),
        labelStyle: TextStyle(
          color: selected ? cream : mulberry,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
        onSelected: (_) {
          setState(() {
            selectedDateFilter = filter;
          });
        },
      ),
    );
  }

  Widget buildSwipeBackground({
    required Alignment alignment,
    required Color color,
    required IconData icon,
    required String label,
  }) {
    final isLeft = alignment == Alignment.centerLeft;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 22),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(18),
      ),
      alignment: alignment,
      child: Row(
        mainAxisAlignment:
            isLeft ? MainAxisAlignment.start : MainAxisAlignment.end,
        children: [
          if (isLeft) ...[
            Icon(icon, color: Colors.white),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ] else ...[
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 8),
            Icon(icon, color: Colors.white),
          ],
        ],
      ),
    );
  }

  Widget buildNotificationCard(Map<String, dynamic> notification) {
    final notificationId =
        (notification['notification_id'] ?? notification.hashCode).toString();

    final title = notification['title'] ?? 'No Title';
    final message = notification['message'] ?? '';
    final type = notification['type']?.toString();
    final isRead = notification['is_read'] == true;
    final createdAt = formatDate(notification['created_at']);

    final color = getNotificationColor(type);

    return Dismissible(
      key: ValueKey(notificationId),
      direction: DismissDirection.horizontal,
      background: buildSwipeBackground(
        alignment: Alignment.centerLeft,
        color: Colors.blue,
        icon: Icons.mark_email_unread,
        label: 'Unread',
      ),
      secondaryBackground: buildSwipeBackground(
        alignment: Alignment.centerRight,
        color: Colors.red,
        icon: Icons.delete,
        label: 'Delete',
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          await markAsUnread(notification);
          return false;
        }

        if (direction == DismissDirection.endToStart) {
          final confirm = await confirmDeleteNotification();

          if (confirm) {
            await deleteNotification(notification);
            return true;
          }

          return false;
        }

        return false;
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: isRead ? softWhite : const Color(0xFFFFF7E6),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isRead ? creamDark.withOpacity(0.65) : Colors.orange.shade200,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: mulberryDark.withOpacity(isRead ? 0.04 : 0.08),
              blurRadius: isRead ? 10 : 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => handleNotificationTap(notification),
          child: Padding(
            padding: const EdgeInsets.all(15),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: color.withOpacity(0.12),
                      child: Icon(
                        getNotificationIcon(type),
                        color: color,
                      ),
                    ),
                    if (!isRead)
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          height: 10,
                          width: 10,
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title.toString(),
                        style: TextStyle(
                          color: mulberryDark,
                          fontWeight:
                              isRead ? FontWeight.w600 : FontWeight.bold,
                          fontSize: 15.5,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        message.toString(),
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text(
                            createdAt,
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            Icons.open_in_new,
                            size: 13,
                            color: Colors.grey.shade500,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            'Tap to open',
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  color: softWhite,
                  onSelected: (value) {
                    if (value == 'read') {
                      markAsRead(notification);
                    } else if (value == 'unread') {
                      markAsUnread(notification);
                    } else if (value == 'delete') {
                      confirmDeleteNotification().then((confirm) {
                        if (confirm) {
                          deleteNotification(notification);
                        }
                      });
                    }
                  },
                  itemBuilder: (context) => [
                    if (!isRead)
                      const PopupMenuItem(
                        value: 'read',
                        child: Row(
                          children: [
                            Icon(Icons.done, color: mulberry),
                            SizedBox(width: 8),
                            Text('Mark as read'),
                          ],
                        ),
                      ),
                    if (isRead)
                      const PopupMenuItem(
                        value: 'unread',
                        child: Row(
                          children: [
                            Icon(Icons.mark_email_unread, color: Colors.blue),
                            SizedBox(width: 8),
                            Text('Mark as unread'),
                          ],
                        ),
                      ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Delete'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void showMessage(String message, {bool isError = false}) {
    if (!mounted) {
      return;
    }

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
    return Scaffold(
      backgroundColor: cream,
      appBar: widget.showAppBar
          ? AppBar(
              title: const Text(
                'Notifications',
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
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: getNotificationStream(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Failed to load notifications:\n${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(
                color: mulberry,
              ),
            );
          }

          final allNotifications = snapshot.data ?? [];
          final unreadCount =
              allNotifications.where((n) => n['is_read'] == false).length;

          final visibleNotifications = allNotifications.where((notification) {
            final unreadMatch =
                !showUnreadOnly || notification['is_read'] == false;

            final dateMatch = matchDateFilter(notification);

            return unreadMatch && dateMatch;
          }).toList();

          return RefreshIndicator(
            color: mulberry,
            onRefresh: () async {
              setState(() {});
            },
            child: ListView(
              padding: const EdgeInsets.all(18),
              children: [
                buildHeader(unreadCount),
                const SizedBox(height: 14),
                buildToggle(unreadCount),
                const SizedBox(height: 12),
                buildDateFilterChips(),
                const SizedBox(height: 18),
                if (visibleNotifications.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 90),
                    child: Center(
                      child: Text(
                        showUnreadOnly
                            ? 'No unread notifications here.'
                            : 'No notifications here.',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  )
                else
                  ...visibleNotifications.map(buildNotificationCard),
              ],
            ),
          );
        },
      ),
    );
  }
}