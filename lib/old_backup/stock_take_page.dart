import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'stock_inventory_detail_page.dart';
import 'stock_take_scanner_page.dart';
import 'stock_count_edit_page.dart';

class StockTakePage extends StatefulWidget {
  const StockTakePage({super.key});

  @override
  State<StockTakePage> createState() => _StockTakePageState();
}

class _StockTakePageState extends State<StockTakePage> {
  final supabase = Supabase.instance.client;

  static const Color mulberry = Color(0xFF6D2B50);
  static const Color mulberryDark = Color(0xFF4A1A35);
  static const Color cream = Color(0xFFF5ECD7);
  static const Color creamDark = Color(0xFFE8D5B5);

  bool loading = false;
  bool scanLocked = false;

  String statusMessage = 'Press scan to start stock taking.';
  String lastScannedCode = '';

  int totalItems = 0;
  int lowStockCount = 0;

  List<Map<String, dynamic>> lowStockItems = [];
  List<Map<String, dynamic>> inventoryItems = [];
  List<Map<String, dynamic>> recentStockTake = [];

  @override
  void initState() {
    super.initState();
    loadDashboard();
  }

  Future<void> loadDashboard() async {
    await loadInventorySummary();
    await loadLowStockItems();
    await loadInventoryItems();
    await loadRecentStockTake();
  }

  Future<void> loadInventorySummary() async {
    try {
      final res = await supabase.from('product').select('product_id');

      if (!mounted) return;

      setState(() {
        totalItems = (res as List).length;
      });
    } catch (e) {
      debugPrint('Load inventory summary error: $e');

      if (!mounted) return;

      setState(() {
        totalItems = 0;
      });
    }
  }

  Future<void> loadLowStockItems() async {
    try {
      final data = await supabase
          .from('product')
          .select()
          .order('current_stock', ascending: true);

      final products = List<Map<String, dynamic>>.from(data);

      final filtered = products.where((item) {
        final currentStock =
            int.tryParse((item['current_stock'] ?? 0).toString()) ?? 0;
        final minThreshold =
            int.tryParse((item['min_threshold'] ?? 0).toString()) ?? 0;

        return minThreshold > 0 && currentStock <= minThreshold;
      }).toList();

      if (!mounted) return;

      setState(() {
        lowStockItems = filtered;
        lowStockCount = filtered.length;
      });
    } catch (e) {
      debugPrint('Load low stock items error: $e');

      if (!mounted) return;

      setState(() {
        lowStockItems = [];
        lowStockCount = 0;
      });
    }
  }

  Future<void> loadInventoryItems() async {
    try {
      final data = await supabase
          .from('product')
          .select(
            'product_id, name, barcode, category, current_stock, min_threshold, base_unit',
          )
          .order('name', ascending: true);

      if (!mounted) return;

      setState(() {
        inventoryItems = List<Map<String, dynamic>>.from(data);
      });
    } catch (e) {
      debugPrint('Load inventory items error: $e');

      if (!mounted) return;

      setState(() {
        inventoryItems = [];
      });
    }
  }

  Future<void> loadRecentStockTake() async {
    try {
      final data = await supabase
          .from('stocktransaction')
          .select('''
            transaction_id,
            product_id,
            transaction_type,
            type,
            source,
            quantity,
            quantity_entered,
            converted_qty,
            scanned_barcode,
            remarks,
            timestamp,
            product:product_id (
              product_id,
              name,
              base_unit,
              current_stock
            )
          ''')
          .inFilter('transaction_type', ['opening', 'closing', 'manual_count'])
          .order('timestamp', ascending: false)
          .limit(8);

      if (!mounted) return;

      setState(() {
        recentStockTake = List<Map<String, dynamic>>.from(data);
      });
    } catch (e) {
      debugPrint('Load recent stock take error: $e');

      if (!mounted) return;

      setState(() {
        recentStockTake = [];
      });
    }
  }

  Future<void> startScanning() async {
    final scannedCode = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => const StockTakeScannerPage(),
      ),
    );

    if (!mounted) return;

    if (scannedCode == null || scannedCode.isEmpty) {
      setState(() {
        statusMessage = 'Scan cancelled.';
      });
      return;
    }

    await processBarcode(scannedCode);
  }

  Future<void> processBarcode(String code) async {
    if (scanLocked || loading || code.isEmpty) return;

    setState(() {
      scanLocked = true;
      loading = true;
      lastScannedCode = code;
      statusMessage = 'Checking barcode...';
    });

    try {
      final result = await supabase
          .from('product_unit')
          .select('''
            unit_id,
            unit_name,
            conversion_qty,
            barcode,
            product:product_id (
              product_id,
              name,
              category,
              base_unit,
              current_stock,
              min_threshold
            )
          ''')
          .eq('barcode', code)
          .maybeSingle();

      if (result == null) {
        if (!mounted) return;

        setState(() {
          statusMessage = 'Barcode not found in product_unit.';
          loading = false;
          scanLocked = false;
        });

        _showSnack('Barcode not found. Please register this barcode first.');
        return;
      }

      if (!mounted) return;

      setState(() {
        loading = false;
        scanLocked = false;
      });

      await _showScannedStockTakeDialog(Map<String, dynamic>.from(result));
    } catch (e) {
      debugPrint('Process barcode error: $e');

      if (!mounted) return;

      setState(() {
        statusMessage = 'Failed to process barcode.';
        loading = false;
        scanLocked = false;
      });

      _showSnack('Failed to process barcode: $e');
    }
  }

  Future<void> _showScannedStockTakeDialog(
    Map<String, dynamic> unitData,
  ) async {
    final qtyController = TextEditingController();
    String selectedType = 'closing';

    final product = Map<String, dynamic>.from(unitData['product'] ?? {});
    final productName = (product['name'] ?? 'Unknown Product').toString();
    final productId = product['product_id'];
    final unitId = unitData['unit_id'];
    final unitName = (unitData['unit_name'] ?? '').toString();
    final baseUnit = (product['base_unit'] ?? 'pcs').toString();
    final conversionQty =
        int.tryParse((unitData['conversion_qty'] ?? 1).toString()) ?? 1;
    final currentStock =
        int.tryParse((product['current_stock'] ?? 0).toString()) ?? 0;
    final barcode = (unitData['barcode'] ?? lastScannedCode).toString();

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final enteredQty = int.tryParse(qtyController.text.trim()) ?? 0;
            final convertedQty = enteredQty * conversionQty;
            final variance = convertedQty - currentStock;

            return AlertDialog(
              backgroundColor: cream,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              title: const Text(
                'Stock Take',
                style: TextStyle(
                  color: mulberryDark,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Georgia',
                  decoration: TextDecoration.none,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      productName,
                      style: const TextStyle(
                        color: mulberryDark,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        decoration: TextDecoration.none,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Scanned unit: $unitName',
                      style: const TextStyle(decoration: TextDecoration.none),
                    ),
                    Text(
                      'Conversion: 1 $unitName = $conversionQty $baseUnit',
                      style: const TextStyle(decoration: TextDecoration.none),
                    ),
                    Text(
                      'System stock: $currentStock $baseUnit',
                      style: const TextStyle(decoration: TextDecoration.none),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: selectedType,
                      decoration: InputDecoration(
                        labelText: 'Count Type',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'opening',
                          child: Text('Opening Count'),
                        ),
                        DropdownMenuItem(
                          value: 'closing',
                          child: Text('Closing Count'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value == null) return;

                        setDialogState(() {
                          selectedType = value;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: qtyController,
                      keyboardType: TextInputType.number,
                      onChanged: (_) => setDialogState(() {}),
                      decoration: InputDecoration(
                        labelText: 'Physical quantity in $unitName',
                        hintText: 'Example: 2',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: creamDark),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Physical count: $convertedQty $baseUnit',
                            style: const TextStyle(
                              color: mulberryDark,
                              fontWeight: FontWeight.bold,
                              decoration: TextDecoration.none,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Variance: ${variance >= 0 ? '+' : ''}$variance $baseUnit',
                            style: TextStyle(
                              color: variance == 0
                                  ? Colors.grey.shade700
                                  : variance > 0
                                      ? Colors.green
                                      : Colors.red,
                              decoration: TextDecoration.none,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                  },
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: mulberryDark),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: mulberry,
                    foregroundColor: cream,
                  ),
                  onPressed: enteredQty <= 0
                      ? null
                      : () {
                          Navigator.pop(dialogContext, {
                            'productId': productId,
                            'unitId': unitId,
                            'barcode': barcode,
                            'quantityEntered': enteredQty,
                            'convertedQty': convertedQty,
                            'currentStock': currentStock,
                            'transactionType': selectedType,
                            'unitName': unitName,
                            'baseUnit': baseUnit,
                            'productName': productName,
                          });
                        },
                  child: const Text('Save Count'),
                ),
              ],
            );
          },
        );
      },
    );

    qtyController.dispose();

    if (result == null) return;
    if (!mounted) return;

    await Future.delayed(const Duration(milliseconds: 150));

    if (!mounted) return;

    await _saveStockTakeTransaction(
      productId: result['productId'],
      unitId: result['unitId'],
      barcode: result['barcode'],
      quantityEntered: result['quantityEntered'],
      convertedQty: result['convertedQty'],
      currentStock: result['currentStock'],
      transactionType: result['transactionType'],
      unitName: result['unitName'],
      baseUnit: result['baseUnit'],
      productName: result['productName'],
    );
  }

  Future<void> _showManualCountDialog(Map<String, dynamic> product) async {
    final productName = (product['name'] ?? 'Unknown Product').toString();
    final productId = product['product_id'];
    final barcode = (product['barcode'] ?? '').toString();
    final baseUnit = (product['base_unit'] ?? 'pcs').toString();
    final currentStock =
        int.tryParse((product['current_stock'] ?? 0).toString()) ?? 0;

    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => StockCountEditPage(
          productId: productId,
          productName: productName,
          barcode: barcode,
          baseUnit: baseUnit,
          currentStock: currentStock,
        ),
      ),
    );

    if (result == null) return;
    if (!mounted) return;

    await _saveStockTakeTransaction(
      productId: result['productId'],
      unitId: result['unitId'],
      barcode: result['barcode'],
      quantityEntered: result['quantityEntered'],
      convertedQty: result['convertedQty'],
      currentStock: result['currentStock'],
      transactionType: result['transactionType'],
      unitName: result['unitName'],
      baseUnit: result['baseUnit'],
      productName: result['productName'],
    );
  }

  Future<void> _saveStockTakeTransaction({
    required dynamic productId,
    required dynamic unitId,
    required String barcode,
    required int quantityEntered,
    required int convertedQty,
    required int currentStock,
    required String transactionType,
    required String unitName,
    required String baseUnit,
    required String productName,
  }) async {
    final user = supabase.auth.currentUser;

    if (user == null) {
      _showSnack('User not logged in. Please login again.');
      return;
    }

    final variance = convertedQty - currentStock;

    try {
      if (!mounted) return;

      setState(() {
        loading = true;
        statusMessage = 'Saving stock take...';
      });

      await supabase.from('stocktransaction').insert({
        'product_id': productId,
        'user_id': user.id,
        'type': 'ADJUSTMENT',
        'quantity': convertedQty,
        'source': 'STOCK_TAKE',
        'unit_id': unitId,
        'scanned_barcode': barcode.isEmpty ? null : barcode,
        'quantity_entered': quantityEntered,
        'converted_qty': convertedQty,
        'transaction_type': transactionType,
        'remarks':
            '${transactionType == 'opening'
                    ? 'Opening'
                    : transactionType == 'closing'
                        ? 'Closing'
                        : 'Manual'} stock count: '
                '$quantityEntered $unitName = $convertedQty $baseUnit. '
            'Stock adjusted: $currentStock → $convertedQty $baseUnit. '
            'Variance: ${variance >= 0 ? '+' : ''}$variance $baseUnit',
      });

      if (!mounted) return;

      await loadDashboard();

      if (!mounted) return;

      setState(() {
        loading = false;
        statusMessage =
            'Stock take saved for $productName. New quantity: $convertedQty $baseUnit';
      });

      _showSnack('Stock take saved successfully.');
    } catch (e) {
      debugPrint('Save stock take error: $e');

      if (!mounted) return;

      setState(() {
        loading = false;
        statusMessage = 'Failed to save stock take.';
      });

      _showSnack('Failed to save stock take: $e');
    }
  }

  void _openInventoryDetail(dynamic productId) {
    if (productId == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StockInventoryDetailPage(productId: productId),
      ),
    ).then((_) => loadDashboard());
  }

  void _showSnack(String msg) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: mulberryDark,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _dashboardCard({
    required String title,
    required String value,
    required IconData icon,
    Color? iconColor,
  }) {
    return Expanded(
      child: Container(
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
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: (iconColor ?? mulberry).withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor ?? mulberry, size: 18),
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
                      decoration: TextDecoration.none,
                    ),
                  ),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade700,
                      decoration: TextDecoration.none,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _scannerPanel() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: creamDark),
        boxShadow: [
          BoxShadow(
            color: mulberryDark.withOpacity(0.08),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              height: 160,
              decoration: BoxDecoration(
                color: cream,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.qr_code_scanner,
                    size: 54,
                    color: mulberry,
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Ready to scan stock barcode',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: mulberryDark,
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: loading ? null : startScanning,
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text('Start Scanning'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: mulberry,
                  foregroundColor: cream,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              statusMessage,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: 13,
                decoration: TextDecoration.none,
              ),
            ),
            if (lastScannedCode.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                'Last scanned: $lastScannedCode',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: mulberryDark,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.none,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _alertCard() {
    if (lowStockItems.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: creamDark),
        ),
        child: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.green),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'No low stock items right now.',
                style: TextStyle(
                  color: Colors.grey.shade700,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7F7),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.red.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.red),
              SizedBox(width: 8),
              Text(
                'Low Stock Alert',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: mulberryDark,
                  decoration: TextDecoration.none,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...lowStockItems.take(3).map((item) {
            final name = (item['name'] ?? '').toString();
            final qty = (item['current_stock'] ?? 0).toString();
            final min = (item['min_threshold'] ?? 0).toString();

            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                '• $name — qty $qty / min $min',
                style: const TextStyle(decoration: TextDecoration.none),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildInventoryList() {
    if (inventoryItems.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: creamDark),
        ),
        child: const Text(
          'No inventory items yet.',
          style: TextStyle(
            color: Colors.grey,
            decoration: TextDecoration.none,
          ),
        ),
      );
    }

    return Column(
      children: inventoryItems.map((item) {
        final productId = item['product_id'];
        final name = (item['name'] ?? '').toString();
        final category = (item['category'] ?? '-').toString();
        final stock = (item['current_stock'] ?? 0).toString();
        final baseUnit = (item['base_unit'] ?? 'pcs').toString();

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: creamDark),
          ),
          child: Row(
            children: [
              InkWell(
                onTap: () => _openInventoryDetail(productId),
                borderRadius: BorderRadius.circular(30),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: mulberry.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.inventory_2_outlined,
                    color: mulberry,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: InkWell(
                  onTap: () => _openInventoryDetail(productId),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: mulberryDark,
                          decoration: TextDecoration.none,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Category: $category',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                          decoration: TextDecoration.none,
                        ),
                      ),
                      Text(
                        'Current stock: $stock $baseUnit',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: loading ? null : () => _showManualCountDialog(item),
                style: ElevatedButton.styleFrom(
                  backgroundColor: mulberry,
                  foregroundColor: cream,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Count'),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildRecentStockTake() {
    if (recentStockTake.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: creamDark),
        ),
        child: const Text(
          'No stock take records yet.',
          style: TextStyle(
            color: Colors.grey,
            decoration: TextDecoration.none,
          ),
        ),
      );
    }

    return Column(
      children: recentStockTake.map((item) {
        final product = Map<String, dynamic>.from(item['product'] ?? {});
        final productId = product['product_id'] ?? item['product_id'];
        final productName = (product['name'] ?? 'Unknown Product').toString();
        final baseUnit = (product['base_unit'] ?? 'pcs').toString();

        return InkWell(
          onTap: productId == null ? null : () => _openInventoryDetail(productId),
          borderRadius: BorderRadius.circular(18),
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: creamDark),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.14),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.fact_check_outlined,
                    color: Colors.orange,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        productName,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: mulberryDark,
                          decoration: TextDecoration.none,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        (item['remarks'] ?? '').toString(),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${item['converted_qty'] ?? item['quantity'] ?? 0} $baseUnit',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: mulberry,
                    decoration: TextDecoration.none,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: cream,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: loadDashboard,
          color: mulberry,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Text(
                'Stock Take',
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
                'Scan barcode or manually count physical inventory.',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade700,
                  decoration: TextDecoration.none,
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  _dashboardCard(
                    title: 'Items',
                    value: totalItems.toString(),
                    icon: Icons.inventory_2_outlined,
                  ),
                  const SizedBox(width: 12),
                  _dashboardCard(
                    title: 'Low Stock',
                    value: lowStockCount.toString(),
                    icon: Icons.warning_amber_rounded,
                    iconColor: Colors.red,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _alertCard(),
              const SizedBox(height: 18),
              _scannerPanel(),
              const SizedBox(height: 20),
              const Text(
                'Inventory Manual Count',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: mulberryDark,
                  fontFamily: 'Georgia',
                  decoration: TextDecoration.none,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Tap Count to enter the actual physical quantity.',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade700,
                  decoration: TextDecoration.none,
                ),
              ),
              const SizedBox(height: 12),
              _buildInventoryList(),
              const SizedBox(height: 20),
              const Text(
                'Recent Stock Take',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: mulberryDark,
                  fontFamily: 'Georgia',
                  decoration: TextDecoration.none,
                ),
              ),
              const SizedBox(height: 12),
              _buildRecentStockTake(),
            ],
          ),
        ),
      ),
    );
  }
}