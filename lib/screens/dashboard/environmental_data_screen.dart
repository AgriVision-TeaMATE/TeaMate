import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../models/environmental_data.dart';
import '../../models/field_model.dart';
import '../../services/environmental_data_service.dart';
import '../../theme.dart';
import '../../widgets/disease_scan_widgets.dart';
import '../../widgets/environmental_data_widgets.dart';
import 'scan_disease_screen.dart';

class EnvironmentalDataScreen extends StatefulWidget {
  final String fieldId;

  const EnvironmentalDataScreen({super.key, required this.fieldId});

  @override
  State<EnvironmentalDataScreen> createState() =>
      _EnvironmentalDataScreenState();
}

class _EnvironmentalDataScreenState extends State<EnvironmentalDataScreen> {
  late EnvironmentalData _environmentalData;
  bool _isFetching = false;
  int _fetchStep = 0; // 0: idle, 1: GPS, 2: Location API, 3: Weather API

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _environmentalData = EnvironmentalData(
      date: DateTime(now.year, now.month, now.day),
      time: DateTime(now.year, now.month, now.day, now.hour, now.minute),
    );
  }

  Future<void> _autoFetchData() async {
    setState(() {
      _isFetching = true;
      _fetchStep = 1;
    });

    try {
      // Step 1: Get GPS location
      final location = await EnvironmentalDataService.getCurrentLocation();

      if (!mounted) return;
      setState(() {
        _fetchStep = 2;
      });

      // Fetch weekly weather summary
      final data = await EnvironmentalDataService.fetchEnvironmentalData(
        latitude: location.latitude,
        longitude: location.longitude,
      );

      if (!mounted) return;
      setState(() {
        _environmentalData = _environmentalData.copyWith(
          latitude: location.latitude,
          longitude: location.longitude,
          avgTemperatureLast7: data.avgTemperatureLast7,
          avgHumidityLast7: data.avgHumidityLast7,
          avgWindSpeedLast7: data.avgWindSpeedLast7,
          avgSunshineHoursLast7: data.avgSunshineHoursLast7,
          totalRainfallLast7: data.totalRainfallLast7,
        );
      });

      // Show success briefly
      await Future.delayed(const Duration(milliseconds: 500));

      if (!mounted) return;
      setState(() {
        _fetchStep = 0;
        _isFetching = false;
      });

      final messenger = ScaffoldMessenger.of(context);
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Environmental data fetched successfully!'),
          backgroundColor: AppTheme.brandGreen,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _fetchStep = 0;
        _isFetching = false;
      });
      _showFetchError(e);
    }
  }

  /// Shows a user-friendly error message based on the exception type.
  /// Provides actionable buttons for GPS settings and app settings.
  void _showFetchError(Object error) {
    final messenger = ScaffoldMessenger.of(context);

    if (error is LocationServiceDisabledException) {
      messenger.showSnackBar(
        SnackBar(
          content: const Text(
            'GPS/location is disabled. Please enable it to fetch environmental data.',
          ),
          backgroundColor: AppTheme.alertRedText,
          action: SnackBarAction(
            label: 'Open Settings',
            textColor: Colors.white,
            onPressed: () async {
              await Geolocator.openLocationSettings();
            },
          ),
        ),
      );
    } else if (error is PermissionDeniedException) {
      final message = error.toString();
      final isPermanentlyDenied = message.toLowerCase().contains('settings');
      messenger.showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: AppTheme.alertRedText,
          action: isPermanentlyDenied
              ? SnackBarAction(
                  label: 'Open Settings',
                  textColor: Colors.white,
                  onPressed: () async {
                    await openAppSettings();
                  },
                )
              : null,
        ),
      );
    } else if (error is LocationFetchException) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(error.toString()),
          backgroundColor: AppTheme.alertRedText,
        ),
      );
    } else {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Failed to fetch data: ${error.toString()}'),
          backgroundColor: AppTheme.alertRedText,
        ),
      );
    }
  }

  void _proceedToScan() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ScanDiseaseScreen(
          fieldId: widget.fieldId,
          environmentalData: _environmentalData,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Field? field = FieldManager().fields
        .where((f) => f.id == widget.fieldId)
        .toList()
        .firstOrNull;

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Environmental Data',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_rounded,
            color: AppTheme.textPrimary,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (field != null) ...[
              FieldContextHero(name: field.name, subtitle: field.subtitle),
              const SizedBox(height: 24),
            ],

            const Text(
              'Prepare scan conditions',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 5),
            const Text(
              'Fetch the latest field conditions, then review them before scanning.',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 13,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 16),

            _buildSectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const EnvironmentalDataCardHeader(
                    icon: Icons.auto_awesome_rounded,
                    title: 'Automatic collection',
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Use GPS and the weekly forecast to populate the values below.',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12.5,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isFetching ? null : _autoFetchData,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryButton,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: _isFetching
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.my_location_rounded, size: 20),
                      label: Text(
                        _isFetching
                            ? 'Collecting field data...'
                            : 'Fetch Field Conditions',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            if (_isFetching) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.accentGreen.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppTheme.brandGreen.withValues(alpha: 0.22),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Collection progress',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    AutoFetchProgressStep(
                      label: 'Fetching GPS location',
                      isActive: _fetchStep == 1,
                      isComplete: _fetchStep > 1,
                    ),
                    const SizedBox(height: 8),
                    AutoFetchProgressStep(
                      label: 'Fetching weekly weather summary',
                      isActive: _fetchStep == 2,
                      isComplete: _fetchStep > 1,
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 16),
            _buildSectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const EnvironmentalDataCardHeader(
                    icon: Icons.fact_check_outlined,
                    title: 'Scan context',
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Confirm when and where this disease scan is being taken.',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12.5,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 18),
                  _buildDateTimeFields(),
                  const SizedBox(height: 16),
                  const Divider(color: Color(0xFFE8ECE8), height: 1),
                  const SizedBox(height: 16),
                  _buildLocationFields(),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _buildSectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const EnvironmentalDataCardHeader(
                    icon: Icons.cloud_outlined,
                    title: 'Growing conditions',
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Seven-day conditions used to support the disease assessment.',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12.5,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 18),
                  _buildWeatherFields(),
                  const SizedBox(height: 16),
                  const Divider(color: Color(0xFFE8ECE8), height: 1),
                  const SizedBox(height: 16),
                  _buildSolarFields(),
                ],
              ),
            ),

            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _proceedToScan,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: const Icon(Icons.camera_alt_outlined, size: 22),
                label: const Text(
                  'Proceed to Disease Scan',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                ),
              ),
            ),

            const SizedBox(height: 16),
            ScanGuidelinesCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE4E9DE), width: 1),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryButton.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildDateTimeFields() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: EnvironmentalDataDisplay(
                label: 'Date',
                value:
                    '${_environmentalData.date.day}/${_environmentalData.date.month}/${_environmentalData.date.year}',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: EnvironmentalDataDisplay(
                label: 'Time',
                value:
                    '${_environmentalData.time.hour.toString().padLeft(2, '0')}:${_environmentalData.time.minute.toString().padLeft(2, '0')}',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLocationFields() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: EnvironmentalDataField(
                label: 'Latitude',
                value: _environmentalData.latitude.toStringAsFixed(4),
                onChanged: (v) {
                  final lat = double.tryParse(v);
                  if (lat != null) {
                    setState(() {
                      _environmentalData = _environmentalData.copyWith(
                        latitude: lat,
                      );
                    });
                  }
                },
                suffix: '°',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: EnvironmentalDataField(
                label: 'Longitude',
                value: _environmentalData.longitude.toStringAsFixed(4),
                onChanged: (v) {
                  final lon = double.tryParse(v);
                  if (lon != null) {
                    setState(() {
                      _environmentalData = _environmentalData.copyWith(
                        longitude: lon,
                      );
                    });
                  }
                },
                suffix: '°',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildWeatherFields() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: EnvironmentalDataField(
                label: 'Avg Temperature (7d)',
                value: _environmentalData.avgTemperatureLast7.toStringAsFixed(
                  1,
                ),
                onChanged: (v) {
                  final temp = double.tryParse(v);
                  if (temp != null) {
                    setState(() {
                      _environmentalData = _environmentalData.copyWith(
                        avgTemperatureLast7: temp,
                      );
                    });
                  }
                },
                suffix: '°C',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: EnvironmentalDataField(
                label: 'Avg Humidity (7d)',
                value: _environmentalData.avgHumidityLast7.toString(),
                onChanged: (v) {
                  final hum = int.tryParse(v);
                  if (hum != null) {
                    setState(() {
                      _environmentalData = _environmentalData.copyWith(
                        avgHumidityLast7: hum,
                      );
                    });
                  }
                },
                suffix: '%',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: EnvironmentalDataField(
                label: 'Total Rainfall (7d)',
                value: _environmentalData.totalRainfallLast7.toStringAsFixed(1),
                onChanged: (v) {
                  final rain = double.tryParse(v);
                  if (rain != null) {
                    setState(() {
                      _environmentalData = _environmentalData.copyWith(
                        totalRainfallLast7: rain,
                      );
                    });
                  }
                },
                suffix: 'mm',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: EnvironmentalDataField(
                label: 'Avg Wind Speed (7d)',
                value: _environmentalData.avgWindSpeedLast7.toStringAsFixed(1),
                onChanged: (v) {
                  final wind = double.tryParse(v);
                  if (wind != null) {
                    setState(() {
                      _environmentalData = _environmentalData.copyWith(
                        avgWindSpeedLast7: wind,
                      );
                    });
                  }
                },
                suffix: 'km/h',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSolarFields() {
    return Column(
      children: [
        EnvironmentalDataField(
          label: 'Avg Sunshine Hours (7d)',
          value: _environmentalData.avgSunshineHoursLast7.toStringAsFixed(1),
          onChanged: (v) {
            final sun = double.tryParse(v);
            if (sun != null) {
              setState(() {
                _environmentalData = _environmentalData.copyWith(
                  avgSunshineHoursLast7: sun,
                );
              });
            }
          },
          suffix: 'h',
        ),
      ],
    );
  }
}
