// lib/screens/home_screen.dart - Main app screen with map and prediction
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:trip_tank_fuely/authProvider.dart';
import 'package:trip_tank_fuely/live_location_screen.dart';
import 'package:trip_tank_fuely/predictionProvider.dart';
import 'package:trip_tank_fuely/predictionResultCard.dart';
import 'package:trip_tank_fuely/profileScreen.dart';
import 'package:trip_tank_fuely/vehcleProvider.dart';
import 'package:trip_tank_fuely/vehicleSelectionScreen.dart';
import 'package:trip_tank_fuely/vehicleModel.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  GoogleMapController? _mapController;
  final TextEditingController _destinationController = TextEditingController();
  final Set<Marker> _markers = {};
  
  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }
  
  @override
  void dispose() {
    _destinationController.dispose();
    _mapController?.dispose();
    super.dispose();
  }
  
  Future<void> _getCurrentLocation() async {
    final predictionProvider = Provider.of<PredictionProvider>(context, listen: false);
    
    try {
      // Get location permission
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        await Geolocator.requestPermission();
      }
      
      // Get current position
      final position = await Geolocator.getCurrentPosition();
      
      predictionProvider.setCurrentLocation(position.latitude, position.longitude);
      
      // Add marker and move camera
      setState(() {
        _markers.add(
          Marker(
            markerId: const MarkerId('current_location'),
            position: LatLng(position.latitude, position.longitude),
            infoWindow: const InfoWindow(title: 'Current Location'),
          ),
        );
      });
      
      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(position.latitude, position.longitude),
          15,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error getting location: $e')),
      );
    }
  }
  
  Future<void> _predictFuelConsumption() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final vehicleProvider = Provider.of<VehicleProvider>(context, listen: false);
    final predictionProvider = Provider.of<PredictionProvider>(context, listen: false);
    
    // Validate a destination is set
    if (predictionProvider.destinationLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please tap on the map to set a destination'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
    // Make sure user is logged in
    final user = authProvider.user;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please login first'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    try {
      // If no current location yet, try to get it again
      if (predictionProvider.currentLocation == null) {
        await _getCurrentLocation();
        if (predictionProvider.currentLocation == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Unable to get your current location. Please allow location access.'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
      }
    
      // Get vehicle data
      final vehicle = user.customVehicle ?? 
                      await vehicleProvider.getVehicleById(user.vehicleId);
      
      if (vehicle == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select a vehicle first (tap car icon in top bar)'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
        return;
      }
      
      // Calculate route and predict consumption
      await predictionProvider.predictFuelConsumption(vehicle, user.drivingStyle);
      
      // Show success message
      if (predictionProvider.predictionResult != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Prediction completed successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Prediction failed - no result returned'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _navigateToLiveTracking() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LiveLocationScreen()),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    final predictionProvider = Provider.of<PredictionProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    
    // Example: Get and print the saved user ID
    void _printSavedUserId() async {
      final userId = await authProvider.getSavedUserId();
      print("Currently saved user ID: $userId");
      // You can use this ID as needed in your application
    }
    
    // Call once when screen builds to demonstrate
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _printSavedUserId();
    });
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fuel Predictor'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ProfileScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.directions_car),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const VehicleSelectionScreen()),
              );
            },
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
              target: LatLng(30.0444, 31.2357), // Cairo, Egypt
              zoom: 10,
            ),
            markers: _markers,
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            mapToolbarEnabled: true,
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
              
              predictionProvider.setDestination(latLng.latitude, latLng.longitude);
            },
          ),
          
          // Destination search bar
          Positioned(
            top: 10,
            left: 10,
            right: 10,
            child: Container(
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
              child: TextField(
                controller: _destinationController,
                decoration: InputDecoration(
                  hintText: 'Enter destination',
                  border: InputBorder.none,
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.search),
                    onPressed: () {
                      // In a real app, you would use Places API for location search
                      // This is a simplified version
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Location search would be implemented here'),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
          
          // Vehicle info and predict button
          Positioned(
            left: 10,
            right: 10,
            bottom: 10,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Live tracking button
                ElevatedButton.icon(
                  onPressed: _navigateToLiveTracking,
                  icon: const Icon(Icons.navigation),
                  label: const Text('Live Tracking with ML Prediction'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    minimumSize: const Size.fromHeight(50),
                  ),
                ),
                const SizedBox(height: 10),
                
                // Basic prediction result (from original app)
                if (predictionProvider.predictionResult != null)
                  PredictionResultCard(
                    result: predictionProvider.predictionResult!,
                  ),
                  
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: predictionProvider.isLoading ? null : _predictFuelConsumption,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                    backgroundColor: Theme.of(context).primaryColor,
                  ),
                  child: predictionProvider.isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Calculate Basic Consumption'),
                ),
              ],
            ),
          ),
          
          // Loading indicator
          if (predictionProvider.isLoading)
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