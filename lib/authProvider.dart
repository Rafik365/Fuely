// lib/providers/auth_provider.dart - Authentication state management
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:trip_tank_fuely/authService.dart';
import 'package:trip_tank_fuely/userModel.dart';

class AuthProvider with ChangeNotifier {
    final AuthService _authService = AuthService();

    UserModel? _user;
    bool _isLoading = false;
    String _errorMessage = '';
    bool _isLocallyAuthenticated = false;

    // Getters
    UserModel? get user => _user;
    bool get isLoading => _isLoading;
    String get errorMessage => _errorMessage;
    bool get isAuthenticated => _authService.currentUser != null || _isLocallyAuthenticated;

    // Initialize - Check for Firebase auth and local auth
    Future<bool> initUser() async {
        if (_authService.currentUser != null) {
          
        print("TEsttt ::: User authenticated with Firebase");
            await getUserData();
            return true;
        } else {
            // Check for locally saved user ID
            return await checkLocalAuth();
        }
    }

    // Check if user ID is saved locally and fetch user data
    Future<bool> checkLocalAuth() async {
        try {
            _isLoading = true;
            notifyListeners();
            
            String? userId = await _authService.getSavedUserId();
            
            if (userId != null && userId.isNotEmpty) {
                _user = await _authService.getUserDataById(userId);
                if (_user != null) {
                    _isLocallyAuthenticated = true;
                    print("User authenticated locally: ${_user!.name}");
                    _isLoading = false;
                    notifyListeners();
                    return true;
                }
            }
            
            _isLoading = false;
            _isLocallyAuthenticated = false;
            notifyListeners();
            return false;
        } catch (e) {
            _isLoading = false;
            _isLocallyAuthenticated = false;
            _errorMessage = 'Error checking local authentication';
            print("Error checking local auth: $e");
            notifyListeners();
            return false;
        }
    }

    // Login with email and password
    Future<bool> login(String email, String password) async {
        try {
            _isLoading = true;
            _errorMessage = '';
            notifyListeners();
            
            print("Login process started in AuthProvider");

            await _authService.signInWithEmailAndPassword(email, password);
            await getUserData();
            
            print("Login successful, user data: ${_user?.name ?? 'No name'}");

            _isLoading = false;
            notifyListeners();
            return true;
        } on FirebaseAuthException catch (e) {
            _isLoading = false;
            _errorMessage = e.message ?? 'An error occurred during login';
            print("Firebase auth exception: ${e.message}");
            notifyListeners();
            return false;
        } catch (e) {
            _isLoading = false;
            _errorMessage = 'An unexpected error occurred';
            print("General exception during login: $e");
            notifyListeners();
            return false;
        }
    }

    // Register a new user
    Future<bool> register(String email, String password, String name) async {
        try {
            _isLoading = true;
            _errorMessage = '';
            notifyListeners();

            await _authService.registerWithEmailAndPassword(email, password, name);
            await getUserData();

            _isLoading = false;
            notifyListeners();
            return true;
        } on FirebaseAuthException catch (e) {
            _isLoading = false;
            _errorMessage = e.message ?? 'An error occurred during registration';
            notifyListeners();
            return false;
        } catch (e) {
            _isLoading = false;
            _errorMessage = 'An unexpected error occurred';
            notifyListeners();
            return false;
        }
    }

    // Sign out
    Future<void> signOut() async {
        try {
            await _authService.signOut();
            _user = null;
            _isLocallyAuthenticated = false;
            notifyListeners();
        } catch (e) {
            _errorMessage = 'Error signing out';
            notifyListeners();
        }
    }

    // Get user data
    Future<void> getUserData() async {
        try {
            _isLoading = true;
            notifyListeners();

            _user = await _authService.getUserData();

            _isLoading = false;
            notifyListeners();
        } catch (e) {
            _isLoading = false;
            _errorMessage = 'Error getting user data';
            notifyListeners();
        }
    }

    // Update user vehicle
    Future<void> updateUserVehicle(String vehicleId) async {
        try {
            _isLoading = true;
            notifyListeners();

            await _authService.updateUserVehicle(vehicleId);
            await getUserData();

            _isLoading = false;
            notifyListeners();
        } catch (e) {
            _isLoading = false;
            _errorMessage = 'Error updating vehicle';
            notifyListeners();
        }
    }

    // Update driving style
    Future<void> updateDrivingStyle(int drivingStyle) async {
        try {
            _isLoading = true;
            notifyListeners();

            await _authService.updateUserDrivingStyle(drivingStyle);

            if (_user != null) {
                _user = _user!.copyWith(drivingStyle: drivingStyle);
            }

            _isLoading = false;
            notifyListeners();
        } catch (e) {
            _isLoading = false;
            _errorMessage = 'Error updating driving style';
            notifyListeners();
        }
    }

    // Save custom vehicle
    Future<void> saveCustomVehicle(UserModel updatedUser) async {
        try {
            _isLoading = true;
            notifyListeners();

            await _authService.saveCustomVehicle(updatedUser);
            _user = updatedUser;

            _isLoading = false;
            notifyListeners();
        } catch (e) {
            _isLoading = false;
            _errorMessage = 'Error saving custom vehicle';
            notifyListeners();
        }
    }

    // Get locally saved user ID
    Future<String?> getSavedUserId() async {
        return await _authService.getSavedUserId();
    }
}