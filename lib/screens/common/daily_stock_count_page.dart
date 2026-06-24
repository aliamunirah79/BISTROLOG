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

  final remarksController = TextEditingController();
  final searchController = TextEditingController();
  final ScrollController contentScrollController = ScrollController();

  bool isLoading = true;
  bool isSubmitting = false;
  bool showFloatingSearch = false;

  DailyCountType selectedType = DailyCountType.opening;

  String searchQuery = '';
  String selectedCategory = 'All';

  List<Map<String, dynamic>> inventoryItems = [];

  Map<String, Map<String, dynamic>> openingCounts = {};
  Map<String, Map<String, dynamic>> closingCounts = {};

  Map<String, num> enteredQuantities = {};
  final Map<String, GlobalKey> categoryKeys = {};

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

    contentScrollController.addListener(handleScroll);

    searchController.addListener(() {
      if (!mounted) return;

      setState(() {
        searchQuery = searchController.text.trim();
      });
    });
  }

  @override
  void dispose() {
    remarksController.dispose();
    searchController.dispose();
    contentScrollController.removeListener(handleScroll);
    contentScrollController.dispose();
    super.dispose();
  }

  String get today {
    return DateTime.now().toIso8601String().substring(0, 10);
  }

  String get selectedCountTypeText {
    return selectedType == DailyCountType.opening ? 'opening' : 'closing';
  }

  String get selectedTitle {
    return selectedType == DailyCountType.opening
        ? 'Opening Stock Count'
        : 'Closing Stock Count';
  }

  bool get isOpening {
    return selectedType == DailyCountType.opening;
  }

  bool get isClosing {
    return selectedType == DailyCountType.closing;
  }

  void handleScroll() {
    final shouldShowSearch =
        contentScrollController.hasClients && contentScrollController.offset > 78;

    if (shouldShowSearch != showFloatingSearch) {
      setState(() {
        showFloatingSearch = shouldShowSearch;
      });
    }

    updateCategoryFromScroll();
  }

  void updateCategoryFromScroll() {
    if (searchQuery.trim().isNotEmpty) return;

    final categories = getCategories().where((c) => c != 'All').toList();

    if (categories.isEmpty) return;

    String? activeCategory;
    double closestTop = double.negativeInfinity;

    for (final category in categories) {
      final key = categoryKeys[category];
      final context = key?.currentContext;

      if (context == null) continue;

      final box = context.findRenderObject() as RenderBox?;
      if (box == null || !box.attached) continue;

      final position = box.localToGlobal(Offset.zero).dy;

      if (position <= 210 && position > closestTop) {
        closestTop = position;
        activeCategory = category;
      }
    }

    if (activeCategory != null && activeCategory != selectedCategory) {
      setState(() {
        selectedCategory = activeCategory!;
      });
    }
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
      final openingList = List<Map<String, dynamic>>.from(openingResponse);
      final closingList = List<Map<String, dynamic>>.from(closingResponse);

      final Map<String, Map<String, dynamic>> openingMap = {};
      final Map<String, Map<String, dynamic>> closingMap = {};

      for (final count in openingList) {
        final itemId = count['item_id']?.toString() ?? '';

        if (itemId.isNotEmpty) {
          openingMap[itemId] = count;
        }
      }

      for (final count in closingList) {
        final itemId = count['item_id']?.toString() ?? '';

        if (itemId.isNotEmpty) {
          closingMap[itemId] = count;
        }
      }

      final Map<String, num> currentEntered = {};

      for (final item in items) {
        final itemId = getItemId(item);
        final existing = isOpening ? openingMap[itemId] : closingMap[itemId];

        if (existing != null) {
          currentEntered[itemId] = getCountQuantity(existing);
        }
      }

      if (!mounted) return;

      setState(() {
        inventoryItems = items;
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

  String getExpiryDate(Map<String, dynamic> item) {
    final value = item['expiry_date'] ?? item['expiration_date'];

    if (value == null || value.toString().trim().isEmpty) {
      return '';
    }

    return value.toString().substring(0, 10);
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
    if (count == null) {
      return 0;
    }

    final value = count['quantity'] ?? count['counted_quantity'] ?? 0;
    return num.tryParse(value.toString()) ?? 0;
  }

  String getReviewStatus(Map<String, dynamic>? count) {
    if (count == null) {
      return 'not_submitted';
    }

    return (count['review_status'] ?? 'pending').toString();
  }

  bool isInventoryDeducted(Map<String, dynamic>? count) {
    if (count == null) {
      return false;
    }

    return count['inventory_deducted'] == true;
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

  IconData getCategoryIcon(String category) {
    final lower = category.toLowerCase();

    if (category == 'All') return Icons.grid_view;
    if (lower.contains('beverage')) return Icons.local_drink;
    if (lower.contains('dairy')) return Icons.local_cafe;
    if (lower.contains('syrup')) return Icons.liquor;
    if (lower.contains('fruit')) return Icons.spa;
    if (lower.contains('bakery')) return Icons.bakery_dining;
    if (lower.contains('cake')) return Icons.cake;
    if (lower.contains('dessert')) return Icons.icecream;
    if (lower.contains('hot')) return Icons.lunch_dining;
    if (lower.contains('dry')) return Icons.inventory_2;
    if (lower.contains('sauce')) return Icons.kitchen;
    if (lower.contains('packaging')) return Icons.takeout_dining;

    return Icons.category;
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

  List<Map<String, dynamic>> getSearchFilteredItems() {
    if (searchQuery.trim().isEmpty) {
      return inventoryItems;
    }

    final query = searchQuery.toLowerCase();

    return inventoryItems.where((item) {
      final name = getItemName(item).toLowerCase();
      final category = getCategory(item).toLowerCase();
      final barcode = getBarcode(item).toLowerCase();
      final supplier = getSupplier(item).toLowerCase();
      final expiryDate = getExpiryDate(item).toLowerCase();

      return name.contains(query) ||
          category.contains(query) ||
          barcode.contains(query) ||
          supplier.contains(query) ||
          expiryDate.contains(query);
    }).toList();
  }

  Map<String, List<Map<String, dynamic>>> getGroupedItems() {
    final sourceItems = getSearchFilteredItems();
    final grouped = <String, List<Map<String, dynamic>>>{};

    for (final item in sourceItems) {
      final category = getCategory(item);
      grouped.putIfAbsent(category, () => []);
      grouped[category]!.add(item);
    }

    for (final list in grouped.values) {
      list.sort((a, b) => getItemName(a).compareTo(getItemName(b)));
    }

    final sortedKeys = grouped.keys.toList()..sort();

    return {
      for (final key in sortedKeys) key: grouped[key]!,
    };
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

    if (opening == null) {
      return null;
    }

    return getCountQuantity(opening);
  }

  num? getClosingQuantity(String itemId) {
    final closing = closingCounts[itemId];

    if (closing == null) {
      return null;
    }

    return getCountQuantity(closing);
  }

  num getUsedQuantity(String itemId) {
    final openingQty = getOpeningQuantity(itemId);
    final closingQty = enteredQuantities[itemId] ?? getClosingQuantity(itemId);

    if (openingQty == null || closingQty == null) {
      return 0;
    }

    return openingQty - closingQty;
  }

  bool isApprovedClosing(String itemId) {
    final closing = closingCounts[itemId];

    if (closing == null) {
      return false;
    }

    return getReviewStatus(closing) == 'approved' &&
        isInventoryDeducted(closing);
  }

  Future<void> changeCountType(DailyCountType type) async {
    setState(() {
      selectedType = type;
      selectedCategory = 'All';
      searchController.clear();
      searchQuery = '';
      remarksController.clear();
    });

    await loadData();
  }

  void jumpToCategory(String category) {
    setState(() {
      selectedCategory = category;
    });

    if (category == 'All') {
      if (contentScrollController.hasClients) {
        contentScrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOut,
        );
      }
      return;
    }

    final key = categoryKeys[category];
    final context = key?.currentContext;

    if (context != null) {
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOut,
        alignment: 0.02,
      );
    }
  }

  void clearSearch() {
    searchController.clear();

    setState(() {
      searchQuery = '';
      selectedCategory = 'All';
    });
  }

  void applyBarcodeSearch(String barcode) {
    final code = barcode.trim();

    if (code.isEmpty) return;

    searchController.text = code;

    setState(() {
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

  void openSearchPanel() {
    showModalBottomSheet(
      context: context,
      backgroundColor: cream,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(24),
        ),
      ),
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            18,
            18,
            18,
            MediaQuery.of(sheetContext).viewInsets.bottom + 20,
          ),
          child: SafeArea(
            child: TextField(
              autofocus: true,
              controller: searchController,
              style: const TextStyle(
                color: mulberryDark,
                fontWeight: FontWeight.w600,
              ),
              decoration: InputDecoration(
                hintText: 'Search item, barcode or supplier...',
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
                      onPressed: () {
                        Navigator.pop(sheetContext);
                        openBarcodeScanner();
                      },
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

    if (isClosing && getReviewStatus(existingClosing) == 'approved') {
      showMessage(
        'This closing count has already been approved and cannot be edited.',
        isError: true,
      );
      return;
    }

    String quantityText = existingEntered == null ? '' : formatNumber(existingEntered);

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
                          '$currentStock $unit',
                        ),
                        if (isClosing)
                          buildDialogInfoRow(
                            'Opening Quantity',
                            openingQty == null
                                ? 'Not entered yet'
                                : '$openingQty $unit',
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
                                      : 'Used today: ${formatNumber(usedQty)} $unit. Inventory will be deducted only after approval.',
                              style: TextStyle(
                                color: usedQty != null && usedQty < 0
                                    ? Colors.red
                                    : Colors.orange.shade900,
                                fontWeight: FontWeight.bold,
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
                              final quantity = num.tryParse(quantityText.trim());

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

      if (userList.isEmpty) {
        return;
      }

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
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      child: showFloatingSearch
          ? const SizedBox.shrink()
          : Padding(
              key: const ValueKey('search_box'),
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
              child: TextField(
                controller: searchController,
                style: const TextStyle(
                  color: mulberryDark,
                  fontWeight: FontWeight.w500,
                ),
                decoration: InputDecoration(
                  hintText: 'Search item, barcode or supplier...',
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

  Widget buildCategorySidebar() {
    final categories = getCategories();

    return Container(
      width: 96,
      decoration: BoxDecoration(
        color: softWhite,
        border: Border(
          right: BorderSide(
            color: creamDark.withOpacity(0.75),
          ),
        ),
      ),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(6, 12, 6, 100),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final category = categories[index];
          final selected = selectedCategory == category;

          return InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => jumpToCategory(category),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(
                horizontal: 6,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: selected ? mulberry.withOpacity(0.10) : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
                border: Border(
                  left: BorderSide(
                    color: selected ? mulberry : Colors.transparent,
                    width: 4,
                  ),
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    getCategoryIcon(category),
                    color: selected ? mulberry : Colors.grey.shade600,
                    size: 25,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    category,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: selected ? mulberry : Colors.grey.shade700,
                      fontSize: 10.8,
                      fontWeight: selected ? FontWeight.bold : FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget buildCategoryHeader(String category, List<Map<String, dynamic>> items) {
    categoryKeys.putIfAbsent(category, () => GlobalKey());

    return Container(
      key: categoryKeys[category],
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              category,
              style: const TextStyle(
                color: mulberryDark,
                fontFamily: 'Georgia',
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 9,
              vertical: 5,
            ),
            decoration: BoxDecoration(
              color: mulberry.withOpacity(0.09),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${items.length} item',
              style: const TextStyle(
                color: mulberry,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
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
    final expiryDate = getExpiryDate(item);
    final expired = isExpired(item);
    final expiringSoon = isExpiringSoon(item);

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
                        buildSmallBadge('Stock: $currentStock $unit'),
                        buildSmallBadge('Min: $minimumStock $unit'),
                        if (barcode.isNotEmpty) buildSmallBadge(barcode),
                        if (expiryDate.isNotEmpty)
                          buildColoredBadge(
                            'Expiry: $expiryDate',
                            expired
                                ? Colors.red
                                : expiringSoon
                                    ? Colors.orange
                                    : Colors.green,
                          ),
                        if (expired) buildColoredBadge('EXPIRED', Colors.red),
                        if (expiringSoon)
                          buildColoredBadge('EXPIRING SOON', Colors.orange),
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

  Widget buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(top: 100),
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

  Widget buildStockCountBody() {
    final groupedItems = getGroupedItems();
    final searchedItems = getSearchFilteredItems();

    return Column(
      children: [
        if (widget.showAppBar) buildHeader(),
        buildTypeToggle(),
        buildInstructionCard(),
        buildSearchBox(),
        buildRemarkBox(),
        Expanded(
          child: Row(
            children: [
              buildCategorySidebar(),
              Expanded(
                child: searchedItems.isEmpty
                    ? buildEmptyState()
                    : ListView(
                        controller: contentScrollController,
                        padding: const EdgeInsets.only(bottom: 115),
                        children: [
                          if (searchQuery.trim().isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                              child: Text(
                                '${searchedItems.length} result(s) found',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12.5,
                                ),
                              ),
                            ),
                          ...groupedItems.entries.expand((entry) {
                            final category = entry.key;
                            final items = entry.value;

                            return [
                              buildCategoryHeader(category, items),
                              ...items.map(buildItemCard),
                            ];
                          }),
                        ],
                      ),
              ),
            ],
          ),
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
      floatingActionButton: showFloatingSearch
          ? FloatingActionButton(
              mini: true,
              backgroundColor: softWhite,
              foregroundColor: mulberry,
              elevation: 5,
              onPressed: openSearchPanel,
              child: const Icon(Icons.search),
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
          : RefreshIndicator(
              color: mulberry,
              onRefresh: loadData,
              child: buildStockCountBody(),
            ),
    );
  }
}
