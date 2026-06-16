import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class InventoryPage extends StatefulWidget {
  final bool showAppBar;

  const InventoryPage({
    super.key,
    this.showAppBar = true,
  });

  @override
  State<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage> {
  final supabase = Supabase.instance.client;

  final ScrollController contentScrollController = ScrollController();
  final TextEditingController searchController = TextEditingController();

  bool isLoading = true;
  bool showFloatingSearch = false;

  String searchQuery = '';
  String selectedCategory = 'All';

  List<Map<String, dynamic>> inventoryItems = [];
  Map<String, Map<String, dynamic>> profilesById = {};
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
    loadInventory();
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
    contentScrollController.removeListener(handleScroll);
    contentScrollController.dispose();
    searchController.dispose();
    super.dispose();
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
    if (searchQuery.trim().isNotEmpty) {
      return;
    }

    final categories = getCategories().where((c) => c != 'All').toList();

    if (categories.isEmpty) {
      return;
    }

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

  Future<void> loadInventory() async {
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

      final profilesResponse =
          await supabase.from('profiles').select('id, full_name, role, profile_id');

      final profileMap = <String, Map<String, dynamic>>{};

      for (final profile in List<Map<String, dynamic>>.from(profilesResponse)) {
        profileMap[profile['id'].toString()] = profile;
      }

      if (!mounted) return;

      setState(() {
        inventoryItems = List<Map<String, dynamic>>.from(itemsResponse);
        profilesById = profileMap;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
      });

      showMessage('Failed to load inventory: $e', isError: true);
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
    final value = item['barcode'];

    if (value == null || value.toString().trim().isEmpty) {
      return '-';
    }

    return value.toString();
  }

  String getSupplier(Map<String, dynamic> item) {
    final value = item['supplier'] ?? item['supplier_name'];

    if (value == null || value.toString().trim().isEmpty) {
      return '-';
    }

    return value.toString();
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

  bool isLowStock(Map<String, dynamic> item) {
    final current = getCurrentQuantity(item);
    final minimum = getMinimumQuantity(item);

    if (minimum <= 0) {
      return false;
    }

    return current <= minimum;
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

  String formatDate(dynamic value) {
    if (value == null) {
      return '-';
    }

    final text = value.toString();

    if (text.length >= 16) {
      return text.substring(0, 16).replaceFirst('T', ' ');
    }

    return text;
  }

  String getProfileName(dynamic userId) {
    if (userId == null) {
      return '-';
    }

    final profile = profilesById[userId.toString()];

    if (profile == null) {
      return '-';
    }

    final fullName = profile['full_name']?.toString() ?? '-';
    final role = profile['role']?.toString() ?? '';

    if (role.isEmpty) {
      return fullName;
    }

    return '$fullName ($role)';
  }

  String formatMovementType(String type) {
    switch (type) {
      case 'stock_in':
        return 'Stock In';
      case 'stock_out':
        return 'Stock Out';
      case 'damaged':
        return 'Damaged';
      case 'expired':
        return 'Expired';
      case 'correction':
        return 'Correction';
      case 'daily_usage':
        return 'Daily Usage';
      default:
        return type.replaceAll('_', ' ').toUpperCase();
    }
  }

  Color getMovementColor(String type) {
    switch (type) {
      case 'stock_in':
        return Colors.green;
      case 'stock_out':
      case 'daily_usage':
        return Colors.orange;
      case 'damaged':
      case 'expired':
        return Colors.red;
      case 'correction':
        return Colors.blue;
      default:
        return mulberry;
    }
  }

  IconData getMovementIcon(String type) {
    switch (type) {
      case 'stock_in':
        return Icons.add_circle;
      case 'stock_out':
      case 'daily_usage':
        return Icons.remove_circle;
      case 'damaged':
        return Icons.broken_image;
      case 'expired':
        return Icons.event_busy;
      case 'correction':
        return Icons.tune;
      default:
        return Icons.history;
    }
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

      return name.contains(query) ||
          category.contains(query) ||
          barcode.contains(query) ||
          supplier.contains(query);
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

  Future<List<Map<String, dynamic>>> loadItemHistory(String itemId) async {
    final response = await supabase
        .from('stock_movements')
        .select()
        .eq('item_id', itemId)
        .order('created_at', ascending: false)
        .limit(50);

    return List<Map<String, dynamic>>.from(response);
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

  void openBarcodeScanner() {
    bool scanned = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(24),
        ),
      ),
      builder: (scannerContext) {
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.of(scannerContext).size.height * 0.72,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
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
                          'Scan Inventory Barcode',
                          style: TextStyle(
                            color: cream,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          Navigator.pop(scannerContext);
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
                          if (scanned) return;

                          final barcodes = capture.barcodes;

                          if (barcodes.isEmpty) return;

                          final code = barcodes.first.rawValue;

                          if (code == null || code.trim().isEmpty) return;

                          scanned = true;

                          Navigator.pop(scannerContext);
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
                            'Point the camera at the barcode label.',
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

  void showInventoryDetail(Map<String, dynamic> item) {
    final itemId = getItemId(item);
    final itemName = getItemName(item);
    final category = getCategory(item);
    final unit = getUnit(item);
    final currentQty = getCurrentQuantity(item);
    final minimumQty = getMinimumQuantity(item);
    final packageName = getPackageName(item);
    final packageQty = getPackageQuantity(item);
    final barcode = getBarcode(item);
    final supplier = getSupplier(item);
    final lowStock = isLowStock(item);

    showModalBottomSheet(
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
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.of(bottomSheetContext).size.height * 0.86,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 27,
                            backgroundColor: lowStock
                                ? Colors.red.shade50
                                : mulberry.withOpacity(0.12),
                            child: Icon(
                              lowStock
                                  ? Icons.warning_amber
                                  : Icons.inventory_2,
                              color: lowStock ? Colors.red : mulberry,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              itemName,
                              style: const TextStyle(
                                color: mulberryDark,
                                fontFamily: 'Georgia',
                                fontSize: 21,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        category,
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          buildDetailBadge(
                            'Current: ${formatNumber(currentQty)} $unit',
                            lowStock ? Colors.red : mulberry,
                          ),
                          buildDetailBadge(
                            'Minimum: ${formatNumber(minimumQty)} $unit',
                            Colors.orange,
                          ),
                          buildDetailBadge(
                            '1 $packageName = ${formatNumber(packageQty)} $unit',
                            Colors.blue,
                          ),
                          if (barcode != '-')
                            buildDetailBadge(
                              'Barcode: $barcode',
                              Colors.grey,
                            ),
                          if (supplier != '-')
                            buildDetailBadge(
                              'Supplier: $supplier',
                              Colors.green,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                Divider(
                  height: 1,
                  color: creamDark.withOpacity(0.85),
                ),
                Expanded(
                  child: FutureBuilder<List<Map<String, dynamic>>>(
                    future: loadItemHistory(itemId),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(
                            color: mulberry,
                          ),
                        );
                      }

                      if (snapshot.hasError) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(18),
                            child: Text(
                              'Failed to load history: ${snapshot.error}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.red,
                              ),
                            ),
                          ),
                        );
                      }

                      final history = snapshot.data ?? [];

                      if (history.isEmpty) {
                        return Center(
                          child: Text(
                            'No stock movement history found.',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                            ),
                          ),
                        );
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.all(18),
                        itemCount: history.length,
                        itemBuilder: (context, index) {
                          return buildHistoryCard(history[index], unit);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget buildDetailBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color.withOpacity(0.25),
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget buildHistoryCard(Map<String, dynamic> movement, String unit) {
    final type = (movement['movement_type'] ?? 'unknown').toString();
    final color = getMovementColor(type);
    final icon = getMovementIcon(type);

    final quantity = movement['quantity'] ?? movement['base_quantity'] ?? 0;
    final baseQuantity = movement['base_quantity'] ?? quantity;
    final beforeQuantity = movement['before_quantity'];
    final afterQuantity = movement['after_quantity'];
    final remarks = movement['remarks'];
    final performedBy = movement['performed_by'];
    final createdAt = movement['created_at'];

    final packageCount = movement['package_count'];
    final packageName = movement['package_name'];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: softWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withOpacity(0.18),
        ),
        boxShadow: [
          BoxShadow(
            color: mulberryDark.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: color.withOpacity(0.12),
              child: Icon(
                icon,
                color: color,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    formatMovementType(type),
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      buildMiniHistoryBadge(
                        'Qty: ${formatNumber(quantity)} $unit',
                      ),
                      buildMiniHistoryBadge(
                        'Base: ${formatNumber(baseQuantity)} $unit',
                      ),
                      if (beforeQuantity != null)
                        buildMiniHistoryBadge(
                          'Before: ${formatNumber(beforeQuantity)}',
                        ),
                      if (afterQuantity != null)
                        buildMiniHistoryBadge(
                          'After: ${formatNumber(afterQuantity)}',
                        ),
                      if (packageCount != null && packageName != null)
                        buildMiniHistoryBadge(
                          '${formatNumber(packageCount)} $packageName',
                        ),
                    ],
                  ),
                  if (remarks != null &&
                      remarks.toString().trim().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      remarks.toString(),
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        height: 1.3,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    '${formatDate(createdAt)} • ${getProfileName(performedBy)}',
                    style: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildMiniHistoryBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: cream,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: creamDark.withOpacity(0.75),
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

  Widget buildHeader() {
    final total = inventoryItems.length;
    final lowStock = inventoryItems.where(isLowStock).length;

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
              Icons.inventory_2,
              color: cream,
              size: 30,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Inventory Overview',
                  style: TextStyle(
                    color: cream,
                    fontFamily: 'Georgia',
                    fontSize: 21,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '$total active item(s) • $lowStock low stock',
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

  Widget buildSearchBox() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      child: showFloatingSearch
          ? const SizedBox.shrink()
          : Padding(
              key: const ValueKey('search_box'),
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
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
        padding: const EdgeInsets.fromLTRB(6, 12, 6, 90),
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

    final lowStockCount = items.where(isLowStock).length;

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
              color: lowStockCount > 0
                  ? Colors.red.withOpacity(0.10)
                  : mulberry.withOpacity(0.09),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              lowStockCount > 0 ? '$lowStockCount low' : '${items.length} item',
              style: TextStyle(
                color: lowStockCount > 0 ? Colors.red : mulberry,
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
    final itemName = getItemName(item);
    final category = getCategory(item);
    final unit = getUnit(item);
    final currentQty = getCurrentQuantity(item);
    final minimumQty = getMinimumQuantity(item);
    final packageName = getPackageName(item);
    final packageQty = getPackageQuantity(item);
    final barcode = getBarcode(item);
    final supplier = getSupplier(item);
    final lowStock = isLowStock(item);

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      decoration: BoxDecoration(
        color: lowStock ? const Color(0xFFFFF7E6) : softWhite,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: lowStock ? Colors.orange.shade200 : creamDark.withOpacity(0.65),
        ),
        boxShadow: [
          BoxShadow(
            color: mulberryDark.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => showInventoryDetail(item),
        child: Padding(
          padding: const EdgeInsets.all(13),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor:
                    lowStock ? Colors.red.shade50 : mulberry.withOpacity(0.10),
                child: Icon(
                  lowStock ? Icons.warning_amber : Icons.inventory_2,
                  color: lowStock ? Colors.red : mulberry,
                  size: 22,
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
                          'Stock: ${formatNumber(currentQty)} $unit',
                        ),
                        buildSmallBadge(
                          'Min: ${formatNumber(minimumQty)}',
                        ),
                        buildSmallBadge(
                          '1 $packageName = ${formatNumber(packageQty)} $unit',
                        ),
                        if (barcode != '-') buildSmallBadge(barcode),
                        if (supplier != '-') buildSmallBadge(supplier),
                        if (lowStock) buildLowStockBadge(),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                Icons.chevron_right,
                color: Colors.grey.shade500,
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

  Widget buildLowStockBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Text(
        'LOW STOCK',
        style: TextStyle(
          color: Colors.red,
          fontSize: 10.5,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget buildInventoryBody() {
    final groupedItems = getGroupedItems();
    final searchedItems = getSearchFilteredItems();

    return Column(
      children: [
        if (widget.showAppBar) ...[
          Padding(
            padding: const EdgeInsets.all(12),
            child: buildHeader(),
          ),
        ],
        buildSearchBox(),
        Expanded(
          child: Row(
            children: [
              buildCategorySidebar(),
              Expanded(
                child: searchedItems.isEmpty
                    ? Center(
                        child: Text(
                          'No inventory item found.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      )
                    : ListView(
                        controller: contentScrollController,
                        padding: const EdgeInsets.only(bottom: 110),
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
                'Inventory',
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
                  onPressed: loadInventory,
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
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: mulberry,
              ),
            )
          : RefreshIndicator(
              color: mulberry,
              onRefresh: loadInventory,
              child: buildInventoryBody(),
            ),
    );
  }
}