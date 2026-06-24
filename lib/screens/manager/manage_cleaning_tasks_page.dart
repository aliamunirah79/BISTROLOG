import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ManageCleaningTasksPage extends StatefulWidget {
  const ManageCleaningTasksPage({super.key});

  @override
  State<ManageCleaningTasksPage> createState() =>
      _ManageCleaningTasksPageState();
}

class _ManageCleaningTasksPageState extends State<ManageCleaningTasksPage>
    with SingleTickerProviderStateMixin {
  final supabase = Supabase.instance.client;

  late TabController tabController;

  bool isLoading = true;

  List<Map<String, dynamic>> allTasks = [];

  static const Color mulberry = Color(0xFF6D2B50);
  static const Color mulberryDark = Color(0xFF4A1A35);
  static const Color mulberryLight = Color(0xFF8B3D68);
  static const Color cream = Color(0xFFF5ECD7);
  static const Color creamDark = Color(0xFFE8D5B5);
  static const Color softWhite = Color(0xFFFFFCF7);

  @override
  void initState() {
    super.initState();
    tabController = TabController(length: 3, vsync: this);
    tabController.addListener(() {
      if (mounted) setState(() {});
    });
    loadTasks();
  }

  @override
  void dispose() {
    tabController.dispose();
    super.dispose();
  }

  Future<void> loadTasks() async {
    if (!mounted) return;

    setState(() {
      isLoading = true;
    });

    try {
      final response = await supabase
          .from('cleaning_tasks')
          .select()
          .eq('is_active', true)
          .order('category', ascending: true)
          .order('created_at', ascending: true);

      if (!mounted) return;

      setState(() {
        allTasks = List<Map<String, dynamic>>.from(response);
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
      });

      showMessage('Failed to load cleaning tasks: $e', isError: true);
    }
  }

  List<Map<String, dynamic>> get openingTasks {
    return allTasks.where((task) => task['category'] == 'opening').toList();
  }

  List<Map<String, dynamic>> get closingTasks {
    return allTasks.where((task) => task['category'] == 'closing').toList();
  }

  List<Map<String, dynamic>> get weeklyTasks {
    return allTasks.where((task) => task['category'] == 'weekly').toList();
  }

  int get totalTasks => allTasks.length;

  String formatValue(String value) {
    return value
        .replaceAll('_', ' ')
        .split(' ')
        .where((part) => part.trim().isNotEmpty)
        .map((part) => part[0].toUpperCase() + part.substring(1))
        .join(' ');
  }

  IconData getCategoryIcon(String category) {
    if (category == 'opening') return Icons.wb_sunny_rounded;
    if (category == 'closing') return Icons.nights_stay_rounded;
    if (category == 'weekly') return Icons.calendar_view_week_rounded;
    return Icons.cleaning_services_rounded;
  }

  Color getCategoryColor(String category) {
    if (category == 'opening') return Colors.orange;
    if (category == 'closing') return Colors.indigo;
    if (category == 'weekly') return Colors.teal;
    return mulberry;
  }

  Future<void> addTask({
    required String title,
    required String description,
    required String category,
    required bool proofRequired,
  }) async {
    try {
      await supabase.from('cleaning_tasks').insert({
        'title': title,
        'description': description,
        'category': category,
        'proof_required': proofRequired,
        'is_active': true,
      });

      showMessage('Cleaning task added successfully.');
      await loadTasks();
    } catch (e) {
      showMessage('Failed to add task: $e', isError: true);
    }
  }

  Future<void> updateTask({
    required dynamic taskId,
    required String title,
    required String description,
    required String category,
    required bool proofRequired,
  }) async {
    try {
      await supabase.from('cleaning_tasks').update({
        'title': title,
        'description': description,
        'category': category,
        'proof_required': proofRequired,
      }).eq('task_id', taskId);

      showMessage('Cleaning task updated successfully.');
      await loadTasks();
    } catch (e) {
      showMessage('Failed to update task: $e', isError: true);
    }
  }

  Future<void> deactivateTask(Map<String, dynamic> task) async {
    try {
      await supabase.from('cleaning_tasks').update({
        'is_active': false,
      }).eq('task_id', task['task_id']);

      showMessage('Cleaning task removed from active checklist.');
      await loadTasks();
    } catch (e) {
      showMessage('Failed to remove task: $e', isError: true);
    }
  }

  Future<bool> confirmRemoveTask(Map<String, dynamic> task) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: softWhite,
          title: const Text(
            'Remove Task?',
            style: TextStyle(
              color: mulberryDark,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            'Remove "${task['title']}" from the active checklist? Existing history logs will remain saved.',
            style: TextStyle(
              color: Colors.grey.shade800,
              height: 1.35,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              style: TextButton.styleFrom(foregroundColor: mulberry),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Remove'),
            ),
          ],
        );
      },
    );

    return result == true;
  }

  void showTaskSheet({Map<String, dynamic>? existingTask}) {
    final isEdit = existingTask != null;

    final titleController = TextEditingController(
      text: isEdit ? (existingTask['title'] ?? '').toString() : '',
    );

    final descriptionController = TextEditingController(
      text: isEdit ? (existingTask['description'] ?? '').toString() : '',
    );

    String selectedCategory =
        isEdit ? (existingTask['category'] ?? 'opening').toString() : 'opening';

    bool proofRequired =
        isEdit ? existingTask['proof_required'] == true : false;

    bool isSaving = false;
    String? formError;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: softWhite,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (bottomSheetContext) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(bottomSheetContext).viewInsets.bottom,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: StatefulBuilder(
                builder: (context, setModalState) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: CircleAvatar(
                          radius: 40,
                          backgroundColor: cream,
                          child: Icon(
                            isEdit
                                ? Icons.edit_note_rounded
                                : Icons.add_task_rounded,
                            color: mulberry,
                            size: 40,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Center(
                        child: Text(
                          isEdit
                              ? 'Edit Cleaning Task'
                              : 'Create Cleaning Task',
                          style: const TextStyle(
                            color: mulberryDark,
                            fontFamily: 'Georgia',
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      if (formError != null) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.red.shade200),
                          ),
                          child: Text(
                            formError!,
                            style: TextStyle(
                              color: Colors.red.shade800,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      buildTextField(
                        controller: titleController,
                        label: 'Task Title *',
                        icon: Icons.title_rounded,
                      ),
                      const SizedBox(height: 12),
                      buildTextField(
                        controller: descriptionController,
                        label: 'Description *',
                        icon: Icons.description_rounded,
                        maxLines: 3,
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: selectedCategory,
                        dropdownColor: softWhite,
                        decoration: buildInputDecoration(
                          label: 'Category',
                          icon: Icons.category_rounded,
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'opening',
                            child: Text('Opening'),
                          ),
                          DropdownMenuItem(
                            value: 'closing',
                            child: Text('Closing'),
                          ),
                          DropdownMenuItem(
                            value: 'weekly',
                            child: Text('Weekly'),
                          ),
                        ],
                        onChanged: isSaving
                            ? null
                            : (value) {
                                if (value == null) return;
                                setModalState(() {
                                  selectedCategory = value;
                                });
                              },
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: cream,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: creamDark),
                        ),
                        child: SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          activeColor: mulberry,
                          title: const Text(
                            'Photo proof required',
                            style: TextStyle(
                              color: mulberryDark,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Text(
                            proofRequired
                                ? 'Staff must upload photo proof.'
                                : 'Staff can complete without photo proof.',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 12.5,
                            ),
                          ),
                          value: proofRequired,
                          onChanged: isSaving
                              ? null
                              : (value) {
                                  setModalState(() {
                                    proofRequired = value;
                                  });
                                },
                        ),
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton.icon(
                          onPressed: isSaving
                              ? null
                              : () async {
                                  final title =
                                      titleController.text.trim();
                                  final description =
                                      descriptionController.text.trim();

                                  if (title.isEmpty ||
                                      description.isEmpty) {
                                    setModalState(() {
                                      formError =
                                          'Task title and description are required.';
                                    });
                                    return;
                                  }

                                  setModalState(() {
                                    isSaving = true;
                                    formError = null;
                                  });

                                  if (isEdit) {
                                    await updateTask(
                                      taskId: existingTask['task_id'],
                                      title: title,
                                      description: description,
                                      category: selectedCategory,
                                      proofRequired: proofRequired,
                                    );
                                  } else {
                                    await addTask(
                                      title: title,
                                      description: description,
                                      category: selectedCategory,
                                      proofRequired: proofRequired,
                                    );
                                  }

                                  if (!bottomSheetContext.mounted) return;
                                  Navigator.pop(bottomSheetContext);
                                },
                          icon: isSaving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: cream,
                                  ),
                                )
                              : Icon(isEdit
                                  ? Icons.save_rounded
                                  : Icons.add_rounded),
                          label: Text(
                            isSaving
                                ? 'Saving...'
                                : isEdit
                                    ? 'Save Changes'
                                    : 'Create Task',
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
                  );
                },
              ),
            ),
          ),
        );
      },
    ).whenComplete(() {
      titleController.dispose();
      descriptionController.dispose();
    });
  }

  Widget buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: const TextStyle(color: mulberryDark),
      decoration: buildInputDecoration(
        label: label,
        icon: icon,
      ),
    );
  }

  InputDecoration buildInputDecoration({
    required String label,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: mulberry),
      prefixIcon: Icon(icon, color: mulberry),
      filled: true,
      fillColor: cream,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: creamDark),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: mulberry, width: 1.8),
      ),
    );
  }

  Widget buildHeaderCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [mulberryDark, mulberry, mulberryLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
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
            radius: 28,
            backgroundColor: cream.withOpacity(0.18),
            child: const Icon(
              Icons.cleaning_services_rounded,
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
                  'Manage Cleaning Tasks',
                  style: TextStyle(
                    color: cream,
                    fontFamily: 'Georgia',
                    fontSize: 21,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'Create, edit or remove active checklist tasks • Total: $totalTasks',
                  style: const TextStyle(
                    color: creamDark,
                    fontWeight: FontWeight.w600,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget buildTabBar() {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: creamDark.withOpacity(0.65),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          buildCustomTab(
            index: 0,
            title: 'Opening',
            count: openingTasks.length,
            icon: Icons.wb_sunny_rounded,
          ),
          buildCustomTab(
            index: 1,
            title: 'Closing',
            count: closingTasks.length,
            icon: Icons.nights_stay_rounded,
          ),
          buildCustomTab(
            index: 2,
            title: 'Weekly',
            count: weeklyTasks.length,
            icon: Icons.calendar_view_week_rounded,
          ),
        ],
      ),
    );
  }

  Widget buildCustomTab({
    required int index,
    required String title,
    required int count,
    required IconData icon,
  }) {
    final selected = tabController.index == index;

    return Expanded(
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: selected ? mulberry : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: mulberryDark.withOpacity(0.18),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : [],
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              tabController.animateTo(index);
              setState(() {});
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    icon,
                    size: 17,
                    color: selected ? cream : mulberry,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      '$title ($count)',
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: selected ? cream : mulberry,
                        fontWeight: FontWeight.bold,
                        fontSize: 12.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget buildTaskList(List<Map<String, dynamic>> tasks) {
    if (tasks.isEmpty) {
      return ListView(
        padding: const EdgeInsets.only(top: 80),
        children: [
          Icon(
            Icons.playlist_add_check_rounded,
            size: 64,
            color: mulberry.withOpacity(0.32),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              'No active task in this category.',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Center(
            child: Text(
              'Tap + Add Task to create a new checklist item.',
              style: TextStyle(
                color: Colors.grey.shade500,
                fontWeight: FontWeight.w600,
                fontSize: 12.5,
              ),
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(0, 14, 0, 90),
      itemCount: tasks.length,
      itemBuilder: (context, index) {
        return buildTaskCard(tasks[index]);
      },
    );
  }

  Widget buildTaskCard(Map<String, dynamic> task) {
    final category = (task['category'] ?? 'general').toString();
    final categoryColor = getCategoryColor(category);
    final proofRequired = task['proof_required'] == true;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: softWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: creamDark.withOpacity(0.75)),
        boxShadow: [
          BoxShadow(
            color: mulberryDark.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.fromLTRB(15, 12, 10, 12),
        leading: CircleAvatar(
          backgroundColor: categoryColor.withOpacity(0.12),
          child: Icon(
            getCategoryIcon(category),
            color: categoryColor,
          ),
        ),
        title: Text(
          (task['title'] ?? 'Cleaning Task').toString(),
          style: const TextStyle(
            color: mulberryDark,
            fontWeight: FontWeight.bold,
            fontSize: 15.5,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                (task['description'] ?? 'No description.').toString(),
                style: TextStyle(
                  color: Colors.grey.shade700,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: [
                  buildStatusBadge(
                    formatValue(category),
                    categoryColor,
                  ),
                  buildStatusBadge(
                    proofRequired ? 'Proof Required' : 'Proof Optional',
                    proofRequired ? Colors.pink : Colors.grey,
                  ),
                ],
              ),
            ],
          ),
        ),
        trailing: PopupMenuButton<String>(
          color: softWhite,
          onSelected: (value) async {
            if (value == 'edit') {
              showTaskSheet(existingTask: task);
            }

            if (value == 'remove') {
              final confirm = await confirmRemoveTask(task);
              if (confirm) {
                await deactivateTask(task);
              }
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'edit',
              child: Text('Edit task'),
            ),
            const PopupMenuItem(
              value: 'remove',
              child: Text(
                'Remove task',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildStatusBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
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
      appBar: AppBar(
        title: const Text(
          'Manage Cleaning Tasks',
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
            tooltip: 'Refresh',
            onPressed: loadTasks,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showTaskSheet(),
        backgroundColor: mulberry,
        foregroundColor: cream,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Task'),
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(color: mulberry),
            )
          : RefreshIndicator(
              color: mulberry,
              onRefresh: loadTasks,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
                child: Column(
                  children: [
                    buildHeaderCard(),
                    const SizedBox(height: 12),
                    buildTabBar(),
                    const SizedBox(height: 2),
                    Expanded(
                      child: TabBarView(
                        controller: tabController,
                        children: [
                          buildTaskList(openingTasks),
                          buildTaskList(closingTasks),
                          buildTaskList(weeklyTasks),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}