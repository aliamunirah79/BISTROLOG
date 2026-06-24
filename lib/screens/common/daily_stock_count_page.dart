import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum DailyCountType {
  opening,
  closing,
}

class DailyStockCountPage extends StatefulWidget {
  final bool showAppBar;

  const DailyStockCountPage({
    super.key,
    this.showAppBar = true,
  });

  @override
  State<DailyStockCountPage> createState() => _DailyStockCountPageState();
}

class _DailyStockCountPageState extends State<DailyStockCountPage> {
  final supabase = Supabase.instance.client;

  final searchController = TextEditingController();
  final remarksController = TextEditingController();

  bool isLoading = true;
  bool isSubmitting = false;

  DailyCountType selectedType = DailyCountType.opening;

  String searchQuery = '';
  String selectedCategory = 'All';

  List<Map<String, dynamic>> inventoryItems = [];
  List<Map<String, dynamic>> inventoryBatches = [];

  Map<String, Map<String, dynamic>> openingCounts = {};
  Map<String, Map<String, dynamic>> closingCounts = {};
  Map<String, num> enteredQuantities = {};

  static const Color mulberry = Color(0xFF6D2B50);
  static const Color mulberryDark = Color(0xFF4A1A35);
  static const Color mulberryLight = Color(0xFF8B3D68);
  static const Color cream = Color(0xFFF5ECD7);
  static const Color creamDark = Color(0xFFE8D5B5);
  static const Color softWhite = Color(0xFFFFFCF7);

  @override
  void initState() {
    super.initState();
    loadData();

    searchController.addListener(() {
      if (!mounted) return;

      setState(() {
        searchQuery = searchController.text.trim();
      });
    });
  }

  @override
  void dispose() {
    searchController.dispose();
    remarksController.dispose();
    super.dispose();
  }

  String get today {
    return DateTime.now().toIso8601String().substring(0, 10);
  }

  bool get isOpening {
    return selectedType == DailyCountType.opening;
  }

  bool get isClosing {
    return selectedType == DailyCountType.closing;
  }

  String get selectedCountTypeText {
    return isOpening ? 'opening' : 'closing';
  }

  String get selectedTitle {
    return isOpening ? 'Opening Stock Count' : 'Closing Stock Count';
  }

