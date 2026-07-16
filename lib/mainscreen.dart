import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sura_driver/deliverydriver/donedelivery.dart';

import 'deliverydriver/delivery.dart';
import 'deliverydriver/homefordel.dart';
import 'orderdriver/doneorder.dart';
import 'orderdriver/order.dart';
import 'package:http/http.dart' as http;

import 'package:sura_driver/color/color.dart';

class MainScreen extends StatefulWidget {
  int id;

  MainScreen({
    required this.id,
  });

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  late List<Widget> _widgetOptions;

  @override
  void initState() {
    super.initState();
    _widgetOptions = <Widget>[
      DeliveryListScreen(),
      Done(),
      OrderScreen(),
      SummaryScreen(),
    ];
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: _widgetOptions.elementAt(_selectedIndex),
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.local_shipping), // Хүргэлт (Delivery)
            label: 'Хүргэлт',
            backgroundColor: Colors.white,
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.check_box), // Хүргэлт (Delivery)
            label: 'Дууссан',
            backgroundColor: Colors.white,
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long), // Захиалга (Order)
            label: 'Захиалга',
            backgroundColor: Colors.white,
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.info_outline), // Мэдээлэл (Info)
            label: 'Мэдээлэл',
            backgroundColor: Colors.white,
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.black,
        unselectedItemColor: Colors.grey,
        selectedLabelStyle:
        GoogleFonts.rubik(fontSize: 12, fontWeight: FontWeight.w500),
        unselectedLabelStyle: GoogleFonts.rubik(fontSize: 11),
        onTap: _onItemTapped,
      ),
    );
  }
}
