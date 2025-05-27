// lib/models/route_model.dart - Route data model

import 'package:trip_tank_fuely/locationPoint.dart';
import 'package:trip_tank_fuely/routeSegment.dart';

class RouteModel {
    final LocationPoint startLocation;
    final LocationPoint endLocation;
    final double distance; // in meters
    final double duration; // in seconds
    final List<RouteSegment> segments;

    RouteModel({
        required this.startLocation,
        required this.endLocation,
        required this.distance,
        required this.duration,
        required this.segments,
    });
}
