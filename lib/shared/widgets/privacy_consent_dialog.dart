import 'package:flutter/material.dart';

class PrivacyConsentDialog extends StatelessWidget {
  const PrivacyConsentDialog({super.key});

  static Future<bool> show(BuildContext context) async {
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const PrivacyConsentDialog(),
    ) ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      title: const Row(
        children: [
          Icon(Icons.shield_outlined, color: Colors.blue),
          SizedBox(width: 12),
          Text('Privacy Policy'),
        ],
      ),
      content: const Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('To protect you from scams, Locode uses:'),
          SizedBox(height: 16),
          _PrivacyItem(
            icon: Icons.location_on_outlined,
            title: 'Fuzzed Location',
            desc: 'We check if the URL matches your area. Precise coordinates are never stored.',
          ),
          _PrivacyItem(
            icon: Icons.camera_alt_outlined,
            title: 'On-device Camera',
            desc: 'Photos of QR codes are analyzed for tampering and immediately discarded.',
          ),
          _PrivacyItem(
            icon: Icons.psychology_outlined,
            title: 'Gemini AI',
            desc: 'Suspect URLs are analyzed by Google Gemini for phishing patterns.',
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Basic Mode'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Accept & Protect'),
        ),
      ],
    );
  }
}

class _PrivacyItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String desc;

  const _PrivacyItem({required this.icon, required this.title, required this.desc});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                Text(desc, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
