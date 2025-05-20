import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math';
import 'dart:async';

class MapScreen extends StatefulWidget {
  final LatLng userLocation;

  const MapScreen({Key? key, required this.userLocation}) : super(key: key);

  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  bool _showInitialFloodPrompt = false;
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();
  List<LatLng> _markers = [];
  List<Map<String, dynamic>> _suggestions = [];
  List<LatLng> _polylinePoints = [];
  double _distanceInKilometers = 0.0;
  List<Map<String, dynamic>> _routeSteps = [];
  bool _showNavigation = false;
  int _currentStepIndex = 0;
  LatLng? _destination;
  List<Map<String, dynamic>> _floodedRoads = [];
  List<Map<String, dynamic>> _reportedFloods = [];
  bool _showFloodReportPrompt = false;
  Timer? _floodReportTimer;
  int _selectedFloodLevel = 1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _mapController.move(widget.userLocation, 16.0);
      _generateRandomFloodedRoads();

      _floodReportTimer = Timer(const Duration(seconds: 30), () {
        if (mounted) {
          setState(() {
            _showInitialFloodPrompt = true;
            _showFloodReportPrompt = true;
          });

          Timer(const Duration(seconds: 10),  () {
            if (mounted && _showFloodReportPrompt) {
              setState(() {
                _showFloodReportPrompt = false;
              });
            }
          });
        }
      });
    });
  }

  @override
  void dispose() {
    _floodReportTimer?.cancel();
    super.dispose();
  }

  void _generateRandomFloodedRoads() {
    final random = Random();
    final center = widget.userLocation;

    for (int i = 0; i < 10; i++) {
      double latOffset = (random.nextDouble() - 0.5) * 0.04;
      double lngOffset = (random.nextDouble() - 0.5) * 0.04;

      List<LatLng> roadSegment = [];
      for (int j = 0; j < 3; j++) {
        roadSegment.add(LatLng(
          center.latitude + latOffset + (random.nextDouble() - 0.5) * 0.005,
          center.longitude + lngOffset + (random.nextDouble() - 0.5) * 0.005,
        ));
      }

      int floodLevel = random.nextInt(3);
      _floodedRoads.add({
        'points': roadSegment,
        'level': floodLevel,
        'reported': false,
      });
    }
  }

  void _handleMapTap(LatLng position) {
    if (_showFloodReportPrompt) {
      _showFloodLevelDialog(position);
    }
  }

  void _showFloodLevelDialog(LatLng position) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Report Flooding"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Select flood level:"),
              const SizedBox(height: 10),
              DropdownButton<int>(
                value: _selectedFloodLevel,
                items: const [
                  DropdownMenuItem(value: 0, child: Text("Low")),
                  DropdownMenuItem(value: 1, child: Text("Medium")),
                  DropdownMenuItem(value: 2, child: Text("High")),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedFloodLevel = value!;
                  });
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _reportFlood(position, _selectedFloodLevel);
              },
              child: const Text("Report"),
            ),
          ],
        );
      },
    );
  }

  void _reportFlood(LatLng position, int level) {
    setState(() {
      _reportedFloods.add({
        'location': position,
        'level': level,
        'reportedAt': DateTime.now(),
      });
      _showFloodReportPrompt = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Flood reported successfully')),
    );
  }

  Future<void> _searchLocation(String query) async {
    final accessToken = 'pk.eyJ1IjoibGVpMjEyMiIsImEiOiJjbTd2c2xmeTkwMnd2MmtwbndwM3oxcXU2In0.RFUpwh_jz9ozfUavQuoeLA';
    final url = 'https://api.mapbox.com/geocoding/v5/mapbox.places/$query.json?access_token=$accessToken';

    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['features'].isNotEmpty) {
        final coordinates = data['features'][0]['geometry']['coordinates'];
        final lat = coordinates[1];
        final lng = coordinates[0];
        final newLocation = LatLng(lat, lng);

        setState(() {
          _markers.add(newLocation);
          _destination = newLocation;
        });

        _mapController.move(newLocation, 16.0);
        _fetchRoute(widget.userLocation, newLocation);
      }
    } else {
      throw Exception('Failed to load location');
    }
  }

  Future<void> _fetchRoute(LatLng start, LatLng end) async {
    final accessToken = 'pk.eyJ1IjoibGVpMjEyMiIsImEiOiJjbTd2c2xmeTkwMnd2MmtwbndwM3oxcXU2In0.RFUpwh_jz9ozfUavQuoeLA';
    final url = 'https://api.mapbox.com/directions/v5/mapbox/driving/${start.longitude},${start.latitude};${end.longitude},${end.latitude}?geometries=geojson&steps=true&access_token=$accessToken';

    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final route = data['routes'][0]['geometry']['coordinates'];
      final distanceInMeters = data['routes'][0]['distance'];
      final steps = data['routes'][0]['legs'][0]['steps'];

      setState(() {
        _polylinePoints = route.map<LatLng>((coord) => LatLng(coord[1], coord[0])).toList();
        _distanceInKilometers = distanceInMeters / 1000;
        _routeSteps = List<Map<String, dynamic>>.from(steps.map((step) => {
          'instruction': step['maneuver']['instruction'],
          'distance': step['distance'],
          'type': step['maneuver']['type'],
          'modifier': step['maneuver']['modifier'] ?? '',
          'location': LatLng(step['maneuver']['location'][1], step['maneuver']['location'][0]),
        }));
      });
    } else {
      throw Exception('Failed to load route');
    }
  }

  Future<void> _fetchSuggestions(String query) async {
    final accessToken = 'pk.eyJ1IjoibGVpMjEyMiIsImEiOiJjbTd2c2xmeTkwMnd2MmtwbndwM3oxcXU2In0.RFUpwh_jz9ozfUavQuoeLA';
    final url = 'https://api.mapbox.com/geocoding/v5/mapbox.places/$query.json?access_token=$accessToken&autocomplete=true';

    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      setState(() {
        _suggestions = List<Map<String, dynamic>>.from(data['features'].map((feature) => {
          'name': feature['place_name'],
          'coordinates': LatLng(feature['geometry']['coordinates'][1], feature['geometry']['coordinates'][0]),
        }));
      });
    } else {
      throw Exception('Failed to load suggestions');
    }
  }

  void _startNavigation() {
    setState(() {
      _showNavigation = true;
      _currentStepIndex = 0;
    });
  }

  void _nextStep() {
    if (_currentStepIndex < _routeSteps.length - 1) {
      setState(() {
        _currentStepIndex++;
      });
      _mapController.move(_routeSteps[_currentStepIndex]['location'], 16.0);
    }
  }

  void _previousStep() {
    if (_currentStepIndex > 0) {
      setState(() {
        _currentStepIndex--;
      });
      _mapController.move(_routeSteps[_currentStepIndex]['location'], 16.0);
    }
  }

  void _stopNavigation() {
    setState(() {
      _showNavigation = false;
    });
  }

  Color _getFloodColor(int level) {
    switch (level) {
      case 2: return Colors.red;
      case 1: return Colors.orange;
      case 0: return Colors.yellow;
      default: return Colors.purple;
    }
  }

  Widget _buildLegendItem(Color color, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 20,
            height: 20,
            color: color,
          ),
          const SizedBox(width: 8),
          Text(text),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Flood Map", style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF003366),
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.report),
            onPressed: () {
              setState(() {
                _showFloodReportPrompt = true;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Tap on map to report flooding')),
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                center: widget.userLocation,
                zoom: 13.0,
                maxZoom: 18.0,
                interactiveFlags: InteractiveFlag.all,
                onTap: (_, LatLng position) => _handleMapTap(position),
              ),
              children: [
                TileLayer(
                  urlTemplate: "https://api.mapbox.com/styles/v1/lei2122/cm7w5q4jy00nz01sca8pq1998/tiles/256/{z}/{x}/{y}@2x?access_token=pk.eyJ1IjoibGVpMjEyMiIsImEiOiJjbTd2c2xmeTkwMnd2MmtwbndwM3oxcXU2In0.RFUpwh_jz9ozfUavQuoeLA",
                  additionalOptions: {
                    'accessToken': 'pk.eyJ1IjoibGVpMjEyMiIsImEiOiJjbTd2c2xmeTkwMnd2MmtwbndwM3oxcXU2In0.RFUpwh_jz9ozfUavQuoeLA',
                    'id': 'mapbox.mapbox-streets-v8',
                  },
                ),
                PolylineLayer(
                  polylines: _floodedRoads.map((road) {
                    Color roadColor;
                    switch (road['level']) {
                      case 2: roadColor = Colors.red.withOpacity(0.7); break;
                      case 1: roadColor = Colors.orange.withOpacity(0.7); break;
                      default: roadColor = Colors.yellow.withOpacity(0.7);
                    }
                    return Polyline(
                      points: road['points'] as List<LatLng>,
                      color: roadColor,
                      strokeWidth: 8.0,
                    );
                  }).toList(),
                ),
                if (_polylinePoints.isNotEmpty)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: _polylinePoints,
                        color: Colors.blue,
                        strokeWidth: 4.0,
                      ),
                    ],
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
                    ..._markers.map(
                          (marker) => Marker(
                        point: marker,
                        builder: (ctx) => const Icon(
                          Icons.location_on,
                          color: Colors.red,
                          size: 40.0,
                        ),
                      ),
                    ),
                    ..._reportedFloods.map((flood) => Marker(
                      point: flood['location'],
                      builder: (ctx) => Icon(
                        Icons.warning,
                        color: _getFloodColor(flood['level']),
                        size: 40.0,
                      ),
                    )),
                  ],
                ),
              ],
            ),
          ),
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          decoration: const InputDecoration(
                            hintText: 'Search for a location...',
                            border: InputBorder.none,
                          ),
                          onChanged: (value) {
                            if (value.isNotEmpty) {
                              _fetchSuggestions(value);
                            } else {
                              setState(() {
                                _suggestions.clear();
                              });
                            }
                          },
                          onSubmitted: _searchLocation,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.search),
                        onPressed: () => _searchLocation(_searchController.text),
                      ),
                    ],
                  ),
                ),
                if (_suggestions.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _suggestions.length,
                      itemBuilder: (context, index) {
                        final suggestion = _suggestions[index];
                        return ListTile(
                          title: Text(suggestion['name']),
                          onTap: () {
                            setState(() {
                              _markers = [suggestion['coordinates']];
                              _destination = suggestion['coordinates'];
                              _mapController.move(suggestion['coordinates'], 16.0);
                              _suggestions.clear();
                              _searchController.clear();
                            });
                            _fetchRoute(widget.userLocation, suggestion['coordinates']);
                          },
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
          Positioned(
            right: 10,
            top: 100,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.8),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 5,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Flood Levels',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildLegendItem(Colors.red, 'High'),
                  _buildLegendItem(Colors.orange, 'Medium'),
                  _buildLegendItem(Colors.yellow, 'Low'),
                  const SizedBox(height: 8),

                ],
              ),
            ),
          ),

          if (_showFloodReportPrompt)
            Positioned(
              bottom: 100,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const Text(
                      'Report Flooded Area',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text('Tap on the map where you see flooding'),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _showFloodReportPrompt = false;
                            });
                          },
                          child: const Text('Cancel'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

          if (_showInitialFloodPrompt)
            Positioned.fill(
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _showInitialFloodPrompt = false;
                    _showFloodReportPrompt = true;
                  });
                },
                child: Container(
                  color: Colors.black.withOpacity(0.5),
                  child: Center(
                    child: Container(
                      width: MediaQuery.of(context).size.width * 0.8,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.warning_amber_rounded,
                            color: Colors.orange,
                            size: 50,
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            "Help Improve Flood Detection",
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            "We've detected you've been using the map for a while. "
                                "Could you help by reporting any flooded areas you know about?",
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              TextButton(
                                onPressed: () {
                                  setState(() {
                                    _showInitialFloodPrompt = false;
                                  });
                                },
                                child: const Text("Not Now"),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _showInitialFloodPrompt = false;
                                    _showFloodReportPrompt = true;
                                  });
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Tap on map to report flooding'),
                                    ),
                                  );
                                },
                                child: const Text("Report Flood"),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          if (_destination != null && !_showNavigation)
            Positioned(
              bottom: 160,
              left: 16,
              right: 16,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: _startNavigation,
                child: const Text(
                  "GO NOW",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          Positioned(
            bottom: 100,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                "Distance: ${_distanceInKilometers.toStringAsFixed(2)} km",
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          if (_showNavigation && _routeSteps.isNotEmpty)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                height: MediaQuery.of(context).size.height * 0.3,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 10,
                      offset: Offset(0, -5),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Step ${_currentStepIndex + 1} of ${_routeSteps.length}",
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: _stopNavigation,
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _routeSteps[_currentStepIndex]['instruction'],
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "${(_routeSteps[_currentStepIndex]['distance'] / 1000).toStringAsFixed(1)} km",
                              style: const TextStyle(
                                fontSize: 16,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          ElevatedButton(
                            onPressed: _previousStep,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.grey,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text("Previous"),
                          ),
                          ElevatedButton(
                            onPressed: _nextStep,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text("Next"),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (!_showNavigation)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: SizedBox(
                height: MediaQuery.of(context).size.height * 0.5,
                child: DraggableScrollableSheet(
                  initialChildSize: 0.1,
                  minChildSize: 0.1,
                  maxChildSize: 0.5,
                  builder: (context, scrollController) {
                    return Container(
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                      ),
                      child: ListView(
                        controller: scrollController,
                        padding: const EdgeInsets.all(16),
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
                          const SizedBox(height: 16),
                          const Text(
                            "Flood Updates",
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Text("⚠️ ${_floodedRoads.length} system-detected flood areas"),
                          Text("⚠️ ${_reportedFloods.length} user-reported floods"),
                          const Text("🌧️ Light rain expected tomorrow."),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}