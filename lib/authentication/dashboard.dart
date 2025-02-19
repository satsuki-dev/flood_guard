import 'package:flutter/material.dart';
import 'map_screen.dart'; // Import the new map screen
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart'; // For fetching location

class DashboardScreen extends StatelessWidget {
  // Function to fetch the user's current location
  Future<LatLng> _getUserLocation() async {
    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Location services are disabled.');
      }

      // Check for location permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permissions are denied.');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception('Location permissions are permanently denied.');
      }

      // Fetch the current position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      return LatLng(position.latitude, position.longitude);
    } catch (e) {
      throw Exception('Failed to fetch location: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFEAF7FF),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text(
          "Dashboard",
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Color(0xFF003366),
        elevation: 0,
        centerTitle: true,
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Opacity(
              opacity: 0.2,
              child: Image.asset(
                "assets/images/bg.jpg",
                fit: BoxFit.cover,
              ),
            ),
          ),
          SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Hello, User!",
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF003366),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Stay dry, stay safe! Here's today's flood updates.",
                    style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 20),
                  // Flood Map
                  GestureDetector(
                    onTap: () async {
                      try {
                        // Fetch the user's current location
                        LatLng userLocation = await _getUserLocation();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => MapScreen(userLocation: userLocation),
                          ),
                        );
                      } catch (e) {
                        // Handle errors (e.g., permissions denied)
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error: $e')),
                        );
                      }
                    },
                    child: _buildCard(
                      title: "Flood Map",
                      child: Container(
                        height: 200,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(15),
                          image: DecorationImage(
                            image: AssetImage("assets/images/flood_map.png"),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Weather Updates
                  _buildCard(
                    title: "Weather Updates",
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _weatherInfo(Icons.cloud, "Rainfall", "12mm"),
                            _weatherInfo(Icons.thermostat, "Temp", "25°C"),
                            _weatherInfo(Icons.wb_sunny, "Forecast", "Rainy"),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Notifications
                  _buildCard(
                    title: "Notifications",
                    child: ListView(
                      shrinkWrap: true,
                      children: [
                        ListTile(
                          leading: Icon(Icons.warning, color: Colors.red),
                          title: Text("High-risk flood area near Riverbank."),
                        ),
                        ListTile(
                          leading: Icon(Icons.info, color: Colors.blue),
                          title: Text("Light rain expected tomorrow."),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard({required String title, required Widget child}) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      elevation: 5,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF003366),
              ),
            ),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }

  Widget _weatherInfo(IconData icon, String label, String value) {
    return Column(
      children: [
        Icon(icon, size: 40, color: Colors.blue),
        const SizedBox(height: 8),
        Text(label, style: TextStyle(color: Colors.grey[600])),
        Text(
          value,
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ],
    );
  }
}