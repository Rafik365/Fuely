//dart pub global activate flutterfire_cli// lib/main.dart - Entry point of the app
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:trip_tank_fuely/authProvider.dart';
import 'package:trip_tank_fuely/firebase_options.dart';
import 'package:trip_tank_fuely/live_location_screen.dart';
import 'package:trip_tank_fuely/profileScreen.dart';
import 'package:trip_tank_fuely/xgboost_provider.dart';
import 'package:trip_tank_fuely/predictionProvider.dart';
import 'package:trip_tank_fuely/splashScreen.dart';
import 'package:trip_tank_fuely/vehcleProvider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:trip_tank_fuely/loginScreen.dart';
import 'package:trip_tank_fuely/themeProvider.dart';
import 'package:trip_tank_fuely/homeScreen.dart';

// App constants
const String kAppTitle = 'Fuely';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()..initUser()),
        ChangeNotifierProvider(create: (_) => VehicleProvider()),
        ChangeNotifierProvider(create: (_) => PredictionProvider()),
        ChangeNotifierProvider(create: (_) => XGBoostPredictionProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            title: kAppTitle,
            theme: themeProvider.theme,
            initialRoute: '/',
            routes: {
              '/': (context) => const SplashScreen(),
              '/login': (context) => const LoginScreen(),
              '/home': (context) => const HomeScreen(),
              '/profile': (context) => const ProfileScreen(),
              '/live_prediction': (context) => const LiveLocationScreen(),
            },
            debugShowCheckedModeBanner: false,
          );
        },
      ),
    );
  }
}
