import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:trip_tank_fuely/authProvider.dart';
import 'package:trip_tank_fuely/xgboost_provider.dart';
import 'package:trip_tank_fuely/predictionResultCard.dart';
import 'package:trip_tank_fuely/vehcleProvider.dart';

class LiveLocationScreen extends StatefulWidget {
  const LiveLocationScreen({super.key});

  @override
  _LiveLocationScreenState createState() => _LiveLocationScreenState();
}

class _LiveLocationScreenState extends State<LiveLocationScreen> {
  GoogleMapController? _mapController;
  final TextEditingController _destinationController = TextEditingController();
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  bool _isFollowingUser = true;
  StreamSubscription<Position>? _positionStream;
  
  @override
  void initState() {
    super.initState();
    _setupLocationTracking();
  }
  
  @override
  void dispose() {
    _destinationController.dispose();
    _mapController?.dispose();
    _positionStream?.cancel();
    super.dispose();
  }
  
  Future<void> _setupLocationTracking() async {
    final xgboostProvider = Provider.of<XGBoostPredictionProvider>(context, listen: false);
    
    try {
      // Get location permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permission denied')),
          );
          return;
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permission permanently denied')),
        );
        return;
      }
      
      // Get initial position
      final position = await Geolocator.getCurrentPosition();
      _updateLocation(position);
      
      // Set up continuous location updates
      final locationSettings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // Update every 10 meters
      );
      
      _positionStream = Geolocator.getPositionStream(locationSettings: locationSettings)
          .listen(_updateLocation);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error setting up location tracking: $e')),
      );
    }
  }
  
  Future<void> _updateLocation(Position position) async {
    final xgboostProvider = Provider.of<XGBoostPredictionProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final vehicleProvider = Provider.of<VehicleProvider>(context, listen: false);
    
    // Try to get address from coordinates
    String address = '';
    try {
      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      
      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        address = '${place.street}, ${place.locality}';
      }
    } catch (e) {
      print('Error getting address: $e');
    }
    
    // Update provider
    xgboostProvider.setCurrentLocation(
      position.latitude,
      position.longitude,
      address: address,
    );
    
    // Update marker on map
    setState(() {
      _markers.removeWhere(
        (marker) => marker.markerId.value == 'current_location',
      );
      
      _markers.add(
        Marker(
          markerId: const MarkerId('current_location'),
          position: LatLng(position.latitude, position.longitude),
          infoWindow: InfoWindow(
            title: 'Current Location',
            snippet: address.isNotEmpty ? address : null,
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        ),
      );
      
      // Draw polyline for movement history
      if (xgboostProvider.locationHistory.length > 1) {
        _polylines.clear();
        
        final List<LatLng> points = xgboostProvider.locationHistory
            .map((loc) => LatLng(loc.latitude, loc.longitude))
            .toList();
        
        _polylines.add(
          Polyline(
            polylineId: const PolylineId('movement_history'),
            points: points,
            color: Colors.blue.withOpacity(0.7),
            width: 5,
          ),
        );
      }
    });
    
    // Auto-follow user if enabled
    if (_isFollowingUser && _mapController != null) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLng(LatLng(position.latitude, position.longitude)),
      );
    }
    
    // Update prediction if destination is set
    if (xgboostProvider.destinationLocation != null) {
      // Get vehicle data
      final user = authProvider.user;
      if (user != null) {
        final vehicle = user.customVehicle ?? 
                      await vehicleProvider.getVehicleById(user.vehicleId);
        
        if (vehicle != null) {
          // Update prediction as location changes
          await xgboostProvider.updatePredictionWithNewLocation(
            vehicle, user.drivingStyle);
        }
      }
    }
  }
  
  void _toggleFollowUser() {
    setState(() {
      _isFollowingUser = !_isFollowingUser;
      
      if (_isFollowingUser && _mapController != null) {
        final xgboostProvider = Provider.of<XGBoostPredictionProvider>(context, listen: false);
        final currentLocation = xgboostProvider.currentLocation;
        
        if (currentLocation != null) {
          _mapController!.animateCamera(
            CameraUpdate.newLatLng(
              LatLng(currentLocation.latitude, currentLocation.longitude),
            ),
          );
        }
      }
    });
  }
  
  Future<void> _searchLocation() async {
    final xgboostProvider = Provider.of<XGBoostPredictionProvider>(context, listen: false);
    final searchQuery = _destinationController.text.trim();
    
    if (searchQuery.isEmpty) {
      return;
    }
    
    try {
      final locations = await locationFromAddress(searchQuery);
      
      if (locations.isNotEmpty) {
        final location = locations.first;
        
        xgboostProvider.setDestination(
          location.latitude,
          location.longitude,
          address: searchQuery,
        );
        
        setState(() {
          _markers.removeWhere(
            (marker) => marker.markerId.value == 'destination',
          );
          
          _markers.add(
            Marker(
              markerId: const MarkerId('destination'),
              position: LatLng(location.latitude, location.longitude),
              infoWindow: InfoWindow(title: 'Destination', snippet: searchQuery),
              icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
            ),
          );
        });
        
        // Calculate route to show in UI
        await xgboostProvider.calculateRoute();
        
        // Update polylines for route if available
        if (xgboostProvider.route != null) {
          final routePolyline = Polyline(
            polylineId: const PolylineId('route'),
            points: xgboostProvider.route!.segments
                .expand((segment) => [
                  LatLng(segment.startPoint.latitude, segment.startPoint.longitude),
                  LatLng(segment.endPoint.latitude, segment.endPoint.longitude),
                ])
                .toSet()
                .toList(),
            color: Colors.green.withOpacity(0.7),
            width: 5,
          );
          
          setState(() {
            _polylines.add(routePolyline);
          });
          
          // Show both origin and destination
          _mapController?.animateCamera(
            CameraUpdate.newLatLngBounds(
              LatLngBounds(
                southwest: LatLng(
                  [
                    location.latitude,
                    xgboostProvider.currentLocation?.latitude ?? location.latitude,
                  ].reduce((min, value) => min < value ? min : value),
                  [
                    location.longitude,
                    xgboostProvider.currentLocation?.longitude ?? location.longitude,
                  ].reduce((min, value) => min < value ? min : value),
                ),
                northeast: LatLng(
                  [
                    location.latitude,
                    xgboostProvider.currentLocation?.latitude ?? location.latitude,
                  ].reduce((max, value) => max > value ? max : value),
                  [
                    location.longitude,
                    xgboostProvider.currentLocation?.longitude ?? location.longitude,
                  ].reduce((max, value) => max > value ? max : value),
                ),
              ),
              100.0, // padding
            ),
          );
        }
        
        // Predict consumption
        await _predictFuelConsumption();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No locations found for this address')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error searching location: $e')),
      );
    }
  }
  
  Future<void> _predictFuelConsumption() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final vehicleProvider = Provider.of<VehicleProvider>(context, listen: false);
    final xgboostProvider = Provider.of<XGBoostPredictionProvider>(context, listen: false);
    
    if (xgboostProvider.destinationLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please set a destination')),
      );
      return;
    }
    
    final user = authProvider.user;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login first')),
      );
      return;
    }
    
    try {
      // Get vehicle data
      final vehicle = user.customVehicle ?? 
                    await vehicleProvider.getVehicleById(user.vehicleId);
      
      if (vehicle == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a vehicle first')),
        );
        return;
      }
      
      // Calculate route and predict consumption using XGBoost
      await xgboostProvider.predictFuelConsumption(vehicle, user.drivingStyle);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }
  
  Future<void> _addConsumptionFeedback() async {
    final xgboostProvider = Provider.of<XGBoostPredictionProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final vehicleProvider = Provider.of<VehicleProvider>(context, listen: false);
    
    if (xgboostProvider.predictionResult == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No prediction available to provide feedback on')),
      );
      return;
    }
    
    final user = authProvider.user;
    if (user == null) return;
    
    final vehicle = user.customVehicle ?? 
                  await vehicleProvider.getVehicleById(user.vehicleId);
    
    if (vehicle == null) return;
    
    // Show dialog to enter actual consumption
    final TextEditingController consumptionController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Trip Feedback'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter your actual fuel consumption for this trip:'),
            const SizedBox(height: 16),
            TextField(
              controller: consumptionController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Actual Consumption (liters)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final consumptionText = consumptionController.text.trim();
              if (consumptionText.isNotEmpty) {
                final actualConsumption = double.tryParse(consumptionText);
                if (actualConsumption != null && actualConsumption > 0) {
                  xgboostProvider.addConsumptionFeedback(vehicle, actualConsumption);
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Thank you for your feedback!')),
                  );
                }
              }
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    final xgboostProvider = Provider.of<XGBoostPredictionProvider>(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Fuel Prediction'),
        actions: [
          IconButton(
            icon: Icon(_isFollowingUser ? Icons.gps_fixed : Icons.gps_not_fixed),
            onPressed: _toggleFollowUser,
            tooltip: _isFollowingUser ? 'Stop following' : 'Follow my location',
          ),
        ],
      ),
      body: Stack(
        children: [
          // Google Map
          GoogleMap(
            onMapCreated: (controller) {
              _mapController = controller;
            },
            initialCameraPosition: const CameraPosition(
              target: LatLng(0, 0), // Will be updated when location is available
              zoom: 15,
            ),
            markers: _markers,
            polylines: _polylines,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            mapToolbarEnabled: true,
            compassEnabled: true,
            zoomControlsEnabled: false,
            onTap: (latLng) {
              // Set destination on map tap
              setState(() {
                _markers.removeWhere(
                  (m) => m.markerId.value == 'destination',
                );
                _markers.add(
                  Marker(
                    markerId: const MarkerId('destination'),
                    position: latLng,
                    infoWindow: const InfoWindow(title: 'Destination'),
                    icon: BitmapDescriptor.defaultMarkerWithHue(
                      BitmapDescriptor.hueGreen),
                  ),
                );
              });
              
              xgboostProvider.setDestination(latLng.latitude, latLng.longitude);
              _predictFuelConsumption();
            },
          ),
          
          // UI Overlay
          Positioned(
            top: 10,
            left: 10,
            right: 10,
            child: Column(
              children: [
                // Search bar
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 5,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _destinationController,
                          decoration: const InputDecoration(
                            hintText: 'Enter destination',
                            border: InputBorder.none,
                          ),
                          onSubmitted: (_) => _searchLocation(),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.search),
                        onPressed: _searchLocation,
                      ),
                    ],
                  ),
                ),
                
                // Current location info
                if (xgboostProvider.currentLocation != null && 
                    xgboostProvider.currentLocation!.address.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.my_location, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            xgboostProvider.currentLocation!.address,
                            style: const TextStyle(fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          
          // Prediction card at bottom
          Positioned(
            left: 10,
            right: 10,
            bottom: 10,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (xgboostProvider.predictionResult != null)
                  Column(
                    children: [
                      PredictionResultCard(
                        result: xgboostProvider.predictionResult!,
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: _addConsumptionFeedback,
                        icon: const Icon(Icons.feedback),
                        label: const Text('Provide Actual Consumption'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                        ),
                      ),
                    ],
                  )
                else if (xgboostProvider.destinationLocation != null)
                  ElevatedButton(
                    onPressed: xgboostProvider.isLoading ? null : _predictFuelConsumption,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                    ),
                    child: xgboostProvider.isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('Calculate Fuel Consumption'),
                  ),
              ],
            ),
          ),
          
          // Loading overlay
          if (xgboostProvider.isLoading)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }
}
