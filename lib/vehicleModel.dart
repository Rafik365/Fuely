import 'package:cloud_firestore/cloud_firestore.dart';

class VehicleModel {
    final String id;
    final String brand;
    final String model;
    final double weight;
    final double tankCapacity;
    final double engineCapacity;
    final int cylinders;
    final double aerodynamics;
    final String fuelType;

    VehicleModel({
        this.id = '',
        required this.brand,
        required this.model,
        required this.weight,
        required this.tankCapacity,
        required this.engineCapacity,
        required this.cylinders,
        required this.aerodynamics,
        required this.fuelType,
    });

    factory VehicleModel.fromMap(Map<String, dynamic> data, String id) {
        return VehicleModel(
            id: id,
            brand: data['brand'] ?? '',
        model: data['model'] ?? '',
        weight: (data['weight'] ?? 0.0).toDouble(),
        tankCapacity: (data['tankCapacity'] ?? 0.0).toDouble(),
        engineCapacity: (data['engineCapacity'] ?? 0.0).toDouble(),
        cylinders: data['cylinders'] ?? 0,
        aerodynamics: (data['aerodynamics'] ?? 0.0).toDouble(),
        fuelType: data['fuelType'] ?? 'Gasoline',
        );
    }

    factory VehicleModel.fromFirestore(DocumentSnapshot doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        return VehicleModel.fromMap(data, doc.id);
    }

    Map<String, dynamic> toMap() {
        return {
            'id': id,
            'brand': brand,
            'model': model,
            'weight': weight,
            'tankCapacity': tankCapacity,
            'engineCapacity': engineCapacity,
            'cylinders': cylinders,
            'aerodynamics': aerodynamics,
            'fuelType': fuelType,
        };
    }
}
