import 'package:flutter/material.dart';

import '../models/field_model.dart';
import '../services/app_settings_service.dart';
import '../services/auth_service.dart';
import '../theme.dart';
import '../widgets/labour_widgets.dart';
import 'login_screen.dart';
import 'profile_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: FieldManager(),
      builder: (context, _) {
        return Scaffold(
          backgroundColor: const Color(0xFFF3F4F6),
          appBar: AppBar(
            title: const Text(
              'Settings',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
              ),
            ),
            bottom: TabBar(
              controller: _tabController,
              labelColor: AppTheme.textPrimary,
              unselectedLabelColor: AppTheme.textSecondary,
              labelStyle: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
              indicatorColor: const Color(0xFF0B4F3F),
              indicatorWeight: 3,
              tabs: const [
                Tab(text: 'Labour Management'),
                Tab(text: 'General'),
              ],
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            children: [_LabourManagementTab(), _GeneralSettingsTab()],
          ),
        );
      },
    );
  }
}

class _LabourManagementTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final manager = FieldManager();
    final settings = AppSettingsService();
    final workers = manager.workers;
    final available = manager.availableWorkers.length;
    final assigned = manager.assignedWorkers.length;
    final onLeave = manager.onLeaveWorkers.length;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Overview Banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: const LinearGradient(
                colors: [Color(0xFF173730), Color(0xFF0E221D)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _OverviewStat(
                        label: 'Total',
                        value: '${workers.length}',
                      ),
                    ),
                    Expanded(
                      child: _OverviewStat(
                        label: 'Available',
                        value: '$available',
                      ),
                    ),
                    Expanded(
                      child: _OverviewStat(
                        label: 'Assigned',
                        value: '$assigned',
                      ),
                    ),
                    Expanded(
                      child: _OverviewStat(
                        label: 'On Leave',
                        value: '$onLeave',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Add Worker Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _showAddWorkerSheet(context),
              icon: const Icon(Icons.person_add_outlined),
              label: const Text('Add New Worker'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0B4F3F),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Field Assignments Section
          const Text(
            'Field Assignments',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Assign available workers to fields based on plucking priority.',
            style: TextStyle(color: AppTheme.textSecondary, height: 1.4),
          ),
          const SizedBox(height: 14),
          ...manager.prioritizedFields.map((field) {
            final fieldWorkers = manager.workersForField(field.id);
            final recommended =
                field.latestMeasurement?.laborPlan?.recommendedWorkers ?? 5;
            return FieldAssignmentCard(
              field: field,
              assignedWorkers: fieldWorkers,
              recommendedWorkers: recommended,
              onAssignTap: () => _showAssignWorkersSheet(context, field),
            );
          }),

          const SizedBox(height: 24),

          ListenableBuilder(
            listenable: settings,
            builder: (context, _) {
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Row(
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Daily plucking capacity',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(height: 6),
                          Text(
                            'Used to estimate required labour from predicted yield.',
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${settings.kgPerWorkerPerDay.toStringAsFixed(0)} kg/day',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton(
                          onPressed: () =>
                              _showKgSettingSheet(context, settings),
                          child: const Text('Change'),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),

          const SizedBox(height: 24),

          // Worker Roster
          Row(
            children: [
              const Text(
                'Worker Roster',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                ),
              ),
              const Spacer(),
              Text(
                '${workers.length} workers',
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...workers.map((worker) {
            String? fieldName;
            if (worker.assignedFieldId != null) {
              try {
                final field = manager.fields.firstWhere(
                  (f) => f.id == worker.assignedFieldId,
                );
                fieldName = field.name;
              } catch (_) {}
            }
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: WorkerAssignmentTile(
                worker: worker,
                fieldName: fieldName != null ? 'Assigned: $fieldName' : null,
                onTap: () => _showWorkerDetailSheet(context, worker),
                trailing: PopupMenuButton<String>(
                  icon: const Icon(
                    Icons.more_vert_rounded,
                    color: AppTheme.textSecondary,
                    size: 20,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  onSelected: (value) {
                    switch (value) {
                      case 'available':
                        manager.setWorkerStatus(
                          worker.id,
                          WorkerStatus.available,
                        );
                        break;
                      case 'leave':
                        manager.setWorkerStatus(
                          worker.id,
                          WorkerStatus.onLeave,
                        );
                        break;
                      case 'unassign':
                        manager.unassignWorker(worker.id);
                        break;
                      case 'delete':
                        _confirmDeleteWorker(context, worker);
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    if (worker.status != WorkerStatus.available)
                      const PopupMenuItem(
                        value: 'available',
                        child: Row(
                          children: [
                            Icon(Icons.check_circle_outline, size: 18),
                            SizedBox(width: 10),
                            Text('Set Available'),
                          ],
                        ),
                      ),
                    if (worker.status != WorkerStatus.onLeave)
                      const PopupMenuItem(
                        value: 'leave',
                        child: Row(
                          children: [
                            Icon(Icons.event_busy_outlined, size: 18),
                            SizedBox(width: 10),
                            Text('Set On Leave'),
                          ],
                        ),
                      ),
                    if (worker.status == WorkerStatus.assigned)
                      const PopupMenuItem(
                        value: 'unassign',
                        child: Row(
                          children: [
                            Icon(Icons.person_remove_outlined, size: 18),
                            SizedBox(width: 10),
                            Text('Unassign'),
                          ],
                        ),
                      ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(
                            Icons.delete_outline,
                            size: 18,
                            color: Color(0xFFD95C5C),
                          ),
                          SizedBox(width: 10),
                          Text(
                            'Delete',
                            style: TextStyle(color: Color(0xFFD95C5C)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  void _showKgSettingSheet(BuildContext context, AppSettingsService settings) {
    final controller = TextEditingController(
      text: settings.kgPerWorkerPerDay.toStringAsFixed(0),
    );

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Plucking capacity',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Set the daily kilograms one labourer can pluck for labour estimation.',
                  style: TextStyle(color: AppTheme.textSecondary, height: 1.45),
                ),
                const SizedBox(height: 18),
                TextField(
                  controller: controller,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Kg per worker per day',
                    filled: true,
                    fillColor: const Color(0xFFF5F7F6),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      final value = double.tryParse(controller.text.trim());
                      if (value == null || value <= 0) return;
                      await settings.setKgPerWorkerPerDay(value);
                      if (context.mounted) Navigator.pop(context);
                    },
                    child: const Text('Save'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showAddWorkerSheet(BuildContext context) {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    SkillLevel selectedSkill = SkillLevel.experienced;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8F5EC),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.person_add_outlined,
                            color: Color(0xFF0B4F3F),
                          ),
                        ),
                        const SizedBox(width: 14),
                        const Text(
                          'Add New Worker',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: nameController,
                      autofocus: true,
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(
                        labelText: 'Full Name',
                        hintText: 'e.g. Kamal Perera',
                        filled: true,
                        fillColor: const Color(0xFFF5F7F6),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        prefixIcon: const Icon(Icons.person_outline),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: 'Phone Number',
                        hintText: '+94 77 123 4567',
                        filled: true,
                        fillColor: const Color(0xFFF5F7F6),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        prefixIcon: const Icon(Icons.phone_outlined),
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Skill Level',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: SkillLevel.values.map((skill) {
                        final isSelected = selectedSkill == skill;
                        final label = switch (skill) {
                          SkillLevel.junior => 'Junior',
                          SkillLevel.experienced => 'Experienced',
                          SkillLevel.senior => 'Senior',
                        };
                        return Expanded(
                          child: GestureDetector(
                            onTap: () {
                              setSheetState(() {
                                selectedSkill = skill;
                              });
                            },
                            child: Container(
                              margin: EdgeInsets.only(
                                right: skill != SkillLevel.senior ? 8 : 0,
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? const Color(0xFF0B4F3F)
                                    : const Color(0xFFF5F7F6),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected
                                      ? const Color(0xFF0B4F3F)
                                      : const Color(0xFFE0E5E9),
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  label,
                                  style: TextStyle(
                                    color: isSelected
                                        ? Colors.white
                                        : AppTheme.textPrimary,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          final name = nameController.text.trim();
                          final phone = phoneController.text.trim();
                          if (name.isEmpty || phone.isEmpty) return;
                          FieldManager().addWorker(
                            name: name,
                            phone: phone,
                            skillLevel: selectedSkill,
                          );
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0B4F3F),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text(
                          'Add Worker',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showAssignWorkersSheet(BuildContext context, Field field) {
    final manager = FieldManager();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final available = manager.availableWorkers;
            final fieldWorkers = manager.workersForField(field.id);

            return DraggableScrollableSheet(
              initialChildSize: 0.7,
              maxChildSize: 0.9,
              minChildSize: 0.4,
              builder: (context, scrollController) {
                return Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(28),
                    ),
                  ),
                  child: Column(
                    children: [
                      // Handle
                      Container(
                        margin: const EdgeInsets.only(top: 12),
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFFD1D5DB),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Assign Workers to ${field.name}',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.4,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              field.subtitle,
                              style: const TextStyle(
                                color: AppTheme.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (fieldWorkers.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Currently Assigned',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 10),
                              ...fieldWorkers.map(
                                (w) => Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: WorkerAssignmentTile(
                                    worker: w,
                                    trailing: TextButton(
                                      onPressed: () {
                                        manager.unassignWorker(w.id);
                                        setSheetState(() {});
                                      },
                                      child: const Text(
                                        'Remove',
                                        style: TextStyle(
                                          color: Color(0xFFD95C5C),
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 24),
                      ],
                      Expanded(
                        child: ListView(
                          controller: scrollController,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          children: [
                            Text(
                              'Available Workers (${available.length})',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 10),
                            if (available.isEmpty)
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF5F7F6),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: const Text(
                                  'No available workers. Set workers as Available from the roster to assign them.',
                                  style: TextStyle(
                                    color: AppTheme.textSecondary,
                                    height: 1.4,
                                  ),
                                ),
                              )
                            else
                              ...available.map(
                                (w) => Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: WorkerAssignmentTile(
                                    worker: w,
                                    trailing: ElevatedButton(
                                      onPressed: () {
                                        manager.assignWorkerToField(
                                          w.id,
                                          field.id,
                                        );
                                        setSheetState(() {});
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(
                                          0xFF0B4F3F,
                                        ),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 8,
                                        ),
                                        minimumSize: Size.zero,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                      ),
                                      child: const Text(
                                        'Assign',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  void _showWorkerDetailSheet(BuildContext context, Worker worker) {
    final manager = FieldManager();
    String? fieldName;
    if (worker.assignedFieldId != null) {
      try {
        final field = manager.fields.firstWhere(
          (f) => f.id == worker.assignedFieldId,
        );
        fieldName = field.name;
      } catch (_) {}
    }

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              WorkerAvatar(worker: worker, size: 64),
              const SizedBox(height: 16),
              Text(
                worker.name,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 6),
              SkillBadge(skillLevel: worker.skillLevel),
              const SizedBox(height: 20),
              _DetailRow(
                icon: Icons.phone_outlined,
                label: 'Phone',
                value: worker.phone,
              ),
              const SizedBox(height: 12),
              _DetailRow(
                icon: Icons.circle,
                label: 'Status',
                value: worker.statusLabel,
              ),
              const SizedBox(height: 12),
              _DetailRow(
                icon: Icons.landscape_outlined,
                label: 'Assigned Field',
                value: fieldName ?? 'Not assigned',
              ),
              const SizedBox(height: 12),
              _DetailRow(
                icon: Icons.calendar_today_outlined,
                label: 'Joined',
                value: _formatDate(worker.createdAt),
              ),
              const SizedBox(height: 24),
              if (worker.status == WorkerStatus.assigned && fieldName != null)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      manager.unassignWorker(worker.id);
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.person_remove_outlined, size: 18),
                    label: const Text('Unassign from Field'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFD95C5C),
                      side: const BorderSide(
                        color: Color(0xFFD95C5C),
                        width: 1.5,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  void _confirmDeleteWorker(BuildContext context, Worker worker) {
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Delete Worker',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          content: Text(
            'Are you sure you want to remove ${worker.name} from the roster? This cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                FieldManager().deleteWorker(worker.id);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD95C5C),
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}

class _GeneralSettingsTab extends StatelessWidget {
  void _openProfile(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ProfileScreen()),
    );
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: const Text('Log out?'),
          content: const Text('You will need to sign in again to use TeaMate.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Log Out'),
            ),
          ],
        );
      },
    );

    if (shouldLogout != true || !context.mounted) return;

    AuthService().logout();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService().currentUser;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SettingsSection(
            title: 'Account',
            children: [
              _SettingsTile(
                icon: Icons.person_outline_rounded,
                title: user?.fullName ?? 'User Profile',
                subtitle: user?.email ?? 'View account details',
                onTap: () => _openProfile(context),
                trailing: const Icon(
                  Icons.chevron_right_rounded,
                  color: AppTheme.textSecondary,
                ),
              ),
              _SettingsTile(
                icon: Icons.logout_rounded,
                title: 'Log Out',
                subtitle: 'Sign out from this device',
                onTap: () => _confirmLogout(context),
                trailing: const Icon(
                  Icons.chevron_right_rounded,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _SettingsSection(
            title: 'Notifications',
            children: [
              _SettingsTile(
                icon: Icons.notifications_outlined,
                title: 'Push Notifications',
                subtitle: 'Weather warnings, labour alerts',
                trailing: Switch(
                  value: true,
                  onChanged: (_) {},
                  activeThumbColor: const Color(0xFF0B4F3F),
                ),
              ),
              _SettingsTile(
                icon: Icons.sms_outlined,
                title: 'SMS Alerts',
                subtitle: 'Send SMS reminders to workers',
                trailing: Switch(
                  value: true,
                  onChanged: (_) {},
                  activeThumbColor: const Color(0xFF0B4F3F),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _SettingsSection(
            title: 'Preferences',
            children: [
              _SettingsTile(
                icon: Icons.landscape_outlined,
                title: 'Default Region',
                subtitle: 'Hatton Division',
                trailing: const Icon(
                  Icons.chevron_right_rounded,
                  color: AppTheme.textSecondary,
                ),
              ),
              _SettingsTile(
                icon: Icons.thermostat_outlined,
                title: 'Temperature Unit',
                subtitle: 'Celsius (°C)',
                trailing: const Icon(
                  Icons.chevron_right_rounded,
                  color: AppTheme.textSecondary,
                ),
              ),
              _SettingsTile(
                icon: Icons.schedule_outlined,
                title: 'Default Shift Time',
                subtitle: '06:00 AM',
                trailing: const Icon(
                  Icons.chevron_right_rounded,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _SettingsSection(
            title: 'About',
            children: [
              _SettingsTile(
                icon: Icons.info_outline_rounded,
                title: 'App Version',
                subtitle: '1.0.0 (Build 1)',
              ),
              _SettingsTile(
                icon: Icons.school_outlined,
                title: 'Research Project',
                subtitle: 'AgriVision - TeaMate',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OverviewStat extends StatelessWidget {
  final String label;
  final String value;

  const _OverviewStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.65),
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F7F6),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppTheme.textSecondary),
          const SizedBox(width: 12),
          Text(
            label,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SettingsSection({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Column(
            children: [
              for (int i = 0; i < children.length; i++) ...[
                if (i > 0) const Divider(height: 1, indent: 54),
                children[i],
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: AppTheme.textPrimary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}
