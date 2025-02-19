import 'package:fg/firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:parallax_rain/parallax_rain.dart'; // Parallax Rain Effect
import 'package:fg/authentication/controller/firebase_controller.dart';
import 'authentication/signup_screen.dart'; // Signup Screen
import 'authentication/login_screen.dart'; // Login Screen
import 'authentication/dashboard.dart'; // Login Screen


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
    return MaterialApp(
      title: 'Flutter Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      // Set the initial screen to SplashScreen
      initialRoute: '/splash',
      routes: {
        '/splash': (context) => const SplashScreen(),
        '/signup': (context) => const SignupScreen(),
        '/login': (context) => const LoginScreen(), // Add the LoginScreen route here
        '/home': (context) =>  DashboardScreen()

      },
    );
  }
}

class SplashScreen extends StatelessWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Navigate to SignupScreen after 10 seconds
    Future.delayed(const Duration(seconds: 10), () {
      Navigator.of(context).pushReplacementNamed('/signup');
    });

    return Scaffold(
      body: Stack(
        children: [
          // Parallax rain effect
          ParallaxRain(
            dropColors: [
              Colors.blueAccent.withOpacity(0.5),
              Colors.lightBlueAccent.withOpacity(0.5),
            ],
            numberOfDrops: 50,
            dropWidth: 2.0,
            dropHeight: 15.0,
            dropFallSpeed: 5.0,
          ),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset("assets/images/FG.png"), // Replace with your logo path
                const SizedBox(height: 10), // Space between logo and text
              ],
            ),
          ),
        ],
      ),
    );
  }
}


