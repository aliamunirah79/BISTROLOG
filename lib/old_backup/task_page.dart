import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TaskPage extends StatefulWidget {
  final Future<void> Function()? onTaskUpdated;

  const TaskPage({
    super.key,
    this.onTaskUpdated,
  });

  @override
  State<TaskPage> createState() => _TaskPageState();
}

class _TaskPageState extends State<TaskPage> {
  final supabase = Supabase.instance.client;

  List<Map<String, dynamic>> parentTasks = [];
  Map<int, List<Map<String, dynamic>>> subTasks = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    loadTasks();
  }

  Future<void> loadTasks() async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      setState(() => _loading = false);
      return;
    }

    try {
      final res = await supabase.from('task').select().order('task_id');
      final all = List<Map<String, dynamic>>.from(res);

      final parentList =
          all.where((t) => t['parent_task_id'] == null).toList();

      final childMap = <int, List<Map<String, dynamic>>>{};

      for (var parent in parentList) {
        final pid = parent['task_id'] as int;
        childMap[pid] = all
            .where((t) => t['parent_task_id'] == pid)
            .cast<Map<String, dynamic>>()
            .toList();
      }

      setState(() {
        parentTasks = parentList.cast<Map<String, dynamic>>();
        subTasks = childMap;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load tasks: $e')),
        );
      }
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<String?> uploadProof(File file) async {
    final user = supabase.auth.currentUser;
    if (user == null) return null;

    try {
      final fileName =
          '${user.id}_${DateTime.now().millisecondsSinceEpoch}.jpg';

      await supabase.storage.from('task_proofs').upload(
            fileName,
            file,
            fileOptions: const FileOptions(upsert: true),
          );

      return supabase.storage.from('task_proofs').getPublicUrl(fileName);
    } catch (e, st) {
      debugPrint('uploadProof error: $e\n$st');
      return null;
    }
  }

 Future<void> completeTask(Map task, {String? proofUrl}) async {
  final user = supabase.auth.currentUser;
  if (user == null) return;

  try {
    final nowUtc = DateTime.now().toUtc().toIso8601String();

    await supabase.from('task').update({
      'done': true,
      'completed_at': nowUtc,
      'completed_by': user.id,
      if (proofUrl != null) 'proof_url': proofUrl,
    }).eq('task_id', task['task_id']);

    await loadTasks();

    if (widget.onTaskUpdated != null) {
      await widget.onTaskUpdated!();
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Task completed successfully')),
      );
    }
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to complete task: $e')),
      );
    }
  }
}

  Future<CroppedFile?> _cropImage(String path) async {
    if (kIsWeb) return null;

    return await ImageCropper().cropImage(
      sourcePath: path,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Crop Image',
          toolbarColor: Colors.deepPurple,
          toolbarWidgetColor: Colors.white,
        ),
        IOSUiSettings(title: 'Crop Image'),
      ],
    );
  }

  void _showImagePreview(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(10),
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void showCompleteDialog(Map task) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        bool uploading = false;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(task['title']),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(task['proof_required'] == true
                      ? "Proof required"
                      : "Optional proof"),
                  const SizedBox(height: 12),
                  if (uploading)
                    const CircularProgressIndicator()
                  else
                    ElevatedButton.icon(
                      icon: const Icon(Icons.camera_alt),
                      label: const Text("Take Photo"),
                      onPressed: () async {
                        final picker = ImagePicker();
                        final photo = await picker.pickImage(
                          source: ImageSource.camera,
                        );

                        if (photo == null) return;

                        final cropped = await _cropImage(photo.path);
                        if (cropped == null) return;

                        setDialogState(() => uploading = true);

                        final url = await uploadProof(File(cropped.path));

                        setDialogState(() => uploading = false);

                        if (url == null) return;

                        await completeTask(task, proofUrl: url);

                        if (dialogContext.mounted) {
                          Navigator.pop(dialogContext);
                        }
                      },
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: uploading
                      ? null
                      : () async {
                          if (task['proof_required'] == true) {
                            ScaffoldMessenger.of(dialogContext).showSnackBar(
                              const SnackBar(
                                content: Text("Photo proof is required"),
                              ),
                            );
                            return;
                          }

                          await completeTask(task);

                          if (dialogContext.mounted) {
                            Navigator.pop(dialogContext);
                          }
                        },
                  child: const Text("Confirm Done"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildTaskTile(Map task) {
    final isDone = task['done'] == true;
    final proofUrl = task['proof_url'] as String?;

    return ListTile(
      title: Text(task['title'] ?? ''),
      subtitle: isDone
          ? proofUrl != null
              ? GestureDetector(
                  onTap: () => _showImagePreview(context, proofUrl),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '✅ Completed — tap to view proof',
                        style: TextStyle(
                          color: Colors.pink,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          proofUrl,
                          height: 80,
                          width: 120,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ],
                  ),
                )
              : const Text(
                  '✅ Completed',
                  style: TextStyle(color: Colors.green),
                )
          : null,
      trailing: Checkbox(
        value: isDone,
        onChanged: (val) {
          if (val == true && !isDone) {
            showCompleteDialog(task);
          }
        },
      ),
    );
  }

  Widget _buildSection(String title, List<Map<String, dynamic>> tasks) {
    if (tasks.isEmpty) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.deepPurple,
            ),
          ),
        ),
        ...tasks.map((parent) {
          final children = subTasks[parent['task_id']] ?? [];

          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: ExpansionTile(
              title: Text(
                parent['title'] ?? '',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              children: children.map((task) => _buildTaskTile(task)).toList(),
            ),
          );
        }).toList(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final dailyParents =
        parentTasks.where((t) => t['frequency'] == 'DAILY').toList();

    final weeklyParents =
        parentTasks.where((t) => t['frequency'] == 'WEEKLY').toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Task Detail"),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : parentTasks.isEmpty
              ? const Center(child: Text('No tasks available'))
              : RefreshIndicator(
                  onRefresh: loadTasks,
                  child: ListView(
                    children: [
                      _buildSection("Daily Tasks", dailyParents),
                      _buildSection("Weekly Tasks", weeklyParents),
                    ],
                  ),
                ),
    );
  }
}