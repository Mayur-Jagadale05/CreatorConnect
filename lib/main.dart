import 'package:creatorconnect/Authwrapper.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'firebase_options.dart';
import 'design_system.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('Firebase currentPlatform initialize warning: $e');
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.web,
      );
    } catch (inner) {
      debugPrint('Firebase fallback initialization error: $inner');
    }
  }

  try {
    await Supabase.initialize(
      url: "https://qklgapnlkjgenklljfsh.supabase.co",
      publishableKey: "sb_publishable_U4JrZexK_Kz2NnW7fufFTw_zko97Qvc",
    );
  } catch (e) {
    debugPrint('Supabase initialization warning: $e');
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: CreatorTheme.theme(),
      home: const Authwrapper(),
    );
  }
}