  Future<void> loadData() async {
    if (!mounted) return;

    setState(() {
      isLoading = true;
    });

    try {
      final itemsResponse = await supabase
          .from('inventory_items')
          .select()
          .eq('is_active', true)
          .order('category', ascending: true)
          .order('item_name', ascending: true);

      final batchResponse = await supabase
          .from('inventory_batches')
          .select()
          .eq('is_active', true)
          .gt('remaining_quantity', 0)
          .order('expiry_date', ascending: true)
          .order('received_date', ascending: true);

      final openingResponse = await supabase
          .from('daily_stock_counts')
          .select()
          .eq('count_date', today)
          .eq('count_type', 'opening');

      final closingResponse = await supabase
          .from('daily_stock_counts')
          .select()
          .eq('count_date', today)
          .eq('count_type', 'closing');

      final items = List<Map<String, dynamic>>.from(itemsResponse);
      final batches = List<Map<String, dynamic>>.from(batchResponse);
      final openingList = List<Map<String, dynamic>>.from(openingResponse);
      final closingList = List<Map<String, dynamic>>.from(closingResponse);

      final Map<String, Map<String, dynamic>> openingMap = {};
      final Map<String, Map<String, dynamic>> closingMap = {};

      for (final count in openingList) {
        final itemId = (count['item_id'] ?? '').toString();

        if (itemId.isNotEmpty) {
          openingMap[itemId] = count;
        }
      }

      for (final count in closingList) {
        final itemId = (count['item_id'] ?? '').toString();

        if (itemId.isNotEmpty) {
          closingMap[itemId] = count;
        }
      }

      final Map<String, num> currentEntered = {};

      for (final item in items) {
        final itemId = getItemId(item);
        final existingCount = isOpening ? openingMap[itemId] : closingMap[itemId];

        if (existingCount != null) {
          currentEntered[itemId] = getCountQuantity(existingCount);
        }
      }

      if (!mounted) return;

      setState(() {
        inventoryItems = items;
        inventoryBatches = batches;
        openingCounts = openingMap;
        closingCounts = closingMap;
        enteredQuantities = currentEntered;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
      });

      showMessage('Failed to load daily stock count: $e', isError: true);
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
    final value = item['category'] ?? item['item_category'];

    if (value == null || value.toString().trim().isEmpty) {
      return 'Uncategorized';
    }

    return value.toString();
  }

  String getUnit(Map<String, dynamic> item) {
    return (item['unit'] ?? item['uom'] ?? item['measurement_unit'] ?? 'unit')
        .toString();
  }

  String getBarcode(Map<String, dynamic> item) {
    return (item['barcode'] ?? '').toString();
  }

  String getSupplier(Map<String, dynamic> item) {
    return (item['supplier'] ?? item['supplier_name'] ?? '').toString();
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

  num getCountQuantity(Map<String, dynamic>? count) {
    if (count == null) return 0;

    final value = count['quantity'] ?? count['counted_quantity'] ?? 0;
    return num.tryParse(value.toString()) ?? 0;
  }

  String getReviewStatus(Map<String, dynamic>? count) {
    if (count == null) return 'not_submitted';

    return (count['review_status'] ?? 'pending').toString();
  }

  bool isInventoryDeducted(Map<String, dynamic>? count) {
    if (count == null) return false;

    return count['inventory_deducted'] == true;
  }

  String formatNumber(dynamic value) {
    if (value == null) return '0';

    final number = num.tryParse(value.toString()) ?? 0;

    if (number % 1 == 0) {
      return number.toInt().toString();
    }

    return number.toString();
  }

  String formatValue(String value) {
    final cleaned = value.trim();

    if (cleaned.isEmpty) return '-';

    return cleaned
        .replaceAll('_', ' ')
        .split(' ')
        .where((part) => part.trim().isNotEmpty)
        .map((part) => part[0].toUpperCase() + part.substring(1))
        .join(' ');
  }

  String getBatchItemId(Map<String, dynamic> batch) {
    return (batch['item_id'] ?? '').toString();
  }

  num getBatchRemainingQuantity(Map<String, dynamic> batch) {
    final value = batch['remaining_quantity'] ?? 0;
    return num.tryParse(value.toString()) ?? 0;
  }

  String getBatchExpiryDate(Map<String, dynamic> batch) {
    final value = batch['expiry_date'];

    if (value == null || value.toString().trim().isEmpty) {
      return '-';
    }

    return value.toString().substring(0, 10);
  }

  String getBatchReceivedDate(Map<String, dynamic> batch) {
    final value = batch['received_date'];

    if (value == null || value.toString().trim().isEmpty) {
      return '-';
    }

    return value.toString().substring(0, 10);
  }

  List<Map<String, dynamic>> getBatchesForItem(String itemId) {
    final batches = inventoryBatches.where((batch) {
      return getBatchItemId(batch) == itemId &&
          getBatchRemainingQuantity(batch) > 0;
    }).toList();

    batches.sort((a, b) {
      final aExpiry = getBatchExpiryDate(a);
      final bExpiry = getBatchExpiryDate(b);

      final expiryCompare = aExpiry.compareTo(bExpiry);

      if (expiryCompare != 0) {
        return expiryCompare;
      }

      final aReceived = getBatchReceivedDate(a);
      final bReceived = getBatchReceivedDate(b);

      return aReceived.compareTo(bReceived);
    });

    return batches;
  }

  Map<String, dynamic>? getRecommendedBatch(String itemId) {
    final batches = getBatchesForItem(itemId);

    if (batches.isEmpty) return null;

    return batches.first;
  }

  String getFifoPreviewText({
    required String itemId,
    required num usedQuantity,
    required String unit,
  }) {
    if (usedQuantity <= 0) {
      return 'No stock deduction needed.';
    }

    final batches = getBatchesForItem(itemId);

    if (batches.isEmpty) {
      return 'No active batch found for FIFO deduction.';
    }

    num remainingNeed = usedQuantity;
    final List<String> lines = [];

    for (final batch in batches) {
      if (remainingNeed <= 0) break;

      final batchQty = getBatchRemainingQuantity(batch);
      final deductQty = remainingNeed > batchQty ? batchQty : remainingNeed;
      final expiry = getBatchExpiryDate(batch);

      lines.add(
        '${formatNumber(deductQty)} $unit from batch expiring $expiry',
      );

      remainingNeed -= deductQty;
    }

    if (remainingNeed > 0) {
      lines.add(
        'Short by ${formatNumber(remainingNeed)} $unit because batch stock is not enough.',
      );
    }

    return lines.join('\n');
  }

  bool isExpiredBatch(Map<String, dynamic> batch) {
    final expiryText = getBatchExpiryDate(batch);

    if (expiryText == '-') return false;

    final expiry = DateTime.tryParse(expiryText);

    if (expiry == null) return false;

    final now = DateTime.now();
    final todayDate = DateTime(now.year, now.month, now.day);
    final expiryDate = DateTime(expiry.year, expiry.month, expiry.day);

    return expiryDate.isBefore(todayDate);
  }

  bool isExpiringSoonBatch(Map<String, dynamic> batch) {
    final expiryText = getBatchExpiryDate(batch);

    if (expiryText == '-') return false;

    final expiry = DateTime.tryParse(expiryText);

    if (expiry == null) return false;

    final now = DateTime.now();
    final todayDate = DateTime(now.year, now.month, now.day);
    final expiryDate = DateTime(expiry.year, expiry.month, expiry.day);

    if (expiryDate.isBefore(todayDate)) return false;

    return expiryDate.difference(todayDate).inDays <= 7;
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
        final itemId = getItemId(item);
        final name = getItemName(item).toLowerCase();
        final category = getCategory(item).toLowerCase();
        final barcode = getBarcode(item).toLowerCase();
        final supplier = getSupplier(item).toLowerCase();
        final batch = getRecommendedBatch(itemId);
        final expiry = batch == null ? '' : getBatchExpiryDate(batch);

        return name.contains(query) ||
            category.contains(query) ||
            barcode.contains(query) ||
            supplier.contains(query) ||
            expiry.contains(query);
      }).toList();
    }

