import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:locode/features/scan/data/datasources/local_heuristic_engine.dart';
import 'package:locode/features/scan/domain/entities/verdict.dart';
import 'package:url_launcher/url_launcher.dart';

class NotificationVerdict {
  static final _notifications = FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: androidSettings);

    await _notifications.initialize(
      settings,
      onDidReceiveNotificationResponse: (response) async {
        final payload = response.payload;
        if (payload != null) {
          if (response.actionId == 'open') {
            final uri = Uri.tryParse(payload);
            if (uri != null) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            }
          }
        }
      },
    );
  }

  static Future<void> showVerdictNotification(String url, {int? riskScore, String? summary}) async {
    final engine = LocalHeuristicEngine();
    final result = engine.analyze(url);

    String title = '🛡️ Locode Security Verdict';
    String body = summary ?? url;
    Importance importance = Importance.defaultImportance;

    final verdictString = riskScore != null 
        ? (riskScore > 65 ? 'DANGEROUS' : (riskScore > 25 ? 'SUSPICIOUS' : 'SAFE'))
        : result.verdict.name.toUpperCase();

    if (riskScore != null) {
      body = '[$verdictString] Risk Score: $riskScore/100 — ${summary ?? url}';
      importance = riskScore > 65 ? Importance.max : (riskScore > 25 ? Importance.high : Importance.defaultImportance);
    } else {
      switch (result.verdict) {
        case Verdict.danger:
          body = '🚫 DANGER — ${result.flags.take(2).join(". ")}';
          importance = Importance.max;
          break;
        case Verdict.suspicious:
          body = '⚠️ Caution — ${result.flags.take(2).join(". ")}';
          importance = Importance.high;
          break;
        case Verdict.safe:
          body = '✅ Link appears safe: $url';
          importance = Importance.defaultImportance;
          break;
        default:
          body = '🛡️ Locode checked this link: $url';
          importance = Importance.defaultImportance;
      }
    }

    final androidDetails = AndroidNotificationDetails(
      'verdict_channel',
      'Locode Alerts',
      channelDescription: 'QR code safety check results',
      importance: importance,
      priority: Priority.high,
      category: AndroidNotificationCategory.recommendation,
      actions: [
        const AndroidNotificationAction(
          'block',
          '🚫 Block',
          showsUserInterface: false,
          cancelNotification: true,
        ),
        const AndroidNotificationAction(
          'open',
          'Open Anyway ▸',
          showsUserInterface: true,
        ),
      ],
    );

    await _notifications.show(
      url.hashCode,
      title,
      body,
      NotificationDetails(android: androidDetails),
      payload: url,
    );
  }
}
