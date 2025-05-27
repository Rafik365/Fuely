// lib/models/location_model.dart - Location data model
class LocationPoint {
    final double latitude;
    final double longitude;
    final String address;

    LocationPoint({
        required this.latitude,
        required this.longitude,
        this.address = '',
    });

    @override
    String toString() {
        return '$latitude,$longitude';
    }
}
