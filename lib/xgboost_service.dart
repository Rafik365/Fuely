import 'package:trip_tank_fuely/xgboost_model.dart';
import 'package:trip_tank_fuely/predicionResult.dart';
import 'package:trip_tank_fuely/routeModel.dart';
import 'package:trip_tank_fuely/segmentConsumption.dart';
import 'package:trip_tank_fuely/vehicleModel.dart';
import 'package:trip_tank_fuely/weatherModel.dart';

class XGBoostService {
  final XGBoostModel _model = XGBoostModel();
  
  // Predict fuel consumption using XGBoost
  PredictionResult predictFuelConsumption(
    VehicleModel vehicle,
    RouteModel route,
    int drivingStyle,
    WeatherData? weatherData,
  ) {
    // If it's an electric vehicle, return zero consumption
    if (vehicle.fuelType.toLowerCase() == 'electric') {
      return PredictionResult(
        totalDistance: 0.0,
        totalFuelConsumption: 0.0,
        fuelConsumptionRate: 0.0,
        costEstimate: 0.0,
        co2Emissions: 0.0,
        segmentConsumptions: [],
      );
    }

    // Get predicted consumption rate (L/100km) from the model
    double consumptionRate = _model.predictConsumption(vehicle, route, weatherData);
    
    // Apply driving style factor
    final Map<int, double> drivingStyleFactors = {
      1: 0.85, // Very economic
      2: 0.92, // Economic
      3: 1.0,  // Normal
      4: 1.12, // Sporty
      5: 1.25  // Aggressive
    };
    double drivingStyleFactor = drivingStyleFactors[drivingStyle] ?? 1.0;
    
    // Adjust consumption based on driving style
    double adjustedConsumptionRate = consumptionRate * drivingStyleFactor;
    
    // Calculate total distance in km
    double distanceInKm = route.distance / 1000.0;
    
    // Calculate total consumption
    double totalConsumption = (adjustedConsumptionRate * distanceInKm) / 100.0;
    
    // Estimate fuel cost (assuming average price of 1.5 USD per liter)
    final costEstimate = totalConsumption * 1.5;

    // Estimate CO2 emissions (kg)
    double co2Factor;
    switch (vehicle.fuelType.toLowerCase()) {
      case 'diesel':
        co2Factor = 2.68; // Average diesel: 2.68 kg CO2 per liter
        break;
      case 'gasoline':
        co2Factor = 2.31; // Average gasoline: 2.31 kg CO2 per liter
        break;
      default:
        co2Factor = 0.0;
    }
    final co2Emissions = totalConsumption * co2Factor;
    
    // Create segment consumption info (simplified for XGBoost)
    final segmentConsumptions = <SegmentConsumption>[];
    
    // Create an average segment consumption
    if (route.segments.isNotEmpty) {
      final Map<String, double> influencingFactors = {
        'Vehicle Type': 0.3 * 100, // 30% influence
        'Route': 0.4 * 100,        // 40% influence
        'Weather': 0.2 * 100,       // 20% influence
        'Driving Style': (drivingStyleFactor - 1.0) * 100, // Remaining percentage
      };
      
      segmentConsumptions.add(SegmentConsumption(
        segmentIndex: 0,
        consumption: totalConsumption,
        influencingFactors: influencingFactors,
      ));
    }

    return PredictionResult(
      totalDistance: distanceInKm,
      totalFuelConsumption: totalConsumption,
      fuelConsumptionRate: adjustedConsumptionRate,
      costEstimate: costEstimate,
      co2Emissions: co2Emissions,
      segmentConsumptions: segmentConsumptions,
    );
  }
  
  // Add training data point
  void addTrainingData(VehicleModel vehicle, RouteModel route, WeatherData? weather, double actualConsumption) {
    _model.addTrainingData(vehicle, route, weather, actualConsumption);
  }
  
  // Train the model
  void trainModel() {
    _model.train();
  }
} 