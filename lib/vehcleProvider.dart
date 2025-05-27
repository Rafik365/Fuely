// lib/providers/vehicle_provider.dart - Vehicle data state management
import 'package:flutter/material.dart';

import 'package:trip_tank_fuely/vehicleModel.dart';
import 'package:trip_tank_fuely/vehicleService.dart';
import 'package:trip_tank_fuely/csvVehicleService.dart';

class VehicleProvider with ChangeNotifier {
    final VehicleService _vehicleService = VehicleService();
    final CsvVehicleService _csvVehicleService = CsvVehicleService();
    
    bool _useFirebase = true; // Set to true to use CSV data by default

    List<String> _brands = [];
    List<VehicleModel> _models = [];
    VehicleModel? _selectedVehicle;
    bool _isLoading = false;
    String _errorMessage = '';
    String _successMessage = '';

    // Getters
    List<String> get brands => _brands;
    List<VehicleModel> get models => _models;
    VehicleModel? get selectedVehicle => _selectedVehicle;
    bool get isLoading => _isLoading;
    String get errorMessage => _errorMessage;
    String get successMessage => _successMessage;
    bool get useFirebase => _useFirebase;

    // Toggle between Firebase and CSV data source
    void toggleDataSource(bool useFirebase) {
        _useFirebase = useFirebase;
        loadBrands(); // Reload brands with the new data source
        notifyListeners();
    }

    // Load all brands
    Future<void> loadBrands() async {
        try {
            _isLoading = true;
            _errorMessage = '';
            notifyListeners();

            if (_useFirebase) {
                _brands = await _vehicleService.getAllBrands();
            } else {
                _brands = await _csvVehicleService.getAllBrands();
            }

            _isLoading = false;
            notifyListeners();
        } catch (e) {
            _isLoading = false;
            _errorMessage = 'Error loading brands';
            notifyListeners();
        }
    }

    // Load models by brand
    Future<void> loadModelsByBrand(String brand) async {
        try {
            _isLoading = true;
            _errorMessage = '';
            notifyListeners();

            if (_useFirebase) {
                _models = await _vehicleService.getVehiclesByBrand(brand);
            } else {
                _models = await _csvVehicleService.getVehiclesByBrand(brand);
            }

            _isLoading = false;
            notifyListeners();
        } catch (e) {
            _isLoading = false;
            _errorMessage = 'Error loading models';
            notifyListeners();
        }
    }

    // Get vehicle by ID
    Future<VehicleModel?> getVehicleById(String id) async {
        try {
            _isLoading = true;
            _errorMessage = '';
            notifyListeners();

            if (_useFirebase) {
                _selectedVehicle = await _vehicleService.getVehicleById(id);
            } else {
                // For CSV, we need to load all vehicles and find by ID
                final allVehicles = await _csvVehicleService.loadVehiclesFromCsv();
                _selectedVehicle = allVehicles.firstWhere(
                    (vehicle) => vehicle.id == id,
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

            _isLoading = false;
            notifyListeners();
            return _selectedVehicle;
        } catch (e) {
            _isLoading = false;
            _errorMessage = 'Error getting vehicle';
            notifyListeners();
            return null;
        }
    }

    // Set selected vehicle
    void setSelectedVehicle(VehicleModel vehicle) {
        _selectedVehicle = vehicle;
        notifyListeners();
    }

    // Import vehicles from CSV
    Future<void> importVehiclesFromCsv(String csvData) async {
        try {
            _isLoading = true;
            _errorMessage = '';
            notifyListeners();

            await _vehicleService.importVehiclesFromCsv(csvData);

            _successMessage = 'Vehicles imported successfully';
            _isLoading = false;
            notifyListeners();
        } catch (e) {
            _isLoading = false;
            _errorMessage = 'Error importing vehicles';
            notifyListeners();
        }
    }

    // Load all vehicles from CSV (for profile page)
    Future<List<VehicleModel>> loadVehiclesFromCsv() async {
        try {
            return await _csvVehicleService.loadVehiclesFromCsv();
        } catch (e) {
            print('Error loading CSV vehicles: $e');
            return [];
        }
    }

    // Clear messages
    void clearMessages() {
        _errorMessage = '';
        _successMessage = '';
        notifyListeners();
    }
}
