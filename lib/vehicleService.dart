import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:trip_tank_fuely/vehicleModel.dart';
import 'package:csv/csv.dart';


class VehicleService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get all vehicles
  Future<List<VehicleModel>> getAllVehicles() async {
    try {
      QuerySnapshot snapshot = await _firestore.collection('vehicles').get();
      return snapshot.docs
          .map((doc) => VehicleModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      print('Error getting vehicles: $e');
      return [];
    }
  }

  // Get vehicles by brand
  Future<List<VehicleModel>> getVehiclesByBrand(String brand) async {
    try {
      QuerySnapshot snapshot =
          await _firestore
              .collection('vehicles')
              .where('brand', isEqualTo: brand)
              .get();
      return snapshot.docs
          .map((doc) => VehicleModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      print('Error getting vehicles by brand: $e');
      return [];
    }
  }

  // Get vehicle by ID
  Future<VehicleModel?> getVehicleById(String id) async {
    try {
      DocumentSnapshot doc =
          await _firestore.collection('vehicles').doc(id).get();
      if (doc.exists) {
        return VehicleModel.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      print('Error getting vehicle by ID: $e');
      return null;
    }
  }

  // Import vehicles from CSV
  Future<void> importVehiclesFromCsv(String csvData) async {
    try {
      List<List<dynamic>> rowsAsListOfValues = const CsvToListConverter()
          .convert(csvData);

      // Skip header row
      for (int i = 1; i < rowsAsListOfValues.length; i++) {
        var row = rowsAsListOfValues[i];
        if (row.length >= 8) {
          VehicleModel vehicle = VehicleModel(
            brand: row[0].toString(),
            model: row[1].toString(),
            weight:
                row[2] is double
                    ? row[2]
                    : double.tryParse(row[2].toString()) ?? 0.0,
            tankCapacity:
                row[3] is double
                    ? row[3]
                    : double.tryParse(row[3].toString()) ?? 0.0,
            engineCapacity:
                row[4] is double
                    ? row[4]
                    : double.tryParse(row[4].toString()) ?? 0.0,
            cylinders:
                row[5] is int ? row[5] : int.tryParse(row[5].toString()) ?? 0,
            aerodynamics:
                row[6] is double
                    ? row[6]
                    : double.tryParse(row[6].toString()) ?? 0.0,
            fuelType: row[7].toString(),
          );

          await _firestore.collection('vehicles').add(vehicle.toMap());
        }
      }
    } catch (e) {
      print('Error importing vehicles from CSV: $e');
    }
  }

  // Get all brand names
  Future<List<String>> getAllBrands() async {
    try {
      QuerySnapshot snapshot = await _firestore.collection('vehicles').get();

      // Extract unique brands
      Set<String> brands = {};
      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        if (data['brand'] != null) {
          brands.add(data['brand'].toString());
        }
      }

      return brands.toList()..sort();
    } catch (e) {
      print('Error getting all brands: $e');
      return [];
    }
  }
}
