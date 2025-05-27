import 'dart:math';
import 'package:trip_tank_fuely/routeModel.dart';
import 'package:trip_tank_fuely/vehicleModel.dart';
import 'package:trip_tank_fuely/weatherModel.dart';
class NaiveBayesModel {
  // Feature probability tables (simplified for example)
Map<String, Map<String, Map<String, double>>> _vehicleFeatureProbabilities = {};
  Map<String, Map<String, Map<String, double>>> _routeFeatureProbabilities = {};
  Map<String, Map<String, Map<String, double>>> _weatherFeatureProbabilities = {};
  Map<String, double> _priorProbabilities = {};
  
  // Consumption ranges
  final List<String> _consumptionRanges = [
    'very_low',    // 0-5 L/100km
    'low',         // 5-7 L/100km
    'medium',      // 7-9 L/100km
    'high',        // 9-12 L/100km
    'very_high'    // >12 L/100km
  ];
  
  // Training data structure
  final List<Map<String, dynamic>> _trainingData = [];
  
  // Initialize with some default probabilities based on known fuel consumption patterns
  NaiveBayesModel() {
    _initializeDefaultProbabilities();
  }
  
  void _initializeDefaultProbabilities() {
    // Prior probabilities for each consumption class
    _priorProbabilities = {
      'very_low': 0.1,   // 10% of vehicles have very low consumption
      'low': 0.25,       // 25% have low consumption
      'medium': 0.40,    // 40% have medium consumption
      'high': 0.15,      // 15% have high consumption
      'very_high': 0.1,  // 10% have very high consumption
    };
    
    // Vehicle feature probabilities (P(feature|consumption_class))
    _vehicleFeatureProbabilities['weight'] = {
      'light': {'very_low': 0.7, 'low': 0.5, 'medium': 0.3, 'high': 0.1, 'very_high': 0.05},
      'medium': {'very_low': 0.25, 'low': 0.4, 'medium': 0.5, 'high': 0.3, 'very_high': 0.15},
      'heavy': {'very_low': 0.05, 'low': 0.1, 'medium': 0.2, 'high': 0.6, 'very_high': 0.8},
    };
    
    _vehicleFeatureProbabilities['engine_size'] = {
      'small': {'very_low': 0.8, 'low': 0.6, 'medium': 0.3, 'high': 0.1, 'very_high': 0.05},
      'medium': {'very_low': 0.15, 'low': 0.3, 'medium': 0.6, 'high': 0.3, 'very_high': 0.15},
      'large': {'very_low': 0.05, 'low': 0.1, 'medium': 0.1, 'high': 0.6, 'very_high': 0.8},
    };
    
    _vehicleFeatureProbabilities['fuel_type'] = {
      'diesel': {'very_low': 0.6, 'low': 0.5, 'medium': 0.4, 'high': 0.3, 'very_high': 0.2},
      'gasoline': {'very_low': 0.3, 'low': 0.4, 'medium': 0.5, 'high': 0.6, 'very_high': 0.7},
      'electric': {'very_low': 0.95, 'low': 0.05, 'medium': 0.0, 'high': 0.0, 'very_high': 0.0},
    };
    
    // Route feature probabilities
    _routeFeatureProbabilities['distance'] = {
      'short': {'very_low': 0.4, 'low': 0.4, 'medium': 0.4, 'high': 0.3, 'very_high': 0.3},
      'medium': {'very_low': 0.4, 'low': 0.4, 'medium': 0.4, 'high': 0.4, 'very_high': 0.4},
      'long': {'very_low': 0.2, 'low': 0.2, 'medium': 0.2, 'high': 0.3, 'very_high': 0.3},
    };
    
    _routeFeatureProbabilities['elevation'] = {
      'flat': {'very_low': 0.7, 'low': 0.6, 'medium': 0.5, 'high': 0.4, 'very_high': 0.3},
      'hilly': {'very_low': 0.2, 'low': 0.3, 'medium': 0.4, 'high': 0.4, 'very_high': 0.4},
      'mountainous': {'very_low': 0.1, 'low': 0.1, 'medium': 0.1, 'high': 0.2, 'very_high': 0.3},
    };
    
    // Weather feature probabilities
    _weatherFeatureProbabilities['temperature'] = {
      'cold': {'very_low': 0.2, 'low': 0.2, 'medium': 0.3, 'high': 0.4, 'very_high': 0.5},
      'mild': {'very_low': 0.6, 'low': 0.5, 'medium': 0.4, 'high': 0.3, 'very_high': 0.3},
      'hot': {'very_low': 0.2, 'low': 0.3, 'medium': 0.3, 'high': 0.3, 'very_high': 0.2},
    };
    
    _weatherFeatureProbabilities['wind'] = {
      'calm': {'very_low': 0.7, 'low': 0.6, 'medium': 0.5, 'high': 0.4, 'very_high': 0.3},
      'moderate': {'very_low': 0.2, 'low': 0.3, 'medium': 0.4, 'high': 0.4, 'very_high': 0.4},
      'strong': {'very_low': 0.1, 'low': 0.1, 'medium': 0.1, 'high': 0.2, 'very_high': 0.3},
    };
    
    _weatherFeatureProbabilities['rain'] = {
      'no': {'very_low': 0.8, 'low': 0.7, 'medium': 0.6, 'high': 0.5, 'very_high': 0.4},
      'yes': {'very_low': 0.2, 'low': 0.3, 'medium': 0.4, 'high': 0.5, 'very_high': 0.6},
    };
  }
  
