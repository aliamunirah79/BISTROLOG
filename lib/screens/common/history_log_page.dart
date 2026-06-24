import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class HistoryLogPage extends StatefulWidget {
  final bool showAppBar;

  const HistoryLogPage({
    super.key,
    this.showAppBar = true,
  });

  @override
  State<HistoryLogPage> createState() => _HistoryLogPageState();
}

class _HistoryLogPageState extends State<HistoryLogPage> {
  final supabase = Supabase.instance.client;
  final searchController = TextEditingController();

  bool isLoading = true;
  String searchQuery = '';
  String selectedType = 'All';

  List<Map<String, dynamic>> logs = [];
  Map<String, Map<String, dynamic>> itemsById = {};
  Map<String, Map<String, dynamic>> profilesById = {};

  static const Color mulberry = Color(0xFF6D2B50);
  static const Color mulberryDark = Color(0xFF4A1A35);
  static const Color mulberryLight = Color(0xFF8B3D68);
  static const Color cream = Color(0xFFF5ECD7);
  static const Color creamDark = Color(0xFFE8D5B5);
  static const Color softWhite = Color(0xFFFFFCF7);

  @override
  void initState() {
    super.initState();
    loadLogs();

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

  Future<void> loadLogs() async {
    if (!mounted) return;

    setState(() {
      isLoading = true;
    });

    try {
      final logsResponse = await supabase
          .from('stock_movements')
          .select()
          .order('created_at', ascending: false)
          .limit(200);

      final logList = List<Map<String, dynamic>>.from(logsResponse);

      final itemIds = logList
          .map((log) => log['item_id']?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .toSet()
          .toList();
      final profileIds = logList
          .map((log) => log['performed_by']?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .toSet()
          .toList();

      final itemMap = <String, Map<String, dynamic>>{};
      final profileMap = <String, Map<String, dynamic>>{};

      if (itemIds.isNotEmpty) {
        final itemsResponse = await supabase
            .from('inventory_items')
            .select('item_id, item_name, category, unit, expiry_date')
            .inFilter('item_id', itemIds);

        for (final item in List<Map<String, dynamic>>.from(itemsResponse)) {
          itemMap[item['item_id'].toString()] = item;
        }
      }

      if (profileIds.isNotEmpty) {
        final profilesResponse = await supabase
            .from('profiles')
            .select('id, full_name, role')
            .inFilter('id', profileIds);

        for (final profile in List<Map<String, dynamic>>.from(profilesResponse)) {
          profileMap[profile['id'].toString()] = profile;
        }
      }

      if (!mounted) return;

      setState(() {
        logs = logList;
        itemsById = itemMap;
        profilesById = profileMap;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
      });

      showMessage('Failed to load history log: $e', isError: true);
    }
  }

  String formatNumber(dynamic value) {
    if (value == null) return '0';

    final number = num.tryParse(value.toString()) ?? 0;
    if (number % 1 == 0) return number.toInt().toString();

    return number.toString();
  }

  String formatDate(dynamic value) {
    if (value == null) return '-';

    final text = value.toString();
    if (text.length >= 16) {
      return text.substring(0, 16).replaceFirst('T', ' ');
    }

    return text;
  }

  String formatType(String type) {
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
      case 'item_created':
        return 'Item Created';
      case 'item_updated':
        return 'Item Updated';
      case 'item_deactivated':
        return 'Item Deactivated';
      case 'item_reactivated':
        return 'Item Reactivated';
      default:
        return type.replaceAll('_', ' ').toUpperCase();
    }
  }

  Color getTypeColor(String type) {
    switch (type) {
      case 'stock_in':
      case 'item_created':
      case 'item_reactivated':
        return Colors.green;
      case 'stock_out':
      case 'daily_usage':
      case 'item_deactivated':
        return Colors.orange;
      case 'damaged':
      case 'expired':
        return Colors.red;
      case 'correction':
      case 'item_updated':
        return Colors.blue;
      default:
        return mulberry;
    }
  }

  IconData getTypeIcon(String type) {
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
      case 'item_created':
        return Icons.add_box;
      case 'item_updated':
        return Icons.edit_note;
      case 'item_deactivated':
        return Icons.block;
      case 'item_reactivated':
        return Icons.restore;
      default:
        return Icons.history;
    }
  }

  String getItemName(Map<String, dynamic> log) {
    final item = itemsById[log['item_id']?.toString() ?? ''];
    return (item?['item_name'] ?? 'Unknown Item').toString();
  }

  String getUnit(Map<String, dynamic> log) {
    final item = itemsById[log['item_id']?.toString() ?? ''];
    return (item?['unit'] ?? 'unit').toString();
  }

  String getCategory(Map<String, dynamic> log) {
    final item = itemsById[log['item_id']?.toString() ?? ''];
    return (item?['category'] ?? 'Uncategorized').toString();
  }

  String getProfileName(Map<String, dynamic> log) {
    final profile = profilesById[log['performed_by']?.toString() ?? ''];
    if (profile == null) return '-';

    final name = (profile['full_name'] ?? '-').toString();
    final role = (profile['role'] ?? '').toString();

    return role.isEmpty ? name : '$name ($role)';
  }

  List<String> getTypes() {
    final types = logs
        .map((log) => (log['movement_type'] ?? 'unknown').toString())
        .toSet()
        .toList();

    types.sort();
    return ['All', ...types];
  }

  List<Map<String, dynamic>> getFilteredLogs() {
    List<Map<String, dynamic>> filtered = logs;

    if (selectedType != 'All') {
      filtered = filtered.where((log) {
        return (log['movement_type'] ?? 'unknown').toString() == selectedType;
      }).toList();
    }

    if (searchQuery.isNotEmpty) {
      final query = searchQuery.toLowerCase();
      filtered = filtered.where((log) {
        final type = formatType((log['movement_type'] ?? '').toString());
        final itemName = getItemName(log);
        final category = getCategory(log);
        final remarks = (log['remarks'] ?? '').toString();
        final staff = getProfileName(log);

        return type.toLowerCase().contains(query) ||
            itemName.toLowerCase().contains(query) ||
            category.toLowerCase().contains(query) ||
            remarks.toLowerCase().contains(query) ||
            staff.toLowerCase().contains(query);
      }).toList();
    }

    return filtered;
  }

  Widget buildHeader() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [mulberryDark, mulberry, mulberryLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 27,
            backgroundColor: cream.withOpacity(0.18),
            child: const Icon(Icons.history, color: cream, size: 30),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'History Log',
                  style: TextStyle(
                    color: cream,
                    fontFamily: 'Georgia',
                    fontSize: 21,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '${logs.length} recent inventory action(s)',
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
      style: const TextStyle(color: mulberryDark, fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        hintText: 'Search item, staff, action or remarks...',
        prefixIcon: const Icon(Icons.search, color: mulberry),
        suffixIcon: searchController.text.trim().isEmpty
            ? null
            : IconButton(
                onPressed: searchController.clear,
                icon: const Icon(Icons.close, color: mulberry),
              ),
        filled: true,
        fillColor: softWhite,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: creamDark.withOpacity(0.85)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: mulberry, width: 1.8),
        ),
      ),
    );
  }

  Widget buildTypeFilter() {
    final types = getTypes();

    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: types.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final type = types[index];
          final selected = selectedType == type;

          return ChoiceChip(
            label: Text(type == 'All' ? 'All' : formatType(type)),
            selected: selected,
            selectedColor: mulberry,
            backgroundColor: softWhite,
            side: BorderSide(color: selected ? mulberry : creamDark),
            labelStyle: TextStyle(
              color: selected ? cream : mulberry,
              fontWeight: FontWeight.bold,
            ),
            onSelected: (_) {
              setState(() {
                selectedType = type;
              });
            },
          );
        },
      ),
    );
  }

  Widget buildLogCard(Map<String, dynamic> log) {
    final type = (log['movement_type'] ?? 'unknown').toString();
    final color = getTypeColor(type);
    final unit = getUnit(log);
    final remarks = (log['remarks'] ?? '').toString();
    final expiryDate = log['expiry_date'];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: softWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: color.withOpacity(0.12),
            child: Icon(getTypeIcon(type), color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  formatType(type),
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  getItemName(log),
                  style: const TextStyle(
                    color: mulberryDark,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 7),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    buildMiniBadge('Qty: ${formatNumber(log['quantity'])} $unit'),
                    if (log['before_quantity'] != null)
                      buildMiniBadge(
                        'Before: ${formatNumber(log['before_quantity'])}',
                      ),
                    if (log['after_quantity'] != null)
                      buildMiniBadge(
                        'After: ${formatNumber(log['after_quantity'])}',
                      ),
                    if (expiryDate != null &&
                        expiryDate.toString().trim().isNotEmpty)
                      buildMiniBadge('Expiry: ${expiryDate.toString().substring(0, 10)}'),
                  ],
                ),
                if (remarks.trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    remarks,
                    style: TextStyle(color: Colors.grey.shade700, height: 1.3),
                  ),
                ],
                const SizedBox(height: 8),
                Text(
                  '${formatDate(log['created_at'])} - ${getProfileName(log)}',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget buildMiniBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: cream,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: creamDark.withOpacity(0.75)),
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

  Widget buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.only(top: 90),
      child: Center(
        child: Text(
          'No history log found.',
          style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  void showMessage(String message, {bool isError = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: cream)),
        backgroundColor: isError ? mulberryDark : mulberry,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredLogs = getFilteredLogs();

    return Scaffold(
      backgroundColor: cream,
      appBar: widget.showAppBar
          ? AppBar(
              title: const Text(
                'History Log',
                style: TextStyle(color: cream, fontWeight: FontWeight.bold),
              ),
              centerTitle: true,
              backgroundColor: mulberry,
              foregroundColor: cream,
              actions: [
                IconButton(onPressed: loadLogs, icon: const Icon(Icons.refresh)),
              ],
            )
          : null,
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: mulberry))
          : RefreshIndicator(
              color: mulberry,
              onRefresh: loadLogs,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 90),
                children: [
                  if (widget.showAppBar) ...[
                    buildHeader(),
                    const SizedBox(height: 14),
                  ],
                  buildSearchBox(),
                  const SizedBox(height: 12),
                  buildTypeFilter(),
                  const SizedBox(height: 16),
                  if (filteredLogs.isEmpty)
                    buildEmptyState()
                  else
                    ...filteredLogs.map(buildLogCard),
                ],
              ),
            ),
    );
  }
}
