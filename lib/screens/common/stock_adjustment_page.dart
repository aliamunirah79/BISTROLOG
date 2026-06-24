import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum StockMovementType {
  stockIn,
  stockOut,
  damaged,
  expired,
  correction,
}

class StockAdjustmentPage extends StatefulWidget {
  final bool showAppBar;

  const StockAdjustmentPage({
    super.key,
    this.showAppBar = true,
  });

  @override
  State<StockAdjustmentPage> createState() => _StockAdjustmentPageState();
}

class _StockAdjustmentPageState extends State<StockAdjustmentPage> {
  final supabase = Supabase.instance.client;

  final searchController = TextEditingController();
  final packageCountController = TextEditingController();
  final remarksController = TextEditingController();

  bool isLoading = true;
  bool isSaving = false;

  String searchQuery = '';
  String selectedCategory = 'All';

  StockMovementType selectedMovementType = StockMovementType.stockIn;

  List<Map<String, dynamic>> inventoryItems = [];
  Map<String, dynamic>? selectedItem;

  DateTime? selectedExpiryDate;

  static const Color mulberry = Color(0xFF6D2B50);
  static const Color mulberryDark = Color(0xFF4A1A35);
  static const Color mulberryLight = Color(0xFF8B3D68);
  static const Color cream = Color(0xFFF5ECD7);
  static const Color creamDark = Color(0xFFE8D5B5);
  static const Color softWhite = Color(0xFFFFFCF7);

  @override
  void initState() {
    super.initState();
    loadInventoryItems();
  }

  @override
  void dispose() {
    searchController.dispose();
    packageCountController.dispose();
    remarksController.dispose();
    super.dispose();
  }

