import 'package:flutter_application_1/Screens/Authentication/signin.dart';
import 'package:flutter_application_1/Screens/Home/home.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final Map<int, Color> color = {
      50: const Color.fromRGBO(33, 111, 182, .1),
      100: const Color.fromRGBO(33, 111, 182, .2),
      200: const Color.fromRGBO(33, 111, 182, .3),
      300: const Color.fromRGBO(33, 111, 182, .4),
      400: const Color.fromRGBO(33, 111, 182, .5),
      500: const Color.fromRGBO(33, 111, 182, .6),
      600: const Color.fromRGBO(33, 111, 182, .7),
      700: const Color.fromRGBO(33, 111, 182, .8),
      800: const Color.fromRGBO(33, 111, 182, .9),
      900: const Color.fromRGBO(33, 111, 182, 1),
    };

    final MaterialColor themeColor = MaterialColor(0xFF216fb6, color);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Eye Suggest',
      theme: ThemeData(
        primarySwatch: themeColor,
        fontFamily: 'ABeeZee',
      ),
      home: StreamBuilder(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, user) {
          if (user.hasData) {
            return const HomePage(
              title: 'Eye Suggest',
            );
          } else {
            return const SignIn();
          }
        },
      ),
    );
  }
}
