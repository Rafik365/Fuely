import 'dart:math';

import 'package:trip_tank_fuely/predicionResult.dart';
import 'package:trip_tank_fuely/routeModel.dart';
import 'package:trip_tank_fuely/segmentConsumption.dart';
import 'package:trip_tank_fuely/vehicleModel.dart';

class PredictionService {
    // Base coefficients for the prediction formula
    final double baseConsumption = 1.5; // L/100km
    final double weightFactor = 0.0015; // L/100km per kg
    final double engineCapacityFactor = 0.8; // L/100km per liter of engine capacity
    final double cylinderFactor = 0.2; // L/100km per cylinder
    final double aerodynamicsFactor = 4.0; // L/100km per drag coefficient
    final double windFactor = 0.1; // Impact of wind
    final double elevationFactor = 0.0004; // L/100km per meter of elevation gain
    final double temperatureFactor = 0.02; // L/100km per degree C away from optimal (20°C)
    final double rainFactor = 0.05; // 5% increase in consumption when raining

    // Adjustments for different fuel types
    final Map<String, double> fuelTypeFactors = {
        'Gasoline': 1.0,
        'Diesel': 0.85,
        'Electric': 0.0 // Electric vehicles don't consume fuel
    };

    // Driving style factors (1-economic to 5-aggressive)
    final Map<int, double> drivingStyleFactors = {
        1: 0.85, // Very economic
        2: 0.92, // Economic
        3: 1.0, // Normal
        4: 1.12, // Sporty
        5: 1.25 // Aggressive
    };

    // Predict fuel consumption
    PredictionResult predictFuelConsumption(
    VehicleModel vehicle,
    RouteModel route,
    int drivingStyle,
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

        final segmentConsumptions = <SegmentConsumption>[];
        double totalConsumption = 0.0;
        double totalDistance = 0.0;

        // Process each route segment
        for (int i = 0; i < route.segments.length; i++) {
            final segment = route.segments[i];
            final segmentDistanceKm = segment.distance / 1000.0; // Convert meters to km
            totalDistance += segmentDistanceKm;

            // Base consumption for this segment without adjustments
            final baseSegmentConsumption = (baseConsumption / 100.0) * segmentDistanceKm;

            // Calculate factors affecting consumption
            final factors = <String, double>{};

            // Vehicle weight factor
            final weightImpact = (weightFactor * vehicle.weight / 100.0) * segmentDistanceKm;
            factors['Weight'] = weightImpact;

            // Engine capacity factor
            final engineImpact = (engineCapacityFactor * vehicle.engineCapacity / 100.0) * segmentDistanceKm;
            factors['Engine'] = engineImpact;

            // Cylinder count factor
            final cylinderImpact = (cylinderFactor * vehicle.cylinders / 100.0) * segmentDistanceKm;
            factors['Cylinders'] = cylinderImpact;

            // Aerodynamics base factor
            final aeroImpact = (aerodynamicsFactor * vehicle.aerodynamics / 100.0) * segmentDistanceKm;
            factors['Aerodynamics'] = aeroImpact;

            // Wind impact calculation
            double windImpact = 0.0;
            if (segment.weatherData != null) {
                // Calculate relative angle between vehicle direction and wind
                final relativeWindAngle = ((segment.bearing - segment.weatherData!.windDirection + 180) % 360 - 180).abs();
                final windAngleRadians = relativeWindAngle * pi / 180;

                // Headwind increases consumption, tailwind decreases it
                final windImpactMultiplier = cos(windAngleRadians);
                windImpact = (windFactor * segment.weatherData!.windSpeed * windImpactMultiplier / 100.0) * segmentDistanceKm;
                factors['Wind'] = windImpact;

                // Temperature impact (deviation from optimal 20°C)
                final tempDeviation = (segment.weatherData!.temperature - 20.0).abs();
                final temperatureImpact = (temperatureFactor * tempDeviation / 100.0) * segmentDistanceKm;
                factors['Temperature'] = temperatureImpact;

                // Rain impact
                if (segment.weatherData!.isRaining) {
                    final rainImpact = baseSegmentConsumption * rainFactor;
                    factors['Rain'] = rainImpact;
                }
            }

            // Elevation impact
            final elevationImpact = segment.elevation > 0
            ? (elevationFactor * segment.elevation / 100.0) * segmentDistanceKm // Uphill
            : (elevationFactor * segment.elevation * 0.3 / 100.0) * segmentDistanceKm; // Downhill reduces consumption slightly
            factors['Elevation'] = elevationImpact;

            // Apply fuel type adjustment
            final fuelTypeFactor = fuelTypeFactors[vehicle.fuelType] ?? 1.0;

            // Apply driving style adjustment
            final drivingStyleFactor = drivingStyleFactors[drivingStyle] ?? 1.0;
            factors['Driving Style'] = baseSegmentConsumption * (drivingStyleFactor - 1.0);

            // Calculate total segment consumption
            final factorsSum = factors.values.fold(0.0, (sum, value) => sum + value);
            final segmentConsumption = (baseSegmentConsumption + factorsSum) * fuelTypeFactor * drivingStyleFactor;

            // Add to results
            segmentConsumptions.add(SegmentConsumption(
                segmentIndex: i,
                consumption: segmentConsumption,
                influencingFactors: factors.map((key, value) =>
            MapEntry(key, (value / segmentConsumption) * 100.0)),
            ));

            totalConsumption += segmentConsumption;
        }

        // Calculate overall consumption rate (L/100km)
        final consumptionRate = totalDistance > 0
        ? (totalConsumption / totalDistance) * 100.0
        : 0.0;

        // Estimate fuel cost (assuming average price of 1.5 USD per liter)
        final costEstimate = totalConsumption * 1.5;

        // Estimate CO2 emissions (kg)
        double co2Factor;
        switch (vehicle.fuelType) {
            case 'Diesel':
            co2Factor = 2.68; // Average diesel: 2.68 kg CO2 per liter
            break;
            case 'Gasoline':
            co2Factor = 2.31; // Average gasoline: 2.31 kg CO2 per liter
            break;
            default:
            co2Factor = 0.0;
        }
        final co2Emissions = totalConsumption * co2Factor;

        return PredictionResult(
            totalDistance: totalDistance,
            totalFuelConsumption: totalConsumption,
            fuelConsumptionRate: consumptionRate,
            costEstimate: costEstimate,
            co2Emissions: co2Emissions,
            segmentConsumptions: segmentConsumptions,
        );
    }
}
