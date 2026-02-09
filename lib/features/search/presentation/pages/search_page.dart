import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;

class SearchPage extends StatefulWidget {
  final double currentLat;
  final double currentLng;
  final String googleMapsApiKey;

  const SearchPage({
    super.key,
    required this.currentLat,
    required this.currentLng,
    required this.googleMapsApiKey,
  });

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _predictions = [];
  bool _isLoading = false;
  Timer? _debounceTimer;

  // Quick search categories
  final List<Map<String, dynamic>> _quickCategories = [
    {'icon': Icons.local_parking, 'label': 'Parking lots', 'query': 'parking lot'},
    {'icon': Icons.local_gas_station, 'label': 'Gas stations', 'query': 'gas station'},
    {'icon': Icons.restaurant, 'label': 'Restaurants', 'query': 'restaurant'},
    {'icon': Icons.local_cafe, 'label': 'Coffee shops', 'query': 'coffee shop'},
    {'icon': Icons.shopping_cart, 'label': 'Grocery stores', 'query': 'grocery store'},
    {'icon': Icons.local_pharmacy, 'label': 'Pharmacies', 'query': 'pharmacy'},
  ];

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      _searchPlaces(query);
    });
  }

  Future<void> _searchPlaces(String query) async {
    if (query.isEmpty) {
      setState(() => _predictions = []);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final url = Uri.parse('https://places.googleapis.com/v1/places:autocomplete');
      
      final requestBody = json.encode({
        'input': query,
        'locationBias': {
          'circle': {
            'center': {
              'latitude': widget.currentLat,
              'longitude': widget.currentLng,
            },
            'radius': 5000.0,
          },
        },
      });

      print('[Loco Search] Requesting Places API (New): $query');
      
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'X-Goog-Api-Key': widget.googleMapsApiKey,
        },
        body: requestBody,
      );

      print('[Loco Search] Status: ${response.statusCode}');
      print('[Loco Search] Body preview: ${response.body.substring(0, response.body.length.clamp(0, 500))}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final suggestions = data['suggestions'] as List<dynamic>? ?? [];
        
        setState(() {
          _predictions = suggestions.where((s) => s['placePrediction'] != null).map((s) {
            final prediction = s['placePrediction'];
            return {
              'description': prediction['text']?['text'] ?? '',
              'place_id': prediction['placeId'] ?? '',
              'main_text': prediction['text']?['text'] ?? '',
              'secondary_text': '',
            };
          }).toList().cast<Map<String, dynamic>>();
        });
      } else {
        print('[Loco Search] Error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('[Loco Search] Error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _selectPlace(String placeId, String name) async {
    if (placeId.isEmpty) return;

    try {
      final url = Uri.parse('https://places.googleapis.com/v1/places/$placeId');
      
      final response = await http.get(
        url,
        headers: {
          'X-Goog-Api-Key': widget.googleMapsApiKey,
          'X-Goog-FieldMask': 'displayName,formattedAddress,location',
        },
      );

      print('[Loco Search] Place details status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final location = data['location'];
        
        if (location != null) {
          final lat = location['latitude'] as double;
          final lng = location['longitude'] as double;
          
          if (mounted) {
            Navigator.pop(context, {
              'lat': lat,
              'lng': lng,
              'name': name,
            });
          }
        }
      }
    } catch (e) {
      print('[Loco Search] Place details error: $e');
    }
  }

  Future<void> _searchCategory(String query) async {
    _searchController.text = query;
    await _searchPlaces(query);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Search header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: TextField(
                        controller: _searchController,
                        autofocus: true,
                        decoration: InputDecoration(
                          hintText: 'Search places...',
                          hintStyle: TextStyle(color: Colors.grey[500]),
                          prefixIcon: Icon(Icons.search, color: Colors.grey[500]),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 20),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => _predictions = []);
                                  },
                                )
                              : null,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onChanged: _onSearchChanged,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Loading indicator
            if (_isLoading)
              const LinearProgressIndicator(minHeight: 2),

            // Results or categories
            Expanded(
              child: _predictions.isEmpty && _searchController.text.isEmpty
                  ? _buildQuickCategories()
                  : _buildSearchResults(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickCategories() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12, top: 4),
          child: Text(
            'Quick Search',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
        ),
        ..._quickCategories.map((cat) => ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(cat['icon'], color: Colors.blue, size: 22),
              ),
              title: Text(
                cat['label'],
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
              ),
              trailing: Icon(Icons.chevron_right, color: Colors.grey[400]),
              onTap: () => _searchCategory(cat['query']),
              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
            )),
      ],
    );
  }

  Widget _buildSearchResults() {
    if (_predictions.isEmpty && _searchController.text.isNotEmpty && !_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 12),
            const Text(
              'No places found',
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _predictions.length,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      itemBuilder: (context, index) {
        final place = _predictions[index];
        return ListTile(
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.place, color: Colors.red[400], size: 22),
          ),
          title: Text(
            place['main_text'] ?? '',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            place['secondary_text'] ?? '',
            style: TextStyle(fontSize: 13, color: Colors.grey[500]),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          onTap: () => _selectPlace(place['place_id'], place['main_text'] ?? ''),
          contentPadding: const EdgeInsets.symmetric(horizontal: 4),
        );
      },
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }
}
