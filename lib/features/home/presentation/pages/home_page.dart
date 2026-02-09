import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase/supabase.dart';
import 'package:get_it/get_it.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../heatmap/data/seed/savannah_parking_data.dart';
import '../../../heatmap/presentation/widgets/threat_marker_builder.dart';
import '../../../heatmap/presentation/widgets/location_detail_sheet.dart';
import '../../../heatmap/presentation/widgets/map_legend.dart';
import '../../../heatmap/presentation/widgets/shield_status_bar.dart';
import 'package:locode/services/notification_verdict.dart';
import 'package:locode/features/scan/presentation/widgets/analysis_bottom_sheet.dart';
import 'package:locode/features/browser/presentation/pages/safe_browser_page.dart';
import 'package:locode/features/scan/domain/services/deep_analysis_service.dart';
import 'package:locode/features/search/presentation/pages/search_page.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  Set<Marker> _parkingMarkers = {};
  bool _isLoading = true;
  bool _isAnalyzing = false;
  bool _isCenteredOnUser = true;
  bool _isAnimating = false;
  bool _isLocationOverridden = false;
  DateTime? _lastParkingFetch;
  LatLng? _currentPosition;
  ParkingLocation? _selectedLocation;
  Offset? _selectedMarkerScreenPosition;
  String? _lastScannedUrl;
  
  BitmapDescriptor? _redPin;
  BitmapDescriptor? _greenPin;
  BitmapDescriptor? _grayPin;
  BitmapDescriptor? _currentLocationIcon;
  BitmapDescriptor? _parkingIcon;

  StreamSubscription<Position>? _positionStream;
  StreamSubscription<CompassEvent>? _compassStream;
  double _currentHeading = 0.0;

  static const _urlEventChannel = EventChannel('com.loco/url_events');
  static const _notifChannel = MethodChannel('com.loco/notifications');
  static const _scanChannel = MethodChannel('com.loco/scan');

  // Fallback: Center of the US
  static const _initialPosition = CameraPosition(
    target: LatLng(39.8283, -98.5795),
    zoom: 3.5,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    NotificationVerdict.init(); 
    _requestNotificationPermission();
    _loadCustomMarkers().then((_) {
      _loadMarkers();
      _loadCurrentLocationIcon();
      _startLocationTracking();
      _startCompass();
    });
    // Check for deep link and init reports on startup
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initRealtimeReports();
      _checkPendingUrl();
    });

    // Listen for intercepted URLs
    _urlEventChannel.receiveBroadcastStream().listen((event) {
      if (event is String) {
        if (event.startsWith('ANALYZE:')) {
          final url = event.substring(8);
          if (!mounted) return;
          setState(() => _lastScannedUrl = url);
          _runBackgroundAnalysis(url);
        } else if (event.startsWith('OPEN_SAFE:')) {
          print('[Locode] Received OPEN_SAFE event: $event');
          _handleOpenSafeEvent(event);
        }
      }
    });
  }

  Future<void> _loadCurrentLocationIcon() async {
    try {
      final icon = await _loadSvgIcon('assets/icons/Currentlocation.svg', 50);
      if (mounted) {
        setState(() {
          _currentLocationIcon = icon;
        });
      }
    } catch (e) {
      debugPrint('[Locode] Error loading current location icon: $e');
    }
  }

  void _startLocationTracking() {
    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5, // Update every 5 meters
      ),
    ).listen((Position position) {
      if (!mounted) return;
      
      // If user has searched for a place, don't let real GPS move the marker away
      if (_isLocationOverridden) return;

      _currentPosition = LatLng(position.latitude, position.longitude);
      _updateMyLocationMarker();
      _loadNearbyParkingLots();
    });
  }

  void _startCompass() {
    _compassStream = FlutterCompass.events?.listen((CompassEvent event) {
      if (event.heading != null) {
        if (!mounted) return;
        _currentHeading = event.heading!;
        _updateMyLocationMarker();
      }
    });
  }

  void _updateMyLocationMarker() {
    if (_currentPosition == null || _currentLocationIcon == null) return;
    
    if (!mounted) return;
    setState(() {
      _markers.removeWhere((m) => m.markerId == const MarkerId('my_location'));
      _markers.add(
        Marker(
          markerId: const MarkerId('my_location'),
          position: _currentPosition!,
          icon: _currentLocationIcon!,
          rotation: _currentHeading,
          anchor: const Offset(0.5, 0.5),
          flat: true,
          zIndex: 999,
          infoWindow: InfoWindow.noText,
        ),
      );
    });
  }

  Future<void> _loadCustomMarkers() async {
    try {
      _redPin = await _loadSvgIcon('assets/icons/Red.svg', 50);
      _greenPin = await _loadSvgIcon('assets/icons/Green.svg', 50);
      _grayPin = await _loadSvgIcon('assets/icons/Gray.svg', 50);
      
      // Initialize custom parking icon using Canvas
      final double dpr = MediaQuery.of(context).devicePixelRatio;
      final int size = (80 * dpr).toInt();
      final ui.PictureRecorder recorder = ui.PictureRecorder();
      final ui.Canvas canvas = ui.Canvas(recorder);
      final ui.Paint paint = ui.Paint()..color = const Color(0xFF1A5276); // App brand color
      
      // Draw rounded rectangle
      final ui.RRect rrect = ui.RRect.fromLTRBR(
        0, 0, size.toDouble(), size.toDouble(), 
        ui.Radius.circular(16 * dpr),
      );
      canvas.drawRRect(rrect, paint);
      
      // Draw white 'P'
      final ui.ParagraphBuilder pb = ui.ParagraphBuilder(
        ui.ParagraphStyle(
          textAlign: ui.TextAlign.center,
          fontSize: 48 * dpr,
          fontWeight: ui.FontWeight.bold,
        ),
      );
      pb.pushStyle(ui.TextStyle(color: Colors.white));
      pb.addText('P');
      final ui.Paragraph paragraph = pb.build();
      paragraph.layout(ui.ParagraphConstraints(width: size.toDouble()));
      canvas.drawParagraph(
        paragraph, 
        Offset(0, (size - paragraph.height) / 2),
      );
      
      final ui.Image image = await recorder.endRecording().toImage(size, size);
      final ByteData? bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      if (bytes != null) {
        _parkingIcon = BitmapDescriptor.bytes(bytes.buffer.asUint8List(), width: 80, height: 80);
      }

      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('[Locode] Error loading custom markers: $e');
    }
  }

  String _getDisplayLabel(ThreatStatus? status) {
    switch (status) {
      case ThreatStatus.safe:
        return 'VERIFIED SAFE';
      case ThreatStatus.reported:
        return 'SCAM REPORTED';
      default:
        return 'UNKNOWN';
    }
  }

  Color _getDisplayColor(ThreatStatus? status) {
    switch (status) {
      case ThreatStatus.safe:
        return const Color(0xFF2ECC40);
      case ThreatStatus.reported:
        return const Color(0xFFE74C3C);
      default:
        return const Color(0xFF9E9E9E);
    }
  }

  Future<BitmapDescriptor> _loadSvgIcon(String svgPath, double logicalSize) async {
    final String svgString = await rootBundle.loadString(svgPath);
    
    // Get device pixel ratio for crisp rendering
    final double dpr = MediaQuery.of(context).devicePixelRatio;
    final double pixelSize = logicalSize * dpr;
    
    final PictureInfo pictureInfo = await vg.loadPicture(SvgStringLoader(svgString), null);
    
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final ui.Canvas canvas = ui.Canvas(recorder);
    
    final double scale = pixelSize / pictureInfo.size.width;
    canvas.scale(scale, scale);
    canvas.drawPicture(pictureInfo.picture);
    pictureInfo.picture.dispose();
    
    final ui.Image image = await recorder.endRecording().toImage(
      pixelSize.toInt(),
      (pictureInfo.size.height * scale).toInt(),
    );
    
    final ByteData? bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.bytes(
      bytes!.buffer.asUint8List(),
      width: logicalSize,
      height: logicalSize * (pictureInfo.size.height / pictureInfo.size.width),
    );
  }

  void _handleOpenSafeEvent(String event) {
    // Format: OPEN_SAFE:verdict|riskScore|summary|url
    try {
      final data = event.substring(10);
      final parts = data.split('|');
      if (parts.length >= 4) {
        final verdict = parts[0];
        final riskScore = int.tryParse(parts[1]) ?? 0;
        final summary = parts[2];
        final url = parts.sublist(3).join('|'); // Rejoin in case URL had |
        
        _openSafeBrowser(url, verdict, summary, riskScore: riskScore);
      }
    } catch (e) {
      debugPrint('Error parsing OPEN_SAFE event: $e');
    }
  }

  Future<void> _checkPendingUrl() async {
    try {
      final pending = await _scanChannel.invokeMethod<String>('getLastScannedUrl');
      if (pending != null) {
        if (pending.startsWith('OPEN_SAFE:')) {
          await _scanChannel.invokeMethod('clearLastScannedUrl');
          _handleOpenSafeEvent(pending);
        } else if (pending.startsWith('ANALYZE:')) {
          final url = pending.substring(8);
          if (!mounted) return;
          setState(() => _lastScannedUrl = url);
          await _scanChannel.invokeMethod('clearLastScannedUrl');
          _runBackgroundAnalysis(url);
        }
      }
    } catch (e) {
      debugPrint('Error checking pending URL: $e');
    }
  }

  void _onMarkerTapped(ParkingLocation location) async {
    if (_mapController == null) return;
    final screenCoord = await _mapController!.getScreenCoordinate(
      LatLng(location.latitude, location.longitude),
    );
    final devicePixelRatio = MediaQuery.of(context).devicePixelRatio;
    
    if (!mounted) return;
    setState(() {
      _selectedLocation = location;
      _selectedMarkerScreenPosition = Offset(
        screenCoord.x.toDouble() / devicePixelRatio,
        screenCoord.y.toDouble() / devicePixelRatio,
      );
    });
  }

  Future<void> _updatePopupPosition() async {
    if (_selectedLocation == null || _mapController == null) return;
    
    final screenCoord = await _mapController!.getScreenCoordinate(
      LatLng(_selectedLocation!.latitude, _selectedLocation!.longitude),
    );
    final devicePixelRatio = MediaQuery.of(context).devicePixelRatio;
    
    if (!mounted) return;
    setState(() {
      _selectedMarkerScreenPosition = Offset(
        screenCoord.x.toDouble() / devicePixelRatio,
        screenCoord.y.toDouble() / devicePixelRatio,
      );
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPendingUrl();
    }
  }

  Future<void> _requestNotificationPermission() async {
    if (Platform.isAndroid) {
      await Permission.notification.request();
    }
  }

  /// Runs the autonomous analysis in background and updates the notification
  Future<void> _runBackgroundAnalysis(String url) async {
    if (_isAnalyzing) {
      print('[Locode] Analysis already in progress, skipping duplicate');
      return;
    }
    _isAnalyzing = true;
    if (!mounted) return;
    setState(() => _lastScannedUrl = url);
    print('[Locode] Starting autonomous agent analysis for: $url');
    
    try {
        // Show initial "analyzing" notification via MethodChannel for heads-up
        await _notifChannel.invokeMethod('updateNotification', {
            'title': '🛡️ Analyzing Link...',
            'body': 'Locode agent is investigating: $url',
            'verdict': 'suspicious',
            'summary': '',
            'url': url,
            'risk_score': 50,
            'ongoing': true,
        });

        final apiKey = GetIt.instance<String>(instanceName: 'geminiApiKey');
        final service = DeepAnalysisService(apiKey);
        int stepCount = 0;
    
        final result = await service.analyzeUrl(
            url,
            onStep: (action, detail) async {
                stepCount++;
                print('[Locode] Agent step #$stepCount: $action — $detail');
                try {
                    await _notifChannel.invokeMethod('updateNotification', {
                        'title': '$action (Step $stepCount)',
                        'body': detail.length > 100 ? detail.substring(0, 100) + '...' : detail,
                        'verdict': 'suspicious',
                        'summary': '',
                        'url': url,
                        'risk_score': 50,
                        'ongoing': true,
                    });
                } catch (e) {
                    print('[Locode] Notification update failed: $e');
                }
            },
        );

        print('[Locode] Agent complete. Verdict: ${result['verdict']}, Score: ${result['risk_score']}, Tools used: ${result['tool_calls']}');

        final verdict = result['verdict'] as String? ?? 'suspicious';
        final riskScore = result['risk_score'] as int? ?? 50;
        final summary = result['summary'] as String? ?? 'Analysis complete.';
        final toolCalls = result['tool_calls'] ?? 0;

        String title;
        if (verdict == 'safe') {
          title = '✅ Safe - $url';
        } else if (verdict == 'dangerous') {
          title = '🚨 Dangerous - $url';
        } else {
          title = '⚠️ Suspicious - $url';
        }

        // Update the native notification state to non-ongoing (Heads-up)
        await _notifChannel.invokeMethod('updateNotification', {
            'title': title,
            'body': 'Risk: $riskScore/100 · $toolCalls checks · $summary',
            'verdict': verdict,
            'summary': summary,
            'url': url,
            'risk_score': riskScore,
            'ongoing': false,
        });

    } catch (e, stackTrace) {
        print('[Locode] Agent FAILED: $e');
        print('[Locode] Stack: $stackTrace');
        
        await _notifChannel.invokeMethod('updateNotification', {
            'title': '⚠️ Analysis incomplete',
            'body': 'Risk: 50/100 · Agent could not complete analysis.',
            'verdict': 'suspicious',
            'summary': 'Analysis incomplete.',
            'url': url,
            'risk_score': 50,
            'ongoing': false,
        });
    } finally {
      _isAnalyzing = false;
    }
  }

  void _openSafeBrowser(String url, String verdict, String summary, {int riskScore = 0}) {
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SafeBrowserPage(
          url: url,
          verdict: verdict,
          summary: summary,
          riskScore: riskScore,
        ),
      ),
    );
  }

  Future<void> _loadNearbyParkingLots({double? lat, double? lng}) async {
    final searchLat = lat ?? _currentPosition?.latitude;
    final searchLng = lng ?? _currentPosition?.longitude;
    
    if (searchLat == null || searchLng == null) return;
    
    // Only apply the 30s fetch throttle if we are NOT searching at an explicit location
    if (lat == null && lng == null) {
      if (_lastParkingFetch != null && 
          DateTime.now().difference(_lastParkingFetch!) < const Duration(seconds: 30)) {
        return;
      }
      _lastParkingFetch = DateTime.now();
    }
    
    try {
      const apiKey = 'AIzaSyCVb27f28ISC8Vu8AyPlp7Ei1fCt3tUMqc';
      final url = Uri.parse('https://places.googleapis.com/v1/places:searchNearby');
      
      List<dynamic> allPlaces = [];
      String? nextPageToken;
      int pagesFetched = 0;

      Future<void> fetchPage(String? token) async {
        final body = {
          'includedTypes': ['parking'],
          'maxResultCount': 20,
          'locationRestriction': {
            'circle': {
              'center': {'latitude': searchLat, 'longitude': searchLng},
              'radius': 3000.0,
            },
          },
        };
        if (token != null) {
          body['pageToken'] = token;
        }

        final response = await http.post(
          url,
          headers: {
            'Content-Type': 'application/json',
            'X-Goog-Api-Key': apiKey,
            'X-Goog-FieldMask': 'places.displayName,places.formattedAddress,places.location,places.id,places.rating,places.regularOpeningHours,nextPageToken',
          },
          body: json.encode(body),
        );

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final List<dynamic>? places = data['places'];
          if (places != null) {
            allPlaces.addAll(places);
          }
          nextPageToken = data['nextPageToken'];
          pagesFetched++;
        } else {
          print('[Locode] Places API error: ${response.body}');
          nextPageToken = null;
        }
      }

      // Fetch first page
      print('[Locode] Fetching parking lots near $searchLat,$searchLng (Page 1)');
      await fetchPage(null);

      // Fetch second page if exists
      if (nextPageToken != null && pagesFetched < 2) {
        print('[Locode] Waiting 2s for nextPageToken to become valid...');
        await Future.delayed(const Duration(seconds: 2));
        print('[Locode] Fetching Page 2');
        await fetchPage(nextPageToken);
      }

      final Set<Marker> newMarkers = {};
      for (final place in allPlaces) {
        final location = place['location'];
        if (location == null) continue;

        final name = place['displayName']?['text'] ?? 'Parking';
        final placeId = place['id'] ?? '${location['latitude']}';
        final rating = place['rating']?.toString() ?? '';
        final isOpen = place['regularOpeningHours']?['openNow'];
        final address = place['formattedAddress'] ?? '';
        
        String snippet = 'QR Payment Zone';
        if (rating.isNotEmpty) snippet += ' • Rating: $rating';
        if (isOpen == true) snippet += ' • Open';
        if (isOpen == false) snippet += ' • Closed';
        
        newMarkers.add(
          Marker(
            markerId: MarkerId('parking_$placeId'),
            position: LatLng(
              location['latitude'].toDouble(),
              location['longitude'].toDouble(),
            ),
            icon: _parkingIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
            infoWindow: InfoWindow(
              title: '🅿️ $name',
              snippet: snippet,
            ),
            zIndex: 0,
            onTap: () {
              print('[Locode] Tapped parking: $name at $address');
            },
          ),
        );
      }
      
      if (mounted) {
        setState(() {
          _parkingMarkers = newMarkers;
        });
      }
      print('[Locode] Loaded ${allPlaces.length} parking lots ($pagesFetched pages)');
    } catch (e) {
      print('[Locode] Parking fetch error: $e');
    }
  }

  void _onLocationButtonPressed() async {
    if (_currentPosition == null) return;
    
    // Set animating flag FIRST to block onCameraMove
    _isAnimating = true;

    // Set state IMMEDIATELY so icon changes right away
    if (!mounted) return;
    setState(() {
      _isCenteredOnUser = true;
    });
    
    await _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: _currentPosition!,
          zoom: 16.0,
          bearing: 0,
        ),
      ),
    );
    
    // Wait a short moment AFTER animation completes before re-enabling onCameraMove detection
    await Future.delayed(const Duration(milliseconds: 300));

    // Animation done, allow camera move detection again
    if (mounted) {
      _isAnimating = false;
    }
  }

  Future<void> _onMapCreated(GoogleMapController controller) async {
    _mapController = controller;
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.always || permission == LocationPermission.whileInUse) {
        final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium,
        );
        controller.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: LatLng(position.latitude, position.longitude),
              zoom: 14.0,
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('[Map] Could not get location: $e');
    }
  }

  Future<void> _loadMarkers() async {
    final seedMarkers = await ThreatMarkerBuilder.buildMarkers(
      locations: savannahParkingData,
      onTap: (location) => _onMarkerTapped(location),
      redPin: _redPin,
      greenPin: _greenPin,
      grayPin: _grayPin,
    );

    if (mounted) {
      setState(() {
        _markers = seedMarkers;
        _isLoading = false;
      });
    }
  }

  void _initRealtimeReports() {
    try {
      final supabase = GetIt.instance<SupabaseClient>();
      supabase
          .channel('public:scams')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'scams',
            callback: (payload) {
              final newReport = payload.newRecord;
              final lat = newReport['latitude'] as double;
              final lng = newReport['longitude'] as double;

              if (mounted) {
                setState(() {
                  _markers.add(Marker(
                    markerId: MarkerId('live_report_${newReport['id']}'),
                    position: LatLng(lat, lng),
                    icon: _redPin ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
                    infoWindow: InfoWindow.noText,
                  ));
                });
              }
            },
          )
          .subscribe();
    } catch (e) {
      debugPrint('[HomePage] Supabase not initialized or available: $e');
    }
  }

  void _showLocationDetail(ParkingLocation location) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => LocationDetailSheet(location: location),
    );
  }

  void _showDetailedReportSheet(ParkingLocation location) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.55,
        minChildSize: 0.3,
        maxChildSize: 0.85,
        expand: false,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SingleChildScrollView(
            controller: scrollController,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Drag handle
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 16),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                // === VERDICT BANNER ===
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: _getVerdictColor(location.status),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _getVerdictIcon(location.status),
                          color: Colors.white,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _getVerdictLabel(location.status).toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _getVerdictSubtitle(location.status),
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.9),
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // === LOCATION NAME ===
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    location.name,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),

                // === ADDRESS ===
                Padding(
                  padding: const EdgeInsets.only(left: 20, right: 20, top: 4),
                  child: Text(
                    location.address,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ),

                // === STAR RATING ===
                if (location.rating != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 20, right: 20, top: 8),
                    child: Row(
                      children: [
                        ...List.generate(5, (index) {
                          final rating = location.rating!;
                          if (index < rating.floor()) {
                            return const Icon(Icons.star, color: Colors.amber, size: 20);
                          } else if (index < rating) {
                            return const Icon(Icons.star_half, color: Colors.amber, size: 20);
                          } else {
                            return const Icon(Icons.star_border, color: Colors.amber, size: 20);
                          }
                        }),
                        const SizedBox(width: 6),
                        Text(
                          location.rating!.toStringAsFixed(1),
                          style: TextStyle(fontSize: 14, color: Colors.grey[700], fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),

                // === QR CODE INDICATOR ===
                if (location.hasQrPayment)
                  Padding(
                    padding: const EdgeInsets.only(left: 20, right: 20, top: 12),
                    child: Row(
                      children: [
                        Icon(Icons.qr_code_2, size: 20, color: Colors.grey[700]),
                        const SizedBox(width: 8),
                        Text(
                          'QR code payment system present',
                          style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 16),

                // === DETAILS CARD ===
                if (location.note != null && location.note!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Details',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[800],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            location.note!,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[700],
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                const SizedBox(height: 20),

                // === GET DIRECTIONS BUTTON ===
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.directions_rounded, color: Color(0xFF1A5276), size: 22),
                      label: const Text(
                        'Get Directions',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF1A5276)),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFF1A5276)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: () {
                        final url = 'https://www.google.com/maps/dir/?api=1&destination=${location.latitude},${location.longitude}';
                        launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                      },
                    ),
                  ),
                ),

                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _getVerdictColor(ThreatStatus status) {
    switch (status) {
      case ThreatStatus.reported:
        return const Color(0xFFE74C3C); // Red
      case ThreatStatus.safe:
        return const Color(0xFF2ECC40); // Green
      case ThreatStatus.suspicious:
        return const Color(0xFFE67E22); // Orange
      default:
        return const Color(0xFF9E9E9E); // Grey
    }
  }

  IconData _getVerdictIcon(ThreatStatus status) {
    switch (status) {
      case ThreatStatus.reported:
        return Icons.dangerous_rounded;
      case ThreatStatus.safe:
        return Icons.verified_rounded;
      case ThreatStatus.suspicious:
        return Icons.warning_rounded;
      default:
        return Icons.help_outline_rounded;
    }
  }

  String _getVerdictLabel(ThreatStatus status) {
    switch (status) {
      case ThreatStatus.reported:
        return 'Scam Reported';
      case ThreatStatus.safe:
        return 'Verified Safe';
      case ThreatStatus.suspicious:
        return 'Suspicious';
      default:
        return 'Unknown';
    }
  }

  String _getVerdictSubtitle(ThreatStatus status) {
    switch (status) {
      case ThreatStatus.safe:
        return 'This QR code has been verified as safe';
      case ThreatStatus.reported:
        return 'This QR code has been reported as dangerous';
      case ThreatStatus.suspicious:
        return 'QR payment complaints found — use with caution';
      default:
        return 'scan carefully - QR payment present but no reports yet.';
    }
  }

  void _showThankYouPopup() {
    Future.delayed(const Duration(milliseconds: 350), () {
      showGeneralDialog(
        context: context,
        barrierDismissible: true,
        barrierLabel: 'Thank you popup',
        barrierColor: Colors.transparent,
        transitionDuration: const Duration(milliseconds: 350),
        pageBuilder: (context, animation, secondaryAnimation) => const SizedBox(),
        transitionBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 1),
              end: Offset.zero,
            ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 50, left: 24, right: 24),
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.green.withOpacity(0.25),
                          blurRadius: 20,
                          spreadRadius: 2,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.check_circle_rounded, color: Colors.green.shade600, size: 28),
                            ),
                            const SizedBox(width: 14),
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Thanks for your feedback!',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green.shade700,
                                    decoration: TextDecoration.none,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Helping keep the community safe',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                    fontWeight: FontWeight.normal,
                                    decoration: TextDecoration.none,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.popUntil(context, (route) => route.isFirst);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green.shade600,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text('Back to Map'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      );

      // Auto-dismiss and go back home after 2 seconds
      Future.delayed(const Duration(milliseconds: 2000), () {
        if (mounted) {
          Navigator.popUntil(context, (route) => route.isFirst);
        }
      });
    });
  }

  void _showReportSheet(BuildContext context, {String? initialUrl}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ReportSheet(
        initialUrl: initialUrl ?? _lastScannedUrl,
        onSuccess: () {
          if (!mounted) return;
          setState(() {
            _selectedLocation = null;
            _selectedMarkerScreenPosition = null;
          });
          _showThankYouPopup();
        },
      ),
    );
  }

  void _showDemoScanDialog() {
    final controller = TextEditingController(text: "https://paypa1-secure.xyz/login");
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Test URL (Demo)'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Enter URL to analyze',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final url = controller.text.trim();
              if (url.isNotEmpty) {
                Navigator.pop(context);
                
                // Store for Report flow
                await _scanChannel.invokeMethod('setLastScannedUrl', url);
                
                _handleInterceptedUrl(url);
              }
            },
            child: const Text('Analyze'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleInterceptedUrl(String url) async {
    if (!mounted) return;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AnalysisBottomSheet(
        url: url,
        onReport: () => _showReportSheet(context, initialUrl: url),
      ),
    );
  }

  void _openSearchSheet() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SearchPage(
          currentLat: _initialPosition.target.latitude,
          currentLng: _initialPosition.target.longitude,
          googleMapsApiKey: 'AIzaSyCVb27f28ISC8Vu8AyPlp7Ei1fCt3tUMqc',
        ),
      ),
    );

    if (result != null && result is Map<String, dynamic>) {
      final lat = result['lat'] as double;
      final lng = result['lng'] as double;

      // 2. Animate the map camera to the selected location
      await _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(LatLng(lat, lng), 15.0),
      );

      // 3. Update _currentPosition to the searched location so parking loads there
      if (!mounted) return;
      setState(() {
        _isLocationOverridden = true;
        _currentPosition = LatLng(lat, lng);
        _isCenteredOnUser = false;
      });

      _updateMyLocationMarker();

      // 4. Call _loadNearbyParkingLots() to fetch parking lots at the NEW searched location
      _loadNearbyParkingLots(lat: lat, lng: lng);
    }
  }

  void _showSettingsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (_) => SettingsSheet(
        onTestUrl: () {
          Navigator.pop(context);
          _showDemoScanDialog();
        },
      ),
    );
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    _compassStream?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Widget _buildMiniPopup() {
    final color = _getDisplayColor(_selectedLocation?.status);
    final label = _getDisplayLabel(_selectedLocation?.status);

    return Positioned(
      left: _selectedMarkerScreenPosition!.dx - 100, // center the 200px wide popup
      top: _selectedMarkerScreenPosition!.dy - 80, // above the pin
      child: GestureDetector(
        onTap: () {
          _showDetailedReportSheet(_selectedLocation!);
          if (!mounted) return;
          setState(() {
            _selectedLocation = null;
            _selectedMarkerScreenPosition = null;
          });
        },
        child: Container(
          width: 200,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 8,
                offset: const Offset(0, 2),
              )
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _selectedLocation!.name,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // ── LAYER 1: Full-screen Map ──
          GoogleMap(
            initialCameraPosition: _initialPosition,
            onMapCreated: _onMapCreated,
            markers: {
              ..._markers,
              ..._parkingMarkers,
            },
            myLocationEnabled: false,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            onCameraMove: (position) {
              // Do NOT toggle state while animating — this causes the double-tap bug
              if (_isAnimating) return;

              if (_selectedLocation != null) {
                _updatePopupPosition();
              }
              
              if (_isCenteredOnUser) {
                if (!mounted) return;
                setState(() {
                  _isCenteredOnUser = false;
                });
              }
            },
            onCameraIdle: () async {
              if (_isAnimating) return;

              final bounds = await _mapController?.getVisibleRegion();
              if (bounds != null) {
                final center = LatLng(
                  (bounds.northeast.latitude + bounds.southwest.latitude) / 2,
                  (bounds.northeast.longitude + bounds.southwest.longitude) / 2,
                );
                _loadNearbyParkingLots(lat: center.latitude, lng: center.longitude);
              }
            },
            onTap: (_) {
              if (!mounted) return;
              setState(() {
                _selectedLocation = null;
                _selectedMarkerScreenPosition = null;
              });
            },
          ),

          // ── LAYER 1.5: Mini Popup ──
          if (_selectedLocation != null && _selectedMarkerScreenPosition != null)
            _buildMiniPopup(),

          // ── LAYER 2: Top bar overlay ──
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  // Search bar - takes most space
                  Expanded(
                    child: GestureDetector(
                      onTap: _openSearchSheet,
                      child: Container(
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            const SizedBox(width: 16),
                            const Icon(Icons.search, color: Colors.grey),
                            const SizedBox(width: 12),
                            Text(
                              'Search places...',
                              style: TextStyle(
                                color: Colors.grey[500],
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Settings button
                  Container(
                    height: 48,
                    width: 48,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: IconButton(
                      icon: Icon(Icons.settings, color: Colors.grey[700]),
                      onPressed: () => _showSettingsSheet(context),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── LAYER 3: Legend (bottom-left) ──
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 24,
            left: 16,
            child: const MapLegend(),
          ),

          // ── LAYER 3.5: Map Control Toggle Button (bottom-left) ──
          Positioned(
            left: 16,
            bottom: MediaQuery.of(context).padding.bottom + 160,
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: _isCenteredOnUser ? Colors.white : const Color(0xFF3F3F46).withOpacity(0.40),
                shape: BoxShape.circle,
                boxShadow: _isCenteredOnUser 
                  ? [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.10),
                        blurRadius: 5.6,
                        offset: const Offset(0, 2.8),
                      ),
                      BoxShadow(
                        color: Colors.black.withOpacity(0.09),
                        blurRadius: 9.8,
                        offset: const Offset(0, 9.8),
                      ),
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 12.6,
                        offset: const Offset(0, 21),
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.10),
                        blurRadius: 5.6,
                        offset: const Offset(0, 2.8),
                      ),
                    ],
              ),
              child: IconButton(
                padding: EdgeInsets.zero,
                icon: _isCenteredOnUser 
                  ? const Icon(
                      Icons.my_location,
                      color: Color(0xFF323232),
                      size: 24,
                    )
                  : SvgPicture.asset(
                      'assets/icons/recenter_icon.svg',
                      width: 28,
                      height: 28,
                    ),
                onPressed: () async {
                  if (_currentPosition == null) return;
                  
                  _isAnimating = true;  // plain assignment, NOT inside setState
                  
                  if (!mounted) return;
                  setState(() {
                    _isCenteredOnUser = true;
                  });
                  
                  await _mapController?.animateCamera(
                    CameraUpdate.newCameraPosition(
                      CameraPosition(
                        target: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
                        zoom: 16.0,
                        bearing: 0,
                      ),
                    ),
                  );
                  
                  // Wait a short moment AFTER animation completes before re-enabling onCameraMove detection
                  // This prevents the final onCameraMove callback from resetting the icon
                  await Future.delayed(const Duration(milliseconds: 300));
                  
                  if (mounted) {
                    _isAnimating = false;
                  }
                },
              ),
            ),
          ),

          // ── LAYER 4: Action button (bottom-center) ──
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 24,
            left: 0,
            right: 0,
            child: Center(
              child: ReportButton(
                onPressed: () => _showReportSheet(context),
              ),
            ),
          ),

          if (_isLoading)
            const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}

class ReportButton extends StatelessWidget {
  final VoidCallback onPressed;
  const ReportButton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 6,
      borderRadius: BorderRadius.circular(28),
      color: Colors.black87,
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: onPressed,
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.flag_outlined, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text(
                'Report',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SettingsSheet extends StatelessWidget {
  final VoidCallback onTestUrl;
  const SettingsSheet({super.key, required this.onTestUrl});

  static const _scanChannel = MethodChannel('com.loco/scan');

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text('Settings', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),

          ListTile(
            leading: const Icon(Icons.language),
            title: const Text('Set as Default Browser'),
            subtitle: const Text('Required for camera scanning protection'),
            trailing: const Icon(Icons.open_in_new, size: 18),
            onTap: () async {
              await _scanChannel.invokeMethod('openDefaultBrowserSettings');
            },
          ),

          ListTile(
            leading: const Icon(Icons.link),
            title: const Text('Test URL (Demo)'),
            subtitle: const Text('Manually enter a URL to analyze'),
            onTap: onTestUrl,
          ),

          const Divider(),

          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('About Locode'),
            subtitle: const Text('Version 1.0.0 (Gemini 3 Hackathon)'),
            onTap: () {},
          ),

          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text('Privacy Policy'),
            onTap: () {},
          ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class ReportSheet extends StatefulWidget {
  final String? initialUrl;
  final VoidCallback? onSuccess;
  const ReportSheet({super.key, this.initialUrl, this.onSuccess});

  @override
  State<ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<ReportSheet> {
  final _urlController = TextEditingController();
  String? _selectedFlow; // 'safe' or 'scam'
  String? _scamCategory;
  bool _isAutoFilled = false;

  static const _scanChannel = MethodChannel('com.loco/scan');

  @override
  void initState() {
    super.initState();
    if (widget.initialUrl != null) {
      _urlController.text = widget.initialUrl!;
    } else {
      _loadLastScannedUrl();
    }
  }

  Future<void> _loadLastScannedUrl() async {
    try {
      final String? url = await _scanChannel.invokeMethod('getLastScannedUrl');
      if (url != null && url.isNotEmpty && mounted) {
        setState(() {
          _urlController.text = url;
          _isAutoFilled = true;
        });
        // Clear it so it doesn't persist forever
        await _scanChannel.invokeMethod('clearLastScannedUrl');
      }
    } catch (e) {
      debugPrint('[ReportSheet] No last scanned URL: $e');
    }
  }

  final _scamCategories = [
    'Phishing / Fake Login',
    'Asked for Money',
    'Spam / Popups',
    'Blocked by Browser',
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
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
            const SizedBox(height: 20),

            Row(
              children: [
                if (_selectedFlow != null)
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios, size: 20),
                    onPressed: () {
                      if (!mounted) return;
                      setState(() {
                        _selectedFlow = null;
                        _scamCategory = null;
                      });
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                if (_selectedFlow != null) const SizedBox(width: 8),
                const Text(
                  'Report a QR Code',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Enter the URL from the QR code you want to report.',
              style: TextStyle(fontSize: 14, color: Colors.black54),
            ),
            const SizedBox(height: 16),

            if (_isAutoFilled) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.qr_code, size: 14, color: Colors.blue),
                    SizedBox(width: 4),
                    Text(
                      'Auto-filled from your last scan',
                      style: TextStyle(fontSize: 12, color: Colors.blue),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],

            TextField(
              controller: _urlController,
              decoration: InputDecoration(
                hintText: 'https://example.com/...',
                prefixIcon: const Icon(Icons.link),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey[50],
              ),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 24),

            if (_selectedFlow == null) ...[
              const Text(
                'What did you find?',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),

              _flowButton(
                icon: Icons.check_circle_outline,
                color: Colors.green,
                title: 'It was safe',
                subtitle: 'Verify the destination to help the community',
                onTap: () => _submitReport('safe', 'confirmed_safe'),
              ),
              const SizedBox(height: 10),

              _flowButton(
                icon: Icons.warning_amber_rounded,
                color: Colors.red,
                title: 'Something was wrong',
                subtitle: 'Alert others about this link',
                onTap: () {
                  if (!mounted) return;
                  setState(() => _selectedFlow = 'scam');
                },
              ),
            ],

            if (_selectedFlow == 'scam') ...[
              const Text(
                'What was wrong?',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              const Text(
                'Select the issue to alert others.',
                style: TextStyle(fontSize: 14, color: Colors.black54),
              ),
              const SizedBox(height: 16),

              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _scamCategories.map((category) {
                  final isSelected = _scamCategory == category;
                  return ChoiceChip(
                    label: Text(category),
                    selected: isSelected,
                    selectedColor: Colors.red[100],
                    onSelected: (selected) {
                      if (!mounted) return;
                      setState(() => _scamCategory = selected ? category : null);
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _scamCategory != null
                      ? () => _submitReport('scam', _scamCategory!)
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Submit Report'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _flowButton({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      elevation: 1,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: color.withOpacity(0.3)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: 32),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600, color: color,
                    )),
                    Text(subtitle, style: const TextStyle(
                      fontSize: 12, color: Colors.black54,
                    )),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submitReport(String verdict, String category) async {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a URL')),
      );
      return;
    }

    try {
      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      final supabase = GetIt.instance<SupabaseClient>();
      await supabase.from('scams').insert({
        'url': url,
        'reason': category,
        'latitude': pos.latitude,
        'longitude': pos.longitude,
        'created_at': DateTime.now().toIso8601String(),
      });

      if (mounted) {
        Navigator.of(context).pop();
        if (widget.onSuccess != null) {
          widget.onSuccess!();
        }
      }
    } catch (e) {
      if (mounted) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }
}