  Future<void> loadInventoryItems() async {
    if (!mounted) return;

    setState(() {
      isLoading = true;
    });

    try {
      final response = await supabase
          .from('inventory_items')
          .select()
          .eq('is_active', true)
          .order('item_name', ascending: true);

      if (!mounted) return;

      setState(() {
        inventoryItems = List<Map<String, dynamic>>.from(response);
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
      });

      showMessage('Failed to load inventory items: $e', isError: true);
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

  String getBarcode(Map<String, dynamic> item) {
    return (item['barcode'] ?? '').toString();
  }

  String getExpiryDate(Map<String, dynamic> item) {
    final value = item['expiry_date'] ?? item['expiration_date'];

    if (value == null || value.toString().trim().isEmpty) {
      return '';
    }

    return value.toString().substring(0, 10);
  }

  String formatDateOnly(DateTime date) {
    final year = date.year.toString();
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');

    return '$year-$month-$day';
  }

  String getSelectedExpiryText() {
    if (selectedExpiryDate == null) return '';
    return formatDateOnly(selectedExpiryDate!);
  }

  DateTime? parseDate(String value) {
    if (value.trim().isEmpty) {
      return null;
    }

    return DateTime.tryParse(value.trim());
  }

  bool isExpired(Map<String, dynamic> item) {
    final expiry = parseDate(getExpiryDate(item));

    if (expiry == null) {
      return false;
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final expiryDay = DateTime(expiry.year, expiry.month, expiry.day);

    return expiryDay.isBefore(today);
  }

  bool isExpiringSoon(Map<String, dynamic> item) {
    final expiry = parseDate(getExpiryDate(item));

    if (expiry == null || isExpired(item)) {
      return false;
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final expiryDay = DateTime(expiry.year, expiry.month, expiry.day);

    return expiryDay.difference(today).inDays <= 7;
  }

  String getPackageName(Map<String, dynamic> item) {
    final value = item['package_name'];

    if (value == null || value.toString().trim().isEmpty) {
      return 'unit';
    }

    return value.toString();
  }

  num getPackageQuantity(Map<String, dynamic> item) {
    final value = item['package_quantity'] ?? 1;
    final number = num.tryParse(value.toString()) ?? 1;

    if (number <= 0) {
      return 1;
    }

    return number;
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

    return number.toString();
  }

  bool isLowStock(Map<String, dynamic> item) {
    final current = getCurrentQuantity(item);
    final minimum = getMinimumQuantity(item);

    if (minimum <= 0) {
      return false;
    }

    return current <= minimum;
  }

  List<String> getCategories() {
    final categories = inventoryItems
        .map(getCategory)
        .where((category) => category.trim().isNotEmpty)
        .toSet()
        .toList();

    categories.sort();

    return ['All', ...categories];
  }

  List<Map<String, dynamic>> getFilteredItems() {
    List<Map<String, dynamic>> filtered = inventoryItems;

    if (selectedCategory != 'All') {
      filtered = filtered.where((item) {
        return getCategory(item) == selectedCategory;
      }).toList();
    }

    if (searchQuery.trim().isNotEmpty) {
      final query = searchQuery.toLowerCase();

      filtered = filtered.where((item) {
        final name = getItemName(item).toLowerCase();
        final category = getCategory(item).toLowerCase();
        final barcode = getBarcode(item).toLowerCase();
        final expiryDate = getExpiryDate(item).toLowerCase();

        return name.contains(query) ||
            category.contains(query) ||
            barcode.contains(query) ||
            expiryDate.contains(query);
      }).toList();
    }

    return filtered;
  }

  String getMovementTypeText() {
    switch (selectedMovementType) {
      case StockMovementType.stockIn:
        return 'stock_in';
      case StockMovementType.stockOut:
        return 'stock_out';
      case StockMovementType.damaged:
        return 'damaged';
      case StockMovementType.expired:
        return 'expired';
      case StockMovementType.correction:
        return 'correction';
    }
  }

  String getMovementTitle() {
    switch (selectedMovementType) {
      case StockMovementType.stockIn:
        return 'Stock In';
      case StockMovementType.stockOut:
        return 'Stock Out';
      case StockMovementType.damaged:
        return 'Damaged';
      case StockMovementType.expired:
        return 'Expired';
      case StockMovementType.correction:
        return 'Correction';
    }
  }

  IconData getMovementIcon() {
    switch (selectedMovementType) {
      case StockMovementType.stockIn:
        return Icons.add_circle_outline;
      case StockMovementType.stockOut:
        return Icons.remove_circle_outline;
      case StockMovementType.damaged:
        return Icons.broken_image_outlined;
      case StockMovementType.expired:
        return Icons.event_busy_outlined;
      case StockMovementType.correction:
        return Icons.tune;
    }
  }

  Color getMovementColor() {
    switch (selectedMovementType) {
      case StockMovementType.stockIn:
        return Colors.green;
      case StockMovementType.stockOut:
        return Colors.orange;
      case StockMovementType.damaged:
        return Colors.red;
      case StockMovementType.expired:
        return Colors.red;
      case StockMovementType.correction:
        return Colors.blue;
    }
  }

  bool isDeductMovement() {
    return selectedMovementType == StockMovementType.stockOut ||
        selectedMovementType == StockMovementType.damaged ||
        selectedMovementType == StockMovementType.expired;
  }

  bool isCorrectionMovement() {
    return selectedMovementType == StockMovementType.correction;
  }

  bool isStockInMovement() {
    return selectedMovementType == StockMovementType.stockIn;
  }

  num getPackageCountInput() {
    return num.tryParse(packageCountController.text.trim()) ?? 0;
  }

  num getBaseQuantity() {
    if (selectedItem == null) {
      return 0;
    }

    final packageCount = getPackageCountInput();
    final packageQuantity = getPackageQuantity(selectedItem!);

    if (isCorrectionMovement()) {
      return packageCount;
    }

    return packageCount * packageQuantity;
  }

  num getAfterQuantity() {
    if (selectedItem == null) {
      return 0;
    }

    final current = getCurrentQuantity(selectedItem!);
    final baseQuantity = getBaseQuantity();

    if (selectedMovementType == StockMovementType.stockIn) {
      return current + baseQuantity;
    }

    if (isDeductMovement()) {
      final result = current - baseQuantity;
      return result < 0 ? 0 : result;
    }

    if (isCorrectionMovement()) {
      return baseQuantity;
    }

    return current;
  }

  Future<void> pickExpiryDate() async {
    final now = DateTime.now();

    final picked = await showDatePicker(
      context: context,
      initialDate: selectedExpiryDate ?? now.add(const Duration(days: 7)),
      firstDate: now,
      lastDate: DateTime(now.year + 5),
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
      selectedExpiryDate = picked;
    });
  }

  Future<void> findItemByBarcode(String barcode) async {
    try {
      final response = await supabase
          .from('inventory_items')
          .select()
          .eq('barcode', barcode)
          .eq('is_active', true)
          .maybeSingle();

      if (response == null) {
        showMessage(
          'Barcode not found. Please ask manager to register this item barcode.',
          isError: true,
        );
        return;
      }

      setState(() {
        selectedItem = Map<String, dynamic>.from(response);
        searchQuery = '';
        searchController.clear();
      });

      showMessage('${getItemName(selectedItem!)} selected.');
    } catch (e) {
      showMessage('Failed to find item by barcode: $e', isError: true);
    }
  }

  Future<void> openBarcodeScanner() async {
    bool detected = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(24),
        ),
      ),
      builder: (bottomSheetContext) {
        return SizedBox(
          height: MediaQuery.of(bottomSheetContext).size.height * 0.78,
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 10),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Scan Barcode',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        Navigator.pop(bottomSheetContext);
                      },
                      icon: const Icon(
                        Icons.close,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(18),
                  ),
                  child: MobileScanner(
                    onDetect: (capture) async {
                      if (detected) {
                        return;
                      }

                      final barcodes = capture.barcodes;

                      if (barcodes.isEmpty) {
                        return;
                      }

                      final code = barcodes.first.rawValue;

                      if (code == null || code.isEmpty) {
                        return;
                      }

                      detected = true;

                      Navigator.pop(bottomSheetContext);

                      await findItemByBarcode(code);
                    },
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.all(18),
                child: Text(
                  'Point your camera at the product or carton barcode.',
                  style: TextStyle(
                    color: Colors.white70,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void selectItem(Map<String, dynamic> item) {
    setState(() {
      selectedItem = item;
    });
  }

  void clearSelectedItem() {
    setState(() {
      selectedItem = null;
      selectedExpiryDate = null;
      packageCountController.clear();
      remarksController.clear();
    });
  }

  Future<void> insertStockInBatch({
    required Map<String, dynamic> item,
    required num baseQuantity,
    required String remarks,
    required String userId,
  }) async {
    if (selectedExpiryDate == null) {
      throw Exception('Expiry date is required for stock in.');
    }

    await supabase.from('inventory_batches').insert({
      'item_id': item['item_id'],
      'received_quantity': baseQuantity,
      'remaining_quantity': baseQuantity,
      'received_date': DateTime.now().toIso8601String().substring(0, 10),
      'expiry_date': getSelectedExpiryText(),
      'source': 'stock_in',
      'notes': remarks.isEmpty ? null : remarks,
      'created_by': userId,
      'is_active': true,
    });
  }

  Future<void> deductBatchByFifo({
    required Map<String, dynamic> item,
    required num baseQuantity,
  }) async {
    await supabase.rpc(
      'fn_fifo_deduct_stock',
      params: {
        'p_item_id': item['item_id'],
        'p_quantity': baseQuantity,
        'p_movement_type': getMovementTypeText(),
      },
    );
  }

  Future<void> saveAdjustment() async {
    final user = supabase.auth.currentUser;

    if (user == null) {
      showMessage('User not logged in.', isError: true);
      return;
    }

    if (selectedItem == null) {
      showMessage('Please select an item first.', isError: true);
      return;
    }

    final packageCount = getPackageCountInput();

    if (packageCount <= 0) {
      showMessage('Please enter a valid quantity.', isError: true);
      return;
    }

    if (isStockInMovement() && selectedExpiryDate == null) {
      showMessage('Please select expiry date for stock in.', isError: true);
      return;
    }

    final item = selectedItem!;
    final currentQuantity = getCurrentQuantity(item);
    final baseQuantity = getBaseQuantity();
    final afterQuantity = getAfterQuantity();
    final packageName = getPackageName(item);
    final remarks = remarksController.text.trim();

    if (isDeductMovement() && baseQuantity > currentQuantity) {
      showMessage(
        'Quantity cannot be more than current stock.',
        isError: true,
      );
      return;
    }

    setState(() {
      isSaving = true;
    });

    try {
      if (isDeductMovement()) {
        await deductBatchByFifo(
          item: item,
          baseQuantity: baseQuantity,
        );
      }

      await supabase.from('inventory_items').update({
        'current_quantity': afterQuantity,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('item_id', item['item_id']);

      await supabase.from('stock_movements').insert({
        'item_id': item['item_id'],
        'movement_type': getMovementTypeText(),
        'quantity': baseQuantity,
        'package_count': isCorrectionMovement() ? null : packageCount,
        'package_name': isCorrectionMovement() ? null : packageName,
        'base_quantity': baseQuantity,
        'before_quantity': currentQuantity,
        'after_quantity': afterQuantity,
        'remarks': remarks.isEmpty ? null : remarks,
        'performed_by': user.id,
        'created_at': DateTime.now().toIso8601String(),
      });

      if (isStockInMovement()) {
        await insertStockInBatch(
          item: item,
          baseQuantity: baseQuantity,
          remarks: remarks,
          userId: user.id,
        );
      }

      if (afterQuantity <= getMinimumQuantity(item)) {
        await notifyLowStock(
          item: item,
          newQuantity: afterQuantity,
        );
      }

      showMessage('Stock adjustment saved.');

      packageCountController.clear();
      remarksController.clear();

      if (isStockInMovement()) {
        setState(() {
          selectedExpiryDate = null;
        });
      }

      await loadInventoryItems();

      final updatedItem = inventoryItems.firstWhere(
        (i) => getItemId(i) == getItemId(item),
        orElse: () => {},
      );

      setState(() {
        selectedItem = updatedItem.isEmpty ? null : updatedItem;
        isSaving = false;
      });
    } catch (e) {
      setState(() {
        isSaving = false;
      });

      showMessage('Failed to save adjustment: $e', isError: true);
    }
  }

  Future<void> notifyLowStock({
    required Map<String, dynamic> item,
    required num newQuantity,
  }) async {
    try {
      final users = await supabase
          .from('profiles')
          .select('id')
          .inFilter('role', ['manager', 'supervisor']);

      final userList = List<Map<String, dynamic>>.from(users);

      if (userList.isEmpty) {
        return;
      }

      final itemName = getItemName(item);
      final unit = getUnit(item);
      final minimumQuantity = getMinimumQuantity(item);

      final notifications = userList.map((user) {
        return {
          'user_id': user['id'],
          'title': 'Low Stock Alert',
          'message':
              '$itemName is low after stock adjustment. Current: ${formatNumber(newQuantity)} $unit, minimum: ${formatNumber(minimumQuantity)} $unit.',
          'type': 'inventory',
          'target_page': 'low_stock',
          'target_id': getItemId(item),
          'is_read': false,
        };
      }).toList();

      await supabase.from('notifications').insert(notifications);
    } catch (e) {
      debugPrint('Failed to notify low stock: $e');
    }
  }

  Widget buildHeader() {
    return Container(
      padding: const EdgeInsets.all(18),
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
        borderRadius: BorderRadius.circular(22),
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
            radius: 27,
            backgroundColor: cream.withOpacity(0.18),
            child: const Icon(
              Icons.qr_code_scanner,
              color: cream,
              size: 29,
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Stock Adjustment',
                  style: TextStyle(
                    color: cream,
                    fontFamily: 'Georgia',
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  'Scan barcode or select item manually',
                  style: TextStyle(
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

  Widget buildScannerButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        onPressed: openBarcodeScanner,
        icon: const Icon(Icons.qr_code_scanner),
        label: const Text('Scan Barcode'),
        style: ElevatedButton.styleFrom(
          backgroundColor: mulberry,
          foregroundColor: cream,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }

  Widget buildMovementTypeSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: creamDark.withOpacity(0.65),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: buildMovementButton(
                  type: StockMovementType.stockIn,
                  label: 'Stock In',
                ),
              ),
              Expanded(
                child: buildMovementButton(
                  type: StockMovementType.stockOut,
                  label: 'Stock Out',
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: buildMovementButton(
                  type: StockMovementType.damaged,
                  label: 'Damaged',
                ),
              ),
              Expanded(
                child: buildMovementButton(
                  type: StockMovementType.expired,
                  label: 'Expired',
                ),
              ),
              Expanded(
                child: buildMovementButton(
                  type: StockMovementType.correction,
                  label: 'Correct',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget buildMovementButton({
    required StockMovementType type,
    required String label,
  }) {
    final selected = selectedMovementType == type;
    final color = getMovementColor();

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () {
        setState(() {
          selectedMovementType = type;

          if (selectedMovementType != StockMovementType.stockIn) {
            selectedExpiryDate = null;
          }
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          color: selected ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : mulberry,
              fontWeight: FontWeight.bold,
              fontSize: 12.5,
            ),
          ),
        ),
      ),
    );
  }

  Widget buildSearchBox() {
    return TextField(
      controller: searchController,
      onChanged: (value) {
        setState(() {
          searchQuery = value;
        });
      },
      style: const TextStyle(
        color: mulberryDark,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        hintText: 'Search item or barcode...',
        hintStyle: TextStyle(
          color: Colors.grey.shade500,
        ),
        prefixIcon: const Icon(
          Icons.search,
          color: mulberry,
        ),
        filled: true,
        fillColor: softWhite,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(
            color: creamDark.withOpacity(0.9),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(
            color: mulberry,
            width: 1.8,
          ),
        ),
      ),
    );
  }

  Widget buildCategoryFilter() {
    final categories = getCategories();

    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final category = categories[index];
          final selected = selectedCategory == category;

          return ChoiceChip(
            label: Text(category),
            selected: selected,
            selectedColor: mulberry,
            backgroundColor: softWhite,
            side: BorderSide(
              color: selected ? mulberry : creamDark,
            ),
            labelStyle: TextStyle(
              color: selected ? cream : mulberry,
              fontWeight: FontWeight.bold,
            ),
            onSelected: (_) {
              setState(() {
                selectedCategory = category;
              });
            },
          );
        },
      ),
    );
  }

  Widget buildSelectedItemCard() {
    if (selectedItem == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF7E6),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.orange.shade100),
        ),
        child: Row(
          children: [
            Icon(
              Icons.info_outline,
              color: Colors.orange.shade800,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'No item selected. Scan barcode or choose an item from the list below.',
                style: TextStyle(
                  color: Colors.orange.shade900,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final item = selectedItem!;
    final itemName = getItemName(item);
    final category = getCategory(item);
    final unit = getUnit(item);
    final packageName = getPackageName(item);
    final packageQuantity = getPackageQuantity(item);
    final current = getCurrentQuantity(item);
    final minimum = getMinimumQuantity(item);
    final expiryDate = getExpiryDate(item);
    final expired = isExpired(item);
    final expiringSoon = isExpiringSoon(item);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: softWhite,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: creamDark.withOpacity(0.9)),
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
              CircleAvatar(
                backgroundColor: mulberry.withOpacity(0.12),
                child: const Icon(
                  Icons.inventory_2,
                  color: mulberry,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  itemName,
                  style: const TextStyle(
                    color: mulberryDark,
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                  ),
                ),
              ),
              IconButton(
                onPressed: clearSelectedItem,
                icon: const Icon(Icons.close),
                color: mulberry,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            category,
            style: TextStyle(
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              buildSmallBadge('Current: ${formatNumber(current)} $unit'),
              buildSmallBadge('Minimum: ${formatNumber(minimum)} $unit'),
              buildSmallBadge('1 $packageName = ${formatNumber(packageQuantity)} $unit'),
              if (getBarcode(item).isNotEmpty)
                buildSmallBadge('Barcode: ${getBarcode(item)}'),
              if (expiryDate.isNotEmpty)
                buildColoredBadge(
                  'Item Expiry: $expiryDate',
                  expired
                      ? Colors.red
                      : expiringSoon
                          ? Colors.orange
                          : Colors.green,
                ),
              if (expired) buildWarningBadge('EXPIRED'),
              if (expiringSoon) buildColoredBadge('EXPIRING SOON', Colors.orange),
            ],
          ),
        ],
      ),
    );
  }

  Widget buildExpiryDatePicker() {
    if (!isStockInMovement()) {
      return const SizedBox();
    }

    final expiryText = getSelectedExpiryText();

    return Column(
      children: [
        const SizedBox(height: 12),
        InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: pickExpiryDate,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: cream,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selectedExpiryDate == null
                    ? Colors.orange.shade300
                    : Colors.green.shade200,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.event,
                  color:
                      selectedExpiryDate == null ? Colors.orange : Colors.green,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    selectedExpiryDate == null
                        ? 'Select expiry date for this stock batch'
                        : 'Batch expiry date: $expiryText',
                    style: TextStyle(
                      color: selectedExpiryDate == null
                          ? Colors.orange.shade900
                          : Colors.green.shade800,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: Colors.grey.shade600,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget buildQuantityForm() {
    if (selectedItem == null) {
      return const SizedBox();
    }

    final item = selectedItem!;
    final unit = getUnit(item);
    final packageName = getPackageName(item);
    final packageQuantity = getPackageQuantity(item);
    final current = getCurrentQuantity(item);
    final baseQuantity = getBaseQuantity();
    final afterQuantity = getAfterQuantity();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: softWhite,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: creamDark.withOpacity(0.85),
        ),
        boxShadow: [
          BoxShadow(
            color: mulberryDark.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: packageCountController,
            keyboardType: const TextInputType.numberWithOptions(
              decimal: true,
            ),
            onChanged: (_) {
              setState(() {});
            },
            style: const TextStyle(
              color: mulberryDark,
              fontWeight: FontWeight.w600,
            ),
            decoration: InputDecoration(
              labelText: isCorrectionMovement()
                  ? 'Correct stock quantity'
                  : 'Number of $packageName',
              hintText: isCorrectionMovement() ? 'Example: 30' : 'Example: 2',
              suffixText: isCorrectionMovement() ? unit : packageName,
              labelStyle: const TextStyle(color: mulberry),
              hintStyle: TextStyle(
                color: Colors.grey.shade500,
              ),
              prefixIcon: Icon(
                getMovementIcon(),
                color: getMovementColor(),
              ),
              filled: true,
              fillColor: cream,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: creamDark.withOpacity(0.9),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: getMovementColor(),
                  width: 1.8,
                ),
              ),
            ),
          ),
          buildExpiryDatePicker(),
          const SizedBox(height: 12),
          if (!isCorrectionMovement())
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: cream,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: creamDark.withOpacity(0.75),
                ),
              ),
              child: Text(
                '${formatNumber(getPackageCountInput())} $packageName × '
                '${formatNumber(packageQuantity)} $unit = '
                '${formatNumber(baseQuantity)} $unit',
                style: const TextStyle(
                  color: mulberry,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          if (isCorrectionMovement())
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.blue.shade100,
                ),
              ),
              child: Text(
                'Inventory will be corrected to ${formatNumber(afterQuantity)} $unit.',
                style: const TextStyle(
                  color: Colors.blue,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: afterQuantity <= getMinimumQuantity(item)
                  ? Colors.orange.shade50
                  : Colors.green.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: afterQuantity <= getMinimumQuantity(item)
                    ? Colors.orange.shade200
                    : Colors.green.shade100,
              ),
            ),
            child: Text(
              'Current: ${formatNumber(current)} $unit → New: ${formatNumber(afterQuantity)} $unit',
              style: TextStyle(
                color: afterQuantity <= getMinimumQuantity(item)
                    ? Colors.orange.shade900
                    : Colors.green,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: remarksController,
            maxLines: 2,
            style: const TextStyle(
              color: mulberryDark,
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              labelText: 'Remarks',
              hintText: 'Example: supplier delivery, damaged item, expired...',
              labelStyle: const TextStyle(color: mulberry),
              hintStyle: TextStyle(
                color: Colors.grey.shade500,
              ),
              prefixIcon: const Icon(
                Icons.notes_outlined,
                color: mulberry,
              ),
              filled: true,
              fillColor: cream,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: creamDark.withOpacity(0.9),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(
                  color: mulberry,
                  width: 1.8,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: isSaving ? null : saveAdjustment,
              icon: isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: cream,
                      ),
                    )
                  : const Icon(Icons.save),
              label: Text(isSaving ? 'Saving...' : 'Save Stock Adjustment'),
              style: ElevatedButton.styleFrom(
                backgroundColor: getMovementColor(),
                foregroundColor: Colors.white,
                disabledBackgroundColor: getMovementColor().withOpacity(0.45),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildItemList() {
    final filteredItems = getFilteredItems();

    if (filteredItems.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 40),
        child: Center(
          child: Column(
            children: [
              Icon(
                Icons.inventory_2_outlined,
                color: mulberry.withOpacity(0.45),
                size: 54,
              ),
              const SizedBox(height: 12),
              Text(
                'No inventory item found.',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: filteredItems.map((item) {
        final itemId = getItemId(item);
        final itemName = getItemName(item);
        final category = getCategory(item);
        final unit = getUnit(item);
        final current = getCurrentQuantity(item);
        final packageName = getPackageName(item);
        final packageQuantity = getPackageQuantity(item);
        final expiryDate = getExpiryDate(item);
        final expired = isExpired(item);
        final expiringSoon = isExpiringSoon(item);
        final selected =
            selectedItem != null && getItemId(selectedItem!) == itemId;
        final lowStock = isLowStock(item);

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: selected
                ? const Color(0xFFFFF7E6)
                : lowStock
                    ? Colors.red.shade50
                    : softWhite,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected
                  ? Colors.orange.shade300
                  : lowStock
                      ? Colors.red.shade100
                      : creamDark.withOpacity(0.75),
            ),
            boxShadow: [
              BoxShadow(
                color: mulberryDark.withOpacity(selected ? 0.08 : 0.04),
                blurRadius: selected ? 14 : 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => selectItem(item),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: selected
                        ? Colors.orange.shade100
                        : mulberry.withOpacity(0.12),
                    child: Icon(
                      selected ? Icons.check : Icons.inventory_2,
                      color: selected ? Colors.orange : mulberry,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          itemName,
                          style: const TextStyle(
                            color: mulberryDark,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          category,
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 7),
                        Wrap(
                          spacing: 7,
                          runSpacing: 6,
                          children: [
                            buildSmallBadge('${formatNumber(current)} $unit'),
                            buildSmallBadge(
                              '1 $packageName = ${formatNumber(packageQuantity)} $unit',
                            ),
                            if (expiryDate.isNotEmpty)
                              buildColoredBadge(
                                'Item Expiry: $expiryDate',
                                expired
                                    ? Colors.red
                                    : expiringSoon
                                        ? Colors.orange
                                        : Colors.green,
                              ),
                            if (expired) buildWarningBadge('EXPIRED'),
                            if (expiringSoon)
                              buildColoredBadge(
                                'EXPIRING SOON',
                                Colors.orange,
                              ),
                            if (lowStock) buildWarningBadge('LOW STOCK'),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    color: Colors.grey.shade500,
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget buildSmallBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: cream,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: creamDark.withOpacity(0.7),
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: Colors.grey.shade700,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget buildWarningBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.red,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget buildColoredBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color.withOpacity(0.22),
        ),
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
                'Stock Adjustment',
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
                  onPressed: loadInventoryItems,
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
              onRefresh: loadInventoryItems,
              child: ListView(
                padding: const EdgeInsets.all(18),
                children: [
                  buildHeader(),
                  const SizedBox(height: 14),
                  buildScannerButton(),
                  const SizedBox(height: 14),
                  buildMovementTypeSelector(),
                  const SizedBox(height: 14),
                  buildSelectedItemCard(),
                  const SizedBox(height: 14),
                  buildQuantityForm(),
                  const SizedBox(height: 18),
                  buildSearchBox(),
                  const SizedBox(height: 12),
                  buildCategoryFilter(),
                  const SizedBox(height: 16),
                  buildItemList(),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }
}