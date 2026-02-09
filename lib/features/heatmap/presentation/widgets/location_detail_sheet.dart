import 'package:flutter/material.dart';
import 'package:locode/features/heatmap/data/seed/savannah_parking_data.dart';

class LocationDetailSheet extends StatelessWidget {
  final ParkingLocation location;

  const LocationDetailSheet({required this.location, super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = _statusColors(location.status, theme);

    return DraggableScrollableSheet(
      initialChildSize: 0.4,
      minChildSize: 0.25,
      maxChildSize: 0.7,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.all(20),
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Status banner
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: colors.background,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(colors.icon, color: colors.foreground, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _statusTitle(location.status),
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: colors.foreground,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            _statusDescription(location.status),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colors.foreground.withOpacity(0.8),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Location name and address
              Text(
                location.name,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                location.address,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),

              // Rating
              if (location.rating != null) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    ...List.generate(5, (i) {
                      return Icon(
                        i < location.rating!.round() ? Icons.star : Icons.star_border,
                        size: 18,
                        color: Colors.amber,
                      );
                    }),
                    const SizedBox(width: 8),
                    Text(
                      '${location.rating}',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ],

              // QR Payment indicator
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(
                    Icons.qr_code,
                    size: 20,
                    color: location.hasQrPayment
                      ? theme.colorScheme.primary
                      : theme.colorScheme.outline,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    location.hasQrPayment
                      ? 'QR code payment system present'
                      : 'No QR payment detected',
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),

              // Note / details
              if (location.note != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Details',
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        location.note!,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],

              // Action buttons
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: () {
                  // External maps would be triggered here
                },
                icon: const Icon(Icons.directions),
                label: const Text('Get Directions'),
              ),
            ],
          ),
        );
      },
    );
  }

  _StatusColors _statusColors(ThreatStatus status, ThemeData theme) {
    return switch (status) {
      ThreatStatus.reported => _StatusColors(
        background: const Color(0xFFC62828),
        foreground: Colors.white,
        icon: Icons.dangerous_rounded,
      ),
      ThreatStatus.suspicious => _StatusColors(
        background: const Color(0xFFF57F17),
        foreground: Colors.white,
        icon: Icons.warning_rounded,
      ),
      ThreatStatus.unknown => _StatusColors(
        background: const Color(0xFF616161),
        foreground: Colors.white,
        icon: Icons.help_outline,
      ),
      ThreatStatus.safe => _StatusColors(
        background: const Color(0xFF2E7D32),
        foreground: Colors.white,
        icon: Icons.verified_rounded,
      ),
    };
  }

  String _statusTitle(ThreatStatus status) {
    return switch (status) {
      ThreatStatus.reported => 'SCAM REPORTED',
      ThreatStatus.suspicious => 'SUSPICIOUS',
      ThreatStatus.unknown => 'UNVERIFIED',
      ThreatStatus.safe => 'VERIFIED SAFE',
    };
  }

  String _statusDescription(ThreatStatus status) {
    return switch (status) {
      ThreatStatus.reported => 'Users have reported QR code fraud at this location',
      ThreatStatus.suspicious => 'QR payment complaints found — use with caution',
      ThreatStatus.unknown => 'scan carefully - QR payment present but no reports yet.',
      ThreatStatus.safe => 'City-operated with verified payment systems',
    };
  }
}

class _StatusColors {
  final Color background;
  final Color foreground;
  final IconData icon;
  _StatusColors({required this.background, required this.foreground, required this.icon});
}
