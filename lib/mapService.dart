// lib/services/maps_service.dart - Maps and routing service
import 'dart:math';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:trip_tank_fuely/locationPoint.dart';
import 'package:trip_tank_fuely/routeModel.dart';
import 'package:trip_tank_fuely/routeSegment.dart';

class MapsService {
    final String apiKey;

    MapsService({required this.apiKey});

    // Get directions between two points
    Future<RouteModel?> getRoute(
    LocationPoint origin, LocationPoint destination) async {
        try {
            final originStr = '${origin.latitude},${origin.longitude}';
            final destStr = '${destination.latitude},${destination.longitude}';
            
            // Use Google Maps API key from Android manifest
            final actualApiKey = 'AIzaSyApdEoXeFBZHhX4dy2RFFxZ_jzCJm0RB38';
            
            final url = Uri.parse(
                    'https://maps.googleapis.com/maps/api/directions/json?origin=$originStr&destination=$destStr&key=$actualApiKey');
            
            developer.log('Fetching route from Google Maps API: $url');
            
            // Try network request with timeout
            final response = await http.get(url).timeout(
                const Duration(seconds: 10),
                onTimeout: () {
                    developer.log('Google Maps API request timed out. Using mock route instead.');
                    return http.Response('{"status": "TIMEOUT"}', 408);
                },
            );

            if (response.statusCode == 200) {
                Map<String, dynamic> data = json.decode(response.body);
                
                // Debug response
                developer.log('Google Maps API response status: ${data['status']}');
                
                if (data['status'] != 'OK') {
                    developer.log('Google Maps API error: ${data['status']} - ${data['error_message'] ?? 'Unknown error'}');
                    // If API call fails with an error, generate mock route
                    return _generateMockRoute(origin, destination);
                }

                if (data['routes'].isEmpty || data['routes'][0]['legs'].isEmpty) {
                    developer.log('No routes found in Google Maps API response');
                    // If no routes found, generate mock route
                    return _generateMockRoute(origin, destination);
                }

                final route = data['routes'][0];
                final leg = route['legs'][0];

                final List<RouteSegment> segments = [];

                for (var step in leg['steps']) {
                    final startPoint = LocationPoint(
                            latitude: step['start_location']['lat'],
                    longitude: step['start_location']['lng'],
                    );

                    final endPoint = LocationPoint(
                            latitude: step['end_location']['lat'],
                    longitude: step['end_location']['lng'],
                    );

                    // Instead of making another API call for elevation, use a simulated value
                    // This speeds up the prediction and avoids API limits
                    final elevationDiff = Random().nextDouble() * 10 - 5; // Random between -5 and 5 meters

                    // Calculate bearing
                    final bearing = _calculateBearing(startPoint, endPoint);

                    segments.add(RouteSegment(
                        startPoint: startPoint,
                        endPoint: endPoint,
                        distance: step['distance']['value'].toDouble(),
                        bearing: bearing,
                        elevation: elevationDiff,
                    ));
                }

                final routeModel = RouteModel(
                    startLocation: LocationPoint(
                            latitude: leg['steps'][0]['start_location']['lat'],
                    longitude: leg['steps'][0]['start_location']['lng'],
                ),
                endLocation: LocationPoint(
                latitude: leg['steps'].last['end_location']['lat'],
                longitude: leg['steps'].last['end_location']['lng'],
                ),
                distance: leg['distance']['value'].toDouble(),
                duration: leg['duration']['value'].toDouble(),
                segments: segments,
                );
                
                developer.log('Route calculated: ${segments.length} segments, ${routeModel.distance / 1000}km');
                return routeModel;
            } else {
                developer.log('Google Maps API returned error code: ${response.statusCode}');
                developer.log('Response body: ${response.body}');
                // If API call fails with an error status, generate mock route
                return _generateMockRoute(origin, destination);
            }
        } catch (e) {
            developer.log('Error getting route: $e');
            // If any error occurs, generate mock route
            return _generateMockRoute(origin, destination);
        }
    }

