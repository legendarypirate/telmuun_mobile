import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sura_driver/screen/login.dart';

import 'customerscreen.dart';
import 'mainscreen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Тэлмүүн',
      debugShowCheckedModeBanner: false,
      home: const CheckAuth(),
    );
  }
}

class CheckAuth extends StatefulWidget {
  const CheckAuth({super.key});

  @override
  State<CheckAuth> createState() => _CheckAuthState();
}

class _CheckAuthState extends State<CheckAuth> {
  bool _loading = true;
  Widget _home = Login();

  @override
  void initState() {
    super.initState();
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final username = prefs.getString('username');
    final role = prefs.getInt('role');
    final userId = prefs.getInt('user_id');

    Widget next = Login();

    final loggedIn = (token != null && token.isNotEmpty) ||
        (username != null && username.isNotEmpty);

    if (loggedIn && userId != null && role != null) {
      if (role == 3) {
        next = MainScreen(id: userId);
      } else if (role == 2) {
        next = Customerscreen(id: userId);
      }
    }

    if (!mounted) return;
    setState(() {
      _home = next;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: CircularProgressIndicator(
            color: Color(0xFFFF6A1A),
          ),
        ),
      );
    }
    return _home;
  }
}
