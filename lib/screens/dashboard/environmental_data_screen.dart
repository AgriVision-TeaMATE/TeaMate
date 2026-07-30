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

  const EnvironmentalDataScreen({
    super.key,
    required this.fieldId,
  });

  @override
  State<EnvironmentalDataScreen> createState() => _EnvironmentalDataScreenState();
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
    final Field? field = FieldManager()
        .fields
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
          icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Field info header
            if (field != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE8ECEF), width: 1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      field.name,
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      field.subtitle,
                      style: const TextStyle(
                        color: Color(0xFF6E7E8B),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Auto Fetch Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isFetching ? null : _autoFetchData,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.brandGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
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
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(Icons.refresh_rounded, size: 22),
                label: Text(
                  _isFetching ? 'Fetching...' : 'Auto Fetch',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ),
            ),

            // Progress Indicator (shown during fetch)
            if (_isFetching) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F8F9),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE8ECEF)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Auto Fetch Progress',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
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

            const SizedBox(height: 24),

            // Data Collection Section
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE8ECEF), width: 1),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryButton.withValues(alpha: 0.06),
                    blurRadius: 22,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const EnvironmentalDataCardHeader(
                    icon: Icons.calendar_today_outlined,
                    title: 'Date & Time',
                  ),
                  const SizedBox(height: 16),
                  _buildDateTimeFields(),
                  const SizedBox(height: 20),

                  const EnvironmentalDataCardHeader(
                    icon: Icons.gps_fixed_outlined,
                    title: 'Location Data',
                  ),
                  const SizedBox(height: 16),
                  _buildLocationFields(),
                  const SizedBox(height: 20),

                  const EnvironmentalDataCardHeader(
                    icon: Icons.thermostat_outlined,
                    title: '7-Day Weather Summary',
                  ),
                  const SizedBox(height: 16),
                  _buildWeatherFields(),
                  const SizedBox(height: 20),

                  const EnvironmentalDataCardHeader(
                    icon: Icons.wb_sunny_outlined,
                    title: 'Solar Data (7-Day)',
                  ),
                  const SizedBox(height: 16),
                  _buildSolarFields(),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Proceed Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _proceedToScan,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFB54848),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: const Icon(Icons.camera_alt_outlined, size: 22),
                label: const Text(
                  'Proceed to Disease Scan',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Info card
            ScanGuidelinesCard(),
          ],
        ),
      ),
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
                value: '${_environmentalData.date.day}/${_environmentalData.date.month}/${_environmentalData.date.year}',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: EnvironmentalDataDisplay(
                label: 'Time',
                value: '${_environmentalData.time.hour.toString().padLeft(2, '0')}:${_environmentalData.time.minute.toString().padLeft(2, '0')}',
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
                      _environmentalData = _environmentalData.copyWith(latitude: lat);
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
                      _environmentalData = _environmentalData.copyWith(longitude: lon);
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
                value: _environmentalData.avgTemperatureLast7.toStringAsFixed(1),
                onChanged: (v) {
                  final temp = double.tryParse(v);
                  if (temp != null) {
                    setState(() {
                      _environmentalData = _environmentalData.copyWith(avgTemperatureLast7: temp);
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
                      _environmentalData = _environmentalData.copyWith(avgHumidityLast7: hum);
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
                      _environmentalData = _environmentalData.copyWith(totalRainfallLast7: rain);
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
                      _environmentalData = _environmentalData.copyWith(avgWindSpeedLast7: wind);
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
                _environmentalData = _environmentalData.copyWith(avgSunshineHoursLast7: sun);
              });
            }
          },
          suffix: 'h',
        ),
      ],
    );
  }
}