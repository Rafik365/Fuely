// lib/models/prediction_result.dart - Prediction result model
import 'package:trip_tank_fuely/segmentConsumption.dart';

class PredictionResult {
    final double totalDistance; // in kilometers
    final double totalFuelConsumption; // in liters
    final double fuelConsumptionRate; // in L/100km
    final double costEstimate; // in local currency
    final double co2Emissions; // in kg
    final List<SegmentConsumption> segmentConsumptions;

    PredictionResult({
        required this.totalDistance,
        required this.totalFuelConsumption,
        required this.fuelConsumptionRate,
        required this.costEstimate,
        required this.co2Emissions,
        required this.segmentConsumptions,
    });
}
