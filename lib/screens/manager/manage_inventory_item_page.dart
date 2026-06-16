import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ManageInventoryItemPage extends StatefulWidget {
  final bool showAppBar;

  const ManageInventoryItemPage({
    super.key,
    this.showAppBar = true,
  });

  @override
  State<ManageInventoryItemPage> createState() =>
      _ManageInventoryItemPageState();
}

class _ManageInventoryItemPageState extends State<ManageInventoryItemPage> {
  final supabase = Supabase.instance.client;
  final TextEditingController searchController = TextEditingController();

  bool isLoading = true;
  bool showInactive = false;

  String searchQuery = '';
  String selectedCategory = 'All';

  List<Map<String, dynamic>> inventoryItems = [];

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
    super.dispose();
  }

  Future<void> loadInventoryItems() async {
    if (!mounted) return;

    setState(() {
      isLoading = true;
    });

    try {
      dynamic query = supabase.from('inventory_items').select();

      if (!showInactive) {
        query = query.eq('is_active', true);
      }

      final response = await query
          .order('category', ascending: true)
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

  bool getIsActive(Map<String, dynamic> item) {
    return item['is_active'] == null ? true : item['is_active'] == true;
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
        final supplier = (item['supplier'] ?? '').toString().toLowerCase();

        return name.contains(query) ||
            category.contains(query) ||
            barcode.contains(query) ||
            supplier.contains(query);
      }).toList();
    }

    return filtered;
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

  Future<void> openSearchBarcodeScanner() async {
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
                          'Scan Barcode to Search',
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
                            'Point your camera at the item or carton barcode.',
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

  Future<void> openBarcodeScanner({
    required TextEditingController barcodeController,
    required void Function() refreshModal,
  }) async {
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
                          'Scan Barcode',
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
                          barcodeController.text = code.trim();
                          refreshModal();

                          Navigator.pop(bottomSheetContext);
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
                            'Point your camera at the item or carton barcode.',
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

  Future<bool> isBarcodeAlreadyUsed({
    required String barcode,
    String? currentItemId,
  }) async {
    if (barcode.trim().isEmpty) {
      return false;
    }

    final response = await supabase
        .from('inventory_items')
        .select('item_id')
        .eq('barcode', barcode.trim());

    final items = List<Map<String, dynamic>>.from(response);

    if (items.isEmpty) {
      return false;
    }

    if (currentItemId == null) {
      return true;
    }

    for (final item in items) {
      if (item['item_id'].toString() != currentItemId) {
        return true;
      }
    }

    return false;
  }

  Future<bool> saveInventoryItem({
    Map<String, dynamic>? existingItem,
    required TextEditingController nameController,
    required TextEditingController categoryController,
    required TextEditingController unitController,
    required TextEditingController currentQtyController,
    required TextEditingController minQtyController,
    required TextEditingController barcodeController,
    required TextEditingController packageNameController,
    required TextEditingController packageQtyController,
    required TextEditingController supplierController,
  }) async {
    final user = supabase.auth.currentUser;

    if (user == null) {
      showMessage('User not logged in.', isError: true);
      return false;
    }

    final itemName = nameController.text.trim();
    final category = categoryController.text.trim();
    final unit = unitController.text.trim();
    final currentQty = num.tryParse(currentQtyController.text.trim());
    final minQty = num.tryParse(minQtyController.text.trim());
    final barcode = barcodeController.text.trim();
    final packageName = packageNameController.text.trim();
    final packageQty = num.tryParse(packageQtyController.text.trim());
    final supplier = supplierController.text.trim();

    if (itemName.isEmpty) {
      showMessage('Please enter item name.', isError: true);
      return false;
    }

    if (category.isEmpty) {
      showMessage('Please enter category.', isError: true);
      return false;
    }

    if (unit.isEmpty) {
      showMessage('Please enter base unit.', isError: true);
      return false;
    }

    if (currentQty == null || currentQty < 0) {
      showMessage('Please enter valid current quantity.', isError: true);
      return false;
    }

    if (minQty == null || minQty < 0) {
      showMessage('Please enter valid minimum quantity.', isError: true);
      return false;
    }

    if (packageName.isEmpty) {
      showMessage('Please enter package name.', isError: true);
      return false;
    }

    if (packageQty == null || packageQty <= 0) {
      showMessage('Please enter valid package quantity.', isError: true);
      return false;
    }

    final currentItemId = existingItem == null ? null : getItemId(existingItem);

    final barcodeUsed = await isBarcodeAlreadyUsed(
      barcode: barcode,
      currentItemId: currentItemId,
    );

    if (barcodeUsed) {
      showMessage(
        'This barcode is already registered to another item.',
        isError: true,
      );
      return false;
    }

    final data = {
      'item_name': itemName,
      'category': category,
      'unit': unit,
      'current_quantity': currentQty,
      'minimum_quantity': minQty,
      'barcode': barcode.isEmpty ? null : barcode,
      'package_name': packageName,
      'package_quantity': packageQty,
      'supplier': supplier.isEmpty ? null : supplier,
      'is_active': true,
      'updated_at': DateTime.now().toIso8601String(),
    };

    try {
      if (existingItem == null) {
        await supabase.from('inventory_items').insert({
          ...data,
          'created_by': user.id,
        });

        showMessage('New inventory item added.');
      } else {
        await supabase
            .from('inventory_items')
            .update(data)
            .eq('item_id', existingItem['item_id']);

        showMessage('Inventory item updated.');
      }

      return true;
    } catch (e) {
      showMessage('Failed to save item: $e', isError: true);
      return false;
    }
  }

  Future<void> deactivateItem(Map<String, dynamic> item) async {
    final itemName = getItemName(item);

    final confirm = await showConfirmDialog(
      title: 'Deactivate Item',
      message:
          'Are you sure you want to deactivate "$itemName"? It will be hidden from active inventory but history will remain.',
      confirmText: 'Deactivate',
      confirmColor: Colors.orange,
    );

    if (!confirm) {
      return;
    }

    try {
      await supabase.from('inventory_items').update({
        'is_active': false,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('item_id', item['item_id']);

      showMessage('$itemName has been deactivated.');
      await loadInventoryItems();
    } catch (e) {
      showMessage('Failed to deactivate item: $e', isError: true);
    }
  }

  Future<void> reactivateItem(Map<String, dynamic> item) async {
    try {
      await supabase.from('inventory_items').update({
        'is_active': true,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('item_id', item['item_id']);

      showMessage('${getItemName(item)} has been reactivated.');
      await loadInventoryItems();
    } catch (e) {
      showMessage('Failed to reactivate item: $e', isError: true);
    }
  }

  Future<void> deleteItem(Map<String, dynamic> item) async {
    final itemName = getItemName(item);

    final confirm = await showConfirmDialog(
      title: 'Delete Item Permanently',
      message:
          'Are you sure you want to permanently delete "$itemName"?\n\nThis action cannot be undone. If this item has stock history, deletion may fail. Deactivate is safer.',
      confirmText: 'Delete',
      confirmColor: Colors.red,
    );

    if (!confirm) {
      return;
    }

    try {
      await supabase
          .from('inventory_items')
          .delete()
          .eq('item_id', item['item_id']);

      showMessage('$itemName has been deleted permanently.');
      await loadInventoryItems();
    } catch (e) {
      showMessage(
        'Failed to delete item. This item may already have stock history. Use deactivate instead. Error: $e',
        isError: true,
      );
    }
  }

  Future<bool> showConfirmDialog({
    required String title,
    required String message,
    required String confirmText,
    required Color confirmColor,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: softWhite,
          title: Text(
            title,
            style: const TextStyle(
              color: mulberryDark,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            message,
            style: TextStyle(
              color: Colors.grey.shade800,
              height: 1.35,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              style: TextButton.styleFrom(
                foregroundColor: mulberry,
              ),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: confirmColor,
                foregroundColor: Colors.white,
              ),
              child: Text(confirmText),
            ),
          ],
        );
      },
    );

    return result == true;
  }

  void showAddEditItemSheet({Map<String, dynamic>? item}) {
    final isEdit = item != null;

    final nameController = TextEditingController(
      text: isEdit ? getItemName(item) : '',
    );

    final categoryController = TextEditingController(
      text: isEdit ? getCategory(item) : '',
    );

    final unitController = TextEditingController(
      text: isEdit ? getUnit(item) : '',
    );

    final currentQtyController = TextEditingController(
      text: isEdit ? formatNumber(getCurrentQuantity(item)) : '0',
    );

    final minQtyController = TextEditingController(
      text: isEdit ? formatNumber(getMinimumQuantity(item)) : '0',
    );

    final barcodeController = TextEditingController(
      text: isEdit ? getBarcode(item) : '',
    );

    final packageNameController = TextEditingController(
      text: isEdit ? getPackageName(item) : '',
    );

    final packageQtyController = TextEditingController(
      text: isEdit ? formatNumber(getPackageQuantity(item)) : '1',
    );

    final supplierController = TextEditingController(
      text: isEdit ? (item['supplier'] ?? '').toString() : '',
    );

    bool isSavingItem = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: softWhite,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(26),
        ),
      ),
      builder: (bottomSheetContext) {
        return StatefulBuilder(
          builder: (modalContext, setModalState) {
            void refreshExample() {
              setModalState(() {});
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
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: CircleAvatar(
                            radius: 36,
                            backgroundColor: cream,
                            child: Icon(
                              isEdit ? Icons.edit : Icons.add,
                              color: mulberry,
                              size: 34,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Center(
                          child: Text(
                            isEdit
                                ? 'Edit Inventory Item'
                                : 'Add New Inventory Item',
                            style: const TextStyle(
                              color: mulberryDark,
                              fontFamily: 'Georgia',
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        buildFormField(
                          controller: nameController,
                          label: 'Item Name',
                          hint: 'Example: Full Cream Milk',
                          icon: Icons.inventory_2,
                        ),
                        const SizedBox(height: 12),
                        buildFormField(
                          controller: categoryController,
                          label: 'Category',
                          hint: 'Example: Dairy, Dry Goods, Beverage',
                          icon: Icons.category_outlined,
                        ),
                        const SizedBox(height: 12),
                        buildFormField(
                          controller: unitController,
                          label: 'Base Unit',
                          hint: 'Example: pcs, pack, kg, bottle',
                          icon: Icons.scale_outlined,
                          onChanged: (_) => refreshExample(),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: buildFormField(
                                controller: currentQtyController,
                                label: 'Current Qty',
                                hint: '0',
                                icon: Icons.numbers,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                  decimal: true,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: buildFormField(
                                controller: minQtyController,
                                label: 'Minimum Qty',
                                hint: '10',
                                icon: Icons.warning_amber,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                  decimal: true,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: barcodeController,
                          style: const TextStyle(
                            color: mulberryDark,
                            fontWeight: FontWeight.w500,
                          ),
                          decoration: InputDecoration(
                            labelText: 'Barcode',
                            hintText: 'Scan or enter barcode',
                            labelStyle: const TextStyle(color: mulberry),
                            hintStyle: TextStyle(
                              color: Colors.grey.shade500,
                            ),
                            prefixIcon: const Icon(
                              Icons.qr_code,
                              color: mulberry,
                            ),
                            suffixIcon: IconButton(
                              tooltip: 'Scan barcode',
                              onPressed: () {
                                openBarcodeScanner(
                                  barcodeController: barcodeController,
                                  refreshModal: () {
                                    setModalState(() {});
                                  },
                                );
                              },
                              icon: const Icon(
                                Icons.qr_code_scanner,
                                color: mulberry,
                              ),
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
                        const SizedBox(height: 12),
                        buildFormField(
                          controller: packageNameController,
                          label: 'Package Name',
                          hint: 'Example: carton, box, big packet',
                          icon: Icons.inventory,
                          onChanged: (_) => refreshExample(),
                        ),
                        const SizedBox(height: 12),
                        buildFormField(
                          controller: packageQtyController,
                          label: 'Package Quantity',
                          hint: 'Example: 12',
                          icon: Icons.calculate_outlined,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          onChanged: (_) => refreshExample(),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(13),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF7E6),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.orange.shade100,
                            ),
                          ),
                          child: Text(
                            'Example: 1 ${packageNameController.text.trim().isEmpty ? 'package' : packageNameController.text.trim()} = ${packageQtyController.text.trim().isEmpty ? '0' : packageQtyController.text.trim()} ${unitController.text.trim().isEmpty ? 'unit' : unitController.text.trim()}',
                            style: TextStyle(
                              color: Colors.orange.shade900,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        buildFormField(
                          controller: supplierController,
                          label: 'Supplier Name',
                          hint: 'Example: Farm Fresh',
                          icon: Icons.local_shipping_outlined,
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton.icon(
                            onPressed: isSavingItem
                                ? null
                                : () async {
                                    setModalState(() {
                                      isSavingItem = true;
                                    });

                                    final saved = await saveInventoryItem(
                                      existingItem: item,
                                      nameController: nameController,
                                      categoryController: categoryController,
                                      unitController: unitController,
                                      currentQtyController:
                                          currentQtyController,
                                      minQtyController: minQtyController,
                                      barcodeController: barcodeController,
                                      packageNameController:
                                          packageNameController,
                                      packageQtyController:
                                          packageQtyController,
                                      supplierController: supplierController,
                                    );

                                    if (!mounted) return;

                                    if (saved) {
                                      if (Navigator.of(bottomSheetContext)
                                          .canPop()) {
                                        Navigator.of(bottomSheetContext).pop();
                                      }

                                      await Future.delayed(
                                        const Duration(milliseconds: 250),
                                      );

                                      await loadInventoryItems();
                                    } else {
                                      setModalState(() {
                                        isSavingItem = false;
                                      });
                                    }
                                  },
                            icon: isSavingItem
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: cream,
                                    ),
                                  )
                                : Icon(isEdit ? Icons.save : Icons.add),
                            label: Text(
                              isSavingItem
                                  ? 'Saving...'
                                  : isEdit
                                      ? 'Save Changes'
                                      : 'Add Item',
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: mulberry,
                              foregroundColor: cream,
                              disabledBackgroundColor:
                                  mulberry.withOpacity(0.45),
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

  Widget buildFormField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    ValueChanged<String>? onChanged,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      onChanged: onChanged,
      style: const TextStyle(
        color: mulberryDark,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: const TextStyle(color: mulberry),
        hintStyle: TextStyle(
          color: Colors.grey.shade500,
        ),
        prefixIcon: Icon(
          icon,
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
    );
  }

  Widget buildHeader() {
    final total = inventoryItems.length;
    final active = inventoryItems.where(getIsActive).length;
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
              Icons.edit_note,
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
                  'Manage Inventory Items',
                  style: TextStyle(
                    color: cream,
                    fontFamily: 'Georgia',
                    fontSize: 21,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  showInactive
                      ? '$total item(s) • showing inactive too'
                      : '$active active item(s) • $lowStock low stock',
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
    return TextField(
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
              onPressed: openSearchBarcodeScanner,
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

  Widget buildShowInactiveSwitch() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
      child: SwitchListTile(
        contentPadding: EdgeInsets.zero,
        value: showInactive,
        activeColor: mulberry,
        title: const Text(
          'Show inactive items',
          style: TextStyle(
            color: mulberryDark,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          'Inactive items are hidden from stock adjustment',
          style: TextStyle(
            color: Colors.grey.shade600,
          ),
        ),
        onChanged: (value) async {
          setState(() {
            showInactive = value;
          });

          await loadInventoryItems();
        },
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
    final supplier = (item['supplier'] ?? '-').toString();
    final active = getIsActive(item);
    final lowStock = isLowStock(item);

    return Container(
      margin: const EdgeInsets.only(bottom: 13),
      decoration: BoxDecoration(
        color: !active
            ? Colors.grey.shade100
            : lowStock
                ? const Color(0xFFFFF7E6)
                : softWhite,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: !active
              ? Colors.grey.shade300
              : lowStock
                  ? Colors.orange.shade200
                  : creamDark.withOpacity(0.75),
        ),
        boxShadow: [
          BoxShadow(
            color: mulberryDark.withOpacity(active ? 0.05 : 0.025),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: active ? () => showAddEditItemSheet(item: item) : null,
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: !active
                    ? Colors.grey.shade300
                    : lowStock
                        ? Colors.red.shade50
                        : mulberry.withOpacity(0.12),
                child: Icon(
                  !active
                      ? Icons.block
                      : lowStock
                          ? Icons.warning_amber
                          : Icons.inventory_2,
                  color: !active
                      ? Colors.grey
                      : lowStock
                          ? Colors.red
                          : mulberry,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      itemName,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15.5,
                        color: active ? mulberryDark : Colors.black45,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      category,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        buildSmallBadge('Stock: $currentQty $unit'),
                        buildSmallBadge('Min: $minimumQty $unit'),
                        buildSmallBadge('1 $packageName = $packageQty $unit'),
                        if (barcode.isNotEmpty)
                          buildSmallBadge('Barcode: $barcode'),
                        if (supplier != '-' && supplier.trim().isNotEmpty)
                          buildSmallBadge('Supplier: $supplier'),
                        if (lowStock && active) buildWarningBadge('LOW STOCK'),
                        if (!active) buildInactiveBadge('INACTIVE'),
                      ],
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                color: softWhite,
                onSelected: (value) {
                  if (value == 'edit') {
                    showAddEditItemSheet(item: item);
                  } else if (value == 'deactivate') {
                    deactivateItem(item);
                  } else if (value == 'reactivate') {
                    reactivateItem(item);
                  } else if (value == 'delete') {
                    deleteItem(item);
                  }
                },
                itemBuilder: (context) {
                  return [
                    if (active)
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit, size: 18, color: mulberry),
                            SizedBox(width: 8),
                            Text('Edit'),
                          ],
                        ),
                      ),
                    if (active)
                      const PopupMenuItem(
                        value: 'deactivate',
                        child: Row(
                          children: [
                            Icon(Icons.block, size: 18, color: Colors.orange),
                            SizedBox(width: 8),
                            Text('Deactivate'),
                          ],
                        ),
                      ),
                    if (!active)
                      const PopupMenuItem(
                        value: 'reactivate',
                        child: Row(
                          children: [
                            Icon(Icons.restore, size: 18, color: Colors.green),
                            SizedBox(width: 8),
                            Text('Reactivate'),
                          ],
                        ),
                      ),
                    const PopupMenuDivider(),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(
                            Icons.delete_forever,
                            size: 18,
                            color: Colors.red,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Delete Permanently',
                            style: TextStyle(color: Colors.red),
                          ),
                        ],
                      ),
                    ),
                  ];
                },
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

  Widget buildInactiveBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.grey,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.only(top: 100),
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
    final filteredItems = getFilteredItems();

    return Scaffold(
      backgroundColor: cream,
      appBar: widget.showAppBar
          ? AppBar(
              title: const Text(
                'Manage Inventory',
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          showAddEditItemSheet();
        },
        backgroundColor: mulberry,
        foregroundColor: cream,
        icon: const Icon(Icons.add),
        label: const Text('Add Item'),
      ),
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
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 90),
                children: [
                  if (widget.showAppBar) ...[
                    buildHeader(),
                    const SizedBox(height: 14),
                  ],
                  buildSearchBox(),
                  const SizedBox(height: 12),
                  buildCategoryFilter(),
                  const SizedBox(height: 12),
                  buildShowInactiveSwitch(),
                  const SizedBox(height: 18),
                  if (filteredItems.isEmpty)
                    buildEmptyState()
                  else
                    ...filteredItems.map(buildItemCard),
                ],
              ),
            ),
    );
  }
}