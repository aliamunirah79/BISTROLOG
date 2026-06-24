import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ReviewStockCountPage extends StatefulWidget {
  final bool showAppBar;

  const ReviewStockCountPage({
    super.key,
    this.showAppBar = true,
  });

  @override
  State<ReviewStockCountPage> createState() => _ReviewStockCountPageState();
}

class _ReviewStockCountPageState extends State<ReviewStockCountPage> {
  final supabase = Supabase.instance.client;

  bool isLoading = true;
  bool isProcessing = false;
  String? processingCountId;

  DateTime selectedDate = DateTime.now();

  String searchQuery = '';
  String selectedCategory = 'All';
  String selectedStatus = 'pending';

  List<Map<String, dynamic>> inventoryItems = [];
  List<Map<String, dynamic>> openingCounts = [];
  List<Map<String, dynamic>> closingCounts = [];
  List<Map<String, dynamic>> inventoryBatches = [];

  static const Color mulberry = Color(0xFF6D2B50);
  static const Color mulberryDark = Color(0xFF4A1A35);
  static const Color mulberryLight = Color(0xFF8B3D68);
  static const Color cream = Color(0xFFF5ECD7);
  static const Color creamDark = Color(0xFFE8D5B5);
  static const Color softWhite = Color(0xFFFFFCF7);

  String get selectedDateText {
    return selectedDate.toIso8601String().substring(0, 10);
  }

  @override
  void initState() {
    super.initState();
    loadReviewData();
  }

