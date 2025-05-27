import 'dart:io';
import 'package:flutter/services.dart';
import 'package:csv/csv.dart';
import 'package:trip_tank_fuely/vehicleModel.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:convert';

class CsvVehicleService {
  static const String _csvAssetPath = 'assets/cars data csv.csv';
  List<VehicleModel> _vehicles = [];

  // Load all vehicles from CSV
  Future<List<VehicleModel>> loadVehiclesFromCsv() async {
    if (_vehicles.isNotEmpty) {
      return _vehicles;
    }

    try {
      // Load the CSV file from assets
      final String csvData = await rootBundle.loadString(_csvAssetPath);
      final List<String> lines = csvData.split('\n');
      
      // Skip header row
      for (int i = 1; i < lines.length; i++) {
        final line = lines[i].trim();
        if (line.isEmpty) continue;

        final values = line.split(',');
        if (values.length >= 8) {
          try {
            final vehicle = VehicleModel(
              id: 'csv-${i.toString().padLeft(4, '0')}', // Generate unique ID
              brand: values[0].trim(),
              model: values[1].trim(),
              weight: double.tryParse(values[2].trim()) ?? 0.0,
              tankCapacity: double.tryParse(values[3].trim()) ?? 0.0,
              engineCapacity: double.tryParse(values[4].trim()) ?? 0.0,
              cylinders: int.tryParse(values[5].trim()) ?? 0,
              aerodynamics: double.tryParse(values[6].trim()) ?? 0.0,
              fuelType: values[7].trim(),
            );
            _vehicles.add(vehicle);
          } catch (e) {
            print('Error parsing vehicle at line $i: $e');
          }
        }
      }
      
      return _vehicles;
    } catch (e) {
      print('Error loading CSV file: $e');
      return [];
    }
  }
  
  // Get all unique brands
  Future<List<String>> getAllBrands() async {
    final vehicles = await loadVehiclesFromCsv();
    final brands = vehicles.map((v) => v.brand).toSet().toList();
    brands.sort();
    return brands;
  }
  
  // Get vehicles by brand
  Future<List<VehicleModel>> getVehiclesByBrand(String brand) async {
    final vehicles = await loadVehiclesFromCsv();
    return vehicles.where((v) => v.brand == brand).toList();
  }
} 