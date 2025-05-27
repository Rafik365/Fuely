// lib/providers/prediction_provider.dart - Prediction state management
import 'package:flutter/material.dart';
import 'dart:developer' as developer;
import 'package:trip_tank_fuely/locationPoint.dart';
import 'package:trip_tank_fuely/mapService.dart';
import 'package:trip_tank_fuely/predicionResult.dart';
import 'package:trip_tank_fuely/predictionService.dart';
import 'package:trip_tank_fuely/routeModel.dart';
import 'package:trip_tank_fuely/vehicleModel.dart';
import 'package:trip_tank_fuely/weatherServices.dart';


class PredictionProvider with ChangeNotifier {
    // Use the same API key from the Android manifest
    final MapsService _mapsService = MapsService(apiKey: 'AIzaSyApdEoXeFBZHhX4dy2RFFxZ_jzCJm0RB38');
    final WeatherService _weatherService = WeatherService(apiKey: '12388a5344458bf725c805de9af177a7');
    final PredictionService _predictionService = PredictionService();

    LocationPoint? _currentLocation;
    LocationPoint? _destinationLocation;
    RouteModel? _route;
    PredictionResult? _predictionResult;
    bool _isLoading = false;
    String _errorMessage = '';

    // Getters
    LocationPoint? get currentLocation => _currentLocation;
    LocationPoint? get destinationLocation => _destinationLocation;
    RouteModel? get route => _route;
    PredictionResult? get predictionResult => _predictionResult;
    bool get isLoading => _isLoading;
    String get errorMessage => _errorMessage;

    // Set current location
    void setCurrentLocation(double latitude, double longitude) {
        _currentLocation = LocationPoint(latitude: latitude, longitude: longitude);
        developer.log('Current location set: $_currentLocation');
        notifyListeners();
    }

    // Set destination
    void setDestination(double latitude, double longitude, {String address = ''}) {
        _destinationLocation = LocationPoint(
            latitude: latitude,
            longitude: longitude,
            address: address,
        );
        developer.log('Destination set: $_destinationLocation');
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
            
            developer.log('Calculating route from $_currentLocation to $_destinationLocation');
            _route = await _mapsService.getRoute(_currentLocation!, _destinationLocation!);

            if (_route != null) {
                developer.log('Route calculated successfully: ${_route!.distance / 1000} km');
                // Add weather data to route segments
                _route = await _addWeatherDataToRoute(_route!);
            } else {
                _errorMessage = 'Could not find route';
                developer.log('Failed to calculate route: $_errorMessage');
            }

            _isLoading = false;
            notifyListeners();
        } catch (e) {
            _isLoading = false;
            _errorMessage = 'Error calculating route: $e';
            developer.log('Error calculating route: $e');
            notifyListeners();
        }
    }

    // Add weather data to route
    Future<RouteModel> _addWeatherDataToRoute(RouteModel route) async {
        try {
            // For simplicity, get weather for start location only
            final weatherData = await _weatherService.getWeatherForLocation(route.startLocation);

            if (weatherData != null) {
                developer.log('Weather data added to route: ${weatherData.temperature}°C, wind: ${weatherData.windSpeed} m/s');
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
            developer.log('Error adding weather data to route: $e');
            return route;
        }
    }

    // Predict fuel consumption
    Future<void> predictFuelConsumption(VehicleModel vehicle, int drivingStyle) async {
        try {
            _isLoading = true;
            _errorMessage = '';
            notifyListeners();
            
            developer.log('Starting fuel consumption prediction');
            
            if (_route == null) {
                developer.log('No route available, calculating route first');
                await calculateRoute();
                if (_route == null) {
                    developer.log('Route calculation failed, unable to predict consumption');
                    _isLoading = false;
                    notifyListeners();
                    return; // Error message should be set in calculateRoute
                }
            }

            // Log vehicle data
            developer.log('Vehicle: ${vehicle.brand} ${vehicle.model}, fuel type: ${vehicle.fuelType}');
            developer.log('Driving style: $drivingStyle');
            
            _predictionResult = _predictionService.predictFuelConsumption(
                vehicle,
                _route!,
                drivingStyle,
            );
            
            if (_predictionResult != null) {
                developer.log('Prediction result: ${_predictionResult!.totalFuelConsumption.toStringAsFixed(2)} L, ${_predictionResult!.fuelConsumptionRate.toStringAsFixed(2)} L/100km');
            } else {
                developer.log('Prediction returned null result');
            }

            _isLoading = false;
            notifyListeners();
        } catch (e) {
            _isLoading = false;
            _errorMessage = 'Error predicting fuel consumption: $e';
            developer.log('Error predicting fuel consumption: $e');
            notifyListeners();
        }
    }

    // Reset prediction
    void resetPrediction() {
        _route = null;
        _predictionResult = null;
        _errorMessage = '';
        developer.log('Prediction reset');
        notifyListeners();
    }
}