    return filtered;
  }

  int getEnteredCount() {
    return enteredQuantities.length;
  }

  int getSavedCount() {
    final map = isOpening ? openingCounts : closingCounts;
    return map.length;
  }

  bool isItemSaved(String itemId) {
    final map = isOpening ? openingCounts : closingCounts;
    return map.containsKey(itemId);
  }

  num? getOpeningQuantity(String itemId) {
    final opening = openingCounts[itemId];

    if (opening == null) return null;

    return getCountQuantity(opening);
  }

  num? getClosingQuantity(String itemId) {
    final closing = closingCounts[itemId];

    if (closing == null) return null;

    return getCountQuantity(closing);
  }

  num getUsedQuantity(String itemId) {
    final openingQty = getOpeningQuantity(itemId);
    final closingQty = enteredQuantities[itemId] ?? getClosingQuantity(itemId);

    if (openingQty == null || closingQty == null) return 0;

    return openingQty - closingQty;
  }

  Future<void> changeCountType(DailyCountType type) async {
    setState(() {
      selectedType = type;
      selectedCategory = 'All';
      searchQuery = '';
      searchController.clear();
      remarksController.clear();
    });

    await loadData();
  }

  void clearSearch() {
    setState(() {
      searchQuery = '';
      searchController.clear();
    });
  }

  void applyBarcodeSearch(String barcode) {
    final code = barcode.trim();

    if (code.isEmpty) return;

    setState(() {
      searchController.text = code;
      searchQuery = code;
      selectedCategory = 'All';
    });
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
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.of(bottomSheetContext).size.height * 0.78,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 10),
                  color: mulberryDark,
                  child: Row(
                    children: [
                      const Icon(
                        Icons.qr_code_scanner,
                        color: cream,
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Scan Item Barcode',
                          style: TextStyle(
                            color: cream,
                            fontSize: 18,
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
                          color: cream,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Stack(
                    children: [
                      MobileScanner(
                        onDetect: (capture) {
                          if (detected) return;
                          if (capture.barcodes.isEmpty) return;

                          final code = capture.barcodes.first.rawValue;

                          if (code == null || code.trim().isEmpty) return;

                          detected = true;

                          Navigator.pop(bottomSheetContext);
                          applyBarcodeSearch(code);
                        },
                      ),
                      Center(
                        child: Container(
                          width: 260,
                          height: 170,
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: cream,
                              width: 3,
                            ),
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 20,
                        right: 20,
                        bottom: 28,
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.55),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Text(
                            'Point your camera at the item barcode.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: cream,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> showQuantityDialog(Map<String, dynamic> item) async {
    final itemId = getItemId(item);
    final itemName = getItemName(item);
    final unit = getUnit(item);
    final currentStock = getCurrentQuantity(item);
    final openingQty = getOpeningQuantity(itemId);
    final existingEntered = enteredQuantities[itemId];
    final existingClosing = closingCounts[itemId];
    final recommendedBatch = getRecommendedBatch(itemId);

    if (isClosing && getReviewStatus(existingClosing) == 'approved') {
      showMessage(
        'This closing count has already been approved and cannot be edited.',
        isError: true,
      );
      return;
    }

    String quantityText =
        existingEntered == null ? '' : formatNumber(existingEntered);

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: cream,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(26),
        ),
      ),
      builder: (bottomSheetContext) {
        return StatefulBuilder(
          builder: (modalContext, setModalState) {
            final entered = num.tryParse(quantityText.trim());

            num? usedQty;

            if (isClosing && openingQty != null && entered != null) {
              usedQty = openingQty - entered;
            }

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(bottomSheetContext).viewInsets.bottom,
                ),
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: CircleAvatar(
                            radius: 34,
                            backgroundColor: mulberry.withOpacity(0.12),
                            child: Icon(
                              isOpening
                                  ? Icons.wb_sunny_outlined
                                  : Icons.nights_stay_outlined,
                              color: mulberry,
                              size: 34,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Center(
                          child: Text(
                            itemName,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: mulberryDark,
                              fontFamily: 'Georgia',
                              fontSize: 21,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Center(
                          child: Text(
                            getCategory(item),
                            style: TextStyle(
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        buildDialogInfoRow(
                          'Inventory Stock',
                          '${formatNumber(currentStock)} $unit',
                        ),
                        if (recommendedBatch != null)
                          buildDialogInfoRow(
                            'FIFO Batch',
                            '${formatNumber(getBatchRemainingQuantity(recommendedBatch))} $unit • Exp: ${getBatchExpiryDate(recommendedBatch)}',
                            valueColor: Colors.green.shade700,
                          )
                        else
                          buildDialogInfoRow(
                            'FIFO Batch',
                            'No active batch found',
                            valueColor: Colors.red,
                          ),
                        if (isClosing)
                          buildDialogInfoRow(
                            'Opening Quantity',
                            openingQty == null
                                ? 'Not entered yet'
                                : '${formatNumber(openingQty)} $unit',
                            valueColor:
                                openingQty == null ? Colors.red : mulberryDark,
                          ),
                        const SizedBox(height: 12),
                        TextFormField(
                          initialValue: quantityText,
                          autofocus: true,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          onChanged: (value) {
                            quantityText = value;
                            setModalState(() {});
                          },
                          decoration: InputDecoration(
                            labelText: isOpening
                                ? 'Opening quantity taken'
                                : 'Closing balance quantity',
                            hintText: isOpening
                                ? 'Enter quantity taken for opening'
                                : 'Enter remaining balance after operation',
                            suffixText: unit,
                            prefixIcon: const Icon(
                              Icons.calculate_outlined,
                              color: mulberry,
                            ),
                            filled: true,
                            fillColor: softWhite,
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(
                                color: creamDark,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(
                                color: mulberry,
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                        if (isClosing && entered != null) ...[
                          const SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: usedQty != null && usedQty < 0
                                  ? Colors.red.shade50
                                  : Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: usedQty != null && usedQty < 0
                                    ? Colors.red.shade200
                                    : Colors.orange.shade200,
                              ),
                            ),
                            child: Text(
                              usedQty == null
                                  ? 'Opening quantity is required before closing.'
                                  : usedQty < 0
                                      ? 'Closing balance cannot be more than opening quantity.'
                                      : 'Used today: ${formatNumber(usedQty)} $unit.\n\nFIFO preview:\n${getFifoPreviewText(itemId: itemId, usedQuantity: usedQty, unit: unit)}\n\nInventory will be deducted only after approval.',
                              style: TextStyle(
                                color: usedQty != null && usedQty < 0
                                    ? Colors.red
                                    : Colors.orange.shade900,
                                fontWeight: FontWeight.bold,
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 18),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              final quantity =
                                  num.tryParse(quantityText.trim());

                              if (quantity == null || quantity < 0) {
                                showMessage(
                                  'Please enter a valid quantity.',
                                  isError: true,
                                );
                                return;
                              }

                              if (isClosing && openingQty == null) {
                                showMessage(
                                  'Opening count is required before closing count.',
                                  isError: true,
                                );
                                return;
                              }

                              if (isClosing &&
                                  openingQty != null &&
                                  quantity > openingQty) {
                                showMessage(
                                  'Closing balance cannot be more than opening quantity.',
                                  isError: true,
                                );
                                return;
                              }

                              setState(() {
                                enteredQuantities[itemId] = quantity;
                              });

                              Navigator.pop(bottomSheetContext);
                            },
                            icon: const Icon(Icons.check),
                            label: const Text('Confirm Quantity'),
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
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget buildDialogInfoRow(
    String label,
    String value, {
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        children: [
          SizedBox(
            width: 145,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: valueColor ?? mulberryDark,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> submitAllCounts() async {
    final user = supabase.auth.currentUser;

    if (user == null) {
      showMessage('User not logged in.', isError: true);
      return;
    }

    if (enteredQuantities.isEmpty) {
      showMessage('Please enter at least one item quantity.', isError: true);
      return;
    }

    if (isClosing) {
      for (final entry in enteredQuantities.entries) {
        final openingQty = getOpeningQuantity(entry.key);

        if (openingQty == null) {
          showMessage(
            'Opening count is required before submitting closing count.',
            isError: true,
          );
          return;
        }

        if (entry.value > openingQty) {
          showMessage(
            'Closing balance cannot be more than opening quantity.',
            isError: true,
          );
          return;
        }

        final existingClosing = closingCounts[entry.key];

        if (getReviewStatus(existingClosing) == 'approved' &&
            isInventoryDeducted(existingClosing)) {
          showMessage(
            'Approved closing count cannot be edited or resubmitted.',
            isError: true,
          );
          return;
        }
      }
    }

    setState(() {
      isSubmitting = true;
    });

    try {
      final remark = remarksController.text.trim().isEmpty
          ? null
          : remarksController.text.trim();

      bool hasClosingSubmission = false;

      for (final item in inventoryItems) {
        final itemId = getItemId(item);

        if (!enteredQuantities.containsKey(itemId)) {
          continue;
        }

        final quantity = enteredQuantities[itemId]!;
        final systemQuantity = getCurrentQuantity(item);
        final existingCount =
            isOpening ? openingCounts[itemId] : closingCounts[itemId];

        final openingQty = getOpeningQuantity(itemId);
        final usedQuantity =
            isClosing && openingQty != null ? openingQty - quantity : 0;

        final data = {
          'item_id': item['item_id'],
          'staff_id': user.id,
          'count_type': selectedCountTypeText,
          'quantity': quantity,
          'count_date': today,
          'remarks': remark,
          'updated_at': DateTime.now().toIso8601String(),
          'counted_quantity': quantity,
          'system_quantity': systemQuantity,
          'variance': isClosing ? usedQuantity : 0,
          'counted_by': user.id,
          'review_status': isClosing ? 'pending' : 'approved',
          'reviewed_by': null,
          'reviewed_at': null,
          'review_remarks': null,
          'inventory_deducted': false,
        };

        if (existingCount == null) {
          await supabase.from('daily_stock_counts').insert(data);
        } else {
          await supabase
              .from('daily_stock_counts')
              .update(data)
              .eq('count_id', existingCount['count_id']);
        }

        if (isClosing) {
          hasClosingSubmission = true;
        }
      }

      if (hasClosingSubmission) {
        await notifyReviewersForStockCount();
      }

      showMessage(
        isOpening
            ? 'Opening stock count submitted successfully.'
            : 'Closing stock count submitted for review. Inventory will be updated after approval.',
      );

      remarksController.clear();

      await loadData();
    } catch (e) {
      showMessage('Failed to submit stock count: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          isSubmitting = false;
        });
      }
    }
  }

  Future<void> notifyReviewersForStockCount() async {
    try {
      final users = await supabase
          .from('profiles')
          .select('id')
          .inFilter('role', ['manager', 'supervisor']);

      final userList = List<Map<String, dynamic>>.from(users);

      if (userList.isEmpty) return;

      final notifications = userList.map((user) {
        return {
          'user_id': user['id'],
          'title': 'Stock Count Pending Review',
          'message':
              'Closing stock count for $today has been submitted and is waiting for approval.',
          'type': 'stock_count',
          'target_page': 'review_stock_count',
          'target_id': today,
          'is_read': false,
        };
      }).toList();

      await supabase.from('notifications').insert(notifications);
    } catch (e) {
      debugPrint('Failed to notify stock count reviewers: $e');
    }
  }

  Widget buildHeader() {
    final total = inventoryItems.length;
    final entered = getEnteredCount();
    final saved = getSavedCount();

    return Container(
      margin: EdgeInsets.fromLTRB(12, widget.showAppBar ? 12 : 0, 12, 8),
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
            blurRadius: 18,
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
              Icons.fact_check,
              color: cream,
              size: 29,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  selectedTitle,
                  style: const TextStyle(
                    color: cream,
                    fontFamily: 'Georgia',
                    fontSize: 21,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'Today: $today • Entered $entered • Saved $saved / $total',
                  style: const TextStyle(
                    color: creamDark,
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

  Widget buildTypeToggle() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: creamDark.withOpacity(0.65),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            Expanded(
              child: buildToggleButton(
                label: 'Opening',
                icon: Icons.wb_sunny_outlined,
                selected: isOpening,
                onTap: () => changeCountType(DailyCountType.opening),
              ),
            ),
            Expanded(
              child: buildToggleButton(
                label: 'Closing',
                icon: Icons.nights_stay_outlined,
                selected: isClosing,
                onTap: () => changeCountType(DailyCountType.closing),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildToggleButton({
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(15),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? mulberry : Colors.transparent,
          borderRadius: BorderRadius.circular(15),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: selected ? cream : mulberry,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: selected ? cream : mulberry,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildInstructionCard() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isOpening ? Colors.blue.shade50 : Colors.orange.shade50,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isOpening ? Colors.blue.shade100 : Colors.orange.shade200,
          ),
        ),
        child: Text(
          isOpening
              ? 'Opening: enter the quantity taken for today operation. Opening count is saved immediately.'
              : 'Closing: enter the remaining balance. Inventory will not be deducted yet. Supervisor or manager must approve it first.',
          style: TextStyle(
            color: isOpening ? Colors.blue.shade900 : Colors.orange.shade900,
            fontWeight: FontWeight.w600,
            height: 1.35,
          ),
        ),
      ),
    );
  }

  Widget buildSearchBox() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
      child: TextField(
        controller: searchController,
        style: const TextStyle(
          color: mulberryDark,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          hintText: 'Search item, barcode, supplier or expiry...',
          hintStyle: TextStyle(
            color: Colors.grey.shade500,
          ),
          prefixIcon: const Icon(
            Icons.search,
            color: mulberry,
          ),
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (searchController.text.trim().isNotEmpty)
                IconButton(
                  tooltip: 'Clear search',
                  onPressed: clearSearch,
                  icon: const Icon(
                    Icons.close,
                    color: mulberry,
                  ),
                ),
              IconButton(
                tooltip: 'Scan barcode',
                onPressed: openBarcodeScanner,
                icon: const Icon(
                  Icons.qr_code_scanner,
                  color: mulberry,
                ),
              ),
            ],
          ),
          filled: true,
          fillColor: softWhite,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide(
              color: creamDark.withOpacity(0.85),
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
      ),
    );
  }

  Widget buildCategoryFilter() {
    final categories = getCategories();

    return SizedBox(
      height: 42,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 12),
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

  Widget buildRemarkBox() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
      child: TextField(
        controller: remarksController,
        maxLines: 2,
        style: const TextStyle(
          color: mulberryDark,
        ),
        decoration: InputDecoration(
          labelText: 'Overall remarks optional',
          hintText: 'Example: normal usage, wastage, damaged item...',
          prefixIcon: const Icon(
            Icons.notes_outlined,
            color: mulberry,
          ),
          filled: true,
          fillColor: softWhite,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide(
              color: creamDark.withOpacity(0.85),
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
      ),
    );
  }

  Widget buildItemList() {
    final items = getFilteredItems();

    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 90),
        child: Center(
          child: Text(
            'No inventory item found.',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }

    return Column(
      children: items.map(buildItemCard).toList(),
    );
  }

  Widget buildItemCard(Map<String, dynamic> item) {
    final itemId = getItemId(item);
    final itemName = getItemName(item);
    final category = getCategory(item);
    final unit = getUnit(item);
    final currentStock = getCurrentQuantity(item);
    final minimumStock = getMinimumQuantity(item);
    final barcode = getBarcode(item);

    final recommendedBatch = getRecommendedBatch(itemId);
    final batchExpired =
        recommendedBatch != null && isExpiredBatch(recommendedBatch);
    final batchExpiringSoon =
        recommendedBatch != null && isExpiringSoonBatch(recommendedBatch);

    final entered = enteredQuantities[itemId];
    final saved = isItemSaved(itemId);

    final openingQty = getOpeningQuantity(itemId);
    final closingQty = getClosingQuantity(itemId);
    final usedQty = getUsedQuantity(itemId);

    final existingClosing = closingCounts[itemId];
    final status =
        getReviewStatus(isOpening ? openingCounts[itemId] : existingClosing);

    final lowStock = minimumStock > 0 && currentStock <= minimumStock;

    Color cardColor = softWhite;
    Color borderColor = creamDark.withOpacity(0.55);

    if (entered != null) {
      cardColor = const Color(0xFFFFF7E6);
      borderColor = Colors.orange.shade200;
    } else if (saved) {
      cardColor = const Color(0xFFF1F8E9);
      borderColor = Colors.green.shade200;
    }

    if (isClosing && status == 'rejected') {
      cardColor = Colors.red.shade50;
      borderColor = Colors.red.shade200;
    }

    if (isClosing && status == 'pending') {
      cardColor = const Color(0xFFFFF7E6);
      borderColor = Colors.orange.shade200;
    }

    if (isClosing && status == 'approved') {
      cardColor = const Color(0xFFF1F8E9);
      borderColor = Colors.green.shade200;
    }

    return Card(
      elevation: entered != null || saved ? 4 : 2,
      color: cardColor,
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 13),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: borderColor,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => showQuantityDialog(item),
        child: Padding(
          padding: const EdgeInsets.all(13),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor:
                    lowStock ? Colors.red.shade50 : mulberry.withOpacity(0.10),
                child: Icon(
                  lowStock ? Icons.warning_amber : Icons.inventory_2,
                  color: lowStock ? Colors.red : mulberry,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      itemName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: mulberryDark,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      category,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12.2,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        buildSmallBadge(
                          'Stock: ${formatNumber(currentStock)} $unit',
                        ),
                        buildSmallBadge(
                          'Min: ${formatNumber(minimumStock)} $unit',
                        ),
                        if (barcode.isNotEmpty) buildSmallBadge(barcode),
                        if (recommendedBatch != null)
                          buildColoredBadge(
                            'FIFO: Exp ${getBatchExpiryDate(recommendedBatch)}',
                            batchExpired
                                ? Colors.red
                                : batchExpiringSoon
                                    ? Colors.orange
                                    : Colors.green,
                          )
                        else
                          buildColoredBadge(
                            'NO BATCH',
                            Colors.red,
                          ),
                        if (batchExpired) buildColoredBadge('EXPIRED', Colors.red),
                        if (batchExpiringSoon)
                          buildColoredBadge('EXPIRING SOON', Colors.orange),
                        if (lowStock) buildColoredBadge('LOW STOCK', Colors.red),
                        if (openingQty != null)
                          buildSmallBadge(
                            'Opening: ${formatNumber(openingQty)} $unit',
                          ),
                        if (closingQty != null)
                          buildSmallBadge(
                            'Closing: ${formatNumber(closingQty)} $unit',
                          ),
                        if (isClosing && openingQty != null && entered != null)
                          buildSmallBadge(
                            'Used: ${formatNumber(usedQty)} $unit',
                          ),
                        if (isClosing && saved) buildStatusBadge(status),
                        if (isClosing &&
                            status == 'rejected' &&
                            existingClosing?['review_remarks'] != null)
                          buildRejectReasonBadge(
                            existingClosing!['review_remarks'].toString(),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (entered != null) ...[
                    Text(
                      formatNumber(entered),
                      style: const TextStyle(
                        color: Colors.orange,
                        fontSize: 21,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      unit,
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 11,
                      ),
                    ),
                  ] else if (saved) ...[
                    Icon(
                      isClosing && status == 'rejected'
                          ? Icons.error
                          : isClosing && status == 'pending'
                              ? Icons.pending
                              : Icons.check_circle,
                      color: isClosing && status == 'rejected'
                          ? Colors.red
                          : isClosing && status == 'pending'
                              ? Colors.orange
                              : Colors.green,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      isClosing ? status.toUpperCase() : 'Saved',
                      style: TextStyle(
                        color: isClosing && status == 'rejected'
                            ? Colors.red
                            : isClosing && status == 'pending'
                                ? Colors.orange
                                : Colors.green,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ] else ...[
                    Icon(
                      Icons.chevron_right,
                      color: Colors.grey.shade500,
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
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
          color: creamDark.withOpacity(0.70),
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: Colors.grey.shade700,
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
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
          fontSize: 10.5,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget buildStatusBadge(String status) {
    Color color = Colors.orange;

    if (status == 'approved') {
      color = Colors.green;
    } else if (status == 'rejected') {
      color = Colors.red;
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 10.5,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget buildRejectReasonBadge(String reason) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.red.shade100,
        ),
      ),
      child: Text(
        'Rejected reason: $reason',
        style: const TextStyle(
          color: Colors.red,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget buildBodyContent() {
    return RefreshIndicator(
      color: mulberry,
      onRefresh: loadData,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 115),
        children: [
          if (widget.showAppBar) buildHeader(),
          buildTypeToggle(),
          buildInstructionCard(),
          buildSearchBox(),
          buildCategoryFilter(),
          buildRemarkBox(),
          const SizedBox(height: 8),
          buildItemList(),
          const SizedBox(height: 30),
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
      appBar: widget.showAppBar
          ? AppBar(
              title: const Text(
                'Daily Stock Count',
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
                  onPressed: isSubmitting ? null : loadData,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            )
          : null,
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 14),
          decoration: BoxDecoration(
            color: softWhite,
            border: Border(
              top: BorderSide(
                color: creamDark.withOpacity(0.85),
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: mulberryDark.withOpacity(0.08),
                blurRadius: 12,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: SizedBox(
            height: 50,
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: isSubmitting ? null : submitAllCounts,
              icon: isSubmitting
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: cream,
                      ),
                    )
                  : const Icon(Icons.send),
              label: Text(
                isSubmitting
                    ? 'Submitting...'
                    : isOpening
                        ? 'Submit Opening Count'
                        : 'Submit Closing Count for Review',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: mulberry,
                foregroundColor: cream,
                disabledBackgroundColor: mulberry.withOpacity(0.45),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ),
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: mulberry,
              ),
            )
          : buildBodyContent(),
    );
  }
}