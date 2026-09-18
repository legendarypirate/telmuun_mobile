import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'customer_driver/CustomerSummary.dart';
import 'customer_driver/customer_order.dart';
import 'customer_driver/delivery.dart';
import 'deliverydriver/ware.dart';

class Customerscreen extends StatefulWidget {
  final int id;

  Customerscreen({required this.id});

  @override
  State<Customerscreen> createState() => _CustomerscreenState();
}

class _CustomerscreenState extends State<Customerscreen> {
  int _selectedIndex = 0;
  late final List<Widget> _widgetOptions;

  @override
  void initState() {
    super.initState();
    _widgetOptions = <Widget>[
      DeliveryCustomer(),
      CustomerOrder(),
      GoodListScreen(),
      Customersummary(),
    ];
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
            icon: Icon(Icons.receipt_long_outlined),
            activeIcon: Icon(Icons.receipt_long),
            label: 'Захиалга',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.warehouse_outlined),
            activeIcon: Icon(Icons.warehouse),
            label: 'Агуулах',
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
        onTap: (index) => setState(() => _selectedIndex = index),
      ),
    );
  }
}