  // Process vehicle features into categories
  Map<String, String> _extractVehicleFeatures(VehicleModel vehicle) {
    // Weight categorization (in kg)
    String weightCategory;
    if (vehicle.weight < 1200) {
      weightCategory = 'light';
    } else if (vehicle.weight < 1800) {
      weightCategory = 'medium';
    } else {
      weightCategory = 'heavy';
    }
    
    // Engine size categorization (in L)
    String engineCategory;
    if (vehicle.engineCapacity < 1.6) {
      engineCategory = 'small';
    } else if (vehicle.engineCapacity < 2.5) {
      engineCategory = 'medium';
    } else {
      engineCategory = 'large';
    }
    
    // Fuel type (lowercase for consistency)
    String fuelType = vehicle.fuelType.toLowerCase();
    
    return {
      'weight': weightCategory,
      'engine_size': engineCategory,
      'fuel_type': fuelType,
    };
  }
  
  // Process route features into categories
  Map<String, String> _extractRouteFeatures(RouteModel route) {
    // Distance categorization (in meters)
    String distanceCategory;
    if (route.distance < 5000) {
      distanceCategory = 'short';  // < 5 km
    } else if (route.distance < 20000) {
      distanceCategory = 'medium'; // 5-20 km
    } else {
      distanceCategory = 'long';   // > 20 km
    }
    
    // Elevation analysis
    double totalElevationGain = 0;
    for (var segment in route.segments) {
      if (segment.elevation > 0) {
        totalElevationGain += segment.elevation;
      }
    }
    
    String elevationCategory;
    if (totalElevationGain < 100) {
      elevationCategory = 'flat';       // < 100 m elevation gain
    } else if (totalElevationGain < 500) {
      elevationCategory = 'hilly';      // 100-500 m elevation gain
    } else {
      elevationCategory = 'mountainous'; // > 500 m elevation gain
    }
    
    return {
      'distance': distanceCategory,
      'elevation': elevationCategory,
    };
  }
  
  // Process weather features into categories
  Map<String, String> _extractWeatherFeatures(WeatherData? weatherData) {
    if (weatherData == null) {
      return {
        'temperature': 'mild',
        'wind': 'calm',
        'rain': 'no',
      };
    }
    
    // Temperature categorization (in Celsius)
    String temperatureCategory;
    if (weatherData.temperature < 10) {
      temperatureCategory = 'cold';
    } else if (weatherData.temperature < 25) {
      temperatureCategory = 'mild';
    } else {
      temperatureCategory = 'hot';
    }
    
    // Wind categorization (in m/s)
    String windCategory;
    if (weatherData.windSpeed < 3) {
      windCategory = 'calm';
    } else if (weatherData.windSpeed < 8) {
      windCategory = 'moderate';
    } else {
      windCategory = 'strong';
    }
    
    // Rain categorization
    String rainCategory = weatherData.isRaining ? 'yes' : 'no';
    
    return {
      'temperature': temperatureCategory,
      'wind': windCategory,
      'rain': rainCategory,
    };
  }
  
  // Add training data
  void addTrainingData(VehicleModel vehicle, RouteModel route, WeatherData? weather, double actualConsumption) {
    String consumptionClass;
    
    // Categorize actual consumption
    if (actualConsumption < 5.0) {
      consumptionClass = 'very_low';
    } else if (actualConsumption < 7.0) {
      consumptionClass = 'low';
    } else if (actualConsumption < 9.0) {
      consumptionClass = 'medium';
    } else if (actualConsumption < 12.0) {
      consumptionClass = 'high';
    } else {
      consumptionClass = 'very_high';
    }
    
    // Extract features
    Map<String, String> vehicleFeatures = _extractVehicleFeatures(vehicle);
    Map<String, String> routeFeatures = _extractRouteFeatures(route);
    Map<String, String> weatherFeatures = _extractWeatherFeatures(weather);
    
    // Add to training data
    _trainingData.add({
      'vehicle_features': vehicleFeatures,
      'route_features': routeFeatures,
      'weather_features': weatherFeatures,
      'consumption_class': consumptionClass,
      'actual_consumption': actualConsumption,
    });
  }
  
  // Train the model based on collected data
  void train() {
    if (_trainingData.isEmpty) {
      // If no training data, we'll use the default probabilities
      return;
    }
    
    // Reset probabilities
    _priorProbabilities = {};
    _vehicleFeatureProbabilities = {};
    _routeFeatureProbabilities = {};
    _weatherFeatureProbabilities = {};
    
    // Count class occurrences for prior probabilities
    Map<String, int> classCounts = {};
    for (var data in _trainingData) {
      String consumptionClass = data['consumption_class'];
      classCounts[consumptionClass] = (classCounts[consumptionClass] ?? 0) + 1;
    }
    
    // Calculate prior probabilities
    int totalSamples = _trainingData.length;
    for (var cls in _consumptionRanges) {
      _priorProbabilities[cls] = (classCounts[cls] ?? 0) / totalSamples;
    }
    
    // Calculate feature probabilities for each class
    // This is a simplified implementation - in a real application, you'd use Laplace smoothing
    
    // ... More training logic would go here, but this is a simplified version
    
    // Re-initialize default probabilities for demo purposes
    _initializeDefaultProbabilities();
  }
  
  // Predict consumption class using Naive Bayes
  String predictConsumptionClass(VehicleModel vehicle, RouteModel route, WeatherData? weather) {
    // Extract features
    Map<String, String> vehicleFeatures = _extractVehicleFeatures(vehicle);
    Map<String, String> routeFeatures = _extractRouteFeatures(route);
    Map<String, String> weatherFeatures = _extractWeatherFeatures(weather);
    
    // Calculate posterior probability for each class
    Map<String, double> posteriorProbabilities = {};
    
    for (var cls in _consumptionRanges) {
      double logProbability = log(_priorProbabilities[cls] ?? 0.00001);
      
      // Vehicle features
      for (var feature in vehicleFeatures.keys) {
        String value = vehicleFeatures[feature]!;
        
        if (_vehicleFeatureProbabilities.containsKey(feature) &&
            _vehicleFeatureProbabilities[feature]!.containsKey(value) &&
            _vehicleFeatureProbabilities[feature]![value]!.containsKey(cls)) {
          double? probability = _vehicleFeatureProbabilities[feature]![value]![cls];
          logProbability += log(probability ?? 0.00001);
        } else {
          logProbability += log(0.00001); // Small value to avoid log(0)
        }
      }
      
      // Route features
      for (var feature in routeFeatures.keys) {
        String value = routeFeatures[feature]!;
        
        if (_routeFeatureProbabilities.containsKey(feature) &&
            _routeFeatureProbabilities[feature]!.containsKey(value) &&
            _routeFeatureProbabilities[feature]![value]!.containsKey(cls)) {
          double? probability = _routeFeatureProbabilities[feature]![value]![cls];
          logProbability += log(probability ?? 0.00001);
        } else {
          logProbability += log(0.00001);
        }
      }
      
      // Weather features
      for (var feature in weatherFeatures.keys) {
        String value = weatherFeatures[feature]!;
        
        if (_weatherFeatureProbabilities.containsKey(feature) &&
            _weatherFeatureProbabilities[feature]!.containsKey(value) &&
            _weatherFeatureProbabilities[feature]![value]!.containsKey(cls)) {
          double? probability = _weatherFeatureProbabilities[feature]![value]![cls];
          logProbability += log(probability ?? 0.00001);
        } else {
          logProbability += log(0.00001);
        }
      }
      
      posteriorProbabilities[cls] = logProbability;
    }
    
    // Find class with highest probability
    String bestClass = _consumptionRanges[0];
    double bestProbability = posteriorProbabilities[bestClass] ?? double.negativeInfinity;
    
    for (var cls in _consumptionRanges) {
      double probability = posteriorProbabilities[cls] ?? double.negativeInfinity;
      if (probability > bestProbability) {
        bestProbability = probability;
        bestClass = cls;
      }
    }
    
    return bestClass;
  }
  
  // Predict actual consumption in L/100km
  double predictConsumption(VehicleModel vehicle, RouteModel route, WeatherData? weather) {
    String consumptionClass = predictConsumptionClass(vehicle, route, weather);
    
    // Convert class to estimated consumption
    switch (consumptionClass) {
      case 'very_low':
        return 4.0 + Random().nextDouble() * 1.0; // 4.0-5.0 L/100km
      case 'low':
        return 5.0 + Random().nextDouble() * 2.0; // 5.0-7.0 L/100km
      case 'medium':
        return 7.0 + Random().nextDouble() * 2.0; // 7.0-9.0 L/100km
      case 'high':
        return 9.0 + Random().nextDouble() * 3.0; // 9.0-12.0 L/100km
      case 'very_high':
        return 12.0 + Random().nextDouble() * 3.0; // 12.0-15.0 L/100km
      default:
        return 7.5; // Default to medium consumption
    }
  }
  
  // Calculate total consumption for a route in liters
  double calculateTotalConsumption(VehicleModel vehicle, RouteModel route, WeatherData? weather) {
    // Get consumption rate in L/100km
    double consumptionRate = predictConsumption(vehicle, route, weather);
    
    // Calculate distance in km
    double distanceInKm = route.distance / 1000.0;
    
    // Calculate total consumption
    return (consumptionRate * distanceInKm) / 100.0;
  }
}