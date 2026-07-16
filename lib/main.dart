import 'dart:io';

// import 'package:sura_driver/screen/mainforavdag.dart';
import 'package:flutter/material.dart';
// import 'package:sura_driver/screen/login.dart';
// import 'package:sura_driver/mainscreen.dart';
// import 'package:sura_driver/screen/settings.dart';
// import 'firebase_options.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sura_driver/screen/login.dart';
import 'package:sura_driver/screen/orderdrivermain.dart';
import 'firebase_options.dart';
import 'mainscreen.dart';

class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
  }
}

void main() async {

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Test App',
      debugShowCheckedModeBanner: false,
      home: CheckAuth(),
    );
  }
}

class CheckAuth extends StatefulWidget {
  @override
  _CheckAuthState createState() => _CheckAuthState();
}

class _CheckAuthState extends State<CheckAuth> {
  bool isAuth = false;
  String types = '';
  String? fcmToken;

  String? username;
  @override
  void initState() {
    super.initState();
    initializeData();
  }

  Future<void> initializeData() async {
    WidgetsFlutterBinding.ensureInitialized();

    // Ensure Firebase has been initialized before accessing any Firebase service
    _checkIfLoggedIn();
    _getFCMToken();
  }

  Future getEmail() async {
    SharedPreferences preferences = await SharedPreferences.getInstance();
    setState(() {
      username = preferences.getString('username');
    });
  }

  Future<void> _getFCMToken() async {

  }

  void _checkIfLoggedIn() async {
    getEmail();
    SharedPreferences localStorage = await SharedPreferences.getInstance();
    var token = localStorage.getString('username');
    if (token != null) {
      setState(() {
        isAuth = true;
      });
    }
    if (localStorage.containsKey("username")) {
      username = localStorage.getString("username");
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget child;

    if (username == null) {
      child = Login();
      print("qqq");
    } else {
      if (types == '1') {
        child = MainScreen(id: 1);
      } else {
        child = MainScreen(id: 1);
      }
      print("sss");
    }
    return Scaffold(
      body: child,
    );
  }
}
