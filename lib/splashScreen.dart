// lib/screens/splash_screen.dart - Initial loading screen
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:developer' as developer;
import 'package:trip_tank_fuely/authProvider.dart';
import 'package:trip_tank_fuely/homeScreen.dart';
import 'package:trip_tank_fuely/loginScreen.dart';
import 'dart:io';
import 'package:trip_tank_fuely/main.dart' show kAppTitle;

class SplashScreen extends StatefulWidget {
    const SplashScreen({super.key});

    @override
    _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
    late AnimationController _animationController;
    late Animation<double> _animation;
    bool _imageLoaded = false;
    String _imageLoadError = '';

    @override
    void initState() {
        super.initState();
        
        // Setup animation
        _animationController = AnimationController(
            vsync: this, 
            duration: const Duration(seconds: 2),
        );
        
        _animation = CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeInOut,
        );
        
        _animationController.forward();
        
        _checkAuth();

        // Check if image exists
        try {
            DefaultAssetBundle.of(context).load('assets/images/png/fuel nozzle.png')
                .then((_) {
                  setState(() {
                    _imageLoaded = true;
                    developer.log('Fuel nozzle image found in assets');
                  });
                })
                .catchError((error) {
                  setState(() {
                    _imageLoadError = error.toString();
                    developer.log('Image load error: $error');
                  });
                });
        } catch (e) {
            setState(() {
              _imageLoadError = e.toString();
              developer.log('Image exception: $e');
            });
        }
    }
    
    @override
    void dispose() {
        _animationController.dispose();
        super.dispose();
    }

    Future<void> _checkAuth() async {
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        await Future.delayed(const Duration(seconds: 3)); // Show splash longer to see logo
        
        // Check both Firebase auth and local storage auth
        final isAuthenticated = await authProvider.initUser();
        
        print("Authentication state: $isAuthenticated (Firebase or local)");

        if (isAuthenticated) {
            if (mounted) {
                Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => const HomeScreen()),
                );
            }
        } else {
            if (mounted) {
                Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
            }
        }
    }

    @override
    Widget build(BuildContext context) {
        // Use the app title constant from main.dart
        final String appTitle = kAppTitle;
        
        return Scaffold(
            backgroundColor: Colors.white,
            body: Center(
                child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                    // Animated logo
                    ScaleTransition(
                        scale: _animation,
                        child: SizedBox(
                          width: 200,
                          height: 200,
                          child: _buildLogo(),
                        ),
                    ),
                    const SizedBox(height: 30),
                    FadeTransition(
                        opacity: _animation,
                        child: Text(
                            appTitle,
                            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                color: Colors.blue,
                                fontWeight: FontWeight.bold,
                            ),
                        ),
                    ),
                    const SizedBox(height: 30),
                    const SpinKitDoubleBounce(
                        color: Colors.blue,
                        size: 50.0,
                    ),
                    // Debug info in development
                    if (_imageLoadError.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(
                          'Image Debug: $_imageLoadError',
                          style: const TextStyle(fontSize: 10, color: Colors.red),
                        ),
                      ),
                ],
                ),
            ),
        );
    }
    
    Widget _buildLogo() {
      // Try to display fuel nozzle image, with fallback to text logo
      try {
        return Image.asset(
          'assets/images/png/fuel nozzle.png',
          width: 200,
          height: 200,
          errorBuilder: (context, error, stackTrace) {
            developer.log('PNG render error: $error');
            return _buildFallbackLogo();
          },
        );
      } catch (e) {
        developer.log('PNG render exception: $e');
        return _buildFallbackLogo();
      }
    }
    
    Widget _buildFallbackLogo() {
      // Try SVG fallback
      try {
        return SvgPicture.asset(
          'assets/images/fuely_logo.svg',
          width: 200,
          height: 200,
          placeholderBuilder: (_) => _buildTextLogo(),
        );
      } catch (e) {
        return _buildTextLogo();
      }
    }
    
    Widget _buildTextLogo() {
      return Container(
        width: 200,
        height: 200,
        decoration: BoxDecoration(
          color: Colors.blue,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.blue.withOpacity(0.3),
              blurRadius: 15,
              spreadRadius: 5,
            ),
          ],
        ),
        child: const Center(
          child: Text(
            "FUELY",
            style: TextStyle(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
        ),
      );
    }
}