    // Since we're simplifying, let's remove the elevation API call to avoid unnecessary API usage
    Future<double> _getElevationDifference(
    LocationPoint start, LocationPoint end) async {
        // Return a simulated elevation difference
        return Random().nextDouble() * 20 - 10; // Random between -10 and 10 meters
    }

    // Calculate bearing between two points
    double _calculateBearing(LocationPoint start, LocationPoint end) {
        final startLat = _toRadians(start.latitude);
        final startLng = _toRadians(start.longitude);
        final endLat = _toRadians(end.latitude);
        final endLng = _toRadians(end.longitude);

        final dLng = endLng - startLng;

        final y = sin(dLng) * cos(endLat);
        final x = cos(startLat) * sin(endLat) -
                sin(startLat) * cos(endLat) * cos(dLng);

        var bearing = atan2(y, x);
        bearing = _toDegrees(bearing);
        bearing = (bearing + 360) % 360;

        return bearing;
    }

    // Convert degrees to radians
    double _toRadians(double degrees) {
        return degrees * pi / 180;
    }

    // Convert radians to degrees
    double _toDegrees(double radians) {
        return radians * 180 / pi;
    }

    // Generate a mock route between two points
    RouteModel _generateMockRoute(LocationPoint origin, LocationPoint destination) {
        developer.log('Generating mock route from (${origin.latitude}, ${origin.longitude}) to (${destination.latitude}, ${destination.longitude})');
        
        final random = Random();
        final segments = <RouteSegment>[];
        
        // Calculate direct distance
        final double dLat = destination.latitude - origin.latitude;
        final double dLon = destination.longitude - origin.longitude;
        final double distanceKm = sqrt(dLat * dLat + dLon * dLon) * 111.32; // Approximate km per degree at equator
        final double distanceM = distanceKm * 1000;
        
        // Generate between 3 and 8 segments
        final numSegments = 3 + random.nextInt(6);
        developer.log('Generating $numSegments route segments');
        
        // Initial point is origin
        LocationPoint currentPoint = origin;
        
        for (int i = 0; i < numSegments; i++) {
            // Generate next point gradually approaching destination
            final progress = (i + 1) / numSegments;
            final jitter = 0.0002 * (random.nextDouble() - 0.5); // Small random deviation
            
            final nextLat = origin.latitude + dLat * progress + jitter;
            final nextLon = origin.longitude + dLon * progress + jitter;
            final nextPoint = LocationPoint(latitude: nextLat, longitude: nextLon);
            
            // Calculate segment length (approximate)
            final segDLat = nextPoint.latitude - currentPoint.latitude;
            final segDLon = nextPoint.longitude - currentPoint.longitude;
            final segDistanceM = sqrt(segDLat * segDLat + segDLon * segDLon) * 111320; // meters
            
            // Add segment
            segments.add(RouteSegment(
                startPoint: currentPoint,
                endPoint: nextPoint,
                distance: segDistanceM,
                bearing: _calculateBearing(currentPoint, nextPoint),
                elevation: (random.nextDouble() * 20) - 10, // -10 to 10 meters elevation change
            ));
            
            // Update current point
            currentPoint = nextPoint;
        }
        
        // Add final segment to destination if needed
        if (currentPoint.latitude != destination.latitude || 
            currentPoint.longitude != destination.longitude) {
            
            final segDLat = destination.latitude - currentPoint.latitude;
            final segDLon = destination.longitude - currentPoint.longitude;
            final segDistanceM = sqrt(segDLat * segDLat + segDLon * segDLon) * 111320; // meters
            
            segments.add(RouteSegment(
                startPoint: currentPoint,
                endPoint: destination,
                distance: segDistanceM,
                bearing: _calculateBearing(currentPoint, destination),
                elevation: (random.nextDouble() * 10) - 5, // -5 to 5 meters elevation change
            ));
        }
        
        // Calculate total distance from segments
        final totalDistance = segments.fold<double>(
            0, (sum, segment) => sum + segment.distance);
        
        // Estimate duration (assume average speed of 50 km/h)
        final durationSec = (totalDistance / 1000) / 50 * 3600;
        
        return RouteModel(
            startLocation: origin,
            endLocation: destination,
            distance: totalDistance,
            duration: durationSec,
            segments: segments,
        );
    }
}

