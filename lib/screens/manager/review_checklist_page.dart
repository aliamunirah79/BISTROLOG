import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'checklist_history_page.dart';

class ReviewChecklistPage extends StatefulWidget {
  final bool showAppBar;

  const ReviewChecklistPage({
    super.key,
    this.showAppBar = true,
  });

  @override
  State<ReviewChecklistPage> createState() => _ReviewChecklistPageState();
}

class _ReviewChecklistPageState extends State<ReviewChecklistPage>
    with SingleTickerProviderStateMixin {
  final supabase = Supabase.instance.client;

  late TabController tabController;

  bool isLoading = true;
  bool isSendingReminder = false;

  DateTime selectedDate = DateTime.now();

  List<Map<String, dynamic>> openingLogs = [];
  List<Map<String, dynamic>> closingLogs = [];
  List<Map<String, dynamic>> weeklyLogs = [];

  static const Color mulberry = Color(0xFF6D2B50);
  static const Color mulberryDark = Color(0xFF4A1A35);
  static const Color mulberryLight = Color(0xFF8B3D68);
  static const Color cream = Color(0xFFF5ECD7);
  static const Color creamDark = Color(0xFFE8D5B5);
  static const Color softWhite = Color(0xFFFFFCF7);

  @override
  void initState() {
    super.initState();
    tabController = TabController(length: 3, vsync: this);
    tabController.addListener(() {
      if (mounted) setState(() {});
    });
    loadReviewData();
  }

  @override
  void dispose() {
    tabController.dispose();
    super.dispose();
  }

  String get selectedDateText {
    return selectedDate.toIso8601String().substring(0, 10);
  }

  String get selectedDateDisplay {
    final day = selectedDate.day.toString().padLeft(2, '0');
    final month = selectedDate.month.toString().padLeft(2, '0');
    final year = selectedDate.year.toString();
    return '$day/$month/$year';
  }

  bool get isToday {
    final now = DateTime.now();
    return selectedDate.year == now.year &&
        selectedDate.month == now.month &&
        selectedDate.day == now.day;
  }

  Future<void> loadReviewData() async {
    if (!mounted) return;

    setState(() {
      isLoading = true;
    });

    try {
      final response = await supabase
          .from('cleaning_task_logs')
          .select('''
            log_id,
            task_id,
            staff_id,
            task_date,
            status,
            remarks,
            proof_url,
            completed_at,
            review_status,
            reviewed_by,
            reviewed_at,
            review_remarks,
            updated_by,
            updated_at,
            cleaning_tasks:task_id (
              title,
              description,
              category,
              proof_required
            ),
            profiles:staff_id (
              full_name,
              role
            )
          ''')
          .eq('task_date', selectedDateText)
          .eq('status', 'completed')
          .eq('review_status', 'pending')
          .order('completed_at', ascending: false);

      final logs = List<Map<String, dynamic>>.from(response);

      if (!mounted) return;

      setState(() {
        openingLogs = logs.where((log) {
          return log['cleaning_tasks']?['category'] == 'opening';
        }).toList();

        closingLogs = logs.where((log) {
          return log['cleaning_tasks']?['category'] == 'closing';
        }).toList();

        weeklyLogs = logs.where((log) {
          return log['cleaning_tasks']?['category'] == 'weekly';
        }).toList();

        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
      });

      showMessage('Failed to load review checklist: $e', isError: true);
    }
  }

  Future<void> pickReviewDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2024),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: mulberry,
              onPrimary: cream,
              surface: softWhite,
              onSurface: mulberryDark,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked == null) return;

    setState(() {
      selectedDate = picked;
    });

    await loadReviewData();
  }

  Future<void> notifyIncompleteChecklist() async {
    if (isSendingReminder) return;

    setState(() {
      isSendingReminder = true;
    });

    try {
      final staffResponse = await supabase
          .from('profiles')
          .select('id, full_name, role, is_active, staff_status')
          .eq('is_active', true)
          .eq('staff_status', 'active');

      final taskResponse = await supabase
          .from('cleaning_tasks')
          .select('task_id, title, category, is_active')
          .eq('is_active', true);

      final logResponse = await supabase
          .from('cleaning_task_logs')
          .select('task_id, staff_id, status')
          .eq('task_date', selectedDateText);

      final staffList = List<Map<String, dynamic>>.from(staffResponse);
      final taskList = List<Map<String, dynamic>>.from(taskResponse);
      final logList = List<Map<String, dynamic>>.from(logResponse);

      int notificationCount = 0;

      for (final staff in staffList) {
        final staffId = staff['id']?.toString() ?? '';
        final staffName = staff['full_name']?.toString() ?? 'Staff';
        final staffRole = staff['role']?.toString() ?? '';

        if (staffId.isEmpty) continue;

        // Cleaning reminder only goes to staff and supervisor.
        if (staffRole != 'staff' && staffRole != 'supervisor') continue;

        final incompleteTasks = taskList.where((task) {
          final taskId = task['task_id']?.toString() ?? '';

          if (taskId.isEmpty) return false;

          final completedLog = logList.any((log) {
            return log['staff_id']?.toString() == staffId &&
                log['task_id']?.toString() == taskId &&
                log['status']?.toString() == 'completed';
          });

          return !completedLog;
        }).toList();

        if (incompleteTasks.isEmpty) continue;

        final notificationKey = 'incomplete_checklist_${selectedDateText}_$staffId';

        final existingResponse = await supabase
            .from('notifications')
            .select('target_id')
            .eq('user_id', staffId)
            .eq('target_id', notificationKey)
            .limit(1);

        final existingList = List<Map<String, dynamic>>.from(existingResponse);

        if (existingList.isNotEmpty) continue;

        await supabase.from('notifications').insert({
          'user_id': staffId,
          'title': 'Incomplete Cleaning Checklist',
          'message':
              '$staffName still has ${incompleteTasks.length} incomplete cleaning checklist task(s) for $selectedDateDisplay. Please complete them as soon as possible.',
          'type': 'checklist',
          'target_page': 'cleaning_checklist',
          'target_id': notificationKey,
          'is_read': false,
        });

        notificationCount++;
      }

      showMessage(
        notificationCount == 0
            ? 'No incomplete checklist reminder needed.'
            : 'Reminder sent to $notificationCount staff member(s).',
      );
    } catch (e) {
      showMessage(
        'Failed to notify incomplete checklist: $e',
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          isSendingReminder = false;
        });
      }
    }
  }

  int get totalPending {
    return openingLogs.length + closingLogs.length + weeklyLogs.length;
  }

  String getTaskTitle(Map<String, dynamic> log) {
    return (log['cleaning_tasks']?['title'] ?? 'Cleaning Task').toString();
  }

  String getTaskDescription(Map<String, dynamic> log) {
    return (log['cleaning_tasks']?['description'] ?? 'No description.')
        .toString();
  }

  String getCategory(Map<String, dynamic> log) {
    return (log['cleaning_tasks']?['category'] ?? 'general').toString();
  }

  String getStaffName(Map<String, dynamic> log) {
    return (log['profiles']?['full_name'] ?? 'Unknown Staff').toString();
  }

  String getStaffRole(Map<String, dynamic> log) {
    return (log['profiles']?['role'] ?? 'staff').toString();
  }

  String formatDateTime(dynamic value) {
    if (value == null) return '-';

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

  String formatValue(String value) {
    return value
        .replaceAll('_', ' ')
        .split(' ')
        .where((part) => part.trim().isNotEmpty)
        .map((part) => part[0].toUpperCase() + part.substring(1))
        .join(' ');
  }

  IconData getCategoryIcon(String category) {
    if (category == 'opening') return Icons.wb_sunny_rounded;
    if (category == 'closing') return Icons.nights_stay_rounded;
    if (category == 'weekly') return Icons.calendar_view_week_rounded;
    return Icons.cleaning_services_rounded;
  }

  Color getCategoryColor(String category) {
    if (category == 'opening') return Colors.orange;
    if (category == 'closing') return Colors.indigo;
    if (category == 'weekly') return Colors.teal;
    return mulberry;
  }

  Future<void> notifyStaff({
    required String staffId,
    required String title,
    required String message,
    required dynamic taskId,
  }) async {
    try {
      await supabase.from('notifications').insert({
        'user_id': staffId,
        'title': title,
        'message': message,
        'type': 'checklist',
        'target_page': 'cleaning_checklist',
        'target_id': taskId.toString(),
        'is_read': false,
      });
    } catch (e) {
      debugPrint('Failed to notify staff: $e');
    }
  }

  Future<void> approveTask(Map<String, dynamic> log) async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) throw Exception('Reviewer not logged in.');

      final taskTitle = getTaskTitle(log);

      await supabase.from('cleaning_task_logs').update({
        'review_status': 'approved',
        'reviewed_by': user.id,
        'reviewed_at': DateTime.now().toIso8601String(),
        'review_remarks': null,
      }).eq('log_id', log['log_id']);

      await notifyStaff(
        staffId: log['staff_id'],
        title: 'Checklist Approved',
        message: 'Your cleaning task "$taskTitle" has been approved.',
        taskId: log['task_id'],
      );

      showMessage('Task approved. Staff has been notified.');
      await loadReviewData();
    } catch (e) {
      showMessage('Failed to approve task: $e', isError: true);
    }
  }

  Future<void> rejectTask(Map<String, dynamic> log, String remarks) async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) throw Exception('Reviewer not logged in.');

      final taskTitle = getTaskTitle(log);

      await supabase.from('cleaning_task_logs').update({
        'review_status': 'rejected',
        'reviewed_by': user.id,
        'reviewed_at': DateTime.now().toIso8601String(),
        'review_remarks': remarks,
      }).eq('log_id', log['log_id']);

      await notifyStaff(
        staffId: log['staff_id'],
        title: 'Checklist Rejected',
        message:
            'Your cleaning task "$taskTitle" was rejected. Reason: $remarks',
        taskId: log['task_id'],
      );

      showMessage('Task rejected. Staff has been notified.');
      await loadReviewData();
    } catch (e) {
      showMessage('Failed to reject task: $e', isError: true);
    }
  }

  void showRejectDialog(Map<String, dynamic> log) {
    final remarksController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: softWhite,
          title: const Text(
            'Reject Task',
            style: TextStyle(
              color: mulberryDark,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: TextField(
            controller: remarksController,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: 'Rejection remarks',
              hintText: 'Example: Please clean again properly.',
              prefixIcon: const Icon(Icons.edit_note, color: mulberry),
              filled: true,
              fillColor: cream,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: mulberry, width: 1.8),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              style: TextButton.styleFrom(foregroundColor: mulberry),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final remarks = remarksController.text.trim();

                if (remarks.isEmpty) {
                  showMessage(
                    'Please enter rejection remarks.',
                    isError: true,
                  );
                  return;
                }

                Navigator.pop(dialogContext);
                await rejectTask(log, remarks);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Reject'),
            ),
          ],
        );
      },
    ).then((_) => remarksController.dispose());
  }

  void showProofPreview(String proofUrl) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: InteractiveViewer(
              child: Image.network(
                proofUrl,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    padding: const EdgeInsets.all(20),
                    color: softWhite,
                    child: const Text('Failed to load proof image.'),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Widget buildHeaderCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [mulberryDark, mulberry, mulberryLight],
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
            radius: 28,
            backgroundColor: cream.withOpacity(0.18),
            child: const Icon(
              Icons.fact_check_rounded,
              color: cream,
              size: 30,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Review Checklist',
                  style: TextStyle(
                    color: cream,
                    fontFamily: 'Georgia',
                    fontSize: 21,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  isToday
                      ? 'Today pending review: $totalPending'
                      : 'Pending review on $selectedDateDisplay: $totalPending',
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

  Widget buildSummaryCards() {
    return Row(
      children: [
        Expanded(
          child: buildSummaryCard(
            title: 'Opening',
            value: openingLogs.length.toString(),
            icon: Icons.wb_sunny_rounded,
            color: Colors.orange,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: buildSummaryCard(
            title: 'Closing',
            value: closingLogs.length.toString(),
            icon: Icons.nights_stay_rounded,
            color: Colors.indigo,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: buildSummaryCard(
            title: 'Weekly',
            value: weeklyLogs.length.toString(),
            icon: Icons.calendar_view_week_rounded,
            color: Colors.teal,
          ),
        ),
      ],
    );
  }

  Widget buildSummaryCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: softWhite,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: creamDark.withOpacity(0.85)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: color.withOpacity(0.12),
            child: Icon(icon, color: color, size: 19),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    color: mulberryDark,
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                  ),
                ),
                Text(
                  title,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w600,
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget buildActionRow() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: pickReviewDate,
            icon: const Icon(Icons.calendar_month_rounded),
            label: Text(
              'Date: $selectedDateDisplay',
              overflow: TextOverflow.ellipsis,
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: mulberry,
              side: const BorderSide(color: mulberry),
              backgroundColor: softWhite,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: ElevatedButton.icon(
            onPressed:
                isSendingReminder ? null : notifyIncompleteChecklist,
            icon: isSendingReminder
                ? const SizedBox(
                    width: 17,
                    height: 17,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: cream,
                    ),
                  )
                : const Icon(Icons.notifications_active_rounded),
            label: Text(
              isSendingReminder ? 'Sending...' : 'Notify Incomplete',
              overflow: TextOverflow.ellipsis,
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: mulberry,
              foregroundColor: cream,
              disabledBackgroundColor: mulberry.withOpacity(0.45),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget buildInfoCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            color: Colors.orange.shade900,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Only completed checklist tasks with pending review are shown for the selected date. Use Notify Incomplete to remind staff who have not completed their checklist.',
              style: TextStyle(
                color: Colors.orange.shade900,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildTabBar() {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: creamDark.withOpacity(0.65),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          buildCustomTab(
            index: 0,
            title: 'Opening',
            count: openingLogs.length,
            icon: Icons.wb_sunny_rounded,
          ),
          buildCustomTab(
            index: 1,
            title: 'Closing',
            count: closingLogs.length,
            icon: Icons.nights_stay_rounded,
          ),
          buildCustomTab(
            index: 2,
            title: 'Weekly',
            count: weeklyLogs.length,
            icon: Icons.calendar_view_week_rounded,
          ),
        ],
      ),
    );
  }

  Widget buildCustomTab({
    required int index,
    required String title,
    required int count,
    required IconData icon,
  }) {
    final selected = tabController.index == index;

    return Expanded(
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: selected ? mulberry : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: mulberryDark.withOpacity(0.18),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : [],
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              tabController.animateTo(index);
              setState(() {});
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    icon,
                    size: 17,
                    color: selected ? cream : mulberry,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      '$title ($count)',
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: selected ? cream : mulberry,
                        fontWeight: FontWeight.bold,
                        fontSize: 12.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget buildTaskList(List<Map<String, dynamic>> logs) {
    if (logs.isEmpty) {
      return ListView(
        padding: const EdgeInsets.only(top: 70),
        children: [
          Icon(
            Icons.task_alt_rounded,
            size: 62,
            color: mulberry.withOpacity(0.32),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              'No pending checklist review.',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Center(
            child: Text(
              'Selected date: $selectedDateDisplay',
              style: TextStyle(
                color: Colors.grey.shade500,
                fontWeight: FontWeight.w600,
                fontSize: 12.5,
              ),
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(0, 14, 0, 90),
      itemCount: logs.length,
      itemBuilder: (context, index) {
        return buildTaskCard(logs[index]);
      },
    );
  }

  Widget buildTaskCard(Map<String, dynamic> log) {
    final category = getCategory(log);
    final categoryColor = getCategoryColor(category);
    final proofUrl = (log['proof_url'] ?? '').toString();
    final remarks = (log['remarks'] ?? '').toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: softWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: creamDark.withOpacity(0.75)),
        boxShadow: [
          BoxShadow(
            color: mulberryDark.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: categoryColor.withOpacity(0.12),
                  child: Icon(
                    getCategoryIcon(category),
                    color: categoryColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        getTaskTitle(log),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: mulberryDark,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${formatValue(category)} • ${getStaffName(log)} (${formatValue(getStaffRole(log))})',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                buildStatusBadge('PENDING', Colors.orange),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              getTaskDescription(log),
              style: const TextStyle(
                color: mulberryDark,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                buildInfoChip(
                  Icons.calendar_today_rounded,
                  'Task date: ${formatValue(log['task_date']?.toString() ?? selectedDateText)}',
                ),
                buildInfoChip(
                  Icons.schedule_rounded,
                  'Completed: ${formatDateTime(log['completed_at'])}',
                ),
                if (remarks.trim().isNotEmpty)
                  buildInfoChip(Icons.notes_rounded, remarks),
              ],
            ),
            if (proofUrl.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  onTap: () => showProofPreview(proofUrl),
                  child: Stack(
                    children: [
                      Image.network(
                        proofUrl,
                        height: 150,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            height: 120,
                            width: double.infinity,
                            color: cream,
                            alignment: Alignment.center,
                            child: const Text('Proof image unavailable'),
                          );
                        },
                      ),
                      Positioned(
                        right: 10,
                        bottom: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.55),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.zoom_in_rounded,
                                color: Colors.white,
                                size: 15,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'View proof',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => showRejectDialog(log),
                    icon: const Icon(Icons.close_rounded),
                    label: const Text('Reject'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => approveTask(log),
                    icon: const Icon(Icons.check_rounded),
                    label: const Text('Approve'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget buildStatusBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
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
      constraints: const BoxConstraints(maxWidth: 360),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: cream,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: creamDark.withOpacity(0.75)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: mulberry),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              text,
              overflow: TextOverflow.ellipsis,
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
    return Scaffold(
      backgroundColor: cream,
      appBar: widget.showAppBar
          ? AppBar(
              title: const Text(
                'Review Checklist',
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
                tooltip: 'Checklist History',
                icon: const Icon(Icons.history_rounded),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ChecklistHistoryPage(),
                    ),
                  );
                },
              ),
              IconButton(
                tooltip: 'Refresh',
                onPressed: loadReviewData,
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
            )
          : null,
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(color: mulberry),
            )
          : RefreshIndicator(
              color: mulberry,
              onRefresh: loadReviewData,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
                child: Column(
                  children: [
                    buildHeaderCard(),
                    const SizedBox(height: 12),
                    buildSummaryCards(),
                    const SizedBox(height: 12),
                    buildActionRow(),
                    const SizedBox(height: 12),
                    buildInfoCard(),
                    const SizedBox(height: 12),
                    buildTabBar(),
                    const SizedBox(height: 2),
                    Expanded(
                      child: TabBarView(
                        controller: tabController,
                        children: [
                          buildTaskList(openingLogs),
                          buildTaskList(closingLogs),
                          buildTaskList(weeklyLogs),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}