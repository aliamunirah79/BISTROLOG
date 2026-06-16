import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class StockInventoryDetailPage extends StatefulWidget {
  final dynamic productId;

  const StockInventoryDetailPage({
    super.key,
    required this.productId,
  });

  @override
  State<StockInventoryDetailPage> createState() =>
      _StockInventoryDetailPageState();
}

class _StockInventoryDetailPageState extends State<StockInventoryDetailPage> {
  final supabase = Supabase.instance.client;

  static const Color mulberry = Color(0xFF6D2B50);
  static const Color mulberryDark = Color(0xFF4A1A35);
  static const Color cream = Color(0xFFF5ECD7);
  static const Color creamDark = Color(0xFFE8D5B5);

  bool loading = true;

  Map<String, dynamic>? product;
  List<Map<String, dynamic>> units = [];
  List<Map<String, dynamic>> transactions = [];

  @override
  void initState() {
    super.initState();
    loadProductDetail();
  }

  Future<void> loadProductDetail() async {
    setState(() {
      loading = true;
    });

    try {
      final productData = await supabase
          .from('product')
          .select()
          .eq('product_id', widget.productId)
          .maybeSingle();

      final unitData = await supabase
          .from('product_unit')
          .select()
          .eq('product_id', widget.productId)
          .order('unit_id', ascending: true);

      final transactionData = await supabase
          .from('stocktransaction')
          .select()
          .eq('product_id', widget.productId)
          .order('timestamp', ascending: false)
          .limit(20);

      if (!mounted) return;

      setState(() {
        product = productData == null
            ? null
            : Map<String, dynamic>.from(productData);
        units = List<Map<String, dynamic>>.from(unitData);
        transactions = List<Map<String, dynamic>>.from(transactionData);
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        loading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load inventory detail: $e'),
          backgroundColor: mulberryDark,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  String _formatDate(dynamic value) {
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

  Widget _infoCard({
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
            child: Icon(
              icon,
              color: iconColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    color: mulberryDark,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    decoration: TextDecoration.none,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  title,
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

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 22, bottom: 10),
      child: Text(
        title,
        style: const TextStyle(
          color: mulberryDark,
          fontSize: 18,
          fontWeight: FontWeight.bold,
          fontFamily: 'Georgia',
          decoration: TextDecoration.none,
        ),
      ),
    );
  }

  Widget _unitCard(Map<String, dynamic> unit) {
    final unitName = (unit['unit_name'] ?? '-').toString();
    final conversionQty = (unit['conversion_qty'] ?? '-').toString();
    final barcode = (unit['barcode'] ?? '-').toString();
    final baseUnit = (product?['base_unit'] ?? 'pcs').toString();

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
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: mulberry.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.qr_code_2,
              color: mulberry,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  unitName,
                  style: const TextStyle(
                    color: mulberryDark,
                    fontWeight: FontWeight.bold,
                    decoration: TextDecoration.none,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '1 $unitName = $conversionQty $baseUnit',
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontSize: 12,
                    decoration: TextDecoration.none,
                  ),
                ),
                Text(
                  'Barcode: $barcode',
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

  Widget _transactionCard(Map<String, dynamic> transaction) {
    final type = (transaction['type'] ?? '-').toString();
    final transactionType =
        (transaction['transaction_type'] ?? '-').toString();
    final source = (transaction['source'] ?? '-').toString();
    final quantity = (transaction['quantity'] ?? 0).toString();
    final convertedQty = (transaction['converted_qty'] ?? quantity).toString();
    final remarks = (transaction['remarks'] ?? '').toString();
    final timestamp = _formatDate(transaction['timestamp']);

    IconData icon = Icons.swap_horiz;
    Color iconColor = mulberry;

    if (type == 'IN') {
      icon = Icons.add_box_outlined;
      iconColor = Colors.green;
    } else if (type == 'OUT') {
      icon = Icons.remove_circle_outline;
      iconColor = Colors.red;
    } else if (type == 'ADJUSTMENT') {
      icon = Icons.fact_check_outlined;
      iconColor = Colors.orange;
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: iconColor,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$type • $transactionType',
                  style: const TextStyle(
                    color: mulberryDark,
                    fontWeight: FontWeight.bold,
                    decoration: TextDecoration.none,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Quantity: $convertedQty',
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontSize: 12,
                    decoration: TextDecoration.none,
                  ),
                ),
                Text(
                  'Source: $source',
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontSize: 12,
                    decoration: TextDecoration.none,
                  ),
                ),
                if (remarks.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    remarks,
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontSize: 12,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            timestamp,
            textAlign: TextAlign.right,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 10,
              decoration: TextDecoration.none,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final productName = (product?['name'] ?? 'Inventory Detail').toString();
    final category = (product?['category'] ?? '-').toString();
    final baseUnit = (product?['base_unit'] ?? 'pcs').toString();
    final currentStock = (product?['current_stock'] ?? 0).toString();
    final minThreshold = (product?['min_threshold'] ?? 0).toString();
    final barcode = (product?['barcode'] ?? '-').toString();

    return Scaffold(
      backgroundColor: cream,
      appBar: AppBar(
        backgroundColor: mulberry,
        foregroundColor: cream,
        title: const Text('Stock Inventory'),
        centerTitle: true,
      ),
      body: loading
          ? const Center(
              child: CircularProgressIndicator(
                color: mulberry,
              ),
            )
          : product == null
              ? const Center(
                  child: Text(
                    'Product not found',
                    style: TextStyle(
                      color: mulberryDark,
                      decoration: TextDecoration.none,
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: loadProductDetail,
                  color: mulberry,
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      Text(
                        productName,
                        style: const TextStyle(
                          color: mulberryDark,
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Georgia',
                          decoration: TextDecoration.none,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Category: $category',
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 13,
                          decoration: TextDecoration.none,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Product barcode: $barcode',
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 12,
                          decoration: TextDecoration.none,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Expanded(
                            child: _infoCard(
                              title: 'Current Stock',
                              value: '$currentStock $baseUnit',
                              icon: Icons.inventory_2_outlined,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _infoCard(
                              title: 'Minimum Stock',
                              value: '$minThreshold $baseUnit',
                              icon: Icons.warning_amber_rounded,
                              iconColor: Colors.red,
                            ),
                          ),
                        ],
                      ),
                      _sectionTitle('Barcode Units'),
                      if (units.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: creamDark),
                          ),
                          child: const Text(
                            'No barcode unit found.',
                            style: TextStyle(
                              color: Colors.grey,
                              decoration: TextDecoration.none,
                            ),
                          ),
                        )
                      else
                        ...units.map(_unitCard),
                      _sectionTitle('Recent Stock Transactions'),
                      if (transactions.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: creamDark),
                          ),
                          child: const Text(
                            'No stock transactions yet.',
                            style: TextStyle(
                              color: Colors.grey,
                              decoration: TextDecoration.none,
                            ),
                          ),
                        )
                      else
                        ...transactions.map(_transactionCard),
                    ],
                  ),
                ),
    );
  }
}