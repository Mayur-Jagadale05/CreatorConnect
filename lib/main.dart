import 'package:creatorconnect/Authwrapper.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'firebase_options.dart';
import 'design_system.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // await Supabase.initialize(
  //   url: "https://qklgapnlkjgenklljfsh.supabase.co",
  //   publishableKey: "sb_publishable_U4JrZexK_Kz2NnW7fufFTw_zko97Qvc",
  // );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: CreatorTheme.theme(),
      home: const Authwrapper(),
    );
  }
}
