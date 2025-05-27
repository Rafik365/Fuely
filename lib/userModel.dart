
// lib/models/user_model.dart - User data model
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:trip_tank_fuely/vehicleModel.dart';


class UserModel {
    final String id;
    final String name;
    final String email;
    final String vehicleId;
    final VehicleModel? customVehicle;
    final int drivingStyle; // 1-5 scale

    UserModel({
        this.id = '',
        this.name = '',
        this.email = '',
        this.vehicleId = '',
        this.customVehicle,
        this.drivingStyle = 3,
    });

    factory UserModel.fromMap(Map<String, dynamic> data, String id) {
        return UserModel(
            id: id,
            name: data['name'] ?? '',
        email: data['email'] ?? '',
        vehicleId: data['vehicleId'] ?? '',
        customVehicle: data['customVehicle'] != null
        ? VehicleModel.fromMap(data['customVehicle'], '')
        : null,
        drivingStyle: data['drivingStyle'] ?? 3,
        );
    }

    factory UserModel.fromFirestore(DocumentSnapshot doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        return UserModel.fromMap(data, doc.id);
    }

    Map<String, dynamic> toMap() {
        return {
            'name': name,
            'email': email,
            'vehicleId': vehicleId,
            'customVehicle': customVehicle?.toMap(),
            'drivingStyle': drivingStyle,
        };
    }

    UserModel copyWith({
        String? id,
        String? name,
        String? email,
        String? vehicleId,
        VehicleModel? customVehicle,
        int? drivingStyle,
    }) {
        return UserModel(
            id: id ?? this.id,
        name: name ?? this.name,
        email: email ?? this.email,
        vehicleId: vehicleId ?? this.vehicleId,
        customVehicle: customVehicle ?? this.customVehicle,
        drivingStyle: drivingStyle ?? this.drivingStyle,
        );
    }
}
