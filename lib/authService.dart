import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:trip_tank_fuely/userModel.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
    final FirebaseAuth _auth = FirebaseAuth.instance;
    final FirebaseFirestore _firestore = FirebaseFirestore.instance;
    
    // Local storage keys
    static const String _userIdKey = 'user_id';

    // Get current user
    User? get currentUser {
        final user = _auth.currentUser;
        print("Current Firebase user: ${user?.uid ?? 'NULL'}");
        return user;
    }

    // Save user ID to local storage
    Future<void> saveUserIdLocally(String userId) async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_userIdKey, userId);
        print("User ID saved locally: $userId");
    }

    // Get user ID from local storage
    Future<String?> getSavedUserId() async {
        final prefs = await SharedPreferences.getInstance();
        final userId = prefs.getString(_userIdKey);
        print("Retrieved user ID from local storage: $userId");
        return userId;
    }

    // Clear user ID from local storage on logout
    Future<void> clearSavedUserId() async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_userIdKey);
        print("User ID cleared from local storage");
    }
    
    // Sign in with email and password
    Future<UserCredential> signInWithEmailAndPassword(
    String email, String password) async {
        final credential = await _auth.signInWithEmailAndPassword(
                email: email, password: password);
        
        // Save user ID locally after successful login
        if (credential.user != null) {
            await saveUserIdLocally(credential.user!.uid);
        }
        
        return credential;
    }

    // Register with email and password
    Future<UserCredential> registerWithEmailAndPassword(
    String email, String password, String name) async {
        UserCredential result = await _auth.createUserWithEmailAndPassword(
            email: email, password: password);

        // Create a new document for the user with their uid
        await _firestore.collection('users').doc(result.user!.uid).set({
            'name': name,
            'email': email,
            'vehicleId': '',
            'drivingStyle': 3,
            'createdAt': FieldValue.serverTimestamp(),
            'lastLoginAt': FieldValue.serverTimestamp(),
            'isActive': true,
            'uid': result.user!.uid,
        });
        // Save user ID locally after successful registration
        await saveUserIdLocally(result.user!.uid);

        return result;
    }

    // Sign out
    Future<void> signOut() async {
        await clearSavedUserId();
        return await _auth.signOut();
    }

    // Get user from Firestore
    Future<UserModel?> getUserData() async {
        String? userId = await getSavedUserId();
        if (userId == null) return null;
        print("TEsttt ::: $userId");
        try {
            DocumentSnapshot doc = await _firestore
                .collection('users')
                .doc(userId)
                .get();
            print("TEsttt ::: $doc");
            print("TEsttt ::: ${doc.exists}");
             print("TEsttt ::: ${UserModel.fromFirestore(doc)}");
            if (doc.exists) {
                UserModel user = UserModel.fromFirestore(doc);
                
                // If no vehicle ID is set in Firebase, check if we have one saved locally
                if (user.vehicleId.isEmpty) {
                    final prefs = await SharedPreferences.getInstance();
                    final localVehicleId = prefs.getString('selected_vehicle_id');
                    if (localVehicleId != null && localVehicleId.isNotEmpty) {
                        print("Found locally saved vehicle ID: $localVehicleId");
                        // Create a new user with the local vehicle ID
                        return user.copyWith(vehicleId: localVehicleId);
                    }
                }
                
                return user;
            }
           
            return null;
        } catch (e) {
            print('Error getting user data: $e');
            return null;
        }
    }
    
    // Get user data by user ID (for local storage login)
    Future<UserModel?> getUserDataById(String userId) async {
        try {
            DocumentSnapshot doc = await _firestore
                .collection('users')
                .doc(userId)
                .get();

            if (doc.exists) {
                return UserModel.fromFirestore(doc);
            }
            return null;
        } catch (e) {
            print('Error getting user data by ID: $e');
            return null;
        }
    }

    // Update user vehicle
    Future<void> updateUserVehicle(String vehicleId) async {
        try {
            if (currentUser == null) {
                // Try to get user from local storage
                String? userId = await getSavedUserId();
                if (userId == null) return;
                
                await _firestore.collection('users').doc(userId).update({
                    'vehicleId': vehicleId,
                });
                
                print('Updated vehicle ID for user $userId to $vehicleId');
                return;
            }

            await _firestore.collection('users').doc(currentUser!.uid).update({
                'vehicleId': vehicleId,
            });
            
            print('Updated vehicle ID for Firebase user ${currentUser!.uid} to $vehicleId');
        } catch (e) {
            print('Error updating vehicle: $e');
            // If Firebase update fails, try saving locally
            try {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setString('selected_vehicle_id', vehicleId);
                print('Saved vehicle ID locally: $vehicleId');
            } catch (localError) {
                print('Error saving vehicle ID locally: $localError');
            }
        }
    }

    // Update user driving style
    Future<void> updateUserDrivingStyle(int drivingStyle) async {
        if (currentUser == null) return;

        await _firestore.collection('users').doc(currentUser!.uid).update({
            'drivingStyle': drivingStyle,
        });
    }

    // Save custom vehicle
    Future<void> saveCustomVehicle(UserModel user) async {
        if (currentUser == null) return;

        await _firestore.collection('users').doc(currentUser!.uid).set(
            user.toMap(),
            SetOptions(merge: true),
        );
    }
}
