import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/field_model.dart';
import '../models/tea_grade_model.dart';
import '../models/user_role.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import 'grade_result_screen.dart';

/// Factory manager home: capture or upload a tea sample photo and submit it
/// for grade composition analysis.
class FactoryHomeScreen extends StatefulWidget {
  const FactoryHomeScreen({super.key});

  @override
  State<FactoryHomeScreen> createState() => _FactoryHomeScreenState();
}

class _FactoryHomeScreenState extends State<FactoryHomeScreen> {
  final ImagePicker _picker = ImagePicker();

  XFile? _selectedImage;
  Uint8List? _selectedBytes; // for preview — Image.file is unavailable on web
  bool _isSubmitting = false;

  // Source field: the backend only accepts a field owned by this account,
  // so the options come from the caller-scoped GET /fields.
  List<Field> _fields = [];
  Field? _selectedField;
  bool _fieldsLoading = false;

  String _method = 'traditional';
  int? _scaleLevel;

  @override
  void initState() {
    super.initState();
    _loadFields();
  }

  Future<void> _loadFields() async {
    setState(() => _fieldsLoading = true);
    final fields = await ApiService().fetchFields();
    if (!mounted) return;
    setState(() {
      _fields = fields;
      _fieldsLoading = false;
      // DropdownButton requires `value` to be one of the current items, so
      // re-point the selection at the freshly fetched instance (or drop it).
      final selectedId = _selectedField?.id;
      _selectedField = null;
      for (final field in fields) {
        if (field.id == selectedId) {
          _selectedField = field;
          break;
        }
      }
    });
  }

  Future<void> _addField() async {
    final created = await showDialog<Field>(
      context: context,
      builder: (context) => const _AddFieldDialog(),
    );
    if (created == null || !mounted) return;
    setState(() {
      _fields = [..._fields, created];
      _selectedField = created;
    });
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final pickedFile =
          await _picker.pickImage(source: source, imageQuality: 85);
      if (pickedFile == null) return;
      final bytes = await pickedFile.readAsBytes();
      if (!mounted) return;
      setState(() {
        _selectedImage = pickedFile;
        _selectedBytes = bytes;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open the image picker.'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _submit() async {
    final image = _selectedImage;
    final field = _selectedField;
    final requiresScaleLevel = _method == 'traditional';
    if (image == null ||
        field == null ||
        (requiresScaleLevel && _scaleLevel == null) ||
        _isSubmitting) {
      return;
    }
    setState(() => _isSubmitting = true);

    final scan = await TeaGradeManager().submitImage(
      image,
      fieldId: field.id,
      method: _method,
      scaleLevel: requiresScaleLevel ? _scaleLevel : null,
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (scan == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Analysis failed. Please try again.'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            GradeResultScreen(scan: scan, localImageBytes: _selectedBytes),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService().currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF9F9FC),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Header(
                name: user?.fullName ?? 'Factory Manager',
                roleLabel: UserRole.label(user?.role ?? UserRole.factoryManager),
              ),
              const SizedBox(height: 22),
              const Text(
                'Tea Quality Grading',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.8,
                  color: Color(0xFF18212B),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Photograph a spread tea sample and get its grade composition instantly.',
                style: TextStyle(
                  fontSize: 15,
                  height: 1.5,
                  color: Color(0xFF7A8794),
                ),
              ),
              const SizedBox(height: 20),
              _ImageCard(
                imageBytes: _selectedBytes,
                onClear: () => setState(() {
                  _selectedImage = null;
                  _selectedBytes = null;
                }),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _PickButton(
                      icon: Icons.photo_camera_outlined,
                      label: 'Camera',
                      onPressed:
                          _isSubmitting ? null : () => _pickImage(ImageSource.camera),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _PickButton(
                      icon: Icons.photo_library_outlined,
                      label: 'Gallery',
                      onPressed: _isSubmitting
                          ? null
                          : () => _pickImage(ImageSource.gallery),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _FieldPickerCard(
                fields: _fields,
                selected: _selectedField,
                isLoading: _fieldsLoading,
                enabled: !_isSubmitting,
                onChanged: (field) => setState(() => _selectedField = field),
                onAddField: _addField,
                onRefresh: _loadFields,
              ),
              const SizedBox(height: 14),
              _AnalysisOptionsCard(
                method: _method,
                scaleLevel: _scaleLevel,
                enabled: !_isSubmitting,
                onMethodChanged: (value) =>
                    setState(() => _method = value ?? 'traditional'),
                onScaleLevelChanged: (value) =>
                    setState(() => _scaleLevel = value),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _selectedImage == null ||
                          _selectedField == null ||
                          (_method == 'traditional' && _scaleLevel == null) ||
                          _isSubmitting
                      ? null
                      : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF335C47),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor:
                        const Color(0xFF335C47).withValues(alpha: 0.35),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.2,
                          ),
                        )
                      : const Text(
                          'Analyze Tea Grade',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 22),
              const _HintCard(),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.name, required this.roleLabel});

  final String name;
  final String roleLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE7ECE9)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 34,
            height: 34,
            child: ClipOval(
              child: Image.asset(
                'assets/images/teamate_logo.png',
                fit: BoxFit.cover,
                errorBuilder: (context, _, __) => Container(
                  color: const Color(0xFF335C47),
                  child: const Icon(
                    Icons.eco_rounded,
                    size: 18,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hello, $name',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF183126),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  roleLabel,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF5F7C6C),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F0EB),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.factory_outlined,
              size: 18,
              color: Color(0xFF335C47),
            ),
          ),
        ],
      ),
    );
  }
}

