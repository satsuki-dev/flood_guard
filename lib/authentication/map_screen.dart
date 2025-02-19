import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class MapScreen extends StatefulWidget {
  final LatLng userLocation;

  const MapScreen({Key? key, required this.userLocation}) : super(key: key);

  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  // Create a MapController to control the map
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();

    // Use a post-frame callback to ensure the map is fully loaded
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Move the map to the user's location and set the zoom level
      _mapController.move(widget.userLocation, 16.0); // Adjust zoom level here
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Flood Map"),
        backgroundColor: Color(0xFF003366),
        elevation: 0,
        centerTitle: true,
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController, // Pass the MapController
            options: MapOptions(
              center: widget.userLocation, // Initial center (user's location)
              zoom: 13.0, // Initial zoom level
            ),
            children: [
              TileLayer(
                urlTemplate: "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
                subdomains: ['a', 'b', 'c'],
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: widget.userLocation,
                    builder: (ctx) => const Icon(
                      Icons.location_on,
                      color: Colors.blue,
                      size: 40.0,
                    ),
                  ),
                ],
              ),
            ],
          ),
          // Search Bar
          Positioned(
            top: 20,
            left: 20,
            right: 20,
            child: Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: "Search for a location...",
                    border: InputBorder.none,
                    suffixIcon: Icon(Icons.search),
                  ),
                  onSubmitted: (value) {
                    // Implement search functionality here
                  },
                ),
              ),
            ),
          ),
          // Zoom Controls
          Positioned(
            bottom: 20,
            right: 20,
            child: Column(
              children: [
                FloatingActionButton(
                  mini: true,
                  onPressed: () {
                    _mapController.move(_mapController.center, _mapController.zoom + 1);
                  },
                  child: Icon(Icons.add),
                ),
                SizedBox(height: 10),
                FloatingActionButton(
                  mini: true,
                  onPressed: () {
                    _mapController.move(_mapController.center, _mapController.zoom - 1);
                  },
                  child: Icon(Icons.remove),
                ),
              ],
            ),
          ),
          // Compass
          Positioned(
            top: 20,
            right: 20,
            child: FloatingActionButton(
              mini: true,
              onPressed: () {
                _mapController.rotate(0); // Reset rotation to north
              },
              child: Icon(Icons.compass_calibration),
            ),
          ),
          // Bottom Sheet
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: DraggableScrollableSheet(
              initialChildSize: 0.1,
              minChildSize: 0.1,
              maxChildSize: 0.5,
              builder: (context, scrollController) {
                return Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  child: ListView(
                    controller: scrollController,
                    padding: EdgeInsets.all(16),
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      SizedBox(height: 16),
                      Text(
                        "Flood Updates",
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 8),
                      Text("High-risk flood area near Riverbank."),
                      Text("Light rain expected tomorrow."),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}