import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ReportsAnalyticsPage extends StatefulWidget {
  final bool showAppBar;

  const ReportsAnalyticsPage({
    super.key,
    this.showAppBar = true,
  });

  @override
  State<ReportsAnalyticsPage> createState() => _ReportsAnalyticsPageState();
}

class _ReportsAnalyticsPageState extends State<ReportsAnalyticsPage> {
  final supabase = Supabase.instance.client;

  bool isLoading = true;

  DateTime selectedWeekDate = DateTime.now();

  List<Map<String, dynamic>> inventoryItems = [];
  List<Map<String, dynamic>> lowStockItems = [];
  List<Map<String, dynamic>> stockMovements = [];
  List<Map<String, dynamic>> dailyStockCounts = [];
  List<Map<String, dynamic>> checklistLogs = [];
  List<Map<String, dynamic>> inventoryUsageSummary = [];
  List<Map<String, dynamic>> activeCleaningTasks = [];
  List<Map<String, dynamic>> activeStaffMembers = [];

  static const Color mulberry = Color(0xFF6D2B50);
  static const Color mulberryDark = Color(0xFF4A1A35);
  static const Color mulberryLight = Color(0xFF8B3D68);
  static const Color cream = Color(0xFFF5ECD7);
  static const Color creamDark = Color(0xFFE8D5B5);
  static const Color softWhite = Color(0xFFFFFCF7);

  @override
  void initState() {
    super.initState();
    loadReportData();
  }

  DateTime get selectedWeekStart {
    final cleanDate = DateTime(
      selectedWeekDate.year,
      selectedWeekDate.month,
      selectedWeekDate.day,
    );

    return cleanDate.subtract(Duration(days: cleanDate.weekday - 1));
  }

  DateTime get selectedWeekEnd {
    return selectedWeekStart.add(const Duration(days: 6));
  }

  String get startDateText {
    return selectedWeekStart.toIso8601String().substring(0, 10);
  }

  String get endDateText {
    return selectedWeekEnd.toIso8601String().substring(0, 10);
  }

  String formatDateOnly(DateTime date) {
    final year = date.year.toString();
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');

    return '$year-$month-$day';
  }

  String get selectedWeekRangeText {
    return '${formatDateOnly(selectedWeekStart)} - ${formatDateOnly(selectedWeekEnd)}';
  }

  Future<void> goToPreviousWeek() async {
    setState(() {
      selectedWeekDate = selectedWeekDate.subtract(const Duration(days: 7));
    });

    await loadReportData();
  }

  Future<void> goToNextWeek() async {
    setState(() {
      selectedWeekDate = selectedWeekDate.add(const Duration(days: 7));
    });

    await loadReportData();
  }

  Future<void> pickReportWeek() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedWeekDate,
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
      selectedWeekDate = picked;
    });

    await loadReportData();
  }

  Future<void> loadReportData() async {
    if (!mounted) return;

    setState(() {
      isLoading = true;
    });

    try {
      final inventoryResponse = await supabase
          .from('inventory_items')
          .select()
          .eq('is_active', true)
          .order('item_name', ascending: true);

      final lowStockResponse = await supabase
          .from('low_stock_view')
          .select()
          .order('current_quantity', ascending: true);

      final movementResponse = await supabase
          .from('stock_movements')
          .select()
          .gte('created_at', '$startDateText 00:00:00')
          .lte('created_at', '$endDateText 23:59:59')
          .order('created_at', ascending: false);

      final usageSummaryResponse = await supabase
          .from('inventory_usage_summary')
          .select()
          .gte('usage_date', startDateText)
          .lte('usage_date', endDateText)
          .order('usage_date', ascending: false);

      final countResponse = await supabase
          .from('daily_stock_counts')
          .select('''
            *,
            inventory_items:item_id (
              item_id,
              item_name,
              category,
              unit,
              current_quantity,
              minimum_quantity
            )
          ''')
          .gte('count_date', startDateText)
          .lte('count_date', endDateText)
          .eq('count_type', 'closing')
          .order('created_at', ascending: false);

      final checklistResponse = await supabase
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
            created_at,
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
          .gte('task_date', startDateText)
          .lte('task_date', endDateText)
          .order('task_date', ascending: false);

      final cleaningTasksResponse = await supabase
          .from('cleaning_tasks')
          .select('task_id, title, category, proof_required, is_active')
          .eq('is_active', true);

      final staffResponse = await supabase
          .from('profiles')
          .select('id, full_name, role, is_active, staff_status')
          .eq('is_active', true)
          .eq('staff_status', 'active');

      if (!mounted) return;

      setState(() {
        inventoryItems = List<Map<String, dynamic>>.from(inventoryResponse);
        lowStockItems = List<Map<String, dynamic>>.from(lowStockResponse);
        stockMovements = List<Map<String, dynamic>>.from(movementResponse);
        inventoryUsageSummary =
            List<Map<String, dynamic>>.from(usageSummaryResponse);
        dailyStockCounts = List<Map<String, dynamic>>.from(countResponse);
        checklistLogs = List<Map<String, dynamic>>.from(checklistResponse);
        activeCleaningTasks =
            List<Map<String, dynamic>>.from(cleaningTasksResponse);

        activeStaffMembers = List<Map<String, dynamic>>.from(staffResponse)
            .where((staff) {
          final role = (staff['role'] ?? '').toString();
          return role == 'staff' || role == 'supervisor';
        }).toList();

        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
      });

      showMessage('Failed to load reports: $e', isError: true);
    }
  }

  String getItemId(Map<String, dynamic> item) {
    return (item['item_id'] ??
            item['inventory_id'] ??
            item['id'] ??
            item['product_id'] ??
            '')
        .toString();
  }

  String getItemName(Map<String, dynamic> item) {
    return (item['item_name'] ??
            item['name'] ??
            item['product_name'] ??
            item['ingredient_name'] ??
            'Unnamed Item')
        .toString();
  }

  String getCategory(Map<String, dynamic> item) {
    return (item['category'] ?? item['item_category'] ?? 'Uncategorized')
        .toString();
  }

  String getUnit(Map<String, dynamic> item) {
    return (item['unit'] ?? item['uom'] ?? item['measurement_unit'] ?? 'unit')
        .toString();
  }

  num getCurrentQuantity(Map<String, dynamic> item) {
    final value = item['current_quantity'] ??
        item['quantity'] ??
        item['stock_quantity'] ??
        item['stock'] ??
        item['current_stock'] ??
        0;

    return num.tryParse(value.toString()) ?? 0;
  }

  num getMinimumQuantity(Map<String, dynamic> item) {
    final value = item['minimum_quantity'] ??
        item['min_quantity'] ??
        item['minimum_stock'] ??
        item['min_stock'] ??
        item['reorder_level'] ??
        0;

    return num.tryParse(value.toString()) ?? 0;
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

  String formatNumber(dynamic value) {
    if (value == null) {
      return '0';
    }

    final number = num.tryParse(value.toString()) ?? 0;

    if (number % 1 == 0) {
      return number.toInt().toString();
    }

    return number.toStringAsFixed(2);
  }

  Map<String, dynamic>? getItemById(String itemId) {
    try {
      return inventoryItems.firstWhere(
        (item) => getItemId(item) == itemId,
      );
    } catch (_) {
      return null;
    }
  }

  int get totalInventoryItems => inventoryItems.length;

  int get lowStockCount => lowStockItems.length;

  int get stockInCount {
    return stockMovements.where((movement) {
      return movement['movement_type']?.toString() == 'stock_in';
    }).length;
  }

  int get stockOutCount {
    return stockMovements.where((movement) {
      final type = movement['movement_type']?.toString();
      return type == 'stock_out' || type == 'daily_usage';
    }).length;
  }

  int get pendingStockCount {
    return dailyStockCounts.where((count) {
      return (count['review_status'] ?? 'pending').toString() == 'pending';
    }).length;
  }

  int get approvedStockCount {
    return dailyStockCounts.where((count) {
      return (count['review_status'] ?? '').toString() == 'approved';
    }).length;
  }

  int get rejectedStockCount {
    return dailyStockCounts.where((count) {
      return (count['review_status'] ?? '').toString() == 'rejected';
    }).length;
  }

  int get totalStockCountReviews {
    return pendingStockCount + approvedStockCount + rejectedStockCount;
  }

  double get stockApprovalRate {
    if (totalStockCountReviews == 0) return 0;
    return approvedStockCount / totalStockCountReviews;
  }

  int get completedChecklistCount {
    return checklistLogs.where((log) {
      return (log['status'] ?? '').toString() == 'completed';
    }).length;
  }

  int get approvedChecklistCount {
    return checklistLogs.where((log) {
      return (log['review_status'] ?? '').toString() == 'approved';
    }).length;
  }

  int get rejectedChecklistCount {
    return checklistLogs.where((log) {
      return (log['review_status'] ?? '').toString() == 'rejected';
    }).length;
  }

  int get pendingChecklistReviewCount {
    return checklistLogs.where((log) {
      final status = (log['status'] ?? '').toString();
      final review = (log['review_status'] ?? 'pending').toString();

      return status == 'completed' && review == 'pending';
    }).length;
  }

  int get openingTaskCount {
    return activeCleaningTasks.where((task) {
      return (task['category'] ?? '').toString() == 'opening';
    }).length;
  }

  int get closingTaskCount {
    return activeCleaningTasks.where((task) {
      return (task['category'] ?? '').toString() == 'closing';
    }).length;
  }

  int get weeklyTaskCount {
    return activeCleaningTasks.where((task) {
      return (task['category'] ?? '').toString() == 'weekly';
    }).length;
  }

  int get expectedChecklistPerStaff {
    return ((openingTaskCount + closingTaskCount) * 7) + weeklyTaskCount;
  }

  double get checklistCompletionRate {
    final expectedTotal = expectedChecklistPerStaff * activeStaffMembers.length;

    if (expectedTotal == 0) {
      return 0;
    }

    return completedChecklistCount / expectedTotal;
  }

  double get checklistApprovalRate {
    if (completedChecklistCount == 0) {
      return 0;
    }

    return approvedChecklistCount / completedChecklistCount;
  }

  String getStaffFullName(Map<String, dynamic> staff) {
    return (staff['full_name'] ?? 'Unknown Staff').toString();
  }

  String getStaffRole(Map<String, dynamic> staff) {
    return (staff['role'] ?? 'staff').toString();
  }

  List<Map<String, dynamic>> getWeeklyStaffChecklistReport() {
    final Map<String, Map<String, dynamic>> reportMap = {};

    for (final staff in activeStaffMembers) {
      final staffId = staff['id']?.toString() ?? '';

      if (staffId.isEmpty) continue;

      reportMap[staffId] = {
        'staff_id': staffId,
        'staff_name': getStaffFullName(staff),
        'role': getStaffRole(staff),
        'expected': expectedChecklistPerStaff,
        'completed': 0,
        'approved': 0,
        'rejected': 0,
        'pending_review': 0,
      };
    }

    for (final log in checklistLogs) {
      final staffId = log['staff_id']?.toString() ?? '';

      if (staffId.isEmpty) continue;
      if (!reportMap.containsKey(staffId)) continue;

      final status = (log['status'] ?? '').toString();
      final reviewStatus = (log['review_status'] ?? 'pending').toString();

      final staffReport = reportMap[staffId]!;

      if (status == 'completed') {
        staffReport['completed'] = (staffReport['completed'] as int) + 1;
      }

      if (reviewStatus == 'approved') {
        staffReport['approved'] = (staffReport['approved'] as int) + 1;
      } else if (reviewStatus == 'rejected') {
        staffReport['rejected'] = (staffReport['rejected'] as int) + 1;
      } else if (status == 'completed' && reviewStatus == 'pending') {
        staffReport['pending_review'] =
            (staffReport['pending_review'] as int) + 1;
      }
    }

    final result = reportMap.values.toList();

    result.sort((a, b) {
      final aRate = getStaffCompletionRate(a);
      final bRate = getStaffCompletionRate(b);

      if (aRate != bRate) {
        return bRate.compareTo(aRate);
      }

      final aName = a['staff_name'].toString().toLowerCase();
      final bName = b['staff_name'].toString().toLowerCase();
      return aName.compareTo(bName);
    });

    return result;
  }

  int getStaffCompletionRate(Map<String, dynamic> staffReport) {
    final expected = staffReport['expected'] as int;
    final completed = staffReport['completed'] as int;

    if (expected == 0) return 0;

    return ((completed / expected) * 100).round();
  }

  List<Map<String, dynamic>> getMostUsedItems() {
    final usageMap = <String, num>{};

    for (final summary in inventoryUsageSummary) {
      final itemId = summary['item_id']?.toString();

      if (itemId == null || itemId.isEmpty) {
        continue;
      }

      final usage = num.tryParse(
            (summary['estimated_usage'] ?? 0).toString(),
          ) ??
          0;

      if (usage <= 0) {
        continue;
      }

      usageMap[itemId] = (usageMap[itemId] ?? 0) + usage;
    }

    final result = usageMap.entries.map((entry) {
      final item = getItemById(entry.key);

      return {
        'item_id': entry.key,
        'item_name': item == null ? 'Unknown Item' : getItemName(item),
        'category': item == null ? '-' : getCategory(item),
        'unit': item == null ? 'unit' : getUnit(item),
        'total_used': entry.value,
      };
    }).toList();

    result.sort((a, b) {
      final aUsed = num.tryParse(a['total_used'].toString()) ?? 0;
      final bUsed = num.tryParse(b['total_used'].toString()) ?? 0;
      return bUsed.compareTo(aUsed);
    });

    return result.take(5).toList();
  }

  List<Map<String, dynamic>> getCriticalLowStockItems() {
    final items = List<Map<String, dynamic>>.from(lowStockItems);

    items.sort((a, b) {
      final aGap = getMinimumQuantity(a) - getCurrentQuantity(a);
      final bGap = getMinimumQuantity(b) - getCurrentQuantity(b);
      return bGap.compareTo(aGap);
    });

    return items.take(8).toList();
  }

  double getStockLevelRatio(Map<String, dynamic> item) {
    final current = getCurrentQuantity(item);
    final minimum = getMinimumQuantity(item);

    if (minimum <= 0) return 0;

    return (current / minimum).clamp(0.0, 1.0).toDouble();
  }

  String getLowStockSeverity(Map<String, dynamic> item) {
    final current = getCurrentQuantity(item);
    final minimum = getMinimumQuantity(item);

    if (minimum <= 0) return 'Monitor';

    final ratio = current / minimum;

    if (ratio <= 0.25) return 'Critical';
    if (ratio <= 0.50) return 'Very Low';
    return 'Low';
  }

  Color getLowStockSeverityColor(String severity) {
    if (severity == 'Critical') return const Color(0xFFD32F2F);
    if (severity == 'Very Low') return const Color(0xFFEF6C00);
    return const Color(0xFFF9A825);
  }

  List<Map<String, dynamic>> getRecentStockCounts() {
    final list = List<Map<String, dynamic>>.from(dailyStockCounts);

    list.sort((a, b) {
      final aDate = (a['created_at'] ?? a['count_date'] ?? '').toString();
      final bDate = (b['created_at'] ?? b['count_date'] ?? '').toString();
      return bDate.compareTo(aDate);
    });

    return list.take(6).toList();
  }

  String getStockCountItemName(Map<String, dynamic> count) {
    final item = count['inventory_items'];

    if (item is Map<String, dynamic>) {
      final name = (item['item_name'] ?? item['name'] ?? '').toString().trim();

      if (name.isNotEmpty) {
        return name;
      }
    }

    if (item is Map) {
      final mappedItem = Map<String, dynamic>.from(item);
      final name =
          (mappedItem['item_name'] ?? mappedItem['name'] ?? '').toString().trim();

      if (name.isNotEmpty) {
        return name;
      }
    }

    return (count['item_name'] ??
            count['product_name'] ??
            count['ingredient_name'] ??
            count['name'] ??
            'Unknown Stock Item')
        .toString();
  }

  String getStockCountItemCategory(Map<String, dynamic> count) {
    final item = count['inventory_items'];

    if (item is Map<String, dynamic>) {
      final category = (item['category'] ?? '').toString().trim();

      if (category.isNotEmpty) {
        return formatValue(category);
      }
    }

    if (item is Map) {
      final mappedItem = Map<String, dynamic>.from(item);
      final category = (mappedItem['category'] ?? '').toString().trim();

      if (category.isNotEmpty) {
        return formatValue(category);
      }
    }

    return 'Uncategorized';
  }

  String getStockCountDate(Map<String, dynamic> count) {
    return (count['count_date'] ??
            count['stock_date'] ??
            count['created_at'] ??
            '-')
        .toString();
  }

  String getStockCountStatus(Map<String, dynamic> count) {
    return (count['review_status'] ?? 'pending').toString();
  }

  String getStockCountQtyText(Map<String, dynamic> count) {
    final opening = count['opening_quantity'] ??
        count['opening_qty'] ??
        count['system_quantity'] ??
        count['previous_quantity'];

    final closing = count['closing_quantity'] ??
        count['closing_qty'] ??
        count['actual_quantity'] ??
        count['counted_quantity'];

    final usage = count['usage_quantity'] ??
        count['estimated_usage'] ??
        count['difference_quantity'] ??
        count['variance'];

    if (opening != null || closing != null || usage != null) {
      return 'Opening: ${formatNumber(opening)} • Closing: ${formatNumber(closing)} • Usage/Variance: ${formatNumber(usage)}';
    }

    return 'Quantity detail unavailable';
  }

  Color getStockReviewColor(String status) {
    if (status == 'approved') return const Color(0xFF2E7D32);
    if (status == 'rejected') return const Color(0xFFD32F2F);
    return const Color(0xFFEF6C00);
  }

  Widget buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
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
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: mulberryDark.withOpacity(0.20),
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
              color: cream.withOpacity(0.18),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.analytics,
              color: cream,
              size: 32,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Reports & Analytics',
                  style: TextStyle(
                    color: cream,
                    fontFamily: 'Georgia',
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'Weekly report: $selectedWeekRangeText',
                  style: const TextStyle(
                    color: creamDark,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget buildRangeSelector() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: softWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: creamDark.withOpacity(0.85),
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
          IconButton(
            tooltip: 'Previous Week',
            onPressed: goToPreviousWeek,
            icon: const Icon(
              Icons.chevron_left_rounded,
              color: mulberry,
              size: 30,
            ),
          ),
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: pickReportWeek,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  children: [
                    Text(
                      'Selected Week',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      selectedWeekRangeText,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: mulberry,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Next Week',
            onPressed: goToNextWeek,
            icon: const Icon(
              Icons.chevron_right_rounded,
              color: mulberry,
              size: 30,
            ),
          ),
        ],
      ),
    );
  }

  Widget buildSummaryGrid() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: buildSummaryCard(
                title: 'Inventory Items',
                value: totalInventoryItems.toString(),
                icon: Icons.inventory_2,
                color: mulberry,
                backgroundColor: cream,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: buildSummaryCard(
                title: 'Low Stock',
                value: lowStockCount.toString(),
                icon: Icons.warning_amber,
                color: const Color(0xFFD32F2F),
                backgroundColor: const Color(0xFFFFEBEE),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: buildSummaryCard(
                title: 'Stock In',
                value: stockInCount.toString(),
                icon: Icons.add_circle,
                color: const Color(0xFF2E7D32),
                backgroundColor: const Color(0xFFE8F5E9),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: buildSummaryCard(
                title: 'Stock Out',
                value: stockOutCount.toString(),
                icon: Icons.remove_circle,
                color: const Color(0xFFEF6C00),
                backgroundColor: const Color(0xFFFFF3E0),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget buildSummaryCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required Color backgroundColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: softWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color.withOpacity(0.12),
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 23,
            backgroundColor: backgroundColor,
            child: Icon(
              icon,
              color: color,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    color: color,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget buildChartDashboard() {
    return Column(
      children: [
        buildStockDonutChart(),
        const SizedBox(height: 14),
        buildMostUsedBarChart(),
        const SizedBox(height: 14),
        buildChecklistProgressPanel(),
      ],
    );
  }

  Widget buildStockDonutChart() {
    final pending = pendingStockCount.toDouble();
    final approved = approvedStockCount.toDouble();
    final rejected = rejectedStockCount.toDouble();
    final total = pending + approved + rejected;
    final approvalRate = stockApprovalRate.clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: buildWhiteBox(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          buildSectionTitle('Stock Count Status', Icons.donut_large),
          const SizedBox(height: 14),
          Row(
            children: [
              SizedBox(
                width: 135,
                height: 135,
                child: CustomPaint(
                  painter: DonutChartPainter(
                    values: [
                      approved,
                      pending,
                      rejected,
                    ],
                    colors: const [
                      Color(0xFF2E7D32),
                      Color(0xFFEF6C00),
                      Color(0xFFD32F2F),
                    ],
                    backgroundColor: creamDark,
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          formatNumber(total),
                          style: const TextStyle(
                            color: mulberry,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'records',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  children: [
                    buildLegendRow(
                      label: 'Approved',
                      value: approvedStockCount.toString(),
                      color: const Color(0xFF2E7D32),
                    ),
                    buildLegendRow(
                      label: 'Pending',
                      value: pendingStockCount.toString(),
                      color: const Color(0xFFEF6C00),
                    ),
                    buildLegendRow(
                      label: 'Rejected',
                      value: rejectedStockCount.toString(),
                      color: const Color(0xFFD32F2F),
                    ),
                    const SizedBox(height: 8),
                    buildProgressMetric(
                      label: 'Stock Count Approval Rate',
                      value: approvalRate,
                      color: const Color(0xFF2E7D32),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (total == 0)
            buildEmptyText('No stock count review submitted for this week.')
          else
            buildStockStatusInsightBox(),
        ],
      ),
    );
  }

  Widget buildStockStatusInsightBox() {
    String message;
    Color color;
    IconData icon;

    if (pendingStockCount > 0) {
      message =
          '$pendingStockCount stock count record(s) still need manager review.';
      color = const Color(0xFFEF6C00);
      icon = Icons.hourglass_top_rounded;
    } else if (rejectedStockCount > 0) {
      message =
          '$rejectedStockCount stock count record(s) were rejected and may need correction.';
      color = const Color(0xFFD32F2F);
      icon = Icons.error_outline_rounded;
    } else {
      message = 'All submitted stock count records are approved this week.';
      color = const Color(0xFF2E7D32);
      icon = Icons.verified_rounded;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: color.withOpacity(0.18),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildLegendRow({
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      child: Row(
        children: [
          Container(
            width: 11,
            height: 11,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: mulberryDark,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget buildMostUsedBarChart() {
    final items = getMostUsedItems();

    num maxUsage = 0;

    for (final item in items) {
      final usage = num.tryParse(item['total_used'].toString()) ?? 0;

      if (usage > maxUsage) {
        maxUsage = usage;
      }
    }

    final chartColors = [
      mulberry,
      const Color(0xFF1976D2),
      const Color(0xFF00897B),
      const Color(0xFFEF6C00),
      const Color(0xFFD32F2F),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: buildWhiteBox(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          buildSectionTitle('Most Used Items', Icons.bar_chart),
          const SizedBox(height: 14),
          if (items.isEmpty)
            buildEmptyText('No usage summary found for this week.')
          else
            ...items.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              final usage = num.tryParse(item['total_used'].toString()) ?? 0;
              final unit = item['unit'].toString();

              final percent = maxUsage == 0 ? 0.0 : usage / maxUsage;

              return buildUsageBar(
                rank: index + 1,
                title: item['item_name'].toString(),
                subtitle: item['category'].toString(),
                value: '${formatNumber(usage)} $unit',
                percent: percent,
                color: chartColors[index % chartColors.length],
              );
            }),
        ],
      ),
    );
  }

  Widget buildUsageBar({
    required int rank,
    required String title,
    required String subtitle,
    required String value,
    required double percent,
    required Color color,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: color.withOpacity(0.12),
                child: Text(
                  rank.toString(),
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: mulberryDark,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: LinearProgressIndicator(
              value: percent.clamp(0.0, 1.0),
              minHeight: 9,
              backgroundColor: color.withOpacity(0.10),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildChecklistProgressPanel() {
    final weeklyReports = getWeeklyStaffChecklistReport();
    final overallCompletionPercent = checklistCompletionRate.clamp(0.0, 1.0);
    final approvalPercent = checklistApprovalRate.clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: buildWhiteBox(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          buildSectionTitle(
            'Weekly Staff Checklist Completion',
            Icons.assignment_turned_in,
          ),
          const SizedBox(height: 14),
          buildProgressMetric(
            label: 'Overall Weekly Completion',
            value: overallCompletionPercent,
            color: const Color(0xFF1976D2),
          ),
          const SizedBox(height: 12),
          buildProgressMetric(
            label: 'Approval Rate',
            value: approvalPercent,
            color: const Color(0xFF2E7D32),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: buildMiniStatusCard(
                  'Completed',
                  completedChecklistCount.toString(),
                  const Color(0xFF1976D2),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: buildMiniStatusCard(
                  'Approved',
                  approvedChecklistCount.toString(),
                  const Color(0xFF2E7D32),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: buildMiniStatusCard(
                  'Rejected',
                  rejectedChecklistCount.toString(),
                  const Color(0xFFD32F2F),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          buildMiniStatusCard(
            'Pending Manager Review',
            pendingChecklistReviewCount.toString(),
            const Color(0xFFEF6C00),
          ),
          const SizedBox(height: 16),
          if (weeklyReports.isEmpty)
            buildEmptyText('No active staff found for checklist report.')
          else
            buildWeeklyStaffCompletionTable(weeklyReports),
        ],
      ),
    );
  }

  Widget buildWeeklyStaffCompletionTable(
    List<Map<String, dynamic>> weeklyReports,
  ) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: cream,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: creamDark.withOpacity(0.75),
        ),
      ),
      child: Column(
        children: [
          buildWeeklyTableHeader(),
          ...weeklyReports.map(buildWeeklyTableRow),
        ],
      ),
    );
  }

  Widget buildWeeklyTableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
      decoration: const BoxDecoration(
        color: mulberry,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
      child: const Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              'Staff',
              style: TextStyle(
                color: cream,
                fontWeight: FontWeight.bold,
                fontSize: 11.5,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'Completion',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: cream,
                fontWeight: FontWeight.bold,
                fontSize: 11.5,
              ),
            ),
          ),
          Expanded(
            child: Text(
              'Appr.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: cream,
                fontWeight: FontWeight.bold,
                fontSize: 11.5,
              ),
            ),
          ),
          Expanded(
            child: Text(
              'Reject',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: cream,
                fontWeight: FontWeight.bold,
                fontSize: 11.5,
              ),
            ),
          ),
          Expanded(
            child: Text(
              'Pend.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: cream,
                fontWeight: FontWeight.bold,
                fontSize: 11.5,
              ),
            ),
          ),
          Expanded(
            child: Text(
              'Rate',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: cream,
                fontWeight: FontWeight.bold,
                fontSize: 11.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildWeeklyTableRow(Map<String, dynamic> staffReport) {
    final expected = staffReport['expected'] as int;
    final completed = staffReport['completed'] as int;
    final approved = staffReport['approved'] as int;
    final rejected = staffReport['rejected'] as int;
    final pendingReview = staffReport['pending_review'] as int;
    final rate = getStaffCompletionRate(staffReport);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
      decoration: BoxDecoration(
        color: softWhite,
        border: Border(
          bottom: BorderSide(
            color: creamDark.withOpacity(0.65),
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 15,
                  backgroundColor: mulberry.withOpacity(0.12),
                  child: const Icon(
                    Icons.person,
                    color: mulberry,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        staffReport['staff_name'].toString(),
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: mulberryDark,
                          fontWeight: FontWeight.bold,
                          fontSize: 12.5,
                        ),
                      ),
                      Text(
                        formatValue(staffReport['role'].toString()),
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              '$completed/$expected',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF1976D2),
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: buildTableNumber(
              approved.toString(),
              const Color(0xFF2E7D32),
            ),
          ),
          Expanded(
            child: buildTableNumber(
              rejected.toString(),
              const Color(0xFFD32F2F),
            ),
          ),
          Expanded(
            child: buildTableNumber(
              pendingReview.toString(),
              const Color(0xFFEF6C00),
            ),
          ),
          Expanded(
            child: buildRateBadge(rate),
          ),
        ],
      ),
    );
  }

  Widget buildTableNumber(String value, Color color) {
    return Text(
      value,
      textAlign: TextAlign.center,
      style: TextStyle(
        color: color,
        fontSize: 12,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget buildRateBadge(int rate) {
    Color color;

    if (rate >= 90) {
      color = const Color(0xFF2E7D32);
    } else if (rate >= 60) {
      color = const Color(0xFFEF6C00);
    } else {
      color = const Color(0xFFD32F2F);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '$rate%',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget buildProgressMetric({
    required String label,
    required double value,
    required Color color,
  }) {
    final percent = (value * 100).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: mulberryDark,
                ),
              ),
            ),
            Text(
              '$percent%',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 7),
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: LinearProgressIndicator(
            value: value.clamp(0.0, 1.0),
            minHeight: 10,
            backgroundColor: color.withOpacity(0.10),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }

  Widget buildStockCountReport() {
    final recentCounts = getRecentStockCounts();

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: buildWhiteBox(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          buildSectionTitle('Stock Count Review Details', Icons.verified),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: buildMiniStatusCard(
                  'Pending',
                  pendingStockCount.toString(),
                  const Color(0xFFEF6C00),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: buildMiniStatusCard(
                  'Approved',
                  approvedStockCount.toString(),
                  const Color(0xFF2E7D32),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: buildMiniStatusCard(
                  'Rejected',
                  rejectedStockCount.toString(),
                  const Color(0xFFD32F2F),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (recentCounts.isEmpty)
            buildEmptyText('No stock count records found for this week.')
          else
            ...recentCounts.map(buildStockCountDetailCard),
        ],
      ),
    );
  }

  Widget buildStockCountDetailCard(Map<String, dynamic> count) {
    final status = getStockCountStatus(count);
    final color = getStockReviewColor(status);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cream,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: creamDark.withOpacity(0.75),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 17,
            backgroundColor: color.withOpacity(0.12),
            child: Icon(
              status == 'approved'
                  ? Icons.verified_rounded
                  : status == 'rejected'
                      ? Icons.cancel_rounded
                      : Icons.hourglass_top_rounded,
              color: color,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  getStockCountItemName(count),
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: mulberryDark,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  getStockCountItemCategory(count),
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  getStockCountQtyText(count),
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontSize: 11.8,
                    fontWeight: FontWeight.w600,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'Date: ${getStockCountDate(count)}',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          buildSmallStatusPill(
            formatValue(status),
            color,
          ),
        ],
      ),
    );
  }

  Widget buildMiniStatusCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 12,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: color.withOpacity(0.18),
        ),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget buildLowStockItems() {
    final items = getCriticalLowStockItems();

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: buildWhiteBox(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          buildSectionTitle('Low Stock Item Details', Icons.warning_amber),
          const SizedBox(height: 12),
          if (items.isEmpty)
            buildEmptyText('No low stock item found.')
          else
            ...items.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;

              return buildLowStockDetailCard(
                rank: index + 1,
                item: item,
              );
            }),
        ],
      ),
    );
  }

  Widget buildLowStockDetailCard({
    required int rank,
    required Map<String, dynamic> item,
  }) {
    final current = getCurrentQuantity(item);
    final minimum = getMinimumQuantity(item);
    final shortage = minimum - current;
    final unit = getUnit(item);
    final severity = getLowStockSeverity(item);
    final severityColor = getLowStockSeverityColor(severity);
    final ratio = getStockLevelRatio(item);

    return Container(
      margin: const EdgeInsets.only(bottom: 11),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cream,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: severityColor.withOpacity(0.22),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: severityColor.withOpacity(0.13),
                child: Text(
                  rank.toString(),
                  style: TextStyle(
                    color: severityColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      getItemName(item),
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: mulberryDark,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      getCategory(item),
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              buildSmallStatusPill(severity, severityColor),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 9,
              backgroundColor: severityColor.withOpacity(0.12),
              valueColor: AlwaysStoppedAnimation<Color>(severityColor),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Current: ${formatNumber(current)} $unit',
                  style: const TextStyle(
                    color: mulberryDark,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                'Min: ${formatNumber(minimum)} $unit',
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            shortage > 0
                ? 'Shortage: ${formatNumber(shortage)} $unit below minimum level'
                : 'Stock is close to minimum level',
            style: TextStyle(
              color: severityColor,
              fontSize: 11.5,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget buildSmallStatusPill(String text, Color color) {
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
          fontSize: 10.8,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(
          icon,
          color: mulberry,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: mulberry,
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget buildEmptyText(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Text(
        text,
        style: TextStyle(
          color: Colors.grey.shade600,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  BoxDecoration buildWhiteBox() {
    return BoxDecoration(
      color: softWhite,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(
        color: creamDark.withOpacity(0.85),
      ),
      boxShadow: [
        BoxShadow(
          color: mulberryDark.withOpacity(0.05),
          blurRadius: 14,
          offset: const Offset(0, 6),
        ),
      ],
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
                'Reports & Analytics',
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
                  onPressed: loadReportData,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            )
          : null,
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: mulberry,
              ),
            )
          : RefreshIndicator(
              color: mulberry,
              onRefresh: loadReportData,
              child: ListView(
                padding: const EdgeInsets.all(18),
                children: [
                  buildHeader(),
                  const SizedBox(height: 14),
                  buildRangeSelector(),
                  const SizedBox(height: 14),
                  buildSummaryGrid(),
                  const SizedBox(height: 14),
                  buildChartDashboard(),
                  const SizedBox(height: 14),
                  buildStockCountReport(),
                  const SizedBox(height: 14),
                  buildLowStockItems(),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }
}

class DonutChartPainter extends CustomPainter {
  final List<double> values;
  final List<Color> colors;
  final Color backgroundColor;

  DonutChartPainter({
    required this.values,
    required this.colors,
    this.backgroundColor = const Color(0xFFE8D5B5),
  });

  @override
  void paint(Canvas canvas, Size size) {
    final total = values.fold<double>(0, (sum, value) => sum + value);

    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;
    final strokeWidth = radius * 0.24;

    final backgroundPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius - strokeWidth / 2, backgroundPaint);

    if (total <= 0) {
      return;
    }

    double startAngle = -math.pi / 2;

    for (int i = 0; i < values.length; i++) {
      final sweepAngle = (values[i] / total) * 2 * math.pi;

      if (sweepAngle <= 0) {
        continue;
      }

      final paint = Paint()
        ..color = colors[i % colors.length]
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      final rect = Rect.fromCircle(
        center: center,
        radius: radius - strokeWidth / 2,
      );

      canvas.drawArc(rect, startAngle, sweepAngle, false, paint);

      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant DonutChartPainter oldDelegate) {
    return oldDelegate.values != values ||
        oldDelegate.colors != colors ||
        oldDelegate.backgroundColor != backgroundColor;
  }
}