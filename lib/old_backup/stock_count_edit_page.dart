import 'package:flutter/material.dart';

class StockCountEditPage extends StatefulWidget {
  final dynamic productId;
  final String productName;
  final String barcode;
  final String baseUnit;
  final int currentStock;

  const StockCountEditPage({
    super.key,
    required this.productId,
    required this.productName,
    required this.barcode,
    required this.baseUnit,
    required this.currentStock,
  });

  @override
  State<StockCountEditPage> createState() => _StockCountEditPageState();
}

class _StockCountEditPageState extends State<StockCountEditPage> {
  final qtyController = TextEditingController();

  static const Color mulberry = Color(0xFF6D2B50);
  static const Color mulberryDark = Color(0xFF4A1A35);
  static const Color cream = Color(0xFFF5ECD7);
  static const Color creamDark = Color(0xFFE8D5B5);

  int enteredQty = -1;

  @override
  void dispose() {
    qtyController.dispose();
    super.dispose();
  }

  void _save() {
    if (enteredQty < 0) return;

    Navigator.pop(context, {
      'productId': widget.productId,
      'unitId': null,
      'barcode': widget.barcode,
      'quantityEntered': enteredQty,
      'convertedQty': enteredQty,
      'currentStock': widget.currentStock,
      'transactionType': 'manual_count',
      'unitName': widget.baseUnit,
      'baseUnit': widget.baseUnit,
      'productName': widget.productName,
    });
  }

  @override
  Widget build(BuildContext context) {
    final displayQty = enteredQty < 0 ? 0 : enteredQty;
    final variance = displayQty - widget.currentStock;

    return Scaffold(
      backgroundColor: cream,
      appBar: AppBar(
        backgroundColor: mulberry,
        foregroundColor: cream,
        title: const Text('Manual Stock Count'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            widget.productName,
            style: const TextStyle(
              color: mulberryDark,
              fontSize: 24,
              fontWeight: FontWeight.bold,
              fontFamily: 'Georgia',
              decoration: TextDecoration.none,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'System stock: ${widget.currentStock} ${widget.baseUnit}',
            style: TextStyle(
              color: Colors.grey.shade700,
              decoration: TextDecoration.none,
            ),
          ),
          Text(
            'Base unit: ${widget.baseUnit}',
            style: TextStyle(
              color: Colors.grey.shade700,
              decoration: TextDecoration.none,
            ),
          ),
          const SizedBox(height: 22),
          TextField(
            controller: qtyController,
            keyboardType: TextInputType.number,
            onChanged: (value) {
              setState(() {
                enteredQty = int.tryParse(value.trim()) ?? -1;
              });
            },
            decoration: InputDecoration(
              labelText: 'Actual physical quantity',
              hintText: 'Example: 12',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: mulberry),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: creamDark),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'New stock will be: $displayQty ${widget.baseUnit}',
                  style: const TextStyle(
                    color: mulberryDark,
                    fontWeight: FontWeight.bold,
                    decoration: TextDecoration.none,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Variance: ${variance >= 0 ? '+' : ''}$variance ${widget.baseUnit}',
                  style: TextStyle(
                    color: variance == 0
                        ? Colors.grey.shade700
                        : variance > 0
                            ? Colors.green
                            : Colors.red,
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.none,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 26),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: enteredQty < 0 ? null : _save,
              icon: const Icon(Icons.save_outlined),
              label: const Text('Save Quantity'),
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
    );
  }
}