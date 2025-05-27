// lib/screens/profile_screen.dart - User profile screen
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:trip_tank_fuely/authProvider.dart';
import 'package:trip_tank_fuely/vehcleProvider.dart';
import 'package:trip_tank_fuely/vehicleModel.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:trip_tank_fuely/themeProvider.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // Add state variable to track vehicle updates
  String? _currentVehicleId;
  VehicleModel? _currentCustomVehicle;

  @override
  void initState() {
    super.initState();
    _loadCurrentVehicle();
  }

  Future<void> _loadCurrentVehicle() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.user != null) {
      setState(() {
        _currentVehicleId = authProvider.user!.vehicleId;
        _currentCustomVehicle = authProvider.user!.customVehicle;
      });
    }
  }

  Future<VehicleModel?> _loadVehicleDetails(BuildContext context, String vehicleId) async {
    final vehicleProvider = Provider.of<VehicleProvider>(context, listen: false);
    
    try {
      // Check if this is a CSV vehicle (has the csv- prefix)
      if (vehicleId.startsWith('csv-')) {
        // Try to get the vehicle data from local storage first
        final prefs = await SharedPreferences.getInstance();
        final savedVehicleData = prefs.getString('selected_vehicle_data');
        
        if (savedVehicleData != null) {
          try {
            final Map<String, dynamic> vehicleMap = jsonDecode(savedVehicleData);
            final String extractedId = vehicleMap['id'] ?? vehicleId;
            return VehicleModel.fromMap(vehicleMap, extractedId);
          } catch (e) {
            print('Error parsing saved vehicle data: $e');
          }
        }
        
        // If not in local storage, try loading from CSV
        final allCsvVehicles = await vehicleProvider.loadVehiclesFromCsv();
        final originalId = vehicleId.substring(4);
        return allCsvVehicles.firstWhere(
          (v) => v.id == originalId,
          orElse: () => VehicleModel(
            brand: 'Unknown',
            model: 'Unknown',
            weight: 0,
            tankCapacity: 0,
            engineCapacity: 0,
            cylinders: 0,
            aerodynamics: 0,
            fuelType: 'Unknown',
          ),
        );
      }
      
      return await vehicleProvider.getVehicleById(vehicleId);
    } catch (e) {
      print('Error loading vehicle details: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user;
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
      ),
      body: user == null
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // User info
                    Center(
                      child: Column(
                        children: [
                          CircleAvatar(
                            radius: 50,
                            backgroundColor: Theme.of(context).colorScheme.primary,
                            child: Icon(
                              Icons.person,
                              size: 50,
                              color: Theme.of(context).colorScheme.onPrimary,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            user.name,
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          Text(
                            user.email,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Driving style
                    Text(
                      'Driving Style',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Slider(
                      value: user.drivingStyle.toDouble(),
                      min: 1,
                      max: 5,
                      divisions: 4,
                      label: _getDrivingStyleLabel(user.drivingStyle),
                      onChanged: (value) {
                        authProvider.updateDrivingStyle(value.round());
                      },
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Economic',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        Text(
                          'Aggressive',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),

                    // Theme Settings
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Appearance',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Icon(
                                  themeProvider.isDarkMode ? Icons.dark_mode : Icons.light_mode,
                                  color: themeProvider.isDarkMode ? Colors.amber : Colors.orange,
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Dark Mode',
                                        style: Theme.of(context).textTheme.titleMedium,
                                      ),
                                      Text(
                                        themeProvider.isDarkMode 
                                            ? 'Switch to light theme' 
                                            : 'Switch to dark theme',
                                        style: Theme.of(context).textTheme.bodyMedium,
                                      ),
                                    ],
                                  ),
                                ),
                                Switch(
                                  value: themeProvider.isDarkMode,
                                  onChanged: (value) {
                                    themeProvider.toggleTheme();
                                  },
                                  activeColor: Theme.of(context).colorScheme.primary,
                                  activeTrackColor: Theme.of(context).colorScheme.primary.withOpacity(0.5),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Vehicle info
                    Text(
                      'Current Vehicle',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    if (_currentCustomVehicle != null)
                      Column(
                        children: [
                          _buildVehicleInfo(_currentCustomVehicle!),
                          const SizedBox(height: 8),
                          ElevatedButton.icon(
                            onPressed: () => _deleteCustomVehicle(),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(context).colorScheme.error,
                              foregroundColor: Theme.of(context).colorScheme.onError,
                            ),
                            icon: const Icon(Icons.delete),
                            label: const Text('Delete Custom Vehicle'),
                          ),
                        ],
                      )
                    else if (_currentVehicleId?.isNotEmpty ?? false)
                      FutureBuilder<VehicleModel?>(
                        future: _loadVehicleDetails(context, _currentVehicleId!),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator());
                          } else if (snapshot.hasError) {
                            return Text('Error loading vehicle: ${snapshot.error}');
                          } else if (snapshot.hasData && snapshot.data != null) {
                            return _buildVehicleInfo(snapshot.data!);
                          } else {
                            return Text(
                              'Vehicle information not available. Try selecting a vehicle again.',
                              style: Theme.of(context).textTheme.bodyMedium,
                            );
                          }
                        },
                      )
                    else
                      Text(
                        'No vehicle selected. Tap the Vehicle icon to select one.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),

                    const SizedBox(height: 32),

                    // Saved Vehicles Section
                    Text(
                      'Saved Cars',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    FutureBuilder<List<VehicleModel>>(
                      future: _loadSavedVehicles(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        } else if (snapshot.hasError) {
                          return Text(
                            'Error loading saved vehicles: ${snapshot.error}',
                            style: Theme.of(context).textTheme.bodyMedium,
                          );
                        } else if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                          return ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: snapshot.data!.length,
                            itemBuilder: (context, index) {
                              final vehicle = snapshot.data![index];
                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                child: ListTile(
                                  leading: Icon(
                                    Icons.directions_car,
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                                  title: Text(
                                    '${vehicle.brand} ${vehicle.model}',
                                    style: Theme.of(context).textTheme.titleMedium,
                                  ),
                                  subtitle: Text(
                                    '${vehicle.fuelType} - ${vehicle.engineCapacity}L',
                                    style: Theme.of(context).textTheme.bodyMedium,
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: Icon(
                                          Icons.delete,
                                          color: Theme.of(context).colorScheme.error,
                                        ),
                                        onPressed: () => _removeSavedVehicle(vehicle.id),
                                      ),
                                      IconButton(
                                        icon: Icon(
                                          Icons.check_circle_outline,
                                          color: Theme.of(context).colorScheme.primary,
                                        ),
                                        onPressed: () => _selectSavedVehicle(vehicle),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          );
                        } else {
                          return Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Text(
                                'No saved vehicles yet. Select a vehicle to save it here.',
                                style: Theme.of(context).textTheme.bodyMedium,
                                textAlign: TextAlign.center,
                              ),
                            ),
                          );
                        }
                      },
                    ),

                    const SizedBox(height: 32),

                    // Sign out button
                    ElevatedButton(
                      onPressed: () async {
                        await authProvider.signOut();
                        if (mounted) {
                          Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                        backgroundColor: Theme.of(context).colorScheme.error,
                        foregroundColor: Theme.of(context).colorScheme.onError,
                      ),
                      child: const Text('Sign Out'),
                    ),
                    const SizedBox(height: 16), // Add bottom padding
                  ],
                ),
              ),
            ),
    );
  }

  String _getDrivingStyleLabel(int style) {
    switch (style) {
      case 1:
        return 'Very Economic';
      case 2:
        return 'Economic';
      case 3:
        return 'Normal';
      case 4:
        return 'Sporty';
      case 5:
        return 'Aggressive';
      default:
        return 'Normal';
    }
  }

  Widget _buildVehicleInfo(VehicleModel vehicle) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${vehicle.brand} ${vehicle.model}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Weight: ${vehicle.weight} kg',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            Text(
              'Engine: ${vehicle.engineCapacity}L, ${vehicle.cylinders} cylinders',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            Text(
              'Fuel: ${vehicle.fuelType}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            Text(
              'Tank: ${vehicle.tankCapacity} L',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            Text(
              'Aerodynamics: ${vehicle.aerodynamics}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  Future<List<VehicleModel>> _loadSavedVehicles() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedVehiclesJson = prefs.getStringList('saved_vehicles') ?? [];
      final vehicles = <VehicleModel>[];

      // First, add custom vehicle if it exists
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (authProvider.user?.customVehicle != null) {
        final customVehicle = authProvider.user!.customVehicle!;
        vehicles.add(customVehicle);
      }

      // Then add other saved vehicles
      for (final vehicleJson in savedVehiclesJson) {
        try {
          final Map<String, dynamic> vehicleMap = jsonDecode(vehicleJson);
          final String id = vehicleMap['id'] as String;
          // Skip if this is the current custom vehicle (we already added it)
          if (id == 'custom-${authProvider.user?.email}') continue;
          vehicles.add(VehicleModel.fromMap(vehicleMap, id));
        } catch (e) {
          print('Error parsing saved vehicle: $e');
        }
      }

      return vehicles;
    } catch (e) {
      print('Error loading saved vehicles: $e');
      return [];
    }
  }

  Future<void> _removeSavedVehicle(String vehicleId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedVehiclesJson = prefs.getStringList('saved_vehicles') ?? [];
      
      final updatedVehicles = savedVehiclesJson.where((vehicleJson) {
        final Map<String, dynamic> vehicleMap = jsonDecode(vehicleJson);
        return vehicleMap['id'] != vehicleId;
      }).toList();

      await prefs.setStringList('saved_vehicles', updatedVehicles);
      setState(() {});
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vehicle removed from saved list')),
        );
      }
    } catch (e) {
      print('Error removing saved vehicle: $e');
    }
  }

  Future<void> _selectSavedVehicle(VehicleModel vehicle) async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      
      if (vehicle.id.startsWith('custom-')) {
        final updatedUser = authProvider.user!.copyWith(
          customVehicle: vehicle,
          vehicleId: '', // Clear selected vehicle ID when using custom
        );
        await authProvider.saveCustomVehicle(updatedUser);
        setState(() {
          _currentCustomVehicle = vehicle;
          _currentVehicleId = '';
        });
      } else {
        final vehicleId = vehicle.id.startsWith('csv-') ? vehicle.id : 'csv-${vehicle.id}';
        await authProvider.updateUserVehicle(vehicleId);
        setState(() {
          _currentVehicleId = vehicleId;
          _currentCustomVehicle = null;
        });
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${vehicle.brand} ${vehicle.model} selected as current vehicle'),
            action: SnackBarAction(
              label: 'OK',
              onPressed: () {},
            ),
          ),
        );
      }
    } catch (e) {
      print('Error selecting saved vehicle: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error selecting vehicle')),
        );
      }
    }
  }

  Future<void> _deleteCustomVehicle() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (authProvider.user != null) {
        final updatedUser = authProvider.user!.copyWith(
          customVehicle: null,
          vehicleId: '', // Clear selected vehicle ID
        );

        await authProvider.saveCustomVehicle(updatedUser);
        
        // Also remove from saved vehicles if it exists
        final prefs = await SharedPreferences.getInstance();
        final savedVehiclesJson = prefs.getStringList('saved_vehicles') ?? [];
        
        final updatedVehicles = savedVehiclesJson.where((vehicleJson) {
          final Map<String, dynamic> vehicleMap = jsonDecode(vehicleJson);
          return vehicleMap['id'] != 'custom-${authProvider.user!.email}';
        }).toList();

        await prefs.setStringList('saved_vehicles', updatedVehicles);
        
        setState(() {
          _currentCustomVehicle = null;
          _currentVehicleId = '';
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Custom vehicle deleted'),
              action: SnackBarAction(
                label: 'OK',
                onPressed: () {},
              ),
            ),
          );
        }
      }
    } catch (e) {
      print('Error deleting custom vehicle: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error deleting custom vehicle'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}