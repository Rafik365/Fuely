import 'dart:math' as math;
import 'package:trip_tank_fuely/routeModel.dart';
import 'package:trip_tank_fuely/vehicleModel.dart';
import 'package:trip_tank_fuely/weatherModel.dart';

class XGBoostModel {
  // Training data structure
  final List<Map<String, dynamic>> _trainingData = [];
  
  // Consumption ranges (kept for compatibility)
  final List<String> _consumptionRanges = [
    'very_low',    // 0-5 L/100km
    'low',         // 5-7 L/100km
    'medium',      // 7-9 L/100km
    'high',        // 9-12 L/100km
    'very_high'    // >12 L/100km
  ];
  
  // Model parameters
  List<List<double>> _coefficients = [];
  List<double> _intercepts = [];
  int _numTrees = 10;
  double _learningRate = 0.1;
  
  // Initialize with default model parameters
  XGBoostModel() {
    _initializeModel();
  }
  
  void _initializeModel() {
    // Initialize with some reasonable default values for trees
    _coefficients = List.generate(_numTrees, (_) => 
      // Weight, engine capacity, fuel efficiency, distance, elevation, temperature, windspeed, rain
      [0.2, 0.3, -0.1, 0.05, 0.15, 0.1, 0.05, 0.1]
    );
    
    _intercepts = List.generate(_numTrees, (_) => 7.0); // Default medium consumption
  }
  
  // Process vehicle features into numeric values
  Map<String, double> _extractVehicleFeatures(VehicleModel vehicle) {
    // Normalized weight (assume 500-3000kg range)
    double normalizedWeight = (vehicle.weight - 500) / 2500;
    normalizedWeight = normalizedWeight.clamp(0.0, 1.0);
    
    // Normalized engine size (assume 0.8-6.0L range)
    double normalizedEngine = (vehicle.engineCapacity - 0.8) / 5.2;
    normalizedEngine = normalizedEngine.clamp(0.0, 1.0);
    
    // Fuel type as numeric value
    double fuelTypeValue;
    switch (vehicle.fuelType.toLowerCase()) {
      case 'diesel':
        fuelTypeValue = 0.7; // More efficient
        break;
      case 'gasoline':
        fuelTypeValue = 1.0; // Base value
        break;
      case 'electric':
        fuelTypeValue = 0.0; // Most efficient
        break;
      default:
        fuelTypeValue = 0.9; // Other types
    }
    
    return {
      'weight': normalizedWeight,
      'engine_capacity': normalizedEngine,
      'fuel_type': fuelTypeValue,
    };
  }
  
  // Process route features into numeric values
  Map<String, double> _extractRouteFeatures(RouteModel route) {
    // Normalized distance (0-100km)
    double normalizedDistance = route.distance / 100000; // Convert meters to 0-1 scale
    normalizedDistance = normalizedDistance.clamp(0.0, 1.0);
    
    // Elevation analysis
    double totalElevationGain = 0;
    for (var segment in route.segments) {
      if (segment.elevation > 0) {
        totalElevationGain += segment.elevation;
      }
    }
    
    // Normalized elevation (0-1000m)
    double normalizedElevation = totalElevationGain / 1000;
    normalizedElevation = normalizedElevation.clamp(0.0, 1.0);
    
    return {
      'distance': normalizedDistance,
      'elevation': normalizedElevation,
    };
  }
  
  // Process weather features into numeric values
  Map<String, double> _extractWeatherFeatures(WeatherData? weatherData) {
    if (weatherData == null) {
      return {
        'temperature': 0.5, // Moderate temperature
        'wind_speed': 0.2, // Light wind
        'rain': 0.0, // No rain
      };
    }
    
    // Normalized temperature (-20 to 40°C)
    double normalizedTemp = (weatherData.temperature + 20) / 60;
    normalizedTemp = normalizedTemp.clamp(0.0, 1.0);
    
    // Normalized wind speed (0-30 m/s)
    double normalizedWind = weatherData.windSpeed / 30;
    normalizedWind = normalizedWind.clamp(0.0, 1.0);
    
    // Rain as binary value
    double rainValue = weatherData.isRaining ? 1.0 : 0.0;
    
    return {
      'temperature': normalizedTemp,
      'wind_speed': normalizedWind,
      'rain': rainValue,
    };
  }
  
  // Add training data
  void addTrainingData(VehicleModel vehicle, RouteModel route, WeatherData? weather, double actualConsumption) {
    // Extract features
    Map<String, double> vehicleFeatures = _extractVehicleFeatures(vehicle);
    Map<String, double> routeFeatures = _extractRouteFeatures(route);
    Map<String, double> weatherFeatures = _extractWeatherFeatures(weather);
    
    // Add to training data
    _trainingData.add({
      'vehicle_features': vehicleFeatures,
      'route_features': routeFeatures,
      'weather_features': weatherFeatures,
      'consumption': actualConsumption,
    });
  }
  
