import 'package:flutter/material.dart';
import 'package:supabase/supabase.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:get_it/get_it.dart';
import 'package:google_fonts/google_fonts.dart';
import 'core/di/injection_container.dart' as di;
import 'features/home/presentation/pages/home_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Storage
  await Hive.initFlutter();
  
  // Initialize Backend using secure compile-time variables
  const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  const supabaseKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  
  if (supabaseUrl.isNotEmpty && supabaseKey.isNotEmpty) {
    try {
      final supabase = SupabaseClient(supabaseUrl, supabaseKey);
      GetIt.instance.registerSingleton<SupabaseClient>(supabase);
    } catch (e) {
      debugPrint('[MAIN] Supabase initialization failed: $e');
    }
  } else {
    debugPrint('[MAIN] WARNING: Supabase keys missing. Skipping init.');
  }

  // Initialize Dependency Injection
  await di.initDependencies();

  runApp(const LocodeApp());
}

class LocodeApp extends StatelessWidget {
  const LocodeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Locode',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.blue,
        textTheme: GoogleFonts.interTextTheme(),
      ),
      home: const HomePage(),
    );
  }
}