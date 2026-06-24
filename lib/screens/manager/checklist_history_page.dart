import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ChecklistHistoryPage extends StatefulWidget {
  const ChecklistHistoryPage({super.key});

  @override
  State<ChecklistHistoryPage> createState() => _ChecklistHistoryPageState();
}

class _ChecklistHistoryPageState extends State<ChecklistHistoryPage>
    with SingleTickerProviderStateMixin {
  final supabase = Supabase.instance.client;

  late TabController tabController;

  bool isLoading = true;

  DateTime selectedDate = DateTime.now();
  DateTime selectedWeekDate = DateTime.now();

  String selectedCategory = 'All';
  String selectedReviewStatus = 'All';
  String searchQuery = '';

  List<Map<String, dynamic>> historyLogs = [];

  static const Color mulberry = Color(0xFF6D2B50);
  static const Color mulberryDark = Color(0xFF4A1A35);
  static const Color mulberryLight = Color(0xFF8B3D68);
  static const Color cream = Color(0xFFF5ECD7);
  static const Color creamDark = Color(0xFFE8D5B5);
  static const Color softWhite = Color(0xFFFFFCF7);

  @override
  void initState() {
    super.initState();

    tabController = TabController(length: 2, vsync: this);
    tabController.addListener(() {
      if (!tabController.indexIsChanging) {
        loadHistory();
      }
    });

    loadHistory();
  }

  @override
  void dispose() {
    tabController.dispose();
    super.dispose();
  }

  bool get isDailyMode => tabController.index == 0;

  String formatDateForQuery(DateTime date) {
    return date.toIso8601String().substring(0, 10);
  }

  String formatDateDisplay(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();
    return '$day/$month/$year';
  }

  DateTime get weekStart {
    final weekday = selectedWeekDate.weekday;
    return DateTime(
      selectedWeekDate.year,
      selectedWeekDate.month,
      selectedWeekDate.day,
    ).subtract(Duration(days: weekday - 1));
  }

  DateTime get weekEnd {
    return weekStart.add(const Duration(days: 6));
  }

  String get weekRangeText {
    return '${formatDateDisplay(weekStart)} - ${formatDateDisplay(weekEnd)}';
  }

  Future<void> loadHistory() async {
    if (!mounted) return;

    setState(() {
      isLoading = true;
    });

    try {
      var query = supabase.from('cleaning_task_logs').select('''
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
          ''');

      if (isDailyMode) {
        query = query.eq('task_date', formatDateForQuery(selectedDate));
      } else {
        query = query
            .gte('task_date', formatDateForQuery(weekStart))
            .lte('task_date', formatDateForQuery(weekEnd));
      }

      final response = await query.order('task_date', ascending: false);

      final list = List<Map<String, dynamic>>.from(response);

      if (!mounted) return;

      setState(() {
        historyLogs = list;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
      });

      showMessage('Failed to load checklist history: $e', isError: true);
    }
  }

  List<Map<String, dynamic>> get filteredLogs {
    List<Map<String, dynamic>> filtered = historyLogs;

    if (selectedCategory != 'All') {
      filtered = filtered.where((log) {
        return getCategory(log) == selectedCategory.toLowerCase();
      }).toList();
    }

    if (selectedReviewStatus != 'All') {
      filtered = filtered.where((log) {
        return getReviewStatus(log) == selectedReviewStatus.toLowerCase();
      }).toList();
    }

    if (searchQuery.trim().isNotEmpty) {
      final query = searchQuery.toLowerCase();

      filtered = filtered.where((log) {
        final staffName = getStaffName(log).toLowerCase();
        final taskTitle = getTaskTitle(log).toLowerCase();
        final category = getCategory(log).toLowerCase();
        final reviewStatus = getReviewStatus(log).toLowerCase();
        final taskStatus = getTaskStatus(log).toLowerCase();

        return staffName.contains(query) ||
            taskTitle.contains(query) ||
            category.contains(query) ||
            reviewStatus.contains(query) ||
            taskStatus.contains(query);
      }).toList();
    }

    return filtered;
  }

  int get totalLogs => historyLogs.length;

  int get approvedCount {
    return historyLogs.where((log) => getReviewStatus(log) == 'approved').length;
  }

  int get rejectedCount {
    return historyLogs.where((log) => getReviewStatus(log) == 'rejected').length;
  }

  int get pendingCount {
    return historyLogs.where((log) => getReviewStatus(log) == 'pending').length;
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

  String getTaskStatus(Map<String, dynamic> log) {
    return (log['status'] ?? 'pending').toString();
  }

  String getReviewStatus(Map<String, dynamic> log) {
    return (log['review_status'] ?? 'pending').toString();
  }

  String formatValue(String value) {
    return value
        .replaceAll('_', ' ')
        .split(' ')
        .where((part) => part.trim().isNotEmpty)
        .map((part) => part[0].toUpperCase() + part.substring(1))
        .join(' ');
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

  Color getCategoryColor(String category) {
    if (category == 'opening') return Colors.orange;
    if (category == 'closing') return Colors.indigo;
    if (category == 'weekly') return Colors.teal;
    return mulberry;
  }

  IconData getCategoryIcon(String category) {
    if (category == 'opening') return Icons.wb_sunny_rounded;
    if (category == 'closing') return Icons.nights_stay_rounded;
    if (category == 'weekly') return Icons.calendar_view_week_rounded;
    return Icons.cleaning_services_rounded;
  }

  Color getReviewColor(String status) {
    if (status == 'approved') return Colors.green;
    if (status == 'rejected') return Colors.red;
    return Colors.orange;
  }

  IconData getReviewIcon(String status) {
    if (status == 'approved') return Icons.verified_rounded;
    if (status == 'rejected') return Icons.cancel_rounded;
    return Icons.hourglass_top_rounded;
  }

  Future<void> pickDailyDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2024),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: datePickerTheme,
    );

    if (picked == null) return;

    setState(() {
      selectedDate = picked;
    });

    await loadHistory();
  }

  Future<void> pickWeekDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedWeekDate,
      firstDate: DateTime(2024),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: datePickerTheme,
    );

    if (picked == null) return;

    setState(() {
      selectedWeekDate = picked;
    });

    await loadHistory();
  }

  Widget datePickerTheme(BuildContext context, Widget? child) {
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
              Icons.history_rounded,
              color: cream,
              size: 31,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Checklist History Log',
                  style: TextStyle(
                    color: cream,
                    fontFamily: 'Georgia',
                    fontSize: 21,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  isDailyMode
                      ? 'Daily checklist records for ${formatDateDisplay(selectedDate)}'
                      : 'Weekly checklist records for $weekRangeText',
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

  Widget buildModeTabs() {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: creamDark.withOpacity(0.65),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          buildModeTab(
            index: 0,
            title: 'Daily',
            icon: Icons.today_rounded,
          ),
          buildModeTab(
            index: 1,
            title: 'Weekly',
            icon: Icons.calendar_view_week_rounded,
          ),
        ],
      ),
    );
  }

  Widget buildModeTab({
    required int index,
    required String title,
    required IconData icon,
  }) {
    final selected = tabController.index == index;

    return Expanded(
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
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
              loadHistory();
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    icon,
                    size: 18,
                    color: selected ? cream : mulberry,
                  ),
                  const SizedBox(width: 7),
                  Text(
                    title,
                    style: TextStyle(
                      color: selected ? cream : mulberry,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
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

  Widget buildSummaryCards() {
    return Row(
      children: [
        Expanded(
          child: buildSummaryCard(
            title: 'Total',
            value: totalLogs.toString(),
            icon: Icons.list_alt_rounded,
            color: mulberry,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: buildSummaryCard(
            title: 'Approved',
            value: approvedCount.toString(),
            icon: Icons.verified_rounded,
            color: Colors.green,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: buildSummaryCard(
            title: 'Rejected',
            value: rejectedCount.toString(),
            icon: Icons.cancel_rounded,
            color: Colors.red,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: buildSummaryCard(
            title: 'Pending',
            value: pendingCount.toString(),
            icon: Icons.hourglass_top_rounded,
            color: Colors.orange,
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

  Widget buildDateActionRow() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: isDailyMode ? pickDailyDate : pickWeekDate,
            icon: Icon(
              isDailyMode
                  ? Icons.calendar_month_rounded
                  : Icons.date_range_rounded,
            ),
            label: Text(
              isDailyMode
                  ? 'Date: ${formatDateDisplay(selectedDate)}'
                  : 'Week: $weekRangeText',
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
        SizedBox(
          height: 48,
          child: ElevatedButton.icon(
            onPressed: loadHistory,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Refresh'),
            style: ElevatedButton.styleFrom(
              backgroundColor: mulberry,
              foregroundColor: cream,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget buildSearchAndFilters() {
    return Column(
      children: [
        TextField(
          onChanged: (value) {
            setState(() {
              searchQuery = value;
            });
          },
          decoration: InputDecoration(
            hintText: 'Search staff, task, category or status...',
            prefixIcon: const Icon(Icons.search_rounded, color: mulberry),
            filled: true,
            fillColor: softWhite,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: creamDark.withOpacity(0.85)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: mulberry, width: 1.8),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: buildDropdown(
                value: selectedCategory,
                items: const ['All', 'Opening', 'Closing', 'Weekly'],
                onChanged: (value) {
                  setState(() {
                    selectedCategory = value ?? 'All';
                  });
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: buildDropdown(
                value: selectedReviewStatus,
                items: const ['All', 'Pending', 'Approved', 'Rejected'],
                onChanged: (value) {
                  setState(() {
                    selectedReviewStatus = value ?? 'All';
                  });
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget buildDropdown({
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      dropdownColor: softWhite,
      decoration: InputDecoration(
        filled: true,
        fillColor: softWhite,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: creamDark.withOpacity(0.85)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: mulberry),
        ),
      ),
      items: items
          .map(
            (item) => DropdownMenuItem(
              value: item,
              child: Text(item),
            ),
          )
          .toList(),
      onChanged: onChanged,
    );
  }

  Widget buildHistoryList() {
    final logs = filteredLogs;

    if (logs.isEmpty) {
      return ListView(
        padding: const EdgeInsets.only(top: 70),
        children: [
          Icon(
            Icons.history_toggle_off_rounded,
            size: 64,
            color: mulberry.withOpacity(0.32),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              'No checklist history found.',
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
              isDailyMode
                  ? 'Selected date: ${formatDateDisplay(selectedDate)}'
                  : 'Selected week: $weekRangeText',
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
        return buildHistoryCard(logs[index]);
      },
    );
  }

  Widget buildHistoryCard(Map<String, dynamic> log) {
    final category = getCategory(log);
    final categoryColor = getCategoryColor(category);
    final reviewStatus = getReviewStatus(log);
    final reviewColor = getReviewColor(reviewStatus);
    final proofUrl = (log['proof_url'] ?? '').toString();
    final remarks = (log['remarks'] ?? '').toString();
    final reviewRemarks = (log['review_remarks'] ?? '').toString();

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
      child: ExpansionTile(
        tilePadding: const EdgeInsets.fromLTRB(15, 10, 15, 8),
        childrenPadding: const EdgeInsets.fromLTRB(15, 0, 15, 15),
        leading: CircleAvatar(
          backgroundColor: categoryColor.withOpacity(0.12),
          child: Icon(
            getCategoryIcon(category),
            color: categoryColor,
          ),
        ),
        title: Text(
          getTaskTitle(log),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: mulberryDark,
            fontWeight: FontWeight.bold,
            fontSize: 15.5,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Text(
            '${formatValue(category)} • ${getStaffName(log)} (${formatValue(getStaffRole(log))})',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        trailing: buildStatusBadge(
          formatValue(reviewStatus).toUpperCase(),
          reviewColor,
        ),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              getTaskDescription(log),
              style: const TextStyle(
                color: mulberryDark,
                height: 1.35,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              buildInfoChip(
                Icons.calendar_today_rounded,
                'Task date: ${formatDateTime(log['task_date'])}',
              ),
              buildInfoChip(
                Icons.task_alt_rounded,
                'Task status: ${formatValue(getTaskStatus(log))}',
              ),
              buildInfoChip(
                getReviewIcon(reviewStatus),
                'Review: ${formatValue(reviewStatus)}',
              ),
              buildInfoChip(
                Icons.schedule_rounded,
                'Completed: ${formatDateTime(log['completed_at'])}',
              ),
              if (log['reviewed_at'] != null)
                buildInfoChip(
                  Icons.rate_review_rounded,
                  'Reviewed: ${formatDateTime(log['reviewed_at'])}',
                ),
            ],
          ),
          if (remarks.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            buildNoteBox(
              title: 'Staff remarks',
              text: remarks,
              icon: Icons.notes_rounded,
              color: mulberry,
            ),
          ],
          if (reviewRemarks.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            buildNoteBox(
              title: 'Review remarks',
              text: reviewRemarks,
              icon: Icons.feedback_rounded,
              color: reviewColor,
            ),
          ],
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
        ],
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
          fontSize: 10.5,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget buildInfoChip(IconData icon, String text) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 370),
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

  Widget buildNoteBox({
    required String title,
    required String text,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 19),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 12.5,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  text,
                  style: const TextStyle(
                    color: mulberryDark,
                    height: 1.35,
                  ),
                ),
              ],
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
      appBar: AppBar(
        title: const Text(
          'Checklist History',
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
            onPressed: loadHistory,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(color: mulberry),
            )
          : RefreshIndicator(
              color: mulberry,
              onRefresh: loadHistory,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
                child: Column(
                  children: [
                    buildHeaderCard(),
                    const SizedBox(height: 12),
                    buildModeTabs(),
                    const SizedBox(height: 12),
                    buildSummaryCards(),
                    const SizedBox(height: 12),
                    buildDateActionRow(),
                    const SizedBox(height: 12),
                    buildSearchAndFilters(),
                    const SizedBox(height: 2),
                    Expanded(
                      child: TabBarView(
                        controller: tabController,
                        children: [
                          buildHistoryList(),
                          buildHistoryList(),
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