  // Train the model based on collected data
  void train() {
    if (_trainingData.isEmpty) {
      return; // No data to train on
    }
    
    // Reset model parameters
    _initializeModel();
    
    // Current predictions (initialized to mean of target)
    double sumConsumption = 0;
    for (var data in _trainingData) {
      sumConsumption += data['consumption'] as double;
    }
    double meanConsumption = sumConsumption / _trainingData.length;
    
    List<double> currentPredictions = List.filled(_trainingData.length, meanConsumption);
    
    // Gradient boosting iterations
    for (int treeIndex = 0; treeIndex < _numTrees; treeIndex++) {
      // Calculate residuals
      List<double> residuals = [];
      for (int i = 0; i < _trainingData.length; i++) {
        residuals.add(_trainingData[i]['consumption'] - currentPredictions[i]);
      }
      
      // Update model parameters using simplified linear regression
      _fitLinearModel(treeIndex, residuals);
      
      // Update predictions
      for (int i = 0; i < _trainingData.length; i++) {
        double treePrediction = _predictWithTree(treeIndex, _trainingData[i]);
        currentPredictions[i] += _learningRate * treePrediction;
      }
    }
  }
  
  // Fit a simplified linear model to the residuals
  void _fitLinearModel(int treeIndex, List<double> residuals) {
    // Create feature matrix
    List<List<double>> features = [];
    for (var data in _trainingData) {
      List<double> featureRow = [
        data['vehicle_features']['weight'],
        data['vehicle_features']['engine_capacity'],
        data['vehicle_features']['fuel_type'],
        data['route_features']['distance'],
        data['route_features']['elevation'],
        data['weather_features']['temperature'],
        data['weather_features']['wind_speed'],
        data['weather_features']['rain'],
      ];
      features.add(featureRow);
    }
    
    // Fit model using simplified linear regression
    List<double> coefs = [0, 0, 0, 0, 0, 0, 0, 0];
    double intercept = 0;
    
    // Calculate means
    double yMean = residuals.reduce((a, b) => a + b) / residuals.length;
    List<double> xMeans = List.filled(8, 0);
    
    for (int i = 0; i < features.length; i++) {
      for (int j = 0; j < 8; j++) {
        xMeans[j] += features[i][j];
      }
    }
    
    for (int j = 0; j < 8; j++) {
      xMeans[j] /= features.length;
    }
    
    // Calculate coefficients using least squares
    for (int j = 0; j < 8; j++) {
      double num = 0;
      double denom = 0;
      
      for (int i = 0; i < features.length; i++) {
        num += (features[i][j] - xMeans[j]) * (residuals[i] - yMean);
        denom += math.pow(features[i][j] - xMeans[j], 2);
      }
      
      if (denom != 0) {
        coefs[j] = num / denom;
      }
    }
    
    // Calculate intercept
    intercept = yMean;
    for (int j = 0; j < 8; j++) {
      intercept -= coefs[j] * xMeans[j];
    }
    
    // Store coefficients and intercept
    _coefficients[treeIndex] = coefs;
    _intercepts[treeIndex] = intercept;
  }
  
  // Predict with a single tree
  double _predictWithTree(int treeIndex, Map<String, dynamic> data) {
    List<double> featureValues = [
      data['vehicle_features']['weight'],
      data['vehicle_features']['engine_capacity'],
      data['vehicle_features']['fuel_type'],
      data['route_features']['distance'],
      data['route_features']['elevation'],
      data['weather_features']['temperature'],
      data['weather_features']['wind_speed'],
      data['weather_features']['rain'],
    ];
    
    double prediction = _intercepts[treeIndex];
    for (int i = 0; i < featureValues.length; i++) {
      prediction += _coefficients[treeIndex][i] * featureValues[i];
    }
    
    return prediction;
  }
  
  // Predict consumption in L/100km
  double predictConsumption(VehicleModel vehicle, RouteModel route, WeatherData? weather) {
    // For electric vehicles, return near-zero consumption
    if (vehicle.fuelType.toLowerCase() == 'electric') {
      return 0.1; // Near zero but not exactly zero
    }
    
    // Extract features
    Map<String, double> vehicleFeatures = _extractVehicleFeatures(vehicle);
    Map<String, double> routeFeatures = _extractRouteFeatures(route);
    Map<String, double> weatherFeatures = _extractWeatherFeatures(weather);
    
    // Combine features
    Map<String, dynamic> featureMap = {
      'vehicle_features': vehicleFeatures,
      'route_features': routeFeatures,
      'weather_features': weatherFeatures,
    };
    
    // Make prediction using all trees
    double prediction = 0;
    for (int treeIndex = 0; treeIndex < _numTrees; treeIndex++) {
      prediction += _learningRate * _predictWithTree(treeIndex, featureMap);
    }
    
    // Ensure prediction is within reasonable bounds
    return prediction.clamp(3.0, 15.0);
  }
  
  // Predict consumption class (kept for compatibility with old code)
  String predictConsumptionClass(VehicleModel vehicle, RouteModel route, WeatherData? weather) {
    double consumption = predictConsumption(vehicle, route, weather);
    
    // Categorize consumption
    if (consumption < 5.0) {
      return 'very_low';
    } else if (consumption < 7.0) {
      return 'low';
    } else if (consumption < 9.0) {
      return 'medium';
    } else if (consumption < 12.0) {
      return 'high';
    } else {
      return 'very_high';
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