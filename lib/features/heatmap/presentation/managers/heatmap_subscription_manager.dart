import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class HeatmapSubscriptionManager with WidgetsBindingObserver {
  final SupabaseClient _client;
  RealtimeChannel? _channel;
  final _reportController = StreamController<List<Map<String, dynamic>>>.broadcast();

  Stream<List<Map<String, dynamic>>> get onNewReports => _reportController.stream;

  HeatmapSubscriptionManager(this._client) {
    WidgetsBinding.instance.addObserver(this);
  }

  void subscribeToRealtime() {
    _unsubscribe(); 
    
    // Listen to INSERT events on the scams table
    _channel = _client.channel('heatmap_live')
      .onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'scams',
        callback: (payload) {
          try {
            // Broadcast the new record as a list (to match existing logic)
            _reportController.add([payload.newRecord]);
          } catch (e) {
            debugPrint('Failed to parse realtime report: $e');
          }
        },
      )
      .subscribe();
  }

  void _unsubscribe() {
    _channel?.unsubscribe();
    _channel = null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        _unsubscribe(); // Save battery/data when backgrounded
        break;
      case AppLifecycleState.resumed:
        subscribeToRealtime(); // Reconnect when foregrounded
        break;
      default:
        break;
    }
  }

  void dispose() {
    _unsubscribe();
    _reportController.close();
    WidgetsBinding.instance.removeObserver(this);
  }
}
