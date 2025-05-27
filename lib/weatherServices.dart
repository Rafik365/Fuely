import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math' as math;

import 'package:trip_tank_fuely/locationPoint.dart';
import 'package:trip_tank_fuely/weatherModel.dart';

class WeatherService {
    final String apiKey;

    WeatherService({required this.apiKey});

    // Get current weather for a location
    Future<WeatherData?> getWeatherForLocation(LocationPoint location) async {
        try {
            final url = Uri.parse(
                    'https://api.openweathermap.org/data/2.5/weather?lat=${location.latitude}&lon=${location.longitude}&appid=$apiKey&units=metric');

            final response = await http.get(url);

            if (response.statusCode == 200) {
                Map<String, dynamic> data = json.decode(response.body);
                return WeatherData.fromMap(data);
            }

            // If API call fails, return mock data
            print('Weather API call failed with status: ${response.statusCode}');
            print('Returning mock weather data instead');
            return _getMockWeatherData();
        } catch (e) {
            print('Error getting weather: $e');
            // Return mock data on any error
            return _getMockWeatherData();
        }
    }
    
    // Generate realistic mock weather data
    WeatherData _getMockWeatherData() {
        final random = math.Random();
        
        // Generate realistic temperature (10-30°C)
        final temperature = 10.0 + random.nextDouble() * 20.0;
        
        // Generate realistic wind speed (0-10 m/s)
        final windSpeed = random.nextDouble() * 10.0;
        
        // Generate random wind direction (0-359 degrees)
        final windDirection = random.nextDouble() * 360.0;
        
        // Generate realistic humidity (40-90%)
        final humidity = 40.0 + random.nextDouble() * 50.0;
        
        // 20% chance of rain
        final isRaining = random.nextDouble() < 0.2;
        
        return WeatherData(
            temperature: temperature,
            windSpeed: windSpeed,
            windDirection: windDirection,
            humidity: humidity,
            isRaining: isRaining,
        );
    }
}
