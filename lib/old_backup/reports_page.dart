import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  final supabase = Supabase.instance.client;

  static const Color mulberry = Color(0xFF6D2B50);
  static const Color mulberryDark = Color(0xFF4A1A35);
  static const Color mulberryLight = Color(0xFF8B3D68);
  static const Color cream = Color(0xFFF5ECD7);
  static const Color creamDark = Color(0xFFE8D5B5);

  String selectedRange = 'Daily';
  bool loading = true;

  int totalProducts = 0;
  int lowStockCount = 0;
  int pendingTasks = 0;
  int waitingApproval = 0;
  int approvedTasks = 0;
  int stockInTransactions = 0;
  int stockTakeTransactions = 0;

  double totalStockInQty = 0;
  double estimatedUsage = 0;

  List<Map<String, dynamic>> lowStockItems = [];
  List<Map<String, dynamic>> usageByProduct = [];
  List<Map<String, dynamic>> recentTransactions = [];

  @override
  void initState() {
    super.initState();
    loadReportData();
  }

  DateTime get _startDate {
    final now = DateTime.now();

    if (selectedRange == 'Weekly') {
      return DateTime(now.year, now.month, now.day)
          .subtract(Duration(days: now.weekday - 1));
    }

    if (selectedRange == 'Monthly') {
      return DateTime(now.year, now.month, 1);
    }

    return DateTime(now.year, now.month, now.day);
  }

  DateTime get _endDate {
    final start = _startDate;

    if (selectedRange == 'Weekly') {
      return start.add(const Duration(days: 7));
    }

    if (selectedRange == 'Monthly') {
      return DateTime(start.year, start.month + 1, 1);
    }

    return start.add(const Duration(days: 1));
  }

  Future<void> loadReportData() async {
    setState(() => loading = true);

    await Future.wait([
      _loadInventoryMetrics(),
      _loadTaskMetrics(),
      _loadStockTransactionMetrics(),
    ]);

    if (!mounted) return;
    setState(() => loading = false);
  }

  Future<void> _loadInventoryMetrics() async {
    try {
      final data = await supabase
          .from('product')
          .select('product_id, name, current_stock, min_threshold, base_unit')
          .order('name', ascending: true);

      final products = List<Map<String, dynamic>>.from(data);

      final lowItems = products.where((item) {
        final currentStock =
            double.tryParse((item['current_stock'] ?? 0).toString()) ?? 0;
        final minThreshold =
            double.tryParse((item['min_threshold'] ?? 0).toString()) ?? 0;

        return minThreshold > 0 && currentStock <= minThreshold;
      }).toList();

      if (!mounted) return;

      setState(() {
        totalProducts = products.length;
        lowStockItems = lowItems;
        lowStockCount = lowItems.length;
      });
    } catch (e) {
      debugPrint('Inventory report load error: $e');

      if (!mounted) return;

      setState(() {
        totalProducts = 0;
        lowStockItems = [];
        lowStockCount = 0;
      });
    }
  }

  Future<void> _loadTaskMetrics() async {
    try {
      final data = await supabase
          .from('task')
          .select('task_id, done, approved');

      final tasks = List<Map<String, dynamic>>.from(data);

      final pending = tasks.where((task) {
        return task['done'] != true;
      }).length;

      final waiting = tasks.where((task) {
        return task['done'] == true && task['approved'] != true;
      }).length;

      final approved = tasks.where((task) {
        return task['done'] == true && task['approved'] == true;
      }).length;

      if (!mounted) return;

      setState(() {
        pendingTasks = pending;
        waitingApproval = waiting;
        approvedTasks = approved;
      });
    } catch (e) {
      debugPrint('Task report load error: $e');

      if (!mounted) return;

      setState(() {
        pendingTasks = 0;
        waitingApproval = 0;
        approvedTasks = 0;
      });
    }
  }

  Future<void> _loadStockTransactionMetrics() async {
    try {
      final start = _startDate.toIso8601String();
      final end = _endDate.toIso8601String();

      final data = await supabase
          .from('stocktransaction')
          .select('''
            transaction_id,
            product_id,
            transaction_type,
            quantity,
            converted_qty,
            timestamp,
            product:product_id (
              product_id,
              name,
              base_unit
            )
          ''')
          .gte('timestamp', start)
          .lt('timestamp', end)
          .order('timestamp', ascending: false);

      final transactions = List<Map<String, dynamic>>.from(data);

      int stockInCount = 0;
      int stockTakeCount = 0;
      double stockInQty = 0;

      final Map<int, Map<String, dynamic>> grouped = {};

      for (final transaction in transactions) {
        final transactionType =
            (transaction['transaction_type'] ?? '').toString();

        final qty = double.tryParse(
              (transaction['converted_qty'] ??
                      transaction['quantity'] ??
                      0)
                  .toString(),
            ) ??
            0;

        if (transactionType == 'stock_in') {
          stockInCount++;
          stockInQty += qty;
        }

        if (transactionType == 'opening' || transactionType == 'closing') {
          stockTakeCount++;
        }

        final product = Map<String, dynamic>.from(
          transaction['product'] ?? {},
        );

        final productIdRaw = product['product_id'] ?? transaction['product_id'];
        final productId = int.tryParse(productIdRaw.toString());

        if (productId == null) continue;

        grouped.putIfAbsent(productId, () {
          return {
            'product_id': productId,
            'name': product['name']?.toString() ?? 'Unknown Product',
            'base_unit': product['base_unit']?.toString() ?? 'pcs',
            'opening': 0.0,
            'stock_in': 0.0,
            'closing': 0.0,
          };
        });

        if (transactionType == 'opening') {
          grouped[productId]!['opening'] =
              (grouped[productId]!['opening'] as double) + qty;
        } else if (transactionType == 'stock_in') {
          grouped[productId]!['stock_in'] =
              (grouped[productId]!['stock_in'] as double) + qty;
        } else if (transactionType == 'closing') {
          grouped[productId]!['closing'] =
              (grouped[productId]!['closing'] as double) + qty;
        }
      }

      final usageList = grouped.values.map((item) {
        final opening = item['opening'] as double;
        final stockIn = item['stock_in'] as double;
        final closing = item['closing'] as double;
        final usage = opening + stockIn - closing;

        return {
          ...item,
          'usage': usage < 0 ? 0.0 : usage,
        };
      }).toList();

      usageList.sort((a, b) {
        final bUsage = b['usage'] as double;
        final aUsage = a['usage'] as double;
        return bUsage.compareTo(aUsage);
      });

      final totalUsage = usageList.fold<double>(
        0,
        (sum, item) => sum + ((item['usage'] as double?) ?? 0),
      );

      if (!mounted) return;

      setState(() {
        stockInTransactions = stockInCount;
        stockTakeTransactions = stockTakeCount;
        totalStockInQty = stockInQty;
        estimatedUsage = totalUsage;
        usageByProduct = usageList.take(6).toList();
        recentTransactions = transactions.take(6).toList();
      });
    } catch (e) {
      debugPrint('Stock transaction report load error: $e');

      if (!mounted) return;

      setState(() {
        stockInTransactions = 0;
        stockTakeTransactions = 0;
        totalStockInQty = 0;
        estimatedUsage = 0;
        usageByProduct = [];
        recentTransactions = [];
      });
    }
  }

  String _formatNumber(num value) {
    if (value % 1 == 0) {
      return value.toInt().toString();
    }

    return value.toStringAsFixed(1);
  }

  String _formatDateTime(dynamic value) {
    if (value == null) return '-';

    try {
      final dt = DateTime.parse(value.toString()).toLocal();
      final day = dt.day.toString().padLeft(2, '0');
      final month = dt.month.toString().padLeft(2, '0');
      final hour = dt.hour.toString().padLeft(2, '0');
      final minute = dt.minute.toString().padLeft(2, '0');

      return '$day/$month $hour:$minute';
    } catch (_) {
      return value.toString();
    }
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
                onRefresh: loadReportData,
                color: mulberry,
                child: loading
                    ? const Center(
                        child: CircularProgressIndicator(color: mulberry),
                      )
                    : ListView(
                        padding: const EdgeInsets.all(20),
                        children: [
                          const Text(
                            'Reports & Analytics',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Georgia',
                              color: mulberryDark,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Inventory usage, task progress, and operational alerts.',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          const SizedBox(height: 18),
                          _rangeSelector(),
                          const SizedBox(height: 18),
                          Row(
                            children: [
                              Expanded(
                                child: _metricCard(
                                  title: 'Pending Tasks',
                                  value: pendingTasks.toString(),
                                  icon: Icons.pending_actions,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _metricCard(
                                  title: 'Waiting Approval',
                                  value: waitingApproval.toString(),
                                  icon: Icons.fact_check_outlined,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _metricCard(
                                  title: 'Products',
                                  value: totalProducts.toString(),
                                  icon: Icons.inventory_2_outlined,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _metricCard(
                                  title: 'Low Stock',
                                  value: lowStockCount.toString(),
                                  icon: Icons.warning_amber_rounded,
                                  iconColor: Colors.red,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _metricCard(
                                  title: 'Stock In',
                                  value: stockInTransactions.toString(),
                                  icon: Icons.add_box_outlined,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _metricCard(
                                  title: 'Stock Counts',
                                  value: stockTakeTransactions.toString(),
                                  icon: Icons.checklist_rtl,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          _sectionTitle('Inventory Usage Analytics'),
                          const SizedBox(height: 10),
                          _usageChart(),
                          const SizedBox(height: 20),
                          _sectionTitle('Operational Summary'),
                          const SizedBox(height: 10),
                          _summaryItem(
                            'Estimated usage',
                            '${_formatNumber(estimatedUsage)} unit(s)',
                          ),
                          _summaryItem(
                            'Total stock received',
                            '${_formatNumber(totalStockInQty)} unit(s)',
                          ),
                          _summaryItem(
                            'Approved tasks',
                            approvedTasks.toString(),
                          ),
                          _summaryItem(
                            'Inventory alert items',
                            lowStockCount == 0
                                ? 'No alerts'
                                : '$lowStockCount item(s)',
                          ),
                          const SizedBox(height: 20),
                          _sectionTitle('Low Stock Items'),
                          const SizedBox(height: 10),
                          _lowStockSection(),
                          const SizedBox(height: 20),
                          _sectionTitle('Recent Stock Activities'),
                          const SizedBox(height: 10),
                          _recentTransactionSection(),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
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
            width: 54,
            height: 54,
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
            child: const Icon(Icons.bar_chart, color: mulberry, size: 28),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'BistroLog',
                  style: TextStyle(
                    fontFamily: 'Georgia',
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: cream,
                    letterSpacing: 1.2,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'Reports & analytics dashboard',
                  style: TextStyle(
                    fontSize: 14,
                    color: cream,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: loadReportData,
            icon: const Icon(Icons.refresh, color: cream),
            tooltip: 'Refresh',
          ),
        ],
      ),
    );
  }

  Widget _rangeSelector() {
    return Row(
      children: ['Daily', 'Weekly', 'Monthly'].map((item) {
        final selected = selectedRange == item;

        return Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () async {
                setState(() {
                  selectedRange = item;
                });

                await loadReportData();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: selected ? mulberry : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: selected ? mulberry : creamDark),
                  boxShadow: [
                    if (selected)
                      BoxShadow(
                        color: mulberryDark.withOpacity(0.10),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                  ],
                ),
                child: Text(
                  item,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: selected ? cream : mulberryDark,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _metricCard({
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

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: mulberryDark,
        fontFamily: 'Georgia',
      ),
    );
  }

  Widget _summaryItem(String title, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: creamDark),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: Colors.grey.shade800,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: mulberryDark,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _usageChart() {
    if (usageByProduct.isEmpty) {
      return Container(
        height: 220,
        width: double.infinity,
        padding: const EdgeInsets.all(18),
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
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.insights,
              size: 46,
              color: Colors.grey.shade500,
            ),
            const SizedBox(height: 10),
            const Text(
              'No usage data yet',
              style: TextStyle(
                color: mulberryDark,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Complete opening stock, stock in, and closing stock to generate analytics.',
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

    final maxUsage = usageByProduct.fold<double>(0, (max, item) {
      final usage = (item['usage'] as double?) ?? 0;
      return usage > max ? usage : max;
    });

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Top estimated product usage',
            style: TextStyle(
              color: mulberryDark,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 14),
          ...usageByProduct.map((item) {
            final name = item['name']?.toString() ?? 'Unknown Product';
            final baseUnit = item['base_unit']?.toString() ?? 'unit';
            final usage = (item['usage'] as double?) ?? 0;
            final percent = maxUsage <= 0 ? 0.0 : usage / maxUsage;

            return Padding(
              padding: const EdgeInsets.only(bottom: 13),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: mulberryDark,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      Text(
                        '${_formatNumber(usage)} $baseUnit',
                        style: const TextStyle(
                          color: mulberry,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: LinearProgressIndicator(
                      value: percent.clamp(0.0, 1.0),
                      minHeight: 10,
                      backgroundColor: creamDark,
                      valueColor:
                          const AlwaysStoppedAnimation<Color>(mulberry),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _lowStockSection() {
    if (lowStockItems.isEmpty) {
      return _emptyCard(
        icon: Icons.check_circle_outline,
        title: 'No low stock items',
        subtitle: 'All products are currently above their minimum threshold.',
        iconColor: Colors.green,
      );
    }

    return Column(
      children: lowStockItems.take(5).map((item) {
        final name = item['name']?.toString() ?? 'Unknown Product';
        final currentStock = item['current_stock']?.toString() ?? '0';
        final minThreshold = item['min_threshold']?.toString() ?? '0';
        final baseUnit = item['base_unit']?.toString() ?? 'unit';

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF7F7),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.red.shade100),
          ),
          child: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.red),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(
                    color: mulberryDark,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text(
                '$currentStock / $minThreshold $baseUnit',
                style: const TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _recentTransactionSection() {
    if (recentTransactions.isEmpty) {
      return _emptyCard(
        icon: Icons.history,
        title: 'No stock activity found',
        subtitle: 'Stock transactions will appear here after scanning.',
        iconColor: mulberry,
      );
    }

    return Column(
      children: recentTransactions.map((transaction) {
        final product = Map<String, dynamic>.from(
          transaction['product'] ?? {},
        );

        final productName = product['name']?.toString() ?? 'Unknown Product';
        final transactionType =
            transaction['transaction_type']?.toString() ?? '-';
        final qty = transaction['converted_qty'] ??
            transaction['quantity'] ??
            0;
        final baseUnit = product['base_unit']?.toString() ?? 'unit';
        final time = _formatDateTime(transaction['timestamp']);

        IconData icon = Icons.sync_alt;
        Color iconColor = mulberry;

        if (transactionType == 'stock_in') {
          icon = Icons.add_box_outlined;
          iconColor = Colors.green;
        } else if (transactionType == 'opening' ||
            transactionType == 'closing') {
          icon = Icons.fact_check_outlined;
          iconColor = mulberry;
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: creamDark),
          ),
          child: Row(
            children: [
              Icon(icon, color: iconColor),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      productName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: mulberryDark,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '$transactionType • $time',
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${_formatNumber(double.tryParse(qty.toString()) ?? 0)} $baseUnit',
                style: const TextStyle(
                  color: mulberryDark,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _emptyCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color iconColor,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: creamDark),
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor),
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
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}