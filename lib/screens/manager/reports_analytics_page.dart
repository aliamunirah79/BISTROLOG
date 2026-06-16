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
  int selectedRangeDays = 7;

  List<Map<String, dynamic>> inventoryItems = [];
  List<Map<String, dynamic>> lowStockItems = [];
  List<Map<String, dynamic>> stockMovements = [];
  List<Map<String, dynamic>> dailyStockCounts = [];
  List<Map<String, dynamic>> checklistLogs = [];
  List<Map<String, dynamic>> inventoryUsageSummary = [];

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

  String get startDateText {
    final date = DateTime.now().subtract(Duration(days: selectedRangeDays - 1));
    return date.toIso8601String().substring(0, 10);
  }

  String get endDateText {
    return DateTime.now().toIso8601String().substring(0, 10);
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
          .select()
          .gte('count_date', startDateText)
          .lte('count_date', endDateText)
          .eq('count_type', 'closing')
          .order('created_at', ascending: false);

      final checklistResponse = await supabase
          .from('cleaning_task_logs')
          .select()
          .gte('task_date', startDateText)
          .lte('task_date', endDateText)
          .order('created_at', ascending: false);

      if (!mounted) return;

      setState(() {
        inventoryItems = List<Map<String, dynamic>>.from(inventoryResponse);
        lowStockItems = List<Map<String, dynamic>>.from(lowStockResponse);
        stockMovements = List<Map<String, dynamic>>.from(movementResponse);
        inventoryUsageSummary =
            List<Map<String, dynamic>>.from(usageSummaryResponse);
        dailyStockCounts = List<Map<String, dynamic>>.from(countResponse);
        checklistLogs = List<Map<String, dynamic>>.from(checklistResponse);
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

  int get totalInventoryItems {
    return inventoryItems.length;
  }

  int get lowStockCount {
    return lowStockItems.length;
  }

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

  int get checklistTotal {
    return checklistLogs.length;
  }

  double get checklistCompletionRate {
    if (checklistTotal == 0) {
      return 0;
    }

    return completedChecklistCount / checklistTotal;
  }

  double get checklistApprovalRate {
    if (completedChecklistCount == 0) {
      return 0;
    }

    return approvedChecklistCount / completedChecklistCount;
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

  List<Map<String, dynamic>> getLowStockItems() {
    final items = List<Map<String, dynamic>>.from(lowStockItems);

    items.sort((a, b) {
      final aQty = getCurrentQuantity(a);
      final bQty = getCurrentQuantity(b);
      return aQty.compareTo(bQty);
    });

    return items.take(6).toList();
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
                  '$startDateText to $endDateText',
                  style: const TextStyle(
                    color: creamDark,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Cafe operation summary based on inventory usage, low stock and cleaning compliance.',
                  style: TextStyle(
                    color: cream.withOpacity(0.92),
                    fontSize: 12.5,
                    height: 1.3,
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
    final ranges = [
      {'label': 'Today', 'days': 1},
      {'label': '7 Days', 'days': 7},
      {'label': '30 Days', 'days': 30},
    ];

    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: ranges.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final range = ranges[index];
          final selected = selectedRangeDays == range['days'];

          return ChoiceChip(
            label: Text(range['label'].toString()),
            selected: selected,
            selectedColor: mulberry,
            backgroundColor: softWhite,
            side: BorderSide(
              color: selected ? mulberry : creamDark,
            ),
            elevation: selected ? 3 : 0,
            labelStyle: TextStyle(
              color: selected ? cream : mulberry,
              fontWeight: FontWeight.bold,
            ),
            onSelected: (_) async {
              setState(() {
                selectedRangeDays = range['days'] as int;
              });

              await loadReportData();
            },
          );
        },
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
                  ],
                ),
              ),
            ],
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
          const SizedBox(height: 4),
          Text(
            'Based on inventory_usage_summary estimated usage.',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 14),
          if (items.isEmpty)
            buildEmptyText('No usage summary found for this period.')
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
    final completionPercent = checklistCompletionRate.clamp(0.0, 1.0);
    final approvalPercent = checklistApprovalRate.clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: buildWhiteBox(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          buildSectionTitle('Checklist Performance', Icons.check_circle),
          const SizedBox(height: 14),
          buildProgressMetric(
            label: 'Completion Rate',
            value: completionPercent,
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
        ],
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
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: buildWhiteBox(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          buildSectionTitle('Stock Count Review', Icons.verified),
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
    final items = getLowStockItems();

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: buildWhiteBox(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          buildSectionTitle('Low Stock Items', Icons.warning_amber),
          const SizedBox(height: 4),
          Text(
            'Based on low_stock_view.',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          if (items.isEmpty)
            buildEmptyText('No low stock item found.')
          else
            ...items.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;

              return buildRankedItem(
                rank: index + 1,
                title: getItemName(item),
                subtitle: getCategory(item),
                trailing:
                    '${formatNumber(getCurrentQuantity(item))} / min ${formatNumber(getMinimumQuantity(item))} ${getUnit(item)}',
                color: const Color(0xFFD32F2F),
              );
            }),
        ],
      ),
    );
  }

  Widget buildRankedItem({
    required int rank,
    required String title,
    required String subtitle,
    required String trailing,
    required Color color,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: cream,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: creamDark.withOpacity(0.7),
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: color.withOpacity(0.13),
            child: Text(
              rank.toString(),
              style: TextStyle(
                color: color,
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
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              trailing,
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ],
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