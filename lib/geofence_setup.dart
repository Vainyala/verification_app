
// Complete geofence_setup_screen.dart
import 'package:flutter/material.dart';
import 'package:id_verification_app/services/geofence_Service.dart';
import 'package:id_verification_app/services/storage_service.dart';
import '../models/geofence_model.dart';
import '../services/location_service.dart';

class GeofenceSetupScreen extends StatefulWidget {
  const GeofenceSetupScreen({super.key});

  @override
  State<GeofenceSetupScreen> createState() => _GeofenceSetupScreenState();
}

class _GeofenceSetupScreenState extends State<GeofenceSetupScreen> {
  List<GeofenceModel> _geofences = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadGeofences();
  }

  Future<void> _loadGeofences() async {
    setState(() => _isLoading = true);
    final geofences = await StorageService.getGeofences();
    setState(() {
      _geofences = geofences;
      _isLoading = false;
    });
  }

  void _showAddGeofenceDialog() {
    showDialog(
      context: context,
      builder: (context) => AddGeofenceDialog(
        onGeofenceAdded: (geofence) async {
          await GeofencingService.addGeofence(geofence);
          await _loadGeofences();
        },
      ),
    );
  }

  Future<void> _deleteGeofence(GeofenceModel geofence) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Geofence'),
        content: Text('Are you sure you want to delete "${geofence.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await GeofencingService.removeGeofence(geofence.id);
      await _loadGeofences();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Geofence "${geofence.name}" deleted'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Geofence Setup'),
        backgroundColor: const Color(0xFF4A5AE8),
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddGeofenceDialog,
        backgroundColor: const Color(0xFF4A5AE8),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _geofences.isEmpty
          ? const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.location_off,
              size: 80,
              color: Colors.grey,
            ),
            SizedBox(height: 20),
            Text(
              'No Geofences Setup',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
            SizedBox(height: 10),
            Text(
              'Tap the + button to add your first geofence',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      )
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _geofences.length,
        itemBuilder: (context, index) {
          final geofence = _geofences[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              leading: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: geofence.isActive ? Colors.green : Colors.grey,
                  borderRadius: BorderRadius.circular(25),
                ),
                child: Icon(
                  _getGeofenceIcon(geofence.type),
                  color: Colors.white,
                  size: 25,
                ),
              ),
              title: Text(
                geofence.name,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Type: ${geofence.type.toString().split('.').last.toUpperCase()}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  Text(
                    'Radius: ${geofence.radius.toInt()}m',
                    style: const TextStyle(fontSize: 12),
                  ),
                  Text(
                    'Status: ${geofence.isActive ? "Active" : "Inactive"}',
                    style: TextStyle(
                      fontSize: 12,
                      color: geofence.isActive ? Colors.green : Colors.red,
                    ),
                  ),
                ],
              ),
              trailing: PopupMenuButton<String>(
                onSelected: (value) async {
                  if (value == 'toggle') {
                    final updatedGeofence = GeofenceModel(
                      id: geofence.id,
                      name: geofence.name,
                      latitude: geofence.latitude,
                      longitude: geofence.longitude,
                      radius: geofence.radius,
                      type: geofence.type,
                      isActive: !geofence.isActive,
                    );
                    await GeofencingService.updateGeofence(updatedGeofence);
                    await _loadGeofences();
                  } else if (value == 'delete') {
                    await _deleteGeofence(geofence);
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'toggle',
                    child: Row(
                      children: [
                        Icon(geofence.isActive ? Icons.pause : Icons.play_arrow),
                        const SizedBox(width: 8),
                        Text(geofence.isActive ? 'Deactivate' : 'Activate'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Delete', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  IconData _getGeofenceIcon(GeofenceType type) {
    switch (type) {
      case GeofenceType.office:
        return Icons.business;
      case GeofenceType.home:
        return Icons.home;
      case GeofenceType.client:
        return Icons.person;
    }
  }
}

class AddGeofenceDialog extends StatefulWidget {
  final Function(GeofenceModel) onGeofenceAdded;

  const AddGeofenceDialog({super.key, required this.onGeofenceAdded});

  @override
  State<AddGeofenceDialog> createState() => _AddGeofenceDialogState();
}

class _AddGeofenceDialogState extends State<AddGeofenceDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _radiusController = TextEditingController(text: '100');
  GeofenceType _selectedType = GeofenceType.office;
  bool _useCurrentLocation = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _radiusController.dispose();
    super.dispose();
  }

  Future<void> _addGeofence() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      try {
        double latitude = 0.0, longitude = 0.0;

        if (_useCurrentLocation) {
          final position = await LocationService.getCurrentPosition();
          if (position != null) {
            latitude = position.latitude;
            longitude = position.longitude;
          } else {
            throw Exception('Unable to get current location');
          }
        }

        final geofence = GeofenceModel(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          name: _nameController.text.trim(),
          latitude: latitude,
          longitude: longitude,
          radius: double.parse(_radiusController.text),
          type: _selectedType,
          isActive: true,
        );

        widget.onGeofenceAdded(geofence);
        Navigator.pop(context);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Geofence "${geofence.name}" added successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding geofence: $e'),
            backgroundColor: Colors.red,
          ),
        );
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add New Geofence'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Geofence Name',
                  prefixIcon: Icon(Icons.label),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<GeofenceType>(
                value: _selectedType,
                decoration: const InputDecoration(
                  labelText: 'Type',
                  prefixIcon: Icon(Icons.category),
                ),
                items: GeofenceType.values.map((type) {
                  return DropdownMenuItem(
                    value: type,
                    child: Text(type.toString().split('.').last.toUpperCase()),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() => _selectedType = value!);
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _radiusController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Radius (meters)',
                  prefixIcon: Icon(Icons.radio_button_unchecked),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter radius';
                  }
                  final radius = double.tryParse(value);
                  if (radius == null || radius <= 0 || radius > 1000) {
                    return 'Please enter valid radius (1-1000m)';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('Use Current Location'),
                subtitle: const Text('Use your current GPS location'),
                value: _useCurrentLocation,
                onChanged: (value) {
                  setState(() => _useCurrentLocation = value);
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _addGeofence,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF4A5AE8),
            foregroundColor: Colors.white,
          ),
          child: _isLoading
              ? const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white,
            ),
          )
              : const Text('Add'),
        ),
      ],
    );
  }
}