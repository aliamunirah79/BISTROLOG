import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
    loadReviewData();
  }

  @override
  void dispose() {
    tabController.dispose();
    super.dispose();
  }

  String get todayText => DateTime.now().toIso8601String().substring(0, 10);

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
          .eq('task_date', todayText)
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

  int get totalPending => openingLogs.length + closingLogs.length + weeklyLogs.length;

  String getTaskTitle(Map<String, dynamic> log) {
    return (log['cleaning_tasks']?['title'] ?? 'Cleaning Task').toString();
  }

  String getTaskDescription(Map<String, dynamic> log) {
    return (log['cleaning_tasks']?['description'] ?? 'No description.').toString();
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

  Color getReviewColor(String status) {
    if (status == 'approved') return Colors.green;
    if (status == 'rejected') return Colors.red;
    return Colors.orange;
  }

  IconData getCategoryIcon(String category) {
    if (category == 'opening') return Icons.wb_sunny;
    if (category == 'closing') return Icons.nights_stay;
    if (category == 'weekly') return Icons.calendar_view_week;
    return Icons.cleaning_services;
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
        message: 'Your cleaning task "$taskTitle" was rejected. Reason: $remarks',
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
            style: TextStyle(color: mulberryDark, fontWeight: FontWeight.bold),
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
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
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
                  showMessage('Please enter rejection remarks.', isError: true);
                  return;
                }

                Navigator.pop(dialogContext);
                await rejectTask(log, remarks);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
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
        borderRadius: BorderRadius.circular(22),
        boxShadow: [BoxShadow(color: mulberryDark.withOpacity(0.16), blurRadius: 16, offset: const Offset(0, 7))],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 27,
            backgroundColor: cream.withOpacity(0.18),
            child: const Icon(Icons.fact_check, color: cream, size: 30),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Review Checklist',
                  style: TextStyle(color: cream, fontFamily: 'Georgia', fontSize: 21, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 5),
                Text(
                  'Approve or reject submitted cleaning checklist proof • Pending: $totalPending',
                  style: const TextStyle(color: creamDark, fontWeight: FontWeight.w500, height: 1.25),
                ),
              ],
            ),
          ),
        ],
      ),
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
      child: Text(
        'Only completed checklist tasks with pending review are shown here. Approving confirms the task, while rejecting sends remarks back to the staff notification page.',
        style: TextStyle(color: Colors.orange.shade900, fontWeight: FontWeight.w600, height: 1.35),
      ),
    );
  }

  Widget buildTabBar() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: creamDark.withOpacity(0.65),
        borderRadius: BorderRadius.circular(18),
      ),
      child: TabBar(
        controller: tabController,
        indicator: BoxDecoration(
          color: mulberry,
          borderRadius: BorderRadius.circular(15),
        ),
        labelColor: cream,
        unselectedLabelColor: mulberry,
        labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
        dividerColor: Colors.transparent,
        tabs: [
          Tab(text: 'Opening (${openingLogs.length})'),
          Tab(text: 'Closing (${closingLogs.length})'),
          Tab(text: 'Weekly (${weeklyLogs.length})'),
        ],
      ),
    );
  }

  Widget buildTaskList(List<Map<String, dynamic>> logs) {
    if (logs.isEmpty) {
      return ListView(
        padding: const EdgeInsets.only(top: 70),
        children: [
          Icon(Icons.check_circle_outline, size: 58, color: mulberry.withOpacity(0.35)),
          const SizedBox(height: 12),
          Center(
            child: Text(
              'No pending checklist review.',
              style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w600),
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
    final proofUrl = (log['proof_url'] ?? '').toString();
    final remarks = (log['remarks'] ?? '').toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: softWhite,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: creamDark.withOpacity(0.75)),
        boxShadow: [BoxShadow(color: mulberryDark.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 5))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: mulberry.withOpacity(0.10),
                  child: Icon(getCategoryIcon(category), color: mulberry),
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
                        style: const TextStyle(color: mulberryDark, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${formatValue(category)} • ${getStaffName(log)} (${formatValue(getStaffRole(log))})',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 12.5),
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
              style: const TextStyle(color: mulberryDark, height: 1.35),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                buildInfoChip(Icons.schedule, 'Completed: ${formatDateTime(log['completed_at'])}'),
                if (remarks.trim().isNotEmpty) buildInfoChip(Icons.notes, remarks),
              ],
            ),
            if (proofUrl.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  onTap: () => showProofPreview(proofUrl),
                  child: Image.network(
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
                ),
              ),
            ],
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => showRejectDialog(log),
                    icon: const Icon(Icons.close),
                    label: const Text('Reject'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => approveTask(log),
                    icon: const Icon(Icons.check),
                    label: const Text('Approve'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
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
      decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
      child: Text(text, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }

  Widget buildInfoChip(IconData icon, String text) {
    return Container(
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
            child: Text(text, style: TextStyle(color: Colors.grey.shade700, fontSize: 11.5, fontWeight: FontWeight.w600)),
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
        content: Text(message, style: const TextStyle(color: cream, fontFamily: 'Georgia')),
        backgroundColor: isError ? mulberryDark : mulberry,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: cream,
      appBar: widget.showAppBar
          ? AppBar(
              title: const Text('Review Checklist', style: TextStyle(color: cream, fontWeight: FontWeight.bold)),
              centerTitle: true,
              backgroundColor: mulberry,
              foregroundColor: cream,
              elevation: 0,
              actions: [IconButton(onPressed: loadReviewData, icon: const Icon(Icons.refresh))],
            )
          : null,
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: mulberry))
          : RefreshIndicator(
              color: mulberry,
              onRefresh: loadReviewData,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
                child: Column(
                  children: [
                    buildHeaderCard(),
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
