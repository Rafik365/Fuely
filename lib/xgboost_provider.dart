import 'dart:math';
import 'package:flutter/material.dart';

import 'package:trip_tank_fuely/locationPoint.dart';
import 'package:trip_tank_fuely/mapService.dart';
import 'package:trip_tank_fuely/xgboost_service.dart';
import 'package:trip_tank_fuely/predicionResult.dart';
import 'package:trip_tank_fuely/routeModel.dart';
import 'package:trip_tank_fuely/vehicleModel.dart';
import 'package:trip_tank_fuely/weatherModel.dart';
import 'package:trip_tank_fuely/weatherServices.dart';

class XGBoostPredictionProvider with ChangeNotifier {
  final MapsService _mapsService = MapsService(apiKey: 'AIzaSyApdEoXeFBZHhX4dy2RFFxZ_jzCJm0RB38');
  final WeatherService _weatherService = WeatherService(apiKey: '12388a5344458bf725c805de9af177a7');
  final XGBoostService _xgboostService = XGBoostService();
  
  LocationPoint? _currentLocation;
  LocationPoint? _destinationLocation;
  RouteModel? _route;
  PredictionResult? _predictionResult;
  bool _isLoading = false;
  String _errorMessage = '';
  final List<LocationPoint> _locationHistory = [];
  
  // Getters
  LocationPoint? get currentLocation => _currentLocation;
  LocationPoint? get destinationLocation => _destinationLocation;
  RouteModel? get route => _route;
  PredictionResult? get predictionResult => _predictionResult;
  bool get isLoading => _isLoading;
  String get errorMessage => _errorMessage;
  List<LocationPoint> get locationHistory => _locationHistory;

  // Calculate distance between two points (in km)
  double _calculateDistance(LocationPoint point1, LocationPoint point2) {
    const double earthRadius = 6371.0; // km
    
    final lat1 = point1.latitude * pi / 180.0;
    final lon1 = point1.longitude * pi / 180.0;
    final lat2 = point2.latitude * pi / 180.0;
    final lon2 = point2.longitude * pi / 180.0;
    
    final dLat = lat2 - lat1;
    final dLon = lon2 - lon1;
    
    final a = sin(dLat/2) * sin(dLat/2) +
              cos(lat1) * cos(lat2) *
              sin(dLon/2) * sin(dLon/2);
    final c = 2 * atan2(sqrt(a), sqrt(1-a));
    
    return earthRadius * c; // Distance in km
  }

  // Set current location
  void setCurrentLocation(double latitude, double longitude, {String address = ''}) {
    final newLocation = LocationPoint(
      latitude: latitude,
      longitude: longitude,
      address: address,
    );
    
    // Only add to history if it's significantly different (to avoid clutter)
    if (_currentLocation == null || 
        _calculateDistance(_currentLocation!, newLocation) > 0.05) { // 50 meters
      _locationHistory.add(newLocation);
      // Keep only the last 100 points to avoid memory issues
      if (_locationHistory.length > 100) {
        _locationHistory.removeAt(0);
      }
    }
    
    _currentLocation = newLocation;
    notifyListeners();
  }

  // Set destination
  void setDestination(double latitude, double longitude, {String address = ''}) {
    _destinationLocation = LocationPoint(
      latitude: latitude,
      longitude: longitude,
      address: address,
    );
    
    // Reset prediction when destination changes
    _predictionResult = null;
    notifyListeners();
  }

  // Calculate route
  Future<void> calculateRoute() async {
    if (_currentLocation == null || _destinationLocation == null) {
      _errorMessage = 'Please set both start and destination locations';
      notifyListeners();
      return;
    }

    try {
      _isLoading = true;
      _errorMessage = '';
      notifyListeners();
      
      _route = await _mapsService.getRoute(_currentLocation!, _destinationLocation!);
      
      if (_route != null) {
        // Add weather data to route segments
        _route = await _addWeatherDataToRoute(_route!);
      } else {
        _errorMessage = 'Could not find route';
      }
      
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Error calculating route: $e';
      notifyListeners();
    }
  }

  // Add weather data to route
  Future<RouteModel> _addWeatherDataToRoute(RouteModel route) async {
    try {
      // For simplicity, get weather for start location only
      final weatherData = await _weatherService.getWeatherForLocation(route.startLocation);
      
      if (weatherData != null) {
        final updatedSegments = route.segments.map((segment) => 
          segment.copyWith(weatherData: weatherData)).toList();
        
        return RouteModel(
          startLocation: route.startLocation,
          endLocation: route.endLocation,
          distance: route.distance,
          duration: route.duration,
          segments: updatedSegments,
        );
      }
      
      return route;
    } catch (e) {
      print('Error adding weather data to route: $e');
      return route;
    }
  }

  // Predict fuel consumption using XGBoost model
  Future<void> predictFuelConsumption(VehicleModel vehicle, int drivingStyle) async {
    if (_route == null) {
      await calculateRoute();
      if (_route == null) {
        return; // Error message should be set in calculateRoute
      }
    }

    try {
      _isLoading = true;
      _errorMessage = '';
      notifyListeners();
      
      // Get weather data from the first segment's weather (if any)
      WeatherData? weatherData = _route!.segments.isNotEmpty 
          ? _route!.segments.first.weatherData 
          : null;
      
      // Use XGBoost to predict consumption
      _predictionResult = _xgboostService.predictFuelConsumption(
        vehicle,
        _route!,
        drivingStyle,
        weatherData,
      );
      
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Error predicting fuel consumption: $e';
      notifyListeners();
    }
  }

  // Reset prediction
  void resetPrediction() {
    _route = null;
    _predictionResult = null;
    _errorMessage = '';
    notifyListeners();
  }
  
  // Update prediction when location changes (for live tracking)
  Future<void> updatePredictionWithNewLocation(VehicleModel vehicle, int drivingStyle) async {
    // Skip if no destination is set
    if (_destinationLocation == null) return;
    
    try {
      // Recalculate route with new current location
      await calculateRoute();
      
      // If route was successfully calculated, update prediction
      if (_route != null) {
        // Get weather data from the first segment's weather (if any)
        WeatherData? weatherData = _route!.segments.isNotEmpty 
            ? _route!.segments.first.weatherData 
            : null;
        
        // Update prediction with new route data
        _predictionResult = _xgboostService.predictFuelConsumption(
          vehicle,
          _route!,
          drivingStyle,
          weatherData,
        );
        
        notifyListeners();
      }
    } catch (e) {
      print('Error updating prediction with new location: $e');
    }
  }
  
  // Add feedback to improve the model (actual consumption after trip)
  void addConsumptionFeedback(VehicleModel vehicle, double actualConsumption) {
    if (_route != null) {
      // Get weather data from the first segment's weather (if any)
      WeatherData? weatherData = _route!.segments.isNotEmpty 
          ? _route!.segments.first.weatherData 
          : null;
      
      // Add training data and retrain the model
      _xgboostService.addTrainingData(
        vehicle,
        _route!,
        weatherData,
        actualConsumption,
      );
      _xgboostService.trainModel();
    }
  }
} 