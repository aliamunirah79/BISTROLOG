import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class WorkSchedulePage extends StatefulWidget {
  final bool showAppBar;

  const WorkSchedulePage({
    super.key,
    this.showAppBar = true,
  });

  @override
  State<WorkSchedulePage> createState() => _WorkSchedulePageState();
}

class _WorkSchedulePageState extends State<WorkSchedulePage> {
  final supabase = Supabase.instance.client;
  final random = math.Random();

  bool isLoading = true;
  bool isSaving = false;

  DateTime selectedDate = DateTime.now();

  String currentRole = '';
  String currentUserId = '';

  List<Map<String, dynamic>> staffList = [];
  List<Map<String, dynamic>> schedules = [];

  static const Color mulberry = Color(0xFF6D2B50);
  static const Color mulberryDark = Color(0xFF4A1A35);
  static const Color mulberryLight = Color(0xFF8B3D68);
  static const Color cream = Color(0xFFF5ECD7);
  static const Color creamDark = Color(0xFFE8D5B5);
  static const Color softWhite = Color(0xFFFFFCF7);

  bool get canManageSchedule {
    return currentRole == 'manager' || currentRole == 'supervisor';
  }

  DateTime get weekStart {
    final day = selectedDate.weekday;
    return DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
    ).subtract(Duration(days: day - 1));
  }

  DateTime get weekEnd {
    return weekStart.add(const Duration(days: 6));
  }

  String get weekStartText {
    return formatDateForDb(weekStart);
  }

  String get weekEndText {
    return formatDateForDb(weekEnd);
  }

  List<DateTime> get weekDates {
    return List.generate(
      7,
      (index) => weekStart.add(Duration(days: index)),
    );
  }

  @override
  void initState() {
    super.initState();
    loadPageData();
  }

  String formatDateForDb(DateTime date) {
    return date.toIso8601String().substring(0, 10);
  }

  String formatShortDate(DateTime date) {
    return '${date.day}/${date.month}';
  }

  String getDayName(DateTime date) {
    switch (date.weekday) {
      case DateTime.monday:
        return 'Mon';
      case DateTime.tuesday:
        return 'Tue';
      case DateTime.wednesday:
        return 'Wed';
      case DateTime.thursday:
        return 'Thu';
      case DateTime.friday:
        return 'Fri';
      case DateTime.saturday:
        return 'Sat';
      case DateTime.sunday:
        return 'Sun';
      default:
        return '';
    }
  }

  String getFullDayName(DateTime date) {
    switch (date.weekday) {
      case DateTime.monday:
        return 'Monday';
      case DateTime.tuesday:
        return 'Tuesday';
      case DateTime.wednesday:
        return 'Wednesday';
      case DateTime.thursday:
        return 'Thursday';
      case DateTime.friday:
        return 'Friday';
      case DateTime.saturday:
        return 'Saturday';
      case DateTime.sunday:
        return 'Sunday';
      default:
        return '';
    }
  }

  bool isToday(DateTime date) {
    final now = DateTime.now();

    return now.year == date.year &&
        now.month == date.month &&
        now.day == date.day;
  }

  Future<void> loadPageData() async {
    if (!mounted) return;

    setState(() {
      isLoading = true;
    });

    try {
      final user = supabase.auth.currentUser;

      if (user == null) {
        showMessage('User not logged in.', isError: true);
        return;
      }

      currentUserId = user.id;

      final profile = await supabase
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      if (profile == null) {
        showMessage('Profile not found.', isError: true);
        return;
      }

      currentRole = (profile['role'] ?? '').toString();

      final staffResponse = await supabase
          .from('profiles')
          .select()
          .eq('is_active', true)
          .inFilter('role', ['supervisor', 'staff']);

      final staffData = List<Map<String, dynamic>>.from(staffResponse);

      staffData.sort((a, b) {
        int rolePriority(String role) {
          switch (role) {
            case 'supervisor':
              return 0;
            case 'staff':
              return 1;
            default:
              return 2;
          }
        }

        final roleA = rolePriority((a['role'] ?? '').toString());
        final roleB = rolePriority((b['role'] ?? '').toString());

        if (roleA != roleB) {
          return roleA.compareTo(roleB);
        }

        return (a['full_name'] ?? '')
            .toString()
            .toLowerCase()
            .compareTo((b['full_name'] ?? '').toString().toLowerCase());
      });

      final scheduleData = await loadSchedulesForWeek();

      if (!mounted) return;

      setState(() {
        staffList = staffData;
        schedules = scheduleData;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
      });

      showMessage('Failed to load schedule: $e', isError: true);
    }
  }

  Future<List<Map<String, dynamic>>> loadSchedulesForWeek() async {
    if (canManageSchedule) {
      final response = await supabase
          .from('work_schedules')
          .select()
          .gte('schedule_date', weekStartText)
          .lte('schedule_date', weekEndText)
          .order('schedule_date', ascending: true)
          .order('created_at', ascending: true);

      return List<Map<String, dynamic>>.from(response);
    }

    final response = await supabase
        .from('work_schedules')
        .select()
        .gte('schedule_date', weekStartText)
        .lte('schedule_date', weekEndText)
        .eq('staff_id', currentUserId)
        .order('schedule_date', ascending: true)
        .order('created_at', ascending: true);

    return List<Map<String, dynamic>>.from(response);
  }

  Map<String, dynamic>? getStaffById(String staffId) {
    try {
      return staffList.firstWhere(
        (staff) => staff['id'].toString() == staffId,
      );
    } catch (_) {
      return null;
    }
  }

  String getStaffName(dynamic staffId) {
    if (staffId == null) {
      return 'Unknown Staff';
    }

    final staff = getStaffById(staffId.toString());

    if (staff == null) {
      return 'Unknown Staff';
    }

    return (staff['full_name'] ?? 'Unnamed Staff').toString();
  }

  String getStaffRole(dynamic staffId) {
    if (staffId == null) {
      return '-';
    }

    final staff = getStaffById(staffId.toString());

    if (staff == null) {
      return '-';
    }

    return (staff['role'] ?? '-').toString();
  }

  String getAvatarUrl(dynamic staffId) {
    if (staffId == null) {
      return '';
    }

    final staff = getStaffById(staffId.toString());

    if (staff == null) {
      return '';
    }

    final value = staff['avatar_url'];

    if (value == null || value.toString().trim().isEmpty) {
      return '';
    }

    return value.toString();
  }

  List<Map<String, dynamic>> getSchedulesForStaffDate({
    required String staffId,
    required DateTime date,
  }) {
    final dateText = formatDateForDb(date);

    return schedules.where((schedule) {
      return schedule['staff_id'].toString() == staffId &&
          schedule['schedule_date'].toString() == dateText &&
          schedule['status'].toString() != 'cancelled';
    }).toList();
  }

  List<Map<String, dynamic>> getTodaySchedules() {
    final todayText = formatDateForDb(DateTime.now());

    List<Map<String, dynamic>> todaySchedules;

    if (canManageSchedule) {
      todaySchedules = schedules.where((schedule) {
        return schedule['schedule_date'].toString() == todayText &&
            schedule['status'].toString() != 'cancelled';
      }).toList();
    } else {
      todaySchedules = schedules.where((schedule) {
        return schedule['schedule_date'].toString() == todayText &&
            schedule['staff_id'].toString() == currentUserId &&
            schedule['status'].toString() != 'cancelled';
      }).toList();
    }

    todaySchedules.sort((a, b) {
      int shiftPriority(String shift) {
        switch (shift) {
          case 'opening':
            return 0;
          case 'full_day':
            return 1;
          case 'closing':
            return 2;
          default:
            return 3;
        }
      }

      final shiftA = shiftPriority((a['shift_type'] ?? '').toString());
      final shiftB = shiftPriority((b['shift_type'] ?? '').toString());

      if (shiftA != shiftB) {
        return shiftA.compareTo(shiftB);
      }

      return getStaffName(a['staff_id'])
          .toLowerCase()
          .compareTo(getStaffName(b['staff_id']).toLowerCase());
    });

    return todaySchedules;
  }

  int get totalAssigned {
    return schedules.where((schedule) {
      return schedule['status'].toString() == 'assigned';
    }).length;
  }

  int get totalCompleted {
    return schedules.where((schedule) {
      return schedule['status'].toString() == 'completed';
    }).length;
  }

  int get totalCancelled {
    return schedules.where((schedule) {
      return schedule['status'].toString() == 'cancelled';
    }).length;
  }

  String formatRole(String role) {
    if (role.isEmpty || role == '-') {
      return 'Staff';
    }

    return role[0].toUpperCase() + role.substring(1);
  }

  String formatShift(String shift) {
    switch (shift) {
      case 'opening':
        return 'Opening';
      case 'closing':
        return 'Closing';
      case 'full_day':
        return 'Full Day';
      default:
        return shift;
    }
  }

  String formatDuty(String duty) {
    switch (duty) {
      case 'cleaning':
        return 'Cleaning Checklist';
      case 'stock_count':
        return 'Stock Count';
      case 'stock_take':
        return 'Stock Take';
      case 'inventory_check':
        return 'Inventory Check';
      case 'general_operation':
        return 'Cafe Operation';
      default:
        return duty;
    }
  }

  String formatStatus(String status) {
    switch (status) {
      case 'assigned':
        return 'Assigned';
      case 'completed':
        return 'Completed';
      case 'cancelled':
        return 'Cancelled';
      default:
        return status;
    }
  }

  String getShortShift(String shift) {
    switch (shift) {
      case 'opening':
        return 'OPEN';
      case 'closing':
        return 'CLOSE';
      case 'full_day':
        return 'FULL';
      default:
        return shift.toUpperCase();
    }
  }

  String getShortDuty(String duty) {
    switch (duty) {
      case 'cleaning':
        return 'CLEAN';
      case 'stock_count':
        return 'STOCK';
      case 'stock_take':
        return 'TAKE';
      case 'inventory_check':
        return 'CHECK';
      case 'general_operation':
        return 'OPS';
      default:
        return duty.toUpperCase();
    }
  }

  Color getShiftColor(String shift) {
    switch (shift) {
      case 'opening':
        return const Color(0xFFFFC107);
      case 'closing':
        return const Color(0xFF00B050);
      case 'full_day':
        return const Color(0xFF1E88E5);
      default:
        return mulberry;
    }
  }

  Color getDutyColor(String duty) {
    switch (duty) {
      case 'cleaning':
        return const Color(0xFF29B6F6);
      case 'stock_count':
        return const Color(0xFF66BB6A);
      case 'stock_take':
        return const Color(0xFF6D4C41);
      case 'inventory_check':
        return const Color(0xFFAB47BC);
      case 'general_operation':
        return const Color(0xFFFFA726);
      default:
        return Colors.grey;
    }
  }

  Color getStatusColor(String status) {
    switch (status) {
      case 'assigned':
        return Colors.orange;
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData getDutyIcon(String duty) {
    switch (duty) {
      case 'cleaning':
        return Icons.cleaning_services;
      case 'stock_count':
        return Icons.fact_check;
      case 'stock_take':
        return Icons.inventory;
      case 'inventory_check':
        return Icons.inventory_2;
      case 'general_operation':
        return Icons.storefront;
      default:
        return Icons.assignment;
    }
  }

  Future<void> previousWeek() async {
    setState(() {
      selectedDate = selectedDate.subtract(const Duration(days: 7));
    });

    await loadPageData();
  }

  Future<void> nextWeek() async {
    setState(() {
      selectedDate = selectedDate.add(const Duration(days: 7));
    });

    await loadPageData();
  }

  Future<void> pickWeekDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2024),
      lastDate: DateTime.now().add(const Duration(days: 365)),
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
    });

    await loadPageData();
  }

  Future<void> generateWeeklyRotation() async {
    if (!canManageSchedule) {
      showMessage(
        'Only manager or supervisor can generate schedule.',
        isError: true,
      );
      return;
    }

    if (staffList.isEmpty) {
      showMessage('No active staff or supervisor found.', isError: true);
      return;
    }

    final confirm = await showConfirmDialog(
      title: 'Generate Weekly Rotation',
      message:
          'Generate weekly rotation for supervisors and staff? Supervisors will stay at the top and Sunday will include Stock Take duty.',
      confirmText: 'Generate',
      confirmColor: mulberry,
    );

    if (!confirm) return;

    final user = supabase.auth.currentUser;

    if (user == null) {
      showMessage('User not logged in.', isError: true);
      return;
    }

    setState(() {
      isSaving = true;
    });

    try {
      final supervisors = staffList.where((staff) {
        return (staff['role'] ?? '').toString() == 'supervisor';
      }).toList();

      final normalStaff = staffList.where((staff) {
        return (staff['role'] ?? '').toString() == 'staff';
      }).toList();

      final duties = [
        'cleaning',
        'stock_count',
        'inventory_check',
        'general_operation',
      ];

      final rowsToInsert = <Map<String, dynamic>>[];

      const sundayIndex = 6;

      for (int supervisorIndex = 0;
          supervisorIndex < supervisors.length;
          supervisorIndex++) {
        final supervisor = supervisors[supervisorIndex];
        final supervisorId = supervisor['id'].toString();

        final shiftType = supervisorIndex % 2 == 0 ? 'opening' : 'closing';

        final offDayIndex = supervisorIndex % 6;

        for (int dayIndex = 0; dayIndex < weekDates.length; dayIndex++) {
          if (dayIndex == offDayIndex) {
            continue;
          }

          final date = weekDates[dayIndex];
          final dateText = formatDateForDb(date);

          final existing = schedules.any((schedule) {
            return schedule['staff_id'].toString() == supervisorId &&
                schedule['schedule_date'].toString() == dateText &&
                schedule['status'].toString() != 'cancelled';
          });

          if (existing) {
            continue;
          }

          String dutyType = 'general_operation';
          String? notes = 'Supervisor duty rotation';

          if (dayIndex == sundayIndex) {
            dutyType = 'stock_take';
            notes =
                'Sunday stock take: supplier stock receiving, full inventory count and weekly stock audit';
          }

          rowsToInsert.add({
            'staff_id': supervisorId,
            'assigned_by': user.id,
            'schedule_date': dateText,
            'work_date': dateText,
            'shift_type': shiftType,
            'shift': shiftType,
            'duty_type': dutyType,
            'notes': notes,
            'status': 'assigned',
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          });
        }
      }

      for (int dayIndex = 0; dayIndex < weekDates.length; dayIndex++) {
        final date = weekDates[dayIndex];
        final dateText = formatDateForDb(date);

        for (int staffIndex = 0; staffIndex < normalStaff.length; staffIndex++) {
          final staff = normalStaff[staffIndex];
          final staffId = staff['id'].toString();

          final existing = schedules.any((schedule) {
            return schedule['staff_id'].toString() == staffId &&
                schedule['schedule_date'].toString() == dateText &&
                schedule['status'].toString() != 'cancelled';
          });

          if (existing) {
            continue;
          }

          final offDayIndex = staffIndex % 7;

          if (dayIndex == offDayIndex) {
            continue;
          }

          final shiftType = random.nextBool() ? 'opening' : 'closing';

          final dutyType = duties[
              (staffIndex + dayIndex + random.nextInt(duties.length)) %
                  duties.length];

          rowsToInsert.add({
            'staff_id': staffId,
            'assigned_by': user.id,
            'schedule_date': dateText,
            'work_date': dateText,
            'shift_type': shiftType,
            'shift': shiftType,
            'duty_type': dutyType,
            'notes': null,
            'status': 'assigned',
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          });
        }
      }

      if (rowsToInsert.isEmpty) {
        showMessage(
          'This week already has schedules. Tap any cell to edit existing schedule.',
        );
        return;
      }

      await supabase.from('work_schedules').insert(rowsToInsert);

      showMessage('Weekly rotation generated successfully.');

      await loadPageData();
    } catch (e) {
      showMessage('Failed to generate rotation: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          isSaving = false;
        });
      }
    }
  }

  Future<void> showScheduleForm({
    required String staffId,
    required DateTime date,
    Map<String, dynamic>? existingSchedule,
  }) async {
    if (!canManageSchedule) {
      return;
    }

    String selectedShift =
        (existingSchedule?['shift_type'] ?? 'opening').toString();

    String selectedDuty =
        (existingSchedule?['duty_type'] ?? 'cleaning').toString();

    final notesController = TextEditingController(
      text: existingSchedule?['notes']?.toString() ?? '',
    );

    final dateText = formatDateForDb(date);
    final staffName = getStaffName(staffId);

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
                          radius: 34,
                          backgroundColor: mulberry.withOpacity(0.12),
                          child: const Icon(
                            Icons.event_available,
                            color: mulberry,
                            size: 34,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Center(
                        child: Text(
                          existingSchedule == null
                              ? 'Assign Schedule'
                              : 'Edit Schedule',
                          style: const TextStyle(
                            color: mulberryDark,
                            fontFamily: 'Georgia',
                            fontSize: 21,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Center(
                        child: Text(
                          '$staffName • $dateText',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      DropdownButtonFormField<String>(
                        value: selectedShift,
                        decoration: buildInputDecoration(
                          label: 'Shift',
                          icon: Icons.schedule,
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
                            value: 'full_day',
                            child: Text('Full Day'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value == null) return;
                          setModalState(() {
                            selectedShift = value;
                          });
                        },
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        value: selectedDuty,
                        decoration: buildInputDecoration(
                          label: 'Duty',
                          icon: Icons.assignment,
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'cleaning',
                            child: Text('Cleaning Checklist'),
                          ),
                          DropdownMenuItem(
                            value: 'stock_count',
                            child: Text('Stock Count'),
                          ),
                          DropdownMenuItem(
                            value: 'stock_take',
                            child: Text('Stock Take'),
                          ),
                          DropdownMenuItem(
                            value: 'inventory_check',
                            child: Text('Inventory Check'),
                          ),
                          DropdownMenuItem(
                            value: 'general_operation',
                            child: Text('Cafe Operation'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value == null) return;
                          setModalState(() {
                            selectedDuty = value;
                          });
                        },
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: notesController,
                        maxLines: 3,
                        decoration: buildInputDecoration(
                          label: 'Notes optional',
                          icon: Icons.notes,
                        ),
                      ),
                      const SizedBox(height: 22),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton.icon(
                          onPressed: isSaving
                              ? null
                              : () async {
                                  final success = await saveSchedule(
                                    staffId: staffId,
                                    dateText: dateText,
                                    shiftType: selectedShift,
                                    dutyType: selectedDuty,
                                    notes: notesController.text.trim(),
                                    existingSchedule: existingSchedule,
                                  );

                                  if (!success) return;

                                  if (bottomSheetContext.mounted) {
                                    Navigator.pop(bottomSheetContext);
                                  }

                                  if (mounted) {
                                    await loadPageData();
                                  }
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
                              : const Icon(Icons.save),
                          label: Text(
                            isSaving ? 'Saving...' : 'Save Schedule',
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
                      if (existingSchedule != null) ...[
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              if (bottomSheetContext.mounted) {
                                Navigator.pop(bottomSheetContext);
                              }

                              await cancelSchedule(existingSchedule);
                            },
                            icon: const Icon(Icons.close),
                            label: const Text('Cancel This Schedule'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                              side: const BorderSide(color: Colors.red),
                            ),
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ),
          ),
        );
      },
    );

    notesController.dispose();
  }

  Future<bool> saveSchedule({
    required String staffId,
    required String dateText,
    required String shiftType,
    required String dutyType,
    required String notes,
    Map<String, dynamic>? existingSchedule,
  }) async {
    final user = supabase.auth.currentUser;

    if (user == null) {
      showMessage('User not logged in.', isError: true);
      return false;
    }

    setState(() {
      isSaving = true;
    });

    try {
      if (existingSchedule == null) {
        final existingSameDate = schedules.any((schedule) {
          return schedule['staff_id'].toString() == staffId &&
              schedule['schedule_date'].toString() == dateText &&
              schedule['status'].toString() != 'cancelled';
        });

        if (existingSameDate) {
          showMessage(
            'This staff already has schedule on this date. Tap the cell to edit it.',
            isError: true,
          );
          return false;
        }

        await supabase.from('work_schedules').insert({
          'staff_id': staffId,
          'assigned_by': user.id,
          'schedule_date': dateText,
          'work_date': dateText,
          'shift_type': shiftType,
          'shift': shiftType,
          'duty_type': dutyType,
          'notes': notes.isEmpty ? null : notes,
          'status': 'assigned',
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        });

        await notifyStaffSchedule(
          staffId: staffId,
          dateText: dateText,
          shiftType: shiftType,
          dutyType: dutyType,
        );

        showMessage('Schedule assigned successfully.');
      } else {
        await supabase.from('work_schedules').update({
          'shift_type': shiftType,
          'shift': shiftType,
          'duty_type': dutyType,
          'notes': notes.isEmpty ? null : notes,
          'status': 'assigned',
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('schedule_id', existingSchedule['schedule_id']);

        showMessage('Schedule updated successfully.');
      }

      return true;
    } catch (e) {
      showMessage('Failed to save schedule: $e', isError: true);
      return false;
    } finally {
      if (mounted) {
        setState(() {
          isSaving = false;
        });
      }
    }
  }

  Future<void> notifyStaffSchedule({
    required String staffId,
    required String dateText,
    required String shiftType,
    required String dutyType,
  }) async {
    try {
      await supabase.from('notifications').insert({
        'user_id': staffId,
        'title': 'New Work Schedule',
        'message':
            'You have been assigned to ${formatDuty(dutyType)} for ${formatShift(shiftType)} shift on $dateText.',
        'type': 'schedule',
        'target_page': 'work_schedule',
        'target_id': dateText,
        'is_read': false,
      });
    } catch (e) {
      debugPrint('Failed to notify staff schedule: $e');
    }
  }

  Future<void> cancelSchedule(Map<String, dynamic> schedule) async {
    final confirm = await showConfirmDialog(
      title: 'Cancel Schedule',
      message: 'Do you want to cancel this schedule?',
      confirmText: 'Cancel Schedule',
      confirmColor: Colors.red,
    );

    if (!confirm) return;

    try {
      await supabase.from('work_schedules').update({
        'status': 'cancelled',
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('schedule_id', schedule['schedule_id']);

      showMessage('Schedule cancelled.');

      await loadPageData();
    } catch (e) {
      showMessage('Failed to cancel schedule: $e', isError: true);
    }
  }

  Future<void> markScheduleCompleted(Map<String, dynamic> schedule) async {
    final confirm = await showConfirmDialog(
      title: 'Complete Schedule',
      message: 'Mark this schedule as completed?',
      confirmText: 'Complete',
      confirmColor: Colors.green,
    );

    if (!confirm) return;

    try {
      await supabase.from('work_schedules').update({
        'status': 'completed',
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('schedule_id', schedule['schedule_id']);

      showMessage('Schedule marked as completed.');

      await loadPageData();
    } catch (e) {
      showMessage('Failed to update schedule: $e', isError: true);
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
              child: const Text('No'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: confirmColor,
                foregroundColor: cream,
              ),
              child: Text(confirmText),
            ),
          ],
        );
      },
    );

    return result == true;
  }

  InputDecoration buildInputDecoration({
    required String label,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(
        color: Colors.grey.shade700,
      ),
      prefixIcon: Icon(
        icon,
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
          width: 1.8,
        ),
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }

  Widget buildHeader() {
    final title = canManageSchedule ? 'Weekly Staff Schedule' : 'My Schedule';

    return Container(
      padding: const EdgeInsets.all(20),
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
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: mulberryDark.withOpacity(0.20),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: cream.withOpacity(0.18),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.calendar_month,
              color: cream,
              size: 32,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: cream,
                    fontFamily: 'Georgia',
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '$weekStartText to $weekEndText',
                  style: const TextStyle(
                    color: creamDark,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  canManageSchedule
                      ? 'Auto-generate weekly duty rotation for supervisors and staff. Sunday includes Stock Take.'
                      : 'View your assigned shift and duty for this week.',
                  style: TextStyle(
                    color: cream.withOpacity(0.9),
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

  Widget buildWeekNavigator() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: buildWhiteBox(),
      child: Row(
        children: [
          IconButton(
            onPressed: previousWeek,
            icon: const Icon(
              Icons.chevron_left,
              color: mulberry,
            ),
          ),
          Expanded(
            child: InkWell(
              onTap: pickWeekDate,
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Column(
                  children: [
                    Text(
                      'Selected Week',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '$weekStartText - $weekEndText',
                      style: const TextStyle(
                        color: mulberry,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          IconButton(
            onPressed: nextWeek,
            icon: const Icon(
              Icons.chevron_right,
              color: mulberry,
            ),
          ),
        ],
      ),
    );
  }

  Widget buildSummaryCards() {
    return Row(
      children: [
        Expanded(
          child: buildMiniSummaryCard(
            label: 'Assigned',
            value: totalAssigned.toString(),
            icon: Icons.assignment,
            color: Colors.orange,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: buildMiniSummaryCard(
            label: 'Completed',
            value: totalCompleted.toString(),
            icon: Icons.check_circle,
            color: Colors.green,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: buildMiniSummaryCard(
            label: 'Cancelled',
            value: totalCancelled.toString(),
            icon: Icons.cancel,
            color: Colors.red,
          ),
        ),
      ],
    );
  }

  Widget buildMiniSummaryCard({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 14,
      ),
      decoration: buildWhiteBox(),
      child: Column(
        children: [
          Icon(
            icon,
            color: color,
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget buildLegend() {
    final items = [
      {
        'label': 'OPEN = Opening shift',
        'color': getShiftColor('opening'),
      },
      {
        'label': 'CLOSE = Closing shift',
        'color': getShiftColor('closing'),
      },
      {
        'label': 'CLEAN = Cleaning checklist',
        'color': getDutyColor('cleaning'),
      },
      {
        'label': 'STOCK = Daily stock count',
        'color': getDutyColor('stock_count'),
      },
      {
        'label': 'TAKE = Sunday stock take',
        'color': getDutyColor('stock_take'),
      },
      {
        'label': 'CHECK = Inventory check',
        'color': getDutyColor('inventory_check'),
      },
      {
        'label': 'OPS = Cafe operation',
        'color': getDutyColor('general_operation'),
      },
    ];

    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final item = items[index];

          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: (item['color'] as Color).withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    color: item['color'] as Color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  item['label'].toString(),
                  style: TextStyle(
                    color: item['color'] as Color,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget buildWeeklyScheduleTable() {
    final rows = canManageSchedule
        ? staffList
        : staffList.where((staff) {
            return staff['id'].toString() == currentUserId;
          }).toList();

    if (rows.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(28),
        decoration: buildWhiteBox(),
        child: Center(
          child: Text(
            'No staff found for schedule.',
            style: TextStyle(
              color: Colors.grey.shade600,
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: buildWhiteBox(),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Column(
            children: [
              buildTableHeader(),
              ...rows.map(buildStaffScheduleRow),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildTableHeader() {
    return Row(
      children: [
        buildHeaderCell(
          text: 'Staff',
          width: 150,
        ),
        ...weekDates.map((date) {
          return buildHeaderCell(
            text: '${getDayName(date)}\n${formatShortDate(date)}',
            width: 120,
            highlight: isToday(date),
          );
        }),
      ],
    );
  }

  Widget buildHeaderCell({
    required String text,
    required double width,
    bool highlight = false,
  }) {
    return Container(
      width: width,
      height: 58,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: highlight ? creamDark.withOpacity(0.65) : cream,
        border: Border(
          right: BorderSide(
            color: creamDark.withOpacity(0.90),
          ),
          bottom: BorderSide(
            color: creamDark.withOpacity(0.90),
          ),
        ),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: highlight ? mulberry : mulberryDark,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget buildStaffScheduleRow(Map<String, dynamic> staff) {
    final staffId = staff['id'].toString();
    final staffName = (staff['full_name'] ?? 'Unnamed Staff').toString();
    final avatarUrl = staff['avatar_url']?.toString() ?? '';
    final role = (staff['role'] ?? 'staff').toString();

    return Row(
      children: [
        Container(
          width: 150,
          height: 82,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: role == 'supervisor'
                ? mulberry.withOpacity(0.08)
                : softWhite,
            border: Border(
              right: BorderSide(
                color: creamDark.withOpacity(0.90),
              ),
              bottom: BorderSide(
                color: creamDark.withOpacity(0.90),
              ),
            ),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: mulberry.withOpacity(0.10),
                backgroundImage:
                    avatarUrl.trim().isNotEmpty ? NetworkImage(avatarUrl) : null,
                child: avatarUrl.trim().isEmpty
                    ? Icon(
                        role == 'supervisor'
                            ? Icons.supervisor_account
                            : Icons.person,
                        color: mulberry,
                        size: 18,
                      )
                    : null,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      staffName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: mulberryDark,
                        fontWeight: FontWeight.bold,
                        fontSize: 12.5,
                      ),
                    ),
                    Text(
                      formatRole(role),
                      style: TextStyle(
                        color: role == 'supervisor'
                            ? mulberry
                            : Colors.grey.shade600,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        ...weekDates.map((date) {
          final cellSchedules = getSchedulesForStaffDate(
            staffId: staffId,
            date: date,
          );

          return buildScheduleCell(
            staffId: staffId,
            date: date,
            cellSchedules: cellSchedules,
          );
        }),
      ],
    );
  }

  Widget buildScheduleCell({
    required String staffId,
    required DateTime date,
    required List<Map<String, dynamic>> cellSchedules,
  }) {
    final hasSchedule = cellSchedules.isNotEmpty;
    final schedule = hasSchedule ? cellSchedules.first : null;

    Color cellColor = softWhite;
    String label = 'OFF';
    String subLabel = '';
    Color textColor = Colors.grey.shade600;

    if (schedule != null) {
      final shift = schedule['shift_type'].toString();
      final duty = schedule['duty_type'].toString();
      final status = schedule['status'].toString();

      if (duty == 'stock_take') {
        cellColor = getDutyColor('stock_take').withOpacity(0.70);
      } else {
        cellColor = getShiftColor(shift).withOpacity(0.72);
      }

      label = getShortShift(shift);
      subLabel = getShortDuty(duty);
      textColor = duty == 'stock_take' ? Colors.white : Colors.black87;

      if (status == 'completed') {
        cellColor = Colors.green.withOpacity(0.68);
        label = 'DONE';
        textColor = Colors.black87;
      }
    }

    return InkWell(
      onTap: canManageSchedule
          ? () {
              showScheduleForm(
                staffId: staffId,
                date: date,
                existingSchedule: schedule,
              );
            }
          : schedule == null
              ? null
              : () {
                  showScheduleDetail(schedule);
                },
      child: Container(
        width: 120,
        height: 82,
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: cellColor,
          border: Border(
            right: BorderSide(
              color: creamDark.withOpacity(0.90),
            ),
            bottom: BorderSide(
              color: creamDark.withOpacity(0.90),
            ),
          ),
        ),
        child: Center(
          child: hasSchedule
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: schedule!['duty_type'].toString() == 'stock_take'
                            ? Colors.white.withOpacity(0.20)
                            : getDutyColor(schedule['duty_type'].toString())
                                .withOpacity(0.24),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        subLabel,
                        style: TextStyle(
                          color: schedule['duty_type'].toString() == 'stock_take'
                              ? Colors.white
                              : Colors.black87,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                )
              : Text(
                  canManageSchedule ? '+' : 'OFF',
                  style: TextStyle(
                    color: canManageSchedule ? mulberry : Colors.grey.shade500,
                    fontSize: canManageSchedule ? 20 : 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
        ),
      ),
    );
  }

  Future<void> showScheduleDetail(Map<String, dynamic> schedule) async {
    final shift = schedule['shift_type'].toString();
    final duty = schedule['duty_type'].toString();
    final notes = schedule['notes'];
    final status = schedule['status'].toString();

    await showModalBottomSheet(
      context: context,
      backgroundColor: cream,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(26),
        ),
      ),
      builder: (bottomSheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 34,
                  backgroundColor: getDutyColor(duty).withOpacity(0.15),
                  child: Icon(
                    getDutyIcon(duty),
                    color: getDutyColor(duty),
                    size: 34,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  formatDuty(duty),
                  style: const TextStyle(
                    color: mulberryDark,
                    fontFamily: 'Georgia',
                    fontSize: 21,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${formatShift(shift)} shift • ${schedule['schedule_date']}',
                  style: TextStyle(
                    color: Colors.grey.shade700,
                  ),
                ),
                if (notes != null && notes.toString().trim().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    notes.toString(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: mulberryDark,
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                if (status == 'assigned')
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(bottomSheetContext);
                        markScheduleCompleted(schedule);
                      },
                      icon: const Icon(Icons.check),
                      label: const Text('Mark as Completed'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget buildTodayTaskPanel() {
    final today = DateTime.now();
    final todayText = formatDateForDb(today);
    final todayTasks = getTodaySchedules();

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: buildWhiteBox(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.today,
                color: mulberry,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  "Today's Task",
                  style: TextStyle(
                    color: mulberryDark,
                    fontFamily: 'Georgia',
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${getFullDayName(today)} • $todayText',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 12.5,
            ),
          ),
          const SizedBox(height: 12),
          if (todayTasks.isEmpty)
            Text(
              'No staff on shift for today.',
              style: TextStyle(
                color: Colors.grey.shade600,
              ),
            )
          else
            ...todayTasks.map(buildTodayTaskCard),
        ],
      ),
    );
  }

  Widget buildTodayTaskCard(Map<String, dynamic> schedule) {
    final staffId = schedule['staff_id'];
    final staffName = getStaffName(staffId);
    final staffRole = getStaffRole(staffId);
    final avatarUrl = getAvatarUrl(staffId);
    final shift = schedule['shift_type'].toString();
    final duty = schedule['duty_type'].toString();
    final status = schedule['status'].toString();
    final dateText = schedule['schedule_date'].toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: getDutyColor(duty).withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: getDutyColor(duty).withOpacity(0.18),
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: getDutyColor(duty).withOpacity(0.15),
            backgroundImage:
                avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
            child: avatarUrl.isEmpty
                ? Icon(
                    getDutyIcon(duty),
                    color: getDutyColor(duty),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  canManageSchedule ? staffName : formatDuty(duty),
                  style: const TextStyle(
                    color: mulberryDark,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  canManageSchedule
                      ? '${formatRole(staffRole)} • ${formatShift(shift)} • ${formatDuty(duty)}'
                      : '${formatShift(shift)} • ${formatDuty(duty)}',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                  ),
                ),
                Text(
                  '${getDayName(DateTime.parse(dateText))} • $dateText',
                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          buildStatusPill(status),
          if (status == 'assigned') ...[
            const SizedBox(width: 6),
            IconButton(
              onPressed: () => markScheduleCompleted(schedule),
              icon: const Icon(Icons.check_circle),
              color: Colors.green,
              tooltip: 'Complete',
            ),
          ],
        ],
      ),
    );
  }

  Widget buildStatusPill(String status) {
    final color = getStatusColor(status);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        formatStatus(status).toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
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
    return Scaffold(
      backgroundColor: cream,
      appBar: widget.showAppBar
          ? AppBar(
              title: Text(
                canManageSchedule ? 'Work Schedule' : 'My Schedule',
                style: const TextStyle(
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
                  onPressed: loadPageData,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            )
          : null,
      floatingActionButton: canManageSchedule
          ? FloatingActionButton.extended(
              onPressed: isSaving ? null : generateWeeklyRotation,
              backgroundColor: mulberry,
              foregroundColor: cream,
              icon: isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: cream,
                      ),
                    )
                  : const Icon(Icons.auto_awesome),
              label: Text(isSaving ? 'Generating...' : 'Generate Week'),
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
              onRefresh: loadPageData,
              child: ListView(
                padding: const EdgeInsets.all(18),
                children: [
                  buildHeader(),
                  const SizedBox(height: 14),
                  buildWeekNavigator(),
                  const SizedBox(height: 14),
                  buildSummaryCards(),
                  const SizedBox(height: 14),
                  buildLegend(),
                  const SizedBox(height: 14),
                  buildWeeklyScheduleTable(),
                  const SizedBox(height: 14),
                  buildTodayTaskPanel(),
                  const SizedBox(height: 90),
                ],
              ),
            ),
    );
  }
}