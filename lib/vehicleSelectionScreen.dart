// lib/screens/vehicle_selection_screen.dart - Vehicle selection screen
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:trip_tank_fuely/authProvider.dart';
import 'package:trip_tank_fuely/vehcleProvider.dart';
import 'package:trip_tank_fuely/vehicleModel.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:trip_tank_fuely/profileScreen.dart';

class VehicleSelectionScreen extends StatefulWidget {
    const VehicleSelectionScreen({super.key});

    @override
    _VehicleSelectionScreenState createState() => _VehicleSelectionScreenState();
}

class _VehicleSelectionScreenState extends State<VehicleSelectionScreen> {
    String? _selectedBrand;
    VehicleModel? _selectedModel;
    bool _useCustomVehicle = false;

    // Controllers for custom vehicle
    final _brandController = TextEditingController();
    final _modelController = TextEditingController();
    final _weightController = TextEditingController();
    final _tankCapacityController = TextEditingController();
    final _engineCapacityController = TextEditingController();
    final _cylindersController = TextEditingController();
    final _aerodynamicsController = TextEditingController();
    String _fuelType = 'Gasoline';

    final _formKey = GlobalKey<FormState>();

    @override
    void initState() {
        super.initState();
        _loadBrands();
    }

    @override
    void dispose() {
        _brandController.dispose();
        _modelController.dispose();
        _weightController.dispose();
        _tankCapacityController.dispose();
        _engineCapacityController.dispose();
        _cylindersController.dispose();
        _aerodynamicsController.dispose();
        super.dispose();
    }

    Future<void> _loadBrands() async {
        await Provider.of<VehicleProvider>(context, listen: false).loadBrands();
    }

    Future<void> _saveVehicle() async {
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        final vehicleProvider = Provider.of<VehicleProvider>(context, listen: false);

        if (_useCustomVehicle) {
            if (_formKey.currentState?.validate() ?? false) {
                // Create custom vehicle
                final customVehicle = VehicleModel(
                    brand: _brandController.text,
                    model: _modelController.text,
                    weight: double.parse(_weightController.text),
                    tankCapacity: double.parse(_tankCapacityController.text),
                    engineCapacity: double.parse(_engineCapacityController.text),
                    cylinders: int.parse(_cylindersController.text),
                    aerodynamics: double.parse(_aerodynamicsController.text),
                    fuelType: _fuelType,
                );

                // Save to user profile
                if (authProvider.user != null) {
                    final updatedUser = authProvider.user!.copyWith(
                        customVehicle: customVehicle,
                        vehicleId: '', // Clear selected vehicle ID when using custom
                    );

                    await authProvider.saveCustomVehicle(updatedUser);

                    // Save to saved vehicles list
                    final prefs = await SharedPreferences.getInstance();
                    final savedVehicles = prefs.getStringList('saved_vehicles') ?? [];
                    
                    // Create a unique ID for the custom vehicle
                    final customVehicleId = 'custom-${authProvider.user!.email}';
                    final customVehicleMap = customVehicle.toMap();
                    customVehicleMap['id'] = customVehicleId;
                    
                    // Check if vehicle is already saved
                    if (!savedVehicles.any((v) {
                        final Map<String, dynamic> vehicleMap = jsonDecode(v);
                        return vehicleMap['id'] == customVehicleId;
                    })) {
                        savedVehicles.add(jsonEncode(customVehicleMap));
                        await prefs.setStringList('saved_vehicles', savedVehicles);
                    }

                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Custom vehicle saved')),
                    );

                    Navigator.of(context).pop();
                }
            }
        } else {
            // Save selected vehicle ID
            if (_selectedModel != null) {
                // Add a prefix to the vehicle ID to indicate its source
                String vehicleId = _selectedModel!.id;
                if (!vehicleProvider.useFirebase) {
                    // For CSV vehicles, add a prefix to identify them
                    vehicleId = 'csv-${_selectedModel!.id}';
                }
                
                // Save the vehicle ID to both Firebase and local storage
                await authProvider.updateUserVehicle(vehicleId);
                
                // Save the full vehicle data to local storage for offline access
                if (!vehicleProvider.useFirebase) {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setString('selected_vehicle_data', jsonEncode(_selectedModel!.toMap()));
                    
                    // Add to saved vehicles list
                    final savedVehicles = prefs.getStringList('saved_vehicles') ?? [];
                    // Check if vehicle is already saved
                    if (!savedVehicles.any((v) {
                        final Map<String, dynamic> vehicleMap = jsonDecode(v);
                        return vehicleMap['id'] == vehicleId;
                    })) {
                        savedVehicles.add(jsonEncode(_selectedModel!.toMap()));
                        await prefs.setStringList('saved_vehicles', savedVehicles);
                    }
                }

                final dataSource = vehicleProvider.useFirebase ? 'Firebase' : 'CSV';
                ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text('${_selectedModel!.brand} ${_selectedModel!.model} selected from $dataSource'),
                        action: SnackBarAction(
                            label: 'VIEW',
                            onPressed: () {
                                Navigator.of(context).pop();
                                // Use direct navigation instead of named route
                                Navigator.of(context).push(
                                    MaterialPageRoute(builder: (_) => const ProfileScreen()),
                                );
                            },
                        ),
                    ),
                );

