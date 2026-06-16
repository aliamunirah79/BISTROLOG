import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CleaningChecklistPage extends StatefulWidget {
  final bool showAppBar;

  const CleaningChecklistPage({
    super.key,
    this.showAppBar = true,
  });

  @override
  State<CleaningChecklistPage> createState() => _CleaningChecklistPageState();
}

class _CleaningChecklistPageState extends State<CleaningChecklistPage>
    with SingleTickerProviderStateMixin {
  final supabase = Supabase.instance.client;
  final picker = ImagePicker();

  late TabController _tabController;

  bool isLoading = true;

  List<Map<String, dynamic>> openingTasks = [];
  List<Map<String, dynamic>> closingTasks = [];
  List<Map<String, dynamic>> weeklyTasks = [];

  Map<dynamic, dynamic> taskLogs = {};

  static const Color mulberry = Color(0xFF6D2B50);
  static const Color mulberryDark = Color(0xFF4A1A35);
  static const Color mulberryLight = Color(0xFF8B3D68);
  static const Color cream = Color(0xFFF5ECD7);
  static const Color creamDark = Color(0xFFE8D5B5);
  static const Color softWhite = Color(0xFFFFFCF7);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    loadChecklist();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> loadChecklist() async {
    setState(() {
      isLoading = true;
    });

    try {
      final today = DateTime.now().toIso8601String().substring(0, 10);

      final tasksResponse = await supabase
          .from('cleaning_tasks')
          .select()
          .eq('is_active', true)
          .order('created_at', ascending: true);

      final logsResponse = await supabase.from('cleaning_task_logs').select('''
            log_id,
            task_id,
            staff_id,
            task_date,
            status,
            remarks,
            proof_url,
            completed_at,
            review_status,
            reviewed_by,
            reviewed_at,
            review_remarks,
            updated_by,
            updated_at,
            profiles:staff_id (
              full_name,
              role
            )
          ''').eq('task_date', today);

      final allTasks = List<Map<String, dynamic>>.from(tasksResponse);
      final logs = List<Map<String, dynamic>>.from(logsResponse);

      final Map<dynamic, dynamic> logsMap = {};

      for (final log in logs) {
        logsMap[log['task_id']] = log;
      }

      setState(() {
        openingTasks =
            allTasks.where((task) => task['category'] == 'opening').toList();

        closingTasks =
            allTasks.where((task) => task['category'] == 'closing').toList();

        weeklyTasks =
            allTasks.where((task) => task['category'] == 'weekly').toList();

        taskLogs = logsMap;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });

      showMessage('Failed to load checklist: $e', isError: true);
    }
  }

  bool isTaskCompleted(dynamic taskId) {
    final log = taskLogs[taskId];

    if (log == null) {
      return false;
    }

    return log['status'] == 'completed';
  }

  String getCompletedBy(dynamic taskId) {
    final log = taskLogs[taskId];

    if (log == null) {
      return 'Not completed yet';
    }

    final profile = log['profiles'];

    if (profile == null) {
      return 'Updated by unknown user';
    }

    final name = profile['full_name'] ?? 'Unknown user';
    final role = profile['role'] ?? '';

    return 'Updated by: $name ($role)';
  }

  String getReviewStatus(dynamic taskId) {
    final log = taskLogs[taskId];

    if (log == null) {
      return 'not submitted';
    }

    return log['review_status'] ?? 'pending';
  }

  String? getReviewRemarks(dynamic taskId) {
    final log = taskLogs[taskId];

    if (log == null) {
      return null;
    }

    return log['review_remarks'];
  }

  String? getProofUrl(dynamic taskId) {
    final log = taskLogs[taskId];

    if (log == null) {
      return null;
    }

    return log['proof_url'];
  }

  bool isProofRequired(Map<String, dynamic> task) {
    return task['proof_required'] == true;
  }

  Future<CroppedFile?> cropImage(String imagePath) async {
    if (kIsWeb) {
      return null;
    }

    return ImageCropper().cropImage(
      sourcePath: imagePath,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Crop Proof Image',
          toolbarColor: mulberry,
          toolbarWidgetColor: cream,
          lockAspectRatio: false,
        ),
        IOSUiSettings(
          title: 'Crop Proof Image',
        ),
      ],
    );
  }

  Future<String?> uploadProof(File imageFile) async {
    final user = supabase.auth.currentUser;

    if (user == null) {
      throw Exception('User not logged in.');
    }

    final fileName = '${user.id}_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final filePath = 'cleaning/$fileName';

    await supabase.storage.from('task_proofs').upload(
          filePath,
          imageFile,
          fileOptions: const FileOptions(
            upsert: true,
            contentType: 'image/jpeg',
          ),
        );

    return supabase.storage.from('task_proofs').getPublicUrl(filePath);
  }

  Future<String?> pickAndUploadProof() async {
    final pickedImage = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 75,
      maxWidth: 1200,
    );

    if (pickedImage == null) {
      return null;
    }

    File finalFile = File(pickedImage.path);

    if (!kIsWeb) {
      final cropped = await cropImage(pickedImage.path);

      if (cropped != null) {
        finalFile = File(cropped.path);
      }
    }

    return uploadProof(finalFile);
  }

  Future<void> notifyManagersForReview({
    required String taskTitle,
    required dynamic taskId,
  }) async {
    try {
      final managers = await supabase
          .from('profiles')
          .select('id')
          .eq('role', 'manager');

      final managerList = List<Map<String, dynamic>>.from(managers);

      if (managerList.isEmpty) {
        return;
      }

      final notifications = managerList.map((manager) {
        return {
          'user_id': manager['id'],
          'title': 'Checklist Pending Review',
          'message': 'A cleaning task "$taskTitle" is waiting for review.',
          'type': 'checklist',
          'target_page': 'review_checklist',
          'target_id': taskId.toString(),
          'is_read': false,
        };
      }).toList();

      await supabase.from('notifications').insert(notifications);
    } catch (e) {
      debugPrint('Failed to notify managers: $e');
    }
  }

  Future<void> markTaskCompleted(
    Map<String, dynamic> task, {
    String? proofUrl,
  }) async {
    try {
      final user = supabase.auth.currentUser;

      if (user == null) {
        throw Exception('User not logged in.');
      }

      final today = DateTime.now().toIso8601String().substring(0, 10);
      final now = DateTime.now().toIso8601String();
      final taskId = task['task_id'];
      final taskTitle = task['title'] ?? 'Cleaning task';

      final existingLog = taskLogs[taskId];

      if (existingLog == null) {
        final inserted = await supabase
            .from('cleaning_task_logs')
            .insert({
              'task_id': taskId,
              'staff_id': user.id,
              'updated_by': user.id,
              'task_date': today,
              'status': 'completed',
              'completed_at': now,
              'proof_url': proofUrl,
              'review_status': 'pending',
              'updated_at': now,
            })
            .select('''
              log_id,
              task_id,
              staff_id,
              task_date,
              status,
              remarks,
              proof_url,
              completed_at,
              review_status,
              reviewed_by,
              reviewed_at,
              review_remarks,
              updated_by,
              updated_at,
              profiles:staff_id (
                full_name,
                role
              )
            ''')
            .single();

        setState(() {
          taskLogs[taskId] = inserted;
        });
      } else {
        final updated = await supabase
            .from('cleaning_task_logs')
            .update({
              'staff_id': user.id,
              'updated_by': user.id,
              'status': 'completed',
              'completed_at': now,
              'proof_url': proofUrl ?? existingLog['proof_url'],
              'review_status': 'pending',
              'reviewed_by': null,
              'reviewed_at': null,
              'review_remarks': null,
              'updated_at': now,
            })
            .eq('log_id', existingLog['log_id'])
            .select('''
              log_id,
              task_id,
              staff_id,
              task_date,
              status,
              remarks,
              proof_url,
              completed_at,
              review_status,
              reviewed_by,
              reviewed_at,
              review_remarks,
              updated_by,
              updated_at,
              profiles:staff_id (
                full_name,
                role
              )
            ''')
            .single();

        setState(() {
          taskLogs[taskId] = updated;
        });
      }

      await notifyManagersForReview(
        taskTitle: taskTitle.toString(),
        taskId: taskId,
      );

      showMessage('Task marked as completed. Manager has been notified.');
    } catch (e) {
      showMessage('Failed to complete task: $e', isError: true);
    }
  }

  Future<void> markTaskPending(Map<String, dynamic> task) async {
    try {
      final user = supabase.auth.currentUser;

      if (user == null) {
        throw Exception('User not logged in.');
      }

      final taskId = task['task_id'];
      final existingLog = taskLogs[taskId];

      if (existingLog == null) {
        return;
      }

      final now = DateTime.now().toIso8601String();

      final updated = await supabase
          .from('cleaning_task_logs')
          .update({
            'staff_id': user.id,
            'updated_by': user.id,
            'status': 'pending',
            'completed_at': null,
            'proof_url': null,
            'review_status': 'pending',
            'reviewed_by': null,
            'reviewed_at': null,
            'review_remarks': null,
            'updated_at': now,
          })
          .eq('log_id', existingLog['log_id'])
          .select('''
            log_id,
            task_id,
            staff_id,
            task_date,
            status,
            remarks,
            proof_url,
            completed_at,
            review_status,
            reviewed_by,
            reviewed_at,
            review_remarks,
            updated_by,
            updated_at,
            profiles:staff_id (
              full_name,
              role
            )
          ''')
          .single();

      setState(() {
        taskLogs[taskId] = updated;
      });

      showMessage('Task changed back to pending.');
    } catch (e) {
      showMessage('Failed to update task: $e', isError: true);
    }
  }

  void showCompleteDialog(Map<String, dynamic> task) {
    final requiredProof = isProofRequired(task);

    showDialog(
      context: context,
      builder: (dialogContext) {
        bool uploading = false;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: softWhite,
              title: Text(
                task['title'] ?? 'Complete Task',
                style: const TextStyle(
                  color: mulberryDark,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    requiredProof
                        ? 'Photo proof is required for this task.'
                        : 'Photo proof is optional for this task.',
                    style: TextStyle(
                      color: requiredProof ? Colors.red : Colors.grey.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (uploading)
                    const Center(
                      child: CircularProgressIndicator(
                        color: mulberry,
                      ),
                    )
                  else
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.camera_alt),
                        label: const Text('Take Photo Proof'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: mulberry,
                          foregroundColor: cream,
                        ),
                        onPressed: () async {
                          try {
                            setDialogState(() {
                              uploading = true;
                            });

                            final proofUrl = await pickAndUploadProof();

                            setDialogState(() {
                              uploading = false;
                            });

                            if (proofUrl == null) {
                              return;
                            }

                            await markTaskCompleted(task, proofUrl: proofUrl);

                            if (dialogContext.mounted) {
                              Navigator.pop(dialogContext);
                            }
                          } catch (e) {
                            setDialogState(() {
                              uploading = false;
                            });

                            showMessage(
                              'Failed to upload proof: $e',
                              isError: true,
                            );
                          }
                        },
                      ),
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: uploading
                      ? null
                      : () {
                          Navigator.pop(dialogContext);
                        },
                  style: TextButton.styleFrom(
                    foregroundColor: mulberry,
                  ),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: uploading
                      ? null
                      : () async {
                          if (requiredProof) {
                            showMessage(
                              'Photo proof is required.',
                              isError: true,
                            );
                            return;
                          }

                          await markTaskCompleted(task);

                          if (dialogContext.mounted) {
                            Navigator.pop(dialogContext);
                          }
                        },
                  style: TextButton.styleFrom(
                    foregroundColor: mulberry,
                  ),
                  child: const Text('Complete Without Photo'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void showRedoDialog(Map<String, dynamic> task) {
    final requiredProof = isProofRequired(task);

    showDialog(
      context: context,
      builder: (dialogContext) {
        bool uploading = false;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: softWhite,
              title: const Text(
                'Redo rejected task?',
                style: TextStyle(
                  color: mulberryDark,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'This task was rejected. Please redo the task and submit it again for manager review.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    requiredProof
                        ? 'Photo proof is required.'
                        : 'Photo proof is optional.',
                    style: TextStyle(
                      color: requiredProof ? Colors.red : Colors.grey.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (uploading)
                    const Center(
                      child: CircularProgressIndicator(
                        color: mulberry,
                      ),
                    )
                  else
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.camera_alt),
                        label: const Text('Take New Photo Proof'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: mulberry,
                          foregroundColor: cream,
                        ),
                        onPressed: () async {
                          try {
                            setDialogState(() {
                              uploading = true;
                            });

                            final proofUrl = await pickAndUploadProof();

                            setDialogState(() {
                              uploading = false;
                            });

                            if (proofUrl == null) {
                              return;
                            }

                            await markTaskCompleted(task, proofUrl: proofUrl);

                            if (dialogContext.mounted) {
                              Navigator.pop(dialogContext);
                            }
                          } catch (e) {
                            setDialogState(() {
                              uploading = false;
                            });

                            showMessage(
                              'Failed to redo task: $e',
                              isError: true,
                            );
                          }
                        },
                      ),
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: uploading
                      ? null
                      : () {
                          Navigator.pop(dialogContext);
                        },
                  style: TextButton.styleFrom(
                    foregroundColor: mulberry,
                  ),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: uploading
                      ? null
                      : () async {
                          if (requiredProof) {
                            showMessage(
                              'Photo proof is required.',
                              isError: true,
                            );
                            return;
                          }

                          await markTaskCompleted(task);

                          if (dialogContext.mounted) {
                            Navigator.pop(dialogContext);
                          }
                        },
                  style: TextButton.styleFrom(
                    foregroundColor: mulberry,
                  ),
                  child: const Text('Redo Without Photo'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void showUntickDialog(Map<String, dynamic> task) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: softWhite,
          title: const Text(
            'Change task to pending?',
            style: TextStyle(
              color: mulberryDark,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            'This will untick "${task['title']}" and remove the proof image from the task log.',
            style: TextStyle(
              color: Colors.grey.shade800,
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
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                Navigator.pop(dialogContext);
                await markTaskPending(task);
              },
              child: const Text('Untick Task'),
            ),
          ],
        );
      },
    );
  }

  void onTaskCheckboxChanged(Map<String, dynamic> task, bool value) {
    final taskId = task['task_id'];
    final currentlyCompleted = isTaskCompleted(taskId);
    final reviewStatus = getReviewStatus(taskId);

    if (value == true && !currentlyCompleted) {
      showCompleteDialog(task);
      return;
    }

    if (value == false && currentlyCompleted) {
      if (reviewStatus == 'rejected') {
        showRedoDialog(task);
      } else {
        showUntickDialog(task);
      }
    }
  }

  int completedCount(List<Map<String, dynamic>> tasks) {
    int count = 0;

    for (final task in tasks) {
      if (isTaskCompleted(task['task_id'])) {
        count++;
      }
    }

    return count;
  }

  Color getReviewColor(String reviewStatus) {
    if (reviewStatus == 'approved') {
      return Colors.green;
    } else if (reviewStatus == 'rejected') {
      return Colors.red;
    } else if (reviewStatus == 'pending') {
      return Colors.orange;
    } else {
      return Colors.grey;
    }
  }

  void showImagePreview(String imageUrl) {
    showDialog(
      context: context,
      builder: (_) {
        return Dialog(
          backgroundColor: Colors.black,
          insetPadding: const EdgeInsets.all(10),
          child: Stack(
            children: [
              Center(
                child: InteractiveViewer(
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return const Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'Failed to load image.',
                          style: TextStyle(color: Colors.white),
                        ),
                      );
                    },
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
        );
      },
    );
  }

  Widget buildProofPreview(String? proofUrl) {
    if (proofUrl == null || proofUrl.isEmpty) {
      return const SizedBox();
    }

    return GestureDetector(
      onTap: () => showImagePreview(proofUrl),
      child: Container(
        margin: const EdgeInsets.only(top: 8),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(
                proofUrl,
                height: 70,
                width: 90,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    height: 70,
                    width: 90,
                    color: creamDark.withOpacity(0.55),
                    child: const Icon(
                      Icons.broken_image,
                      color: mulberry,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Photo proof attached. Tap image to view.',
                style: TextStyle(
                  color: mulberry,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildProgressCard({
    required int completed,
    required int total,
    required double progress,
  }) {
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
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: mulberryDark.withOpacity(0.16),
            blurRadius: 16,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Today Checklist Progress',
            style: TextStyle(
              color: cream,
              fontFamily: 'Georgia',
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.white24,
            color: cream,
            minHeight: 8,
            borderRadius: BorderRadius.circular(20),
          ),
          const SizedBox(height: 10),
          Text(
            '$completed / $total tasks completed',
            style: const TextStyle(
              color: creamDark,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget buildTaskList(List<Map<String, dynamic>> tasks) {
    if (tasks.isEmpty) {
      return Center(
        child: Text(
          'No checklist task found.',
          style: TextStyle(
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    final completed = completedCount(tasks);
    final total = tasks.length;
    final progress = total == 0 ? 0.0 : completed / total;

    return RefreshIndicator(
      color: mulberry,
      onRefresh: loadChecklist,
      child: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          buildProgressCard(
            completed: completed,
            total: total,
            progress: progress,
          ),
          const SizedBox(height: 18),
          ...tasks.map((task) {
            final taskId = task['task_id'];
            final completed = isTaskCompleted(taskId);
            final reviewStatus = getReviewStatus(taskId);
            final completedBy = getCompletedBy(taskId);
            final proofUrl = getProofUrl(taskId);
            final requiredProof = isProofRequired(task);
            final reviewRemarks = getReviewRemarks(taskId);

            return Container(
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: softWhite,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: creamDark.withOpacity(0.75),
                ),
                boxShadow: [
                  BoxShadow(
                    color: mulberryDark.withOpacity(0.05),
                    blurRadius: 12,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: CheckboxListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                value: completed,
                activeColor: mulberry,
                checkColor: cream,
                onChanged: (value) {
                  onTaskCheckboxChanged(task, value ?? false);
                },
                title: Row(
                  children: [
                    Expanded(
                      child: Text(
                        task['title'] ?? '',
                        style: TextStyle(
                          color: mulberryDark,
                          fontWeight: FontWeight.bold,
                          decoration:
                              completed ? TextDecoration.lineThrough : null,
                        ),
                      ),
                    ),
                    if (requiredProof)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.pink.shade50,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'Proof',
                          style: TextStyle(
                            color: Colors.pink,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task['description'] ?? '',
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        completedBy,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Review status: $reviewStatus',
                        style: TextStyle(
                          fontSize: 12,
                          color: getReviewColor(reviewStatus),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (reviewStatus == 'rejected' &&
                          reviewRemarks != null &&
                          reviewRemarks.toString().isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.red.shade100),
                          ),
                          child: Text(
                            'Rejected reason: $reviewRemarks',
                            style: const TextStyle(
                              color: Colors.red,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                      buildProofPreview(proofUrl),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
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

  PreferredSizeWidget buildTopAppBar() {
    return AppBar(
      title: const Text(
        'Cleaning Checklist',
        style: TextStyle(
          color: cream,
          fontWeight: FontWeight.bold,
        ),
      ),
      centerTitle: true,
      backgroundColor: mulberry,
      foregroundColor: cream,
      elevation: 0,
      bottom: buildTabBar(),
    );
  }

  PreferredSizeWidget buildTabBar() {
    return TabBar(
      controller: _tabController,
      indicatorColor: cream,
      labelColor: cream,
      unselectedLabelColor: creamDark,
      labelStyle: const TextStyle(
        fontWeight: FontWeight.bold,
      ),
      tabs: const [
        Tab(text: 'Opening'),
        Tab(text: 'Closing'),
        Tab(text: 'Weekly'),
      ],
    );
  }

  Widget buildBodyContent() {
    return Column(
      children: [
        if (!widget.showAppBar)
          Container(
            color: mulberry,
            child: SafeArea(
              bottom: false,
              child: buildTabBar(),
            ),
          ),
        Expanded(
          child: isLoading
              ? const Center(
                  child: CircularProgressIndicator(
                    color: mulberry,
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    buildTaskList(openingTasks),
                    buildTaskList(closingTasks),
                    buildTaskList(weeklyTasks),
                  ],
                ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: cream,
      appBar: widget.showAppBar ? buildTopAppBar() : null,
      body: buildBodyContent(),
    );
  }
}