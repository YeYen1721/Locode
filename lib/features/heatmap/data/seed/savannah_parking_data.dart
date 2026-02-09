// lib/features/heatmap/data/seed/savannah_parking_data.dart

class ParkingLocation {
  final String name;
  final double latitude;
  final double longitude;
  final String address;
  final ThreatStatus status;
  final bool hasQrPayment;
  final String? note;
  final double? rating;

  const ParkingLocation({
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.address,
    required this.status,
    required this.hasQrPayment,
    this.note,
    this.rating,
  });
}

enum ThreatStatus {
  reported,    // Red — confirmed scam reports or major QR payment fraud complaints
  suspicious,  // Amber — complaints about QR issues, overcharging, confusing payment
  unknown,     // Gray — has QR payment but no reports
  safe,        // Green — well-known, city-operated, no complaints
}

/// Real parking locations in downtown Savannah, GA
/// Data sourced from Google Places with actual coordinates and review insights
final List<ParkingLocation> savannahParkingData = [

  // ═══════════════════════════════════════
  // 🔴 REPORTED — Real complaints about QR/payment scams
  // ═══════════════════════════════════════

  ParkingLocation(
    name: 'Bay Street Parking',
    latitude: 32.0822144,
    longitude: -81.0969296,
    address: '501 W Bay St, Savannah, GA 31401',
    status: ThreatStatus.reported,
    hasQrPayment: true,
    rating: 3.6,
    note: 'Multiple reports of QR scanning overcharging (\$32 for 2 hours). '
          'Users report car towing after QR payment confusion. '
          'Review: "They want \$32 for two hours on the QR scanning."',
  ),

  ParkingLocation(
    name: 'Congress Street iParkit Garage',
    latitude: 32.0790688,
    longitude: -81.08990879,
    address: '115 E Congress St, Savannah, GA 31401',
    status: ThreatStatus.reported,
    hasQrPayment: true,
    rating: 3.1,
    note: 'Multiple reviews calling this location a SCAM. '
          'Signage designed to look like city parking but charges \$25 for 2 hours. '
          'Review: "This deck has signage as if they are part of the Savannah Public Parking system... SCAM."',
  ),

  ParkingLocation(
    name: 'Parking Management Company',
    latitude: 32.077501,
    longitude: -81.087339,
    address: '409 E Broughton St, Savannah, GA 31401',
    status: ThreatStatus.reported,
    hasQrPayment: true,
    rating: 1.4,
    note: 'QR code payment system double-charges users. Help button staff unhelpful. '
          'Review: "Scan the QR code which then charged us again... we were charged 2x." '
          'Valet locked keys in car. \$100 overnight parking.',
  ),

  ParkingLocation(
    name: 'Pay to Car Park 24/7',
    latitude: 32.0785623,
    longitude: -81.08810129,
    address: '315 E Congress St, Savannah, GA 31401',
    status: ThreatStatus.reported,
    hasQrPayment: true,
    rating: 1.0,
    note: '\$48 for 4 hours. Unverified QR payment kiosk. '
          'Extremely low rating indicates persistent issues.',
  ),

  // ═══════════════════════════════════════
  // 🟡 SUSPICIOUS — QR payment issues or confusing systems
  // ═══════════════════════════════════════

  ParkingLocation(
    name: 'Liberty Street Parking Garage',
    latitude: 32.0751354,
    longitude: -81.0974808,
    address: '301 W Liberty St, Savannah, GA 31401',
    status: ThreatStatus.unknown,
    hasQrPayment: true,
    rating: 3.6,
    note: 'Digital payment kiosk reported as broken. Students report being trapped '
          'because long-term tickets have no barcode. '
          'Review: "The speaker is almost entirely broken... we had to wait half an hour."',
  ),

  ParkingLocation(
    name: 'Liberty Parking Deck',
    latitude: 32.074693100,
    longitude: -81.0942565,
    address: '15 W Liberty St, Savannah, GA 31401',
    status: ThreatStatus.unknown,
    hasQrPayment: true,
    rating: 3.5,
    note: 'Pricing inconsistency between posted rates and actual charges. '
          'Google says \$14-\$17/day but users charged \$49.50. '
          'Review: "I was charged \$49.50 for 24 hours."',
  ),

  ParkingLocation(
    name: 'Lincoln Street iParkit Garage',
    latitude: 32.0790235,
    longitude: -81.088047,
    address: '20 Lincoln St, Savannah, GA 31401',
    status: ThreatStatus.unknown,
    hasQrPayment: true,
    rating: 3.7,
    note: 'Uses QR code for entry/exit. \$25 for a few hours. '
          'Review: "Fast and easy to scan the QR code in and out" — but pricing is opaque.',
  ),

  ParkingLocation(
    name: 'parkingmgt.com Lot',
    latitude: 32.0774736,
    longitude: -81.08715699,
    address: '415 E Broughton St, Savannah, GA 31401',
    status: ThreatStatus.unknown,
    hasQrPayment: true,
    rating: null,
    note: 'Online parking management system. No reviews available — unverified QR payment. '
          'Exercise caution with unfamiliar digital payment systems.',
  ),

  // ═══════════════════════════════════════
  // ⚪ UNKNOWN — Has QR/digital payment, no issues reported
  // ═══════════════════════════════════════

  ParkingLocation(
    name: 'Bryan Street Car Park',
    latitude: 32.0799708,
    longitude: -81.0897391,
    address: '100 E Bryan St, Savannah, GA 31401',
    status: ThreatStatus.unknown,
    hasQrPayment: true,
    rating: 3.9,
    note: 'City-operated garage. Card-only payment kiosks. '
          '\$1/hr weekdays, \$2 flat after 5pm. '
          'No QR scam reports but uses digital payment.',
  ),

  ParkingLocation(
    name: 'State Street Car Park',
    latitude: 32.0780114,
    longitude: -81.0909485,
    address: '100 E State St, Savannah, GA 31401',
    status: ThreatStatus.unknown,
    hasQrPayment: true,
    rating: 4.0,
    note: 'City-operated. \$5 Saturday parking. '
          'Digital payment system present. No QR complaints.',
  ),

  ParkingLocation(
    name: 'Visitor Center Car Park',
    latitude: 32.0768088,
    longitude: -81.09992989,
    address: '301 MLK Jr Blvd, Savannah, GA 31401',
    status: ThreatStatus.unknown,
    hasQrPayment: true,
    rating: 4.0,
    note: 'Meter payment required before leaving. '
          '\$20 fixed rate for RVs. Digital meters present.',
  ),

  // ═══════════════════════════════════════
  // 🟢 SAFE — Well-established, city-run, good track record
  // ═══════════════════════════════════════

  ParkingLocation(
    name: 'Robinson Car Park',
    latitude: 32.0787824,
    longitude: -81.09641719,
    address: '132 Montgomery St, Savannah, GA 31401',
    status: ThreatStatus.safe,
    hasQrPayment: true,
    rating: 4.2,
    note: 'City-managed. Highest rated garage in downtown Savannah. '
          'Tap-to-pay credit card machines. Staff present. '
          'Review: "Payment is easy — make sure you tap if you have a chip credit card."',
  ),

  ParkingLocation(
    name: 'Whitaker Street Car Park',
    latitude: 32.0807631,
    longitude: -81.09267969,
    address: '7 Whitaker St, Savannah, GA 31401',
    status: ThreatStatus.safe,
    hasQrPayment: true,
    rating: 4.0,
    note: 'City-operated. \$2/hr. Staff on-site. '
          'Well-reviewed, affordable, close to City Market.',
  ),

  ParkingLocation(
    name: 'W Broughton Street Garage',
    latitude: 32.080037499,
    longitude: -81.0966414,
    address: '353 W Broughton St, Savannah, GA 31401',
    status: ThreatStatus.safe,
    hasQrPayment: true,
    rating: 3.9,
    note: 'City-operated. \$12/day. Free parking after hours and on Sundays. '
          'Near City Market and River Street.',
  ),
];