class _ImageCard extends StatelessWidget {
  const _ImageCard({required this.imageBytes, required this.onClear});

  final Uint8List? imageBytes;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 240,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE3E8E5)),
      ),
      clipBehavior: Clip.antiAlias,
      child: imageBytes == null
          ? const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.grain_rounded,
                  size: 44,
                  color: Color(0xFF8FA99B),
                ),
                SizedBox(height: 10),
                Text(
                  'No sample selected',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF7A8794),
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Use the camera or pick from the gallery',
                  style: TextStyle(fontSize: 13, color: Color(0xFF9AA6A0)),
                ),
              ],
            )
          : Stack(
              fit: StackFit.expand,
              children: [
                Image.memory(imageBytes!, fit: BoxFit.cover),
                Positioned(
                  top: 10,
                  right: 10,
                  child: GestureDetector(
                    onTap: onClear,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _FieldPickerCard extends StatelessWidget {
  const _FieldPickerCard({
    required this.fields,
    required this.selected,
    required this.isLoading,
    required this.enabled,
    required this.onChanged,
    required this.onAddField,
    required this.onRefresh,
  });

  final List<Field> fields;
  final Field? selected;
  final bool isLoading;
  final bool enabled;
  final ValueChanged<Field?> onChanged;
  final VoidCallback onAddField;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE3E8E5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.map_outlined, size: 19, color: Color(0xFF8FA99B)),
          const SizedBox(width: 10),
          Expanded(
            child: isLoading
                ? const Text(
                    'Loading fields…',
                    style: TextStyle(fontSize: 14, color: Color(0xFF9AA6A0)),
                  )
                : fields.isEmpty
                    ? const Text(
                        'No fields yet — add one to continue',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF7A8794),
                        ),
                      )
                    : DropdownButtonHideUnderline(
                        child: DropdownButton<Field>(
                          value: selected,
                          isExpanded: true,
                          hint: const Text(
                            'Select source field',
                            style: TextStyle(
                              fontSize: 14,
                              color: Color(0xFF9AA6A0),
                            ),
                          ),
                          style: const TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF183126),
                          ),
                          items: [
                            for (final field in fields)
                              DropdownMenuItem(
                                value: field,
                                child: Text(
                                  field.name,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                          onChanged: enabled ? onChanged : null,
                        ),
                      ),
          ),
          IconButton(
            onPressed: enabled && !isLoading ? onRefresh : null,
            icon: const Icon(
              Icons.refresh_rounded,
              size: 20,
              color: Color(0xFF8FA99B),
            ),
            tooltip: 'Reload fields',
          ),
          IconButton(
            onPressed: enabled ? onAddField : null,
            icon: const Icon(
              Icons.add_circle_outline_rounded,
              size: 20,
              color: Color(0xFF335C47),
            ),
            tooltip: 'Add field',
          ),
        ],
      ),
    );
  }
}

class _AnalysisOptionsCard extends StatelessWidget {
  const _AnalysisOptionsCard({
    required this.method,
    required this.scaleLevel,
    required this.enabled,
    required this.onMethodChanged,
    required this.onScaleLevelChanged,
  });

  final String method;
  final int? scaleLevel;
  final bool enabled;
  final ValueChanged<String?> onMethodChanged;
  final ValueChanged<int?> onScaleLevelChanged;

  @override
  Widget build(BuildContext context) {
    final scaleLevelEnabled = enabled && method == 'traditional';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE3E8E5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Analysis Method',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF7A8794),
            ),
          ),
          const SizedBox(height: 6),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: method,
              isExpanded: true,
              style: const TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFF183126),
              ),
              items: const [
                DropdownMenuItem(
                  value: 'traditional',
                  child: Text('Traditional (Random Forest)'),
                ),
                DropdownMenuItem(
                  value: 'cnn',
                  child: Text('CNN (ResNet 18)'),
                ),
              ],
              onChanged: enabled ? onMethodChanged : null,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Scale Level',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: scaleLevelEnabled
                  ? const Color(0xFF7A8794)
                  : const Color(0xFFBFC7C3),
            ),
          ),
          const SizedBox(height: 6),
          DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: scaleLevelEnabled ? scaleLevel : null,
              isExpanded: true,
              hint: Text(
                scaleLevelEnabled
                    ? 'Select scale level'
                    : 'Not applicable for CNN',
                style: const TextStyle(fontSize: 14, color: Color(0xFF9AA6A0)),
              ),
              style: const TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFF183126),
              ),
              items: const [
                DropdownMenuItem(value: 1, child: Text('20px/mm')),
                DropdownMenuItem(value: 2, child: Text('31px/mm')),
              ],
              onChanged: scaleLevelEnabled ? onScaleLevelChanged : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _AddFieldDialog extends StatefulWidget {
  const _AddFieldDialog();

  @override
  State<_AddFieldDialog> createState() => _AddFieldDialogState();
}

class _AddFieldDialogState extends State<_AddFieldDialog> {
  final _nameController = TextEditingController();
  final _areaController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _areaController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _isSaving) return;
    setState(() => _isSaving = true);

    final field = await ApiService().addField(
      name: _nameController.text.trim(),
      areaHectares: double.parse(_areaController.text.trim()),
    );

    if (!mounted) return;
    if (field == null) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not create the field. Is the server running?'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    Navigator.pop(context, field);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text(
        'Add Field',
        style: TextStyle(
          fontSize: 19,
          fontWeight: FontWeight.w700,
          color: Color(0xFF18212B),
        ),
      ),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Field name',
                hintText: 'e.g. Upper Estate Lot A',
              ),
              validator: (val) =>
                  (val == null || val.trim().isEmpty) ? 'Enter a name' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _areaController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Area (hectares)',
                hintText: 'e.g. 1.5',
              ),
              validator: (val) {
                final parsed = double.tryParse(val?.trim() ?? '');
                if (parsed == null || parsed <= 0) {
                  return 'Enter a valid area';
                }
                return null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: const Text(
            'Cancel',
            style: TextStyle(color: Color(0xFF7A8794)),
          ),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : _save,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF335C47),
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: _isSaving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : const Text('Create'),
        ),
      ],
    );
  }
}

class _PickButton extends StatelessWidget {
  const _PickButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 19, color: const Color(0xFF335C47)),
        label: Text(
          label,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Color(0xFF335C47),
          ),
        ),
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white,
          side: const BorderSide(color: Color(0xFFCBD8D0)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}

class _HintCard extends StatelessWidget {
  const _HintCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F0EB),
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.tips_and_updates_outlined,
                size: 18,
                color: Color(0xFF335C47),
              ),
              SizedBox(width: 8),
              Text(
                'How to capture a good sample',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF335C47),
                ),
              ),
            ],
          ),
          SizedBox(height: 10),
          Text(
            '• Spread the particles so they do not touch each other\n'
            '• Use a plain white background and diffuse lighting\n'
            '• Shoot from directly overhead and keep the image sharp',
            style: TextStyle(
              fontSize: 13,
              height: 1.6,
              color: Color(0xFF48604F),
            ),
          ),
        ],
      ),
    );
  }
}
