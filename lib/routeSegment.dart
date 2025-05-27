
import 'package:trip_tank_fuely/locationPoint.dart';
import 'package:trip_tank_fuely/weatherModel.dart';

class RouteSegment {
    final LocationPoint startPoint;
    final LocationPoint endPoint;
    final double distance; // in meters
    final double bearing; // direction in degrees
    final double elevation; // in meters
    final WeatherData? weatherData;

    RouteSegment({
        required this.startPoint,
        required this.endPoint,
        required this.distance,
        required this.bearing,
        required this.elevation,
        this.weatherData,
    });

    RouteSegment copyWith({
        LocationPoint? startPoint,
        LocationPoint? endPoint,
        double? distance,
        double? bearing,
        double? elevation,
        WeatherData? weatherData,
    }) {
        return RouteSegment(
            startPoint: startPoint ?? this.startPoint,
        endPoint: endPoint ?? this.endPoint,
        distance: distance ?? this.distance,
        bearing: bearing ?? this.bearing,
        elevation: elevation ?? this.elevation,
        weatherData: weatherData ?? this.weatherData,
        );
    }
}
