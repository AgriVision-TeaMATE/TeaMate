import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/field_model.dart';
import '../../services/app_settings_service.dart';
import '../../services/auth_service.dart';
import '../../theme.dart';
import '../../widgets/labour_widgets.dart';
import '../auth/login_screen.dart';
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
    AppSettingsService().loadYieldSettings();
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
          backgroundColor: AppTheme.backgroundLight,
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
              indicatorColor: AppTheme.primaryButton,
              indicatorWeight: 3,
              tabs: const [
                Tab(text: 'Labour Management'),
                Tab(text: 'General'),
              ],
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            children: const [_LabourManagementTab(), _GeneralSettingsTab()],
          ),
        );
      },
    );
  }
}

class _LabourManagementTab extends StatelessWidget {
  const _LabourManagementTab();

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
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: const LinearGradient(
                colors: [Color(0xFF4A4A4A), Color(0xFF2F2F2F)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _OverviewStat(
                    label: 'Total',
                    value: '${workers.length}',
                  ),
                ),
                Expanded(
                  child: _OverviewStat(label: 'Available', value: '$available'),
                ),
                Expanded(
                  child: _OverviewStat(label: 'Assigned', value: '$assigned'),
                ),
                Expanded(
                  child: _OverviewStat(label: 'On Leave', value: '$onLeave'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _showAddWorkerSheet(context),
              icon: const Icon(Icons.person_add_outlined),
              label: const Text('Add New Worker'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryButton,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          ListenableBuilder(
            listenable: settings,
            builder: (context, _) {
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE8ECEF)),
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
                        SizedBox(
                          width: 78,
                          height: 36,
                          child: ElevatedButton(
                            onPressed: () =>
                                _showKgSettingSheet(context, settings),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryButton,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: EdgeInsets.zero,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'Change',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 24),
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

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
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
                const Text(
                  'Add New Worker',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: 'Full Name',
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
                    filled: true,
                    fillColor: const Color(0xFFF5F7F6),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    prefixIcon: const Icon(Icons.phone_outlined),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      final name = nameController.text.trim();
                      final phone = phoneController.text.trim();
                      if (name.isEmpty || phone.isEmpty) return;
                      FieldManager().addWorker(name: name, phone: phone);
                      Navigator.pop(context);
                    },
                    child: const Text('Add Worker'),
                  ),
                ),
              ],
            ),
          ),
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
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          top: false,
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.72,
            ),
            padding: const EdgeInsets.fromLTRB(22, 10, 22, 14),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD7DDE2),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                  const SizedBox(height: 16),
                  WorkerAvatar(worker: worker, size: 64),
                  const SizedBox(height: 12),
                  Text(
                    worker.name,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    worker.statusLabel,
                    style: const TextStyle(
                      color: AppTheme.brandGreen,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 18),
                  _DetailRow(
                    icon: Icons.phone_outlined,
                    label: 'Phone',
                    value: worker.phone,
                    actionIcon: Icons.call_rounded,
                    onTap: () => _callWorker(context, worker.phone),
                  ),
                  const SizedBox(height: 9),
                  _DetailRow(
                    icon: Icons.circle,
                    label: 'Status',
                    value: worker.statusLabel,
                    iconColor: AppTheme.brandGreen,
                  ),
                  const SizedBox(height: 9),
                  _DetailRow(
                    icon: Icons.landscape_outlined,
                    label: 'Assigned Field',
                    value: fieldName ?? 'Not assigned',
                  ),
                  const SizedBox(height: 9),
                  _DetailRow(
                    icon: Icons.calendar_today_outlined,
                    label: 'Joined',
                    value: _formatDate(worker.createdAt),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _callWorker(BuildContext context, String phone) async {
    final cleaned = phone.replaceAll(RegExp(r'\s+'), '');
    final uri = Uri(scheme: 'tel', path: cleaned);
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (opened || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Unable to open phone dialer.')),
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
  const _GeneralSettingsTab();

  static const List<String> _teaVariants = [
    'TRI 2025',
    'TRI 2026',
    'TRI 2027',
    'TRI 2023',
    'Seedling Tea',
    'Custom',
  ];

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

  void _showYieldSettingsSheet(
    BuildContext context,
    AppSettingsService settings,
  ) {
    var selectedVariant = settings.teaVariant;
    final pluckableController = TextEditingController(
      text: settings.pluckable100BudWeightG?.toStringAsFixed(1) ?? '',
    );
    final arimbuController = TextEditingController(
      text: settings.arimbu100BudWeightG?.toStringAsFixed(1) ?? '',
    );
    var isSaving = false;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.82,
                ),
                padding: const EdgeInsets.all(24),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Yield prediction setup',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Choose the tea variant and enter estate-average fresh weights. TeaMate will use these values for each yield prediction.',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F7F6),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: const Color(0xFFE5E7EB)),
                        ),
                        child: const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Prediction model',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Sample weight = (pluckable count x pluckable bud weight) + (arimbu count x arimbu bud weight)',
                              style: TextStyle(
                                color: AppTheme.textSecondary,
                                height: 1.45,
                              ),
                            ),
                            SizedBox(height: 6),
                            Text(
                              'Predicted yield = (sample weight / sampled area) x total field area',
                              style: TextStyle(
                                color: AppTheme.textSecondary,
                                height: 1.45,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      DropdownButtonFormField<String>(
                        initialValue: selectedVariant,
                        decoration: InputDecoration(
                          labelText: 'Tea variant',
                          helperText:
                              'Select the cultivar or estate tea type used for this estate.',
                          filled: true,
                          fillColor: const Color(0xFFF5F7F6),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        items: _teaVariants
                            .map(
                              (variant) => DropdownMenuItem<String>(
                                value: variant,
                                child: Text(variant),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value == null) return;
                          setSheetState(() {
                            selectedVariant = value;
                          });
                        },
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: pluckableController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          labelText: '100 pluckable buds weight (g)',
                          helperText:
                              'Average fresh weight of 100 ready-to-pluck buds.',
                          filled: true,
                          fillColor: const Color(0xFFF5F7F6),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: arimbuController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          labelText: '100 arimbu buds weight (g)',
                          helperText:
                              'Average fresh weight of 100 immature arimbu buds.',
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
                          onPressed: isSaving
                              ? null
                              : () async {
                                  final pluckableWeight = double.tryParse(
                                    pluckableController.text.trim(),
                                  );
                                  final arimbuWeight = double.tryParse(
                                    arimbuController.text.trim(),
                                  );
                                  if (pluckableWeight == null ||
                                      pluckableWeight <= 0 ||
                                      arimbuWeight == null ||
                                      arimbuWeight <= 0) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Enter valid positive bud weights.',
                                        ),
                                      ),
                                    );
                                    return;
                                  }

                                  setSheetState(() {
                                    isSaving = true;
                                  });
                                  final saved = await settings
                                      .saveYieldSettings(
                                        teaVariant: selectedVariant,
                                        pluckable100BudWeightG: pluckableWeight,
                                        arimbu100BudWeightG: arimbuWeight,
                                      );
                                  if (!context.mounted) return;
                                  setSheetState(() {
                                    isSaving = false;
                                  });
                                  if (!saved) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Failed to save yield settings.',
                                        ),
                                      ),
                                    );
                                    return;
                                  }
                                  Navigator.pop(context);
                                },
                          child: Text(isSaving ? 'Saving...' : 'Save'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService().currentUser;
    final settings = AppSettingsService();

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
            title: 'Yield Prediction',
            children: [
              ListenableBuilder(
                listenable: settings,
                builder: (context, _) {
                  String subtitle;
                  if (settings.yieldSettingsLoading) {
                    subtitle = 'Loading saved tea variant and bud weights...';
                  } else if (settings.hasConfiguredYieldSettings) {
                    subtitle =
                        'Variant: ${settings.teaVariant}\n'
                        '100 pluckable buds: ${settings.pluckable100BudWeightG!.toStringAsFixed(1)} g\n'
                        '100 arimbu buds: ${settings.arimbu100BudWeightG!.toStringAsFixed(1)} g';
                  } else {
                    subtitle =
                        'Save tea variant and 100-bud weights before predicting yield.';
                  }

                  return _SettingsTile(
                    icon: Icons.science_outlined,
                    title: 'Tea variant and bud weights',
                    subtitle: subtitle,
                    onTap: () => _showYieldSettingsSheet(context, settings),
                    trailing: const Icon(
                      Icons.chevron_right_rounded,
                      color: AppTheme.textSecondary,
                    ),
                  );
                },
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
  final IconData? actionIcon;
  final Color? iconColor;
  final VoidCallback? onTap;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.actionIcon,
    this.iconColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: const Color(0xFFF7F8F9),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE8ECEF)),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(color: const Color(0xFFE2E7EA)),
                ),
                child: Icon(
                  icon,
                  size: 17,
                  color: iconColor ?? AppTheme.brandGreen,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      value,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              if (actionIcon != null) ...[
                const SizedBox(width: 12),
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppTheme.brandGreen,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(actionIcon, size: 18, color: Colors.white),
                ),
              ],
            ],
          ),
        ),
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
          crossAxisAlignment: CrossAxisAlignment.start,
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
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            if (trailing != null) ...[const SizedBox(width: 12), trailing!],
          ],
        ),
      ),
    );
  }
}