                Navigator.of(context).pop();
            } else {
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please select a vehicle')),
                );
            }
        }
    }

    @override
    Widget build(BuildContext context) {
        final vehicleProvider = Provider.of<VehicleProvider>(context);

        return Scaffold(
            appBar: AppBar(
                    title: const Text('Select Vehicle'),
                    actions: [
                        // Data source info button
                        IconButton(
                            icon: const Icon(Icons.info_outline),
                            onPressed: () {
                                showDialog(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                        title: const Text('Data Source'),
                                        content: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                                Text(
                                                    'Currently using: ${vehicleProvider.useFirebase ? 'Firebase Database' : 'Local CSV File'}',
                                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                                ),
                                                const SizedBox(height: 10),
                                                const Text(
                                                    'Toggle between data sources using the switch in the top-right corner of the screen.',
                                                ),
                                            ],
                                        ),
                                        actions: [
                                            TextButton(
                                                onPressed: () => Navigator.pop(context),
                                                child: const Text('OK'),
                                            ),
                                        ],
                                    ),
                                );
                            },
                        ),
                    ],
        ),
        body: vehicleProvider.isLoading
        ? const Center(child: CircularProgressIndicator())
        : Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
        children: [
        // Data source toggle
        SwitchListTile(
            title: Text('Use ${vehicleProvider.useFirebase ? 'Database' : 'Database'}'),
            //subtitle: Text(vehicleProvider.useFirebase ? 'use database' : 'Using vehicles database'),
            value: !vehicleProvider.useFirebase,
            onChanged: (value) {
                vehicleProvider.toggleDataSource(!value);
                setState(() {
                    // Reset selections when data source changes
                    _selectedBrand = null;
                    _selectedModel = null;
                });
            },

        ),
        
        // Custom vehicle toggle
        SwitchListTile(
            title: const Text('Use custom vehicle'),
            value: _useCustomVehicle,
            onChanged: (value) {
            setState(() {
                _useCustomVehicle = value;
            });
        },
        ),

        const SizedBox(height: 16),

        Expanded(
            child: _useCustomVehicle
            ? _buildCustomVehicleForm()
        : _buildVehicleSelection(vehicleProvider),
        ),

        const SizedBox(height: 16),

        ElevatedButton(
            onPressed: _saveVehicle,
            style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
        ),
        child: const Text('Save'),
        ),
        ],
        ),
        ),
        );
    }

    Widget _buildVehicleSelection(VehicleProvider vehicleProvider) {
        return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            // Data source indicator
            Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                    color: Colors.blue.withAlpha(25),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.withAlpha(76)),
                ),
                child: Row(
                    children: [
                        const Icon(Icons.info_outline, size: 16, color: Colors.blue),
                        const SizedBox(width: 8),
                        Expanded(
                            child: Text(
                                'Using ${vehicleProvider.useFirebase ? 'Firebase' : 'CSV'} data - ${vehicleProvider.brands.length} brands available',
                                style: const TextStyle(fontSize: 12, color: Colors.blue),
                            ),
                        ),
                    ],
                ),
            ),
            
            // Brand dropdown
            DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                    labelText: 'Brand',
                border: OutlineInputBorder(),
            ),
            value: _selectedBrand,
            items: vehicleProvider.brands.map((brand) {
            return DropdownMenuItem(
                value: brand,
                child: Text(brand),
            );
        }).toList(),
            onChanged: (value) {
            setState(() {
                _selectedBrand = value;
                _selectedModel = null;
            });
            if (value != null) {
                vehicleProvider.loadModelsByBrand(value);
            }
        },
            hint: const Text('Select brand'),
            ),

            const SizedBox(height: 16),

            // Model dropdown
            DropdownButtonFormField<VehicleModel>(
                decoration: const InputDecoration(
                    labelText: 'Model',
                border: OutlineInputBorder(),
            ),
            value: _selectedModel,
            items: vehicleProvider.models.map((model) {
            return DropdownMenuItem(
                value: model,
                child: Text(model.model),
            );
        }).toList(),
            onChanged: (value) {
            setState(() {
                _selectedModel = value;
            });
        },
            hint: const Text('Select model'),
            ),

            const SizedBox(height: 24),

            // Vehicle details
            if (_selectedModel != null) ...[
            const Text(
                    'Vehicle Details:',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Card(
                elevation: 2,
                child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                            _buildDetailRow('Brand', _selectedModel!.brand),
                            _buildDetailRow('Model', _selectedModel!.model),
                            _buildDetailRow('Weight', '${_selectedModel!.weight.toStringAsFixed(1)} kg'),
                            _buildDetailRow('Tank Capacity', '${_selectedModel!.tankCapacity.toStringAsFixed(1)} L'),
                            _buildDetailRow('Engine Capacity', '${_selectedModel!.engineCapacity.toStringAsFixed(2)} L'),
                            _buildDetailRow('Cylinders', '${_selectedModel!.cylinders}'),
                            _buildDetailRow('Aerodynamics', _selectedModel!.aerodynamics.toStringAsFixed(3)),
                            _buildDetailRow('Fuel Type', _selectedModel!.fuelType),
                            const SizedBox(height: 8),
                            // Fuel efficiency visualization
                            Row(
                                children: [
                                    const Expanded(
                                        flex: 2,
                                        child: Text(
                                            'Estimated Efficiency:',
                                            style: TextStyle(fontWeight: FontWeight.bold),
                                        ),
                                    ),
                                    Expanded(
                                        flex: 3,
                                        child: _buildEfficiencyIndicator(_selectedModel!),
                                    ),
                                ],
                            ),
                        ],
                    ),
                ),
            ),
            ],
            ],
        );
    }

    Widget _buildCustomVehicleForm() {
        return Form(
            key: _formKey,
            child: ListView(
                    children: [
            TextFormField(
                controller: _brandController,
                decoration: const InputDecoration(
                    labelText: 'Brand',
                border: OutlineInputBorder(),
            ),
            validator: (value) {
        if (value == null || value.isEmpty) {
            return 'Please enter brand';
        }
        return null;
    },
        ),
        const SizedBox(height: 16),
        TextFormField(
            controller: _modelController,
            decoration: const InputDecoration(
                labelText: 'Model',
            border: OutlineInputBorder(),
        ),
        validator: (value) {
        if (value == null || value.isEmpty) {
            return 'Please enter model';
        }
        return null;
    },
        ),
        const SizedBox(height: 16),
        TextFormField(
            controller: _weightController,
            keyboardType: TextInputType.number,
        decoration: const InputDecoration(
        labelText: 'Weight (kg)',
        border: OutlineInputBorder(),
        ),
        validator: (value) {
        if (value == null || value.isEmpty) {
            return 'Please enter weight';
        }
        if (double.tryParse(value) == null) {
            return 'Please enter a valid number';
        }
        return null;
    },
        ),
        const SizedBox(height: 16),
        TextFormField(
            controller: _tankCapacityController,
            keyboardType: TextInputType.number,
        decoration: const InputDecoration(
        labelText: 'Tank Capacity (L)',
        border: OutlineInputBorder(),
        ),
        validator: (value) {
        if (value == null || value.isEmpty) {
            return 'Please enter tank capacity';
        }
        if (double.tryParse(value) == null) {
            return 'Please enter a valid number';
        }
        return null;
    },
        ),
        const SizedBox(height: 16),
        TextFormField(
            controller: _engineCapacityController,
            keyboardType: TextInputType.number,
        decoration: const InputDecoration(
        labelText: 'Engine Capacity (L)',
        border: OutlineInputBorder(),
        ),
        validator: (value) {
        if (value == null || value.isEmpty) {
            return 'Please enter engine capacity';
        }
        if (double.tryParse(value) == null) {
            return 'Please enter a valid number';
        }
        return null;
    },
        ),
        const SizedBox(height: 16),
        TextFormField(
            controller: _cylindersController,
            keyboardType: TextInputType.number,
        decoration: const InputDecoration(
        labelText: 'Cylinders',
        border: OutlineInputBorder(),
        ),
        validator: (value) {
        if (value == null || value.isEmpty) {
            return 'Please enter cylinders';
        }
        if (int.tryParse(value) == null) {
            return 'Please enter a valid number';
        }
        return null;
    },
        ),
        const SizedBox(height: 16),
        TextFormField(
            controller: _aerodynamicsController,
            keyboardType: TextInputType.number,
        decoration: const InputDecoration(
        labelText: 'Aerodynamics',
        border: OutlineInputBorder(),
        ),
        validator: (value) {
        if (value == null || value.isEmpty) {
            return 'Please enter aerodynamics';
        }
        if (double.tryParse(value) == null) {
            return 'Please enter a valid number';
        }
        return null;
    },
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
            decoration: const InputDecoration(
                labelText: 'Fuel Type',
            border: OutlineInputBorder(),
        ),
        value: _fuelType,
        items: const [
        DropdownMenuItem(value: 'Gasoline', child: Text('Gasoline')),
        DropdownMenuItem(value: 'Diesel', child: Text('Diesel')),
        DropdownMenuItem(value: 'Electric', child: Text('Electric')),
        ],
        onChanged: (value) {
        setState(() {
            _fuelType = value ?? 'Gasoline';
        });
    },
        ),
        ],
        ),
        );
    }

    Widget _buildDetailRow(String label, String value) {
        return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
        children: [
        Expanded(
            flex: 2,
        child: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        ),
        Expanded(
            flex: 3,
        child: Text(value),
        ),
        ],
        ),
        );
    }

    Widget _buildEfficiencyIndicator(VehicleModel vehicle) {
        // Calculate a simple efficiency score based on model attributes
        double efficiencyScore = 0.0;
        
        // Lower weight, better efficiency
        double weightFactor = (2000 - vehicle.weight) / 1000;
        
        // Smaller engine, better efficiency (for ICE vehicles)
        double engineFactor = 0.0;
        if (vehicle.fuelType == 'Electric') {
            engineFactor = 1.0; // Electric vehicles are most efficient
        } else {
            engineFactor = (3.0 - vehicle.engineCapacity) / 3.0;
        }
        
        // Better aerodynamics, better efficiency
        double aeroFactor = (0.4 - vehicle.aerodynamics) / 0.2;
        
        // Fuel type factor
        double fuelFactor = 0.0;
        if (vehicle.fuelType == 'Electric') {
            fuelFactor = 1.0;
        } else if (vehicle.fuelType == 'Diesel') {
            fuelFactor = 0.7;
        } else {
            fuelFactor = 0.5; // Gasoline
        }
        
        // Calculate overall score (0.0 to 1.0)
        efficiencyScore = (weightFactor * 0.3 + engineFactor * 0.3 + aeroFactor * 0.2 + fuelFactor * 0.2);
        efficiencyScore = efficiencyScore.clamp(0.0, 1.0);
        
        // Convert to a 0-5 scale
        double starRating = efficiencyScore * 5;
        
        // Create a horizontal efficiency bar
        return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
                // Star rating display
                Row(
                    children: List.generate(5, (index) {
                        if (index < starRating.floor()) {
                            return const Icon(Icons.star, color: Colors.amber, size: 18);
                        } else if (index < starRating.ceil() && index > starRating.floor()) {
                            return const Icon(Icons.star_half, color: Colors.amber, size: 18);
                        } else {
                            return const Icon(Icons.star_border, color: Colors.amber, size: 18);
                        }
                    }),
                ),
                
                // Text description
                Text(
                    _getEfficiencyDescription(efficiencyScore),
                    style: TextStyle(
                        fontSize: 12,
                        color: _getEfficiencyColor(efficiencyScore),
                        fontWeight: FontWeight.bold,
                    ),
                ),
                
                // Progress bar
                const SizedBox(height: 4),
                LinearProgressIndicator(
                    value: efficiencyScore,
                    backgroundColor: Colors.grey[200],
                    valueColor: AlwaysStoppedAnimation<Color>(_getEfficiencyColor(efficiencyScore)),
                ),
            ],
        );
    }
    
    String _getEfficiencyDescription(double score) {
        if (score >= 0.8) {
            return 'Excellent';
        } else if (score >= 0.6) {
            return 'Good';
        } else if (score >= 0.4) {
            return 'Average';
        } else if (score >= 0.2) {
            return 'Below Average';
        } else {
            return 'Poor';
        }
    }
    
    Color _getEfficiencyColor(double score) {
        if (score >= 0.8) {
            return Colors.green;
        } else if (score >= 0.6) {
            return Colors.lightGreen;
        } else if (score >= 0.4) {
            return Colors.amber;
        } else if (score >= 0.2) {
            return Colors.orange;
        } else {
            return Colors.red;
        }
    }
}
