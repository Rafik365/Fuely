// lib/models/weather_model.dart - Weather data model
class WeatherData {
    final double windSpeed; // in m/s
    final double windDirection; // in degrees
    final double temperature; // in Celsius
    final double humidity; // in percentage
    final bool isRaining;

    WeatherData({
        required this.windSpeed,
        required this.windDirection,
        required this.temperature,
        required this.humidity,
        required this.isRaining,
    });

    factory WeatherData.fromMap(Map<String, dynamic> data) {
        return WeatherData(
            windSpeed: (data['wind']?['speed'] ?? 0.0).toDouble(),
        windDirection: (data['wind']?['deg'] ?? 0.0).toDouble(),
        temperature: (data['main']?['temp'] ?? 0.0).toDouble(),
        humidity: (data['main']?['humidity'] ?? 0.0).toDouble(),
        isRaining: (data['weather'] != null && data['weather'].isNotEmpty)
        ? (data['weather'][0]['id'] >= 200 && data['weather'][0]['id'] < 600)
        : false,
        );
    }
}