  Future<void> loadReviewData() async {
    if (!mounted) return;

    setState(() {
      isLoading = true;
    });

    try {
      final itemsResponse = await supabase
          .from('inventory_items')
          .select()
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
          .eq('count_date', selectedDateText)
          .eq('count_type', 'opening');

      final dynamic closingResponse;

      if (selectedStatus == 'all') {
        closingResponse = await supabase
            .from('daily_stock_counts')
            .select()
            .eq('count_date', selectedDateText)
            .eq('count_type', 'closing')
            .order('created_at', ascending: false);
      } else {
        closingResponse = await supabase
            .from('daily_stock_counts')
            .select()
            .eq('count_date', selectedDateText)
            .eq('count_type', 'closing')
            .eq('review_status', selectedStatus)
            .order('created_at', ascending: false);
      }

      if (!mounted) return;

      setState(() {
        inventoryItems = List<Map<String, dynamic>>.from(itemsResponse);
        inventoryBatches = List<Map<String, dynamic>>.from(batchResponse);
        openingCounts = List<Map<String, dynamic>>.from(openingResponse);
        closingCounts = List<Map<String, dynamic>>.from(closingResponse);
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
      });

      showMessage('Failed to load review data: $e', isError: true);
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

  num getCountQuantity(Map<String, dynamic>? count) {
    if (count == null) {
      return 0;
    }

    final value = count['quantity'] ?? count['counted_quantity'] ?? 0;
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

  String getReviewStatus(Map<String, dynamic> count) {
    return (count['review_status'] ?? 'pending').toString();
  }

  bool getInventoryDeducted(Map<String, dynamic> count) {
    return count['inventory_deducted'] == true;
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

  Map<String, dynamic>? getOpeningCount(String itemId) {
    try {
      return openingCounts.firstWhere(
        (count) => count['item_id'].toString() == itemId,
      );
    } catch (_) {
      return null;
    }
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

    if (batches.isEmpty) {
      return null;
    }

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

  bool hasEnoughBatchStock({
    required String itemId,
    required num usedQuantity,
  }) {
    if (usedQuantity <= 0) {
      return true;
    }

    final totalBatchQuantity = getBatchesForItem(itemId).fold<num>(
      0,
      (sum, batch) => sum + getBatchRemainingQuantity(batch),
    );

    return totalBatchQuantity >= usedQuantity;
  }

  List<String> getCategories() {
    final categories = closingCounts
        .map((count) {
          final item = getItemById(count['item_id'].toString());

          if (item == null) {
            return 'Uncategorized';
          }

          return getCategory(item);
        })
        .where((category) => category.trim().isNotEmpty)
        .toSet()
        .toList();

    categories.sort();

    return ['All', ...categories];
  }

  List<Map<String, dynamic>> getFilteredClosingCounts() {
    List<Map<String, dynamic>> filtered = closingCounts;

    if (selectedCategory != 'All') {
      filtered = filtered.where((count) {
        final item = getItemById(count['item_id'].toString());

        if (item == null) {
          return false;
        }

        return getCategory(item) == selectedCategory;
      }).toList();
    }

    if (searchQuery.trim().isNotEmpty) {
      final query = searchQuery.toLowerCase();

      filtered = filtered.where((count) {
        final item = getItemById(count['item_id'].toString());

        if (item == null) {
          return false;
        }

        final itemId = getItemId(item);
        final name = getItemName(item).toLowerCase();
        final category = getCategory(item).toLowerCase();
        final batch = getRecommendedBatch(itemId);
        final expiry = batch == null ? '' : getBatchExpiryDate(batch);

        return name.contains(query) ||
            category.contains(query) ||
            expiry.contains(query);
      }).toList();
    }

    return filtered;
  }

  Future<void> pickDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2024),
      lastDate: DateTime.now().add(const Duration(days: 30)),
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

    if (pickedDate == null) {
      return;
    }

    setState(() {
      selectedDate = pickedDate;
      selectedCategory = 'All';
      searchQuery = '';
    });

    await loadReviewData();
  }

  Future<void> saveInventoryUsageSummary({
    required String itemId,
    required String usageDate,
    required num openingQuantity,
    required num closingQuantity,
    required num estimatedUsage,
  }) async {
    try {
      await supabase.from('inventory_usage_summary').upsert(
        {
          'item_id': itemId,
          'usage_date': usageDate,
          'opening_quantity': openingQuantity,
          'closing_quantity': closingQuantity,
          'estimated_usage': estimatedUsage,
        },
        onConflict: 'item_id,usage_date',
      );
    } catch (e) {
      debugPrint('Failed to save inventory usage summary: $e');
    }
  }

  Future<void> deductBatchByFifo({
    required String itemId,
    required num usedQuantity,
  }) async {
    if (usedQuantity <= 0) {
      return;
    }

    await supabase.rpc(
      'fn_fifo_deduct_stock',
      params: {
        'p_item_id': itemId,
        'p_quantity': usedQuantity,
        'p_movement_type': 'daily_usage',
      },
    );
  }

  Future<void> approveCount(Map<String, dynamic> closingCount) async {
    if (isProcessing) {
      return;
    }

    final user = supabase.auth.currentUser;

    if (user == null) {
      showMessage('User not logged in.', isError: true);
      return;
    }

    final countId = closingCount['count_id'].toString();
    final status = getReviewStatus(closingCount);

    if (status == 'approved' || getInventoryDeducted(closingCount)) {
      showMessage(
        'This stock count has already been approved.',
        isError: true,
      );
      return;
    }

    final itemId = closingCount['item_id'].toString();
    final item = getItemById(itemId);
    final openingCount = getOpeningCount(itemId);

    if (item == null) {
      showMessage('Inventory item not found.', isError: true);
      return;
    }

    if (openingCount == null) {
      showMessage('Opening count not found for this item.', isError: true);
      return;
    }

    final openingQty = getCountQuantity(openingCount);
    final closingQty = getCountQuantity(closingCount);
    final usedQty = openingQty - closingQty;

    if (usedQty < 0) {
      showMessage(
        'Invalid count. Closing balance is more than opening quantity.',
        isError: true,
      );
      return;
    }

    if (!hasEnoughBatchStock(itemId: itemId, usedQuantity: usedQty)) {
      showMessage(
        'Not enough batch stock for FIFO deduction. Please check stock batches.',
        isError: true,
      );
      return;
    }

    final currentInventory = getCurrentQuantity(item);
    final newInventory = currentInventory - usedQty;
    final finalInventory = newInventory < 0 ? 0 : newInventory;

    setState(() {
      isProcessing = true;
      processingCountId = countId;
    });

    try {
      await deductBatchByFifo(
        itemId: itemId,
        usedQuantity: usedQty,
      );

      await supabase.from('inventory_items').update({
        'current_quantity': finalInventory,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('item_id', item['item_id']);

      await supabase.from('daily_stock_counts').update({
        'review_status': 'approved',
        'reviewed_by': user.id,
        'reviewed_at': DateTime.now().toIso8601String(),
        'review_remarks': null,
        'inventory_deducted': true,
        'variance': usedQty,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('count_id', closingCount['count_id']);

      await supabase.from('stock_movements').insert({
        'item_id': item['item_id'],
        'movement_type': 'stock_out',
        'quantity': usedQty,
        'base_quantity': usedQty,
        'before_quantity': currentInventory,
        'after_quantity': finalInventory,
        'daily_count_id': closingCount['count_id'],
        'remarks':
            'Daily usage approved from stock count for $selectedDateText. Used: ${formatNumber(usedQty)} ${getUnit(item)}. FIFO deduction applied.',
        'performed_by': user.id,
        'created_at': DateTime.now().toIso8601String(),
      });

      await saveInventoryUsageSummary(
        itemId: itemId,
        usageDate: selectedDateText,
        openingQuantity: openingQty,
        closingQuantity: closingQty,
        estimatedUsage: usedQty,
      );

      await notifyStaff(
        staffId: closingCount['staff_id'],
        title: 'Stock Count Approved',
        message:
            '${getItemName(item)} closing count has been approved. Inventory deducted by ${formatNumber(usedQty)} ${getUnit(item)} using FIFO.',
        targetPage: 'inventory',
        targetId: getItemId(item),
      );

      if (finalInventory <= getMinimumQuantity(item)) {
        await notifyManagerSupervisorLowStock(
          item: item,
          newQuantity: finalInventory,
        );
      }

      showMessage('Stock count approved. FIFO deduction has been applied.');

      await loadReviewData();
    } catch (e) {
      showMessage('Failed to approve count: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          isProcessing = false;
          processingCountId = null;
        });
      }
    }
  }

  Future<void> rejectCount(Map<String, dynamic> closingCount) async {
    if (isProcessing) {
      return;
    }

    final countId = closingCount['count_id'].toString();
    final reasonController = TextEditingController();

    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: softWhite,
          title: const Text(
            'Reject Stock Count',
            style: TextStyle(
              color: mulberryDark,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: TextField(
            controller: reasonController,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: 'Rejection reason',
              hintText: 'Example: closing balance does not match physical count',
              prefixIcon: const Icon(
                Icons.edit_note,
                color: mulberry,
              ),
              filled: true,
              fillColor: cream,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(
                  color: mulberry,
                  width: 1.8,
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              style: TextButton.styleFrom(
                foregroundColor: mulberry,
              ),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final text = reasonController.text.trim();

                if (text.isEmpty) {
                  return;
                }

                Navigator.pop(dialogContext, text);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Reject'),
            ),
          ],
        );
      },
    );

    reasonController.dispose();

    if (reason == null || reason.trim().isEmpty) {
      return;
    }

    final user = supabase.auth.currentUser;

    if (user == null) {
      showMessage('User not logged in.', isError: true);
      return;
    }

    final item = getItemById(closingCount['item_id'].toString());

    setState(() {
      isProcessing = true;
      processingCountId = countId;
    });

    try {
      await supabase.from('daily_stock_counts').update({
        'review_status': 'rejected',
        'review_remarks': reason,
        'reviewed_by': user.id,
        'reviewed_at': DateTime.now().toIso8601String(),
        'inventory_deducted': false,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('count_id', closingCount['count_id']);

      await notifyStaff(
        staffId: closingCount['staff_id'],
        title: 'Stock Count Rejected',
        message:
            '${item == null ? 'Your closing stock count' : getItemName(item)} was rejected. Reason: $reason',
        targetPage: 'daily_stock_count',
        targetId: closingCount['count_id'].toString(),
      );

      showMessage('Stock count rejected.');

      await loadReviewData();
    } catch (e) {
      showMessage('Failed to reject count: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          isProcessing = false;
          processingCountId = null;
        });
      }
    }
  }

  Future<void> notifyStaff({
    required dynamic staffId,
    required String title,
    required String message,
    required String targetPage,
    required String targetId,
  }) async {
    if (staffId == null) {
      return;
    }

    try {
      await supabase.from('notifications').insert({
        'user_id': staffId,
        'title': title,
        'message': message,
        'type': 'stock_count',
        'target_page': targetPage,
        'target_id': targetId,
        'is_read': false,
      });
    } catch (e) {
      debugPrint('Failed to notify staff: $e');
    }
  }

  Future<void> notifyManagerSupervisorLowStock({
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
              '$itemName is low after approved stock count. Current: ${formatNumber(newQuantity)} $unit, minimum: ${formatNumber(minimumQuantity)} $unit.',
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
    final total = closingCounts.length;
    final pending = closingCounts
        .where((count) => getReviewStatus(count) == 'pending')
        .length;

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
              Icons.verified,
              color: cream,
              size: 29,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Review Stock Count',
                  style: TextStyle(
                    color: cream,
                    fontFamily: 'Georgia',
                    fontSize: 21,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '$selectedDateText • $pending pending • $total record(s)',
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

  Widget buildDateSelector() {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: pickDate,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: buildWhiteBox(),
        child: Row(
          children: [
            const Icon(
              Icons.calendar_month,
              color: mulberry,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                selectedDateText,
                style: const TextStyle(
                  color: mulberryDark,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const Icon(
              Icons.chevron_right,
              color: mulberry,
            ),
          ],
        ),
      ),
    );
  }

  Widget buildStatusFilter() {
    final statuses = [
      {'label': 'Pending', 'value': 'pending'},
      {'label': 'Approved', 'value': 'approved'},
      {'label': 'Rejected', 'value': 'rejected'},
      {'label': 'All', 'value': 'all'},
    ];

    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: statuses.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final status = statuses[index];
          final selected = selectedStatus == status['value'];

          return ChoiceChip(
            label: Text(status['label']!),
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
            onSelected: (_) async {
              setState(() {
                selectedStatus = status['value']!;
                selectedCategory = 'All';
                searchQuery = '';
              });

              await loadReviewData();
            },
          );
        },
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

  Widget buildSearchBox() {
    return TextField(
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
        hintText: 'Search item or expiry...',
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
    );
  }

  Widget buildReviewCard(Map<String, dynamic> closingCount) {
    final itemId = closingCount['item_id'].toString();
    final item = getItemById(itemId);
    final openingCount = getOpeningCount(itemId);
    final status = getReviewStatus(closingCount);
    final countId = closingCount['count_id'].toString();

    final isThisCardProcessing = processingCountId == countId;

    if (item == null) {
      return Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: buildWhiteBox(),
        child: ListTile(
          title: const Text('Item not found'),
          subtitle: Text('Item ID: $itemId'),
        ),
      );
    }

    final itemName = getItemName(item);
    final category = getCategory(item);
    final unit = getUnit(item);

    final openingQty = getCountQuantity(openingCount);
    final closingQty = getCountQuantity(closingCount);
    final usedQty = openingQty - closingQty;

    final currentInventory = getCurrentQuantity(item);
    final afterApproval = currentInventory - usedQty;
    final finalInventory = afterApproval < 0 ? 0 : afterApproval;

    final recommendedBatch = getRecommendedBatch(itemId);
    final enoughBatchStock = hasEnoughBatchStock(
      itemId: itemId,
      usedQuantity: usedQty,
    );

    final isPending = status == 'pending';
    final isApproved = status == 'approved';
    final isRejected = status == 'rejected';

    Color statusColor = Colors.orange;
    IconData statusIcon = Icons.pending;

    if (isApproved) {
      statusColor = Colors.green;
      statusIcon = Icons.check_circle;
    } else if (isRejected) {
      statusColor = Colors.red;
      statusIcon = Icons.cancel;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: softWhite,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: statusColor.withOpacity(0.25),
        ),
        boxShadow: [
          BoxShadow(
            color: mulberryDark.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: statusColor.withOpacity(0.12),
                  child: Icon(
                    statusIcon,
                    color: statusColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    itemName,
                    style: const TextStyle(
                      color: mulberryDark,
                      fontWeight: FontWeight.bold,
                      fontSize: 15.5,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              category,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 12.5,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                buildBadge('Opening: ${formatNumber(openingQty)} $unit'),
                buildBadge('Closing: ${formatNumber(closingQty)} $unit'),
                buildBadge('Used: ${formatNumber(usedQty)} $unit'),
                buildBadge('Inventory: ${formatNumber(currentInventory)} $unit'),
                if (isPending)
                  buildBadge(
                    'After approve: ${formatNumber(finalInventory)} $unit',
                  ),
                if (recommendedBatch != null)
                  buildStatusBadge(
                    'FIFO Exp ${getBatchExpiryDate(recommendedBatch)}',
                    Colors.green,
                  )
                else
                  buildStatusBadge(
                    'No Batch',
                    Colors.red,
                  ),
                if (getInventoryDeducted(closingCount))
                  buildStatusBadge('Deducted', Colors.green),
              ],
            ),
            if (isPending && usedQty > 0) ...[
              const SizedBox(height: 10),
              buildInfoBox(
                'FIFO deduction preview:\n${getFifoPreviewText(itemId: itemId, usedQuantity: usedQty, unit: unit)}',
              ),
            ],
            if (openingCount == null) ...[
              const SizedBox(height: 10),
              buildWarningBox('Opening count missing. Cannot approve this item.'),
            ],
            if (usedQty < 0) ...[
              const SizedBox(height: 10),
              buildWarningBox(
                'Invalid count. Closing balance is greater than opening quantity.',
              ),
            ],
            if (!enoughBatchStock && usedQty > 0) ...[
              const SizedBox(height: 10),
              buildWarningBox(
                'Batch stock is not enough for FIFO deduction. Please check inventory batches before approving.',
              ),
            ],
            if (closingCount['remarks'] != null &&
                closingCount['remarks'].toString().trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                'Staff remarks: ${closingCount['remarks']}',
                style: TextStyle(
                  color: Colors.grey.shade700,
                ),
              ),
            ],
            if (isRejected &&
                closingCount['review_remarks'] != null &&
                closingCount['review_remarks'].toString().trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                'Reject reason: ${closingCount['review_remarks']}',
                style: const TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            if (isPending) ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: isThisCardProcessing
                          ? null
                          : () => rejectCount(closingCount),
                      icon: isThisCardProcessing
                          ? const SizedBox(
                              width: 17,
                              height: 17,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.red,
                              ),
                            )
                          : const Icon(Icons.close),
                      label: Text(
                        isThisCardProcessing ? 'Processing...' : 'Reject',
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: isThisCardProcessing ||
                              openingCount == null ||
                              usedQty < 0 ||
                              !enoughBatchStock
                          ? null
                          : () => approveCount(closingCount),
                      icon: isThisCardProcessing
                          ? const SizedBox(
                              width: 17,
                              height: 17,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: cream,
                              ),
                            )
                          : const Icon(Icons.check),
                      label: Text(
                        isThisCardProcessing ? 'Approving...' : 'Approve',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.green.withOpacity(0.35),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget buildBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 5,
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
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget buildStatusBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget buildInfoBox(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.green.shade100,
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: Colors.green.shade900,
          fontWeight: FontWeight.w600,
          height: 1.35,
        ),
      ),
    );
  }

  Widget buildWarningBox(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.red.shade100,
        ),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.red,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  BoxDecoration buildWhiteBox() {
    return BoxDecoration(
      color: softWhite,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(
        color: creamDark.withOpacity(0.80),
      ),
      boxShadow: [
        BoxShadow(
          color: mulberryDark.withOpacity(0.04),
          blurRadius: 10,
          offset: const Offset(0, 4),
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
    final filteredCounts = getFilteredClosingCounts();

    return Scaffold(
      backgroundColor: cream,
      appBar: widget.showAppBar
          ? AppBar(
              title: const Text(
                'Review Stock Count',
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
                  onPressed: isProcessing ? null : loadReviewData,
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
              onRefresh: loadReviewData,
              child: ListView(
                padding: const EdgeInsets.all(18),
                children: [
                  buildHeader(),
                  const SizedBox(height: 14),
                  buildDateSelector(),
                  const SizedBox(height: 12),
                  buildStatusFilter(),
                  const SizedBox(height: 12),
                  buildSearchBox(),
                  const SizedBox(height: 12),
                  buildCategoryFilter(),
                  const SizedBox(height: 18),
                  if (filteredCounts.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 100),
                      child: Center(
                        child: Text(
                          'No stock count record found.',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    )
                  else
                    ...filteredCounts.map(buildReviewCard),
                ],
              ),
            ),
    );
  }
}