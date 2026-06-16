import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TaskApprovalPage extends StatefulWidget {
  const TaskApprovalPage({super.key});

  @override
  State<TaskApprovalPage> createState() => _TaskApprovalPageState();
}

class _TaskApprovalPageState extends State<TaskApprovalPage> {
  final supabase = Supabase.instance.client;

  static const Color mulberry = Color(0xFF6D2B50);
  static const Color mulberryDark = Color(0xFF4A1A35);
  static const Color mulberryLight = Color(0xFF8B3D68);
  static const Color cream = Color(0xFFF5ECD7);
  static const Color creamDark = Color(0xFFE8D5B5);

  List<Map<String, dynamic>> tasks = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    loadTasks();
  }

  Future<void> loadTasks() async {
    setState(() => _loading = true);

    try {
      final res = await supabase
          .from('task')
          .select()
          .eq('done', true)
          .eq('approved', false)
          .order('completed_at', ascending: false);

      if (!mounted) return;

      setState(() {
        tasks = List<Map<String, dynamic>>.from(res);
        _loading = false;
      });
    } catch (e) {
      debugPrint('loadTasks error: $e');

      if (!mounted) return;

      setState(() => _loading = false);
      _showSnack('Failed to load completed tasks.');
    }
  }

  Future<void> approveTask(int taskId) async {
    try {
      await supabase.from('task').update({
        'approved': true,
      }).eq('task_id', taskId);

      _showSnack('Task approved successfully.');
      await loadTasks();
    } catch (e) {
      _showSnack('Approve failed: $e');
    }
  }

  Future<void> rejectTask(int taskId) async {
    try {
      await supabase.from('task').update({
        'done': false,
        'approved': false,
        'completed_by': null,
        'completed_at': null,
        'proof_url': null,
      }).eq('task_id', taskId);

      _showSnack('Task rejected and returned to pending.');
      await loadTasks();
    } catch (e) {
      _showSnack('Reject failed: $e');
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: mulberryDark,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  String _formatDateTime(dynamic value) {
    if (value == null) return '-';

    try {
      final dt = DateTime.parse(value.toString()).toLocal();
      final day = dt.day.toString().padLeft(2, '0');
      final month = dt.month.toString().padLeft(2, '0');
      final year = dt.year.toString();
      final hour = dt.hour.toString().padLeft(2, '0');
      final minute = dt.minute.toString().padLeft(2, '0');

      return '$day/$month/$year $hour:$minute';
    } catch (_) {
      return value.toString();
    }
  }

  Future<void> _confirmApprove(Map<String, dynamic> task) async {
    final taskId = task['task_id'];

    if (taskId == null) {
      _showSnack('Invalid task ID.');
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: cream,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Approve Task?',
            style: TextStyle(
              color: mulberryDark,
              fontWeight: FontWeight.bold,
              fontFamily: 'Georgia',
            ),
          ),
          content: Text(
            'Are you sure you want to approve "${task['title'] ?? 'this task'}"?',
            style: const TextStyle(color: mulberryDark),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text(
                'Cancel',
                style: TextStyle(color: mulberryDark),
              ),
            ),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(dialogContext, true),
              icon: const Icon(Icons.check),
              label: const Text('Approve'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      await approveTask(taskId as int);
    }
  }

  Future<void> _confirmReject(Map<String, dynamic> task) async {
    final taskId = task['task_id'];

    if (taskId == null) {
      _showSnack('Invalid task ID.');
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: cream,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Reject Task?',
            style: TextStyle(
              color: mulberryDark,
              fontWeight: FontWeight.bold,
              fontFamily: 'Georgia',
            ),
          ),
          content: Text(
            'This will return "${task['title'] ?? 'this task'}" to pending status.',
            style: const TextStyle(color: mulberryDark),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text(
                'Cancel',
                style: TextStyle(color: mulberryDark),
              ),
            ),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(dialogContext, true),
              icon: const Icon(Icons.close),
              label: const Text('Reject'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      await rejectTask(taskId as int);
    }
  }

  Widget _header() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(8, 14, 20, 20),
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
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back, color: cream),
          ),
          Container(
            width: 52,
            height: 52,
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
                padding: const EdgeInsets.all(9),
                child: Image.asset(
                  'logo.png',
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.restaurant,
                    size: 28,
                    color: mulberry,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Task Approval',
                  style: TextStyle(
                    fontFamily: 'Georgia',
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: cream,
                    letterSpacing: 0.8,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'Review completed tasks and proof',
                  style: TextStyle(
                    fontSize: 13,
                    color: cream,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: cream),
            onPressed: loadTasks,
            tooltip: 'Refresh',
          ),
        ],
      ),
    );
  }

  Widget _summaryCard() {
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
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: mulberry.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.fact_check_outlined,
              color: mulberry,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '${tasks.length} completed task(s) waiting for approval',
              style: const TextStyle(
                color: mulberryDark,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: creamDark),
      ),
      child: Column(
        children: [
          Icon(
            Icons.task_alt,
            size: 46,
            color: Colors.green.shade600,
          ),
          const SizedBox(height: 12),
          const Text(
            'No completed tasks to approve',
            style: TextStyle(
              color: mulberryDark,
              fontSize: 16,
              fontWeight: FontWeight.bold,
              fontFamily: 'Georgia',
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Completed staff tasks will appear here after submission.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey.shade700,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _taskCard(Map<String, dynamic> task) {
    final title = (task['title'] ?? 'No title').toString();
    final description = (task['description'] ?? '').toString();
    final category = (task['category'] ?? '').toString();
    final frequency = (task['frequency'] ?? '').toString();
    final completedBy = (task['completed_by'] ?? '-').toString();
    final completedAt = _formatDateTime(task['completed_at']);
    final proofUrl = task['proof_url']?.toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: creamDark),
        boxShadow: [
          BoxShadow(
            color: mulberryDark.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: mulberry.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.assignment_turned_in_outlined,
                  color: mulberry,
                  size: 20,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: mulberryDark,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (description.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (category.isNotEmpty) _infoLine(Icons.category_outlined, 'Category: $category'),
          if (frequency.isNotEmpty) _infoLine(Icons.repeat, 'Frequency: $frequency'),
          _infoLine(Icons.person_outline, 'Completed by: $completedBy'),
          if (completedAt != '-') _infoLine(Icons.access_time, 'Completed at: $completedAt'),
          if (proofUrl != null && proofUrl.isNotEmpty) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.network(
                proofUrl,
                height: 150,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  height: 90,
                  width: double.infinity,
                  color: cream,
                  alignment: Alignment.center,
                  child: const Text(
                    'Proof image unavailable',
                    style: TextStyle(color: mulberryDark),
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _confirmReject(task),
                  icon: const Icon(Icons.close),
                  label: const Text('Reject'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _confirmApprove(task),
                  icon: const Icon(Icons.check),
                  label: const Text('Approve'),
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
          ),
        ],
      ),
    );
  }

  Widget _infoLine(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        children: [
          Icon(icon, size: 16, color: mulberry),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
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
              child: RefreshIndicator(
                onRefresh: loadTasks,
                color: mulberry,
                child: _loading
                    ? const Center(
                        child: CircularProgressIndicator(color: mulberry),
                      )
                    : ListView(
                        padding: const EdgeInsets.all(20),
                        children: [
                          const Text(
                            'Completed Tasks',
                            style: TextStyle(
                              fontFamily: 'Georgia',
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: mulberryDark,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Approve or reject submitted task completion proof.',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          const SizedBox(height: 18),
                          _summaryCard(),
                          const SizedBox(height: 18),
                          if (tasks.isEmpty)
                            _emptyState()
                          else
                            ...tasks.map(_taskCard),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}