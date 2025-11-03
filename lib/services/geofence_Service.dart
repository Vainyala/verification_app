// services/geofencing_service.dart
import 'dart:async';
import 'package:geolocator/geolocator.dart';
import '../models/geofence_model.dart';
import 'storage_service.dart';
import 'location_service.dart';

class GeofencingService {
  static StreamSubscription<Position>? _positionStream;
  static Map<String, bool> _geofenceStatus = {}; // Track current status for each geofence
  static bool _isMonitoring = false;
  static DateTime? _lastNotificationTime;
  static const Duration _notificationCooldown = Duration(minutes: 2); // Prevent spam notifications

  static bool get isMonitoring => _isMonitoring;

  /// Start monitoring geofences
  static Future<void> startMonitoring() async {
    if (_isMonitoring) return;

    final hasPermission = await LocationService.requestLocationPermission();
    if (!hasPermission) {
      throw Exception('Location permission not granted');
    }
    // Initialize geofence status
    final geofences = await StorageService.getGeofences();
    for (var geofence in geofences) {
      if (geofence.isActive) {
        _geofenceStatus[geofence.id] = false; // Initially outside
      }
    }

    _positionStream = LocationService.getPositionStream().listen(
      _onLocationUpdate,
      onError: (error) {
        print('Location stream error: $error');
      },
    );

    _isMonitoring = true;
    print('Geofencing monitoring started');
  }
  static Future<void> initialize() async {
    // Request permission or prepare service if needed
    await LocationService.requestLocationPermission();
    print('GeofencingService initialized');
  }
  /// Stop monitoring geofences
  static Future<void> stopMonitoring() async {
    _positionStream?.cancel();
    _positionStream = null;
    _isMonitoring = false;
    _geofenceStatus.clear();
    print('Geofencing monitoring stopped');
  }

  /// Handle location updates
  static Future<void> _onLocationUpdate(Position position) async {
    try {
      final geofences = await StorageService.getGeofences();
      final activeGeofences = geofences.where((g) => g.isActive).toList();

      for (var geofence in activeGeofences) {
        final isCurrentlyInside = LocationService.isWithinGeofence(position, geofence);
        final wasInside = _geofenceStatus[geofence.id] ?? false;

        // Check for geofence entry
        if (isCurrentlyInside && !wasInside) {
          await _handleGeofenceEntry(geofence, position);
          _geofenceStatus[geofence.id] = true;
        }
        // Check for geofence exit
        else if (!isCurrentlyInside && wasInside) {
          await _handleGeofenceExit(geofence, position);
          _geofenceStatus[geofence.id] = false;
        }
      }
    } catch (e) {
      print('Error in location update handler: $e');
    }
  }

  /// Handle geofence entry
  static Future<void> _handleGeofenceEntry(GeofenceModel geofence, Position position) async {
    try {
      print('Geofence entered: ${geofence.name}');
    } catch (e) {
      print('Error handling geofence entry: $e');
    }
  }

  /// Handle geofence exit
  static Future<void> _handleGeofenceExit(GeofenceModel geofence, Position position) async {
    try {
      print('Geofence exited: ${geofence.name}');
    } catch (e) {
      print('Error handling geofence exit: $e');
    }
  }

  /// Check if notification should be shown (cooldown mechanism)
  static bool _shouldShowNotification() {
    if (_lastNotificationTime == null) return true;

    final timeSinceLastNotification = DateTime.now().difference(_lastNotificationTime!);
    return timeSinceLastNotification >= _notificationCooldown;
  }

  /// Add a new geofence
  static Future<void> addGeofence(GeofenceModel geofence) async {
    await StorageService.addGeofence(geofence);

    // If monitoring is active and geofence is active, add to status tracking
    if (_isMonitoring && geofence.isActive) {
      _geofenceStatus[geofence.id] = false;

      // Check if user is currently inside the new geofence
      final position = await LocationService.getCurrentPosition();
      if (position != null) {
        final isInside = LocationService.isWithinGeofence(position, geofence);
        _geofenceStatus[geofence.id] = isInside;

        if (isInside) {
          await _handleGeofenceEntry(geofence, position);
        }
      }
    }
  }

  /// Update an existing geofence
  static Future<void> updateGeofence(GeofenceModel geofence) async {
    await StorageService.updateGeofence(geofence);

    if (_isMonitoring) {
      if (geofence.isActive) {
        // If geofence was activated, start tracking it
        if (!_geofenceStatus.containsKey(geofence.id)) {
          _geofenceStatus[geofence.id] = false;
        }
      } else {
        // If geofence was deactivated, stop tracking it
        _geofenceStatus.remove(geofence.id);
      }
    }
  }

  /// Remove a geofence
  static Future<void> removeGeofence(String geofenceId) async {
    await StorageService.removeGeofence(geofenceId);
    _geofenceStatus.remove(geofenceId);
  }

  /// Get current geofence status
  static Future<Map<String, dynamic>> getCurrentStatus() async {
    final position = await LocationService.getCurrentPosition();
    if (position == null) {
      return {
        'position': null,
        'insideGeofences': [],
        'outsideGeofences': [],
        'isMonitoring': _isMonitoring,
      };
    }

    final geofences = await StorageService.getGeofences();
    final activeGeofences = geofences.where((g) => g.isActive).toList();

    final insideGeofences = <GeofenceModel>[];
    final outsideGeofences = <GeofenceModel>[];

    for (var geofence in activeGeofences) {
      if (LocationService.isWithinGeofence(position, geofence)) {
        insideGeofences.add(geofence);
      } else {
        outsideGeofences.add(geofence);
      }
    }

    return {
      'position': {
        'latitude': position.latitude,
        'longitude': position.longitude,
        'accuracy': position.accuracy,
        'timestamp': position.timestamp,
      },
      'insideGeofences': insideGeofences,
      'outsideGeofences': outsideGeofences,
      'isMonitoring': _isMonitoring,
    };
  }

  /// Restart monitoring (useful after app resume)
  static Future<void> restartMonitoring() async {
    if (_isMonitoring) {
      await stopMonitoring();
    }
    await startMonitoring();
  }

  /// Check if user is currently inside any geofence
  static Future<bool> isInsideAnyGeofence() async {
    final status = await getCurrentStatus();
    final insideGeofences = status['insideGeofences'] as List<GeofenceModel>;
    return insideGeofences.isNotEmpty;
  }

  /// Get the name of the geofence user is currently inside (if any)
  static Future<String?> getCurrentGeofenceName() async {
    final status = await getCurrentStatus();
    final insideGeofences = status['insideGeofences'] as List<GeofenceModel>;
    return insideGeofences.isNotEmpty ? insideGeofences.first.name : null;
  }

  /// Force check all geofences (useful for manual refresh)
  static Future<void> forceCheck() async {
    final position = await LocationService.getCurrentPosition();
    if (position != null) {
      await _onLocationUpdate(position);
    }
  }
}