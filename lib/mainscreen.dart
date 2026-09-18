import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sura_driver/deliverydriver/donedelivery.dart';

import 'deliverydriver/delivery.dart';
import 'deliverydriver/homefordel.dart';
import 'orderdriver/order.dart';

class MainScreen extends StatefulWidget {
  final int id;

  MainScreen({
    required this.id,
  });

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  late final List<Widget> _widgetOptions;

  @override
  void initState() {
    super.initState();
    _widgetOptions = <Widget>[
      DeliveryListScreen(),
      const Done(),
      OrderScreen(),
      SummaryScreen(),
    ];
  }

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _widgetOptions,
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        elevation: 8,
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.local_shipping_outlined),
            activeIcon: Icon(Icons.local_shipping),
            label: 'Хүргэлт',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.check_circle_outline),
            activeIcon: Icon(Icons.check_circle),
            label: 'Дууссан',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long_outlined),
            activeIcon: Icon(Icons.receipt_long),
            label: 'Захиалга',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart_outlined),
            activeIcon: Icon(Icons.bar_chart),
            label: 'Мэдээлэл',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: const Color(0xFFFF6A1A),
        unselectedItemColor: Colors.grey,
        selectedLabelStyle:
            GoogleFonts.rubik(fontSize: 12, fontWeight: FontWeight.w600),
        unselectedLabelStyle: GoogleFonts.rubik(fontSize: 11),
        onTap: _onItemTapped,
      ),
    );
  }
}
