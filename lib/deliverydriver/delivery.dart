import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sura_driver/deliverydriver/detaildelivery.dart';
import 'package:http/http.dart' as http;
import 'package:sura_driver/deliverydriver/user.dart';

import '../color/color.dart';
import '../screen/login.dart';
import 'dashboard.dart';

class Delivery {
  final int id;
  final String phone;
  String status;
  final DateTime createdDate;
  String comment;
  String price;
  final String address;
  List<String> possibleStatuses;

  Delivery({
    required this.id,
    required this.phone,
    required this.status,
    required this.createdDate,
    required this.comment,
    required this.price,
    required this.address,
    this.possibleStatuses = const ["Pending", "In Transit", "Delivered", "Cancelled"],
  });

  factory Delivery.fromJson(Map<String, dynamic> json) {
    return Delivery(
      id: json['id'],
      phone: json['phone'],
      status: _statusFromCode(json['status']),
      createdDate: DateTime.parse(json['createdAt']),
      comment: json['comment'] ?? '',
      address: json['address'],
      price: json['price'],
    );
  }

  static String _statusFromCode(int statusCode) {
    switch (statusCode) {
      case 1:
        return "Pending";
      case 2:
        return "In Transit";
      case 3:
        return "Delivered";
      case 4:
        return "Cancelled";
      default:
        return "Unknown";
    }
  }

  static int _codeFromStatus(String status) {
    switch (status) {
      case "Pending":
        return 1;
      case "In Transit":
        return 2;
      case "Delivered":
        return 3;
      case "Cancelled":
        return 4;
      default:
        return 0;
    }
  }

  int get statusCode => _codeFromStatus(status);
}

class DeliveryListScreen extends StatefulWidget {
  @override
  _DeliveryListScreenState createState() => _DeliveryListScreenState();
}

class _DeliveryListScreenState extends State<DeliveryListScreen> {
  List<Delivery> deliveries = [];
  bool isLoading = true;

  List<String> statuses = [
    'Pending',
    'Жолоочид',
    'Delivered',
    'Cancelled',
  ];

  Future<void> saveOrderLocally() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String> order = deliveries.map((d) => d.id.toString()).toList();
    await prefs.setStringList('delivery_order', order);
  }

  Future<void> loadOrderLocally() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String>? savedOrder = prefs.getStringList('delivery_order');
    if (savedOrder != null && deliveries.isNotEmpty) {
      deliveries.sort((a, b) {
        int indexA = savedOrder.indexOf(a.id.toString());
        int indexB = savedOrder.indexOf(b.id.toString());
        if (indexA == -1) indexA = deliveries.length;
        if (indexB == -1) indexB = deliveries.length;
        return indexA.compareTo(indexB);
      });
    }
  }

  Future<void> fetchDeliveries() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    int? userId = prefs.getInt('user_id');
    final url = Uri.parse(Url.url + '/api/mobile/delivery/driver/$userId/status-2');
    print(url);
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        final List data = jsonResponse['data'];

        setState(() {
          deliveries = data.map((item) => Delivery.fromJson(item)).toList();
        });

        await loadOrderLocally(); // Apply saved order
      } else {
        print('Error: ${response.statusCode}');
      }
    } catch (e) {
      print('Failed to load deliveries: $e');
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> updateStatus(int index, String newStatus) async {
    final delivery = deliveries[index];
    final url = Uri.parse(Url.url + '/api/mobile/delivery/${delivery.id}/status');

    try {
      final response = await http.put(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'status': Delivery._codeFromStatus(newStatus)}),
      );

      if (response.statusCode == 200) {
        setState(() {
          delivery.status = newStatus;
        });
      } else {
        print('Failed to update status: ${response.statusCode}');
      }
    } catch (e) {
      print('Error updating status: $e');
    }
  }

  Color statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'in transit':
        return Colors.blue;
      case 'delivered':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String formatDate(DateTime date) {
    return DateFormat('yyyy-MM-dd – kk:mm').format(date);
  }

  @override
  void initState() {
    super.initState();
    fetchDeliveries();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: Icon(Icons.supervised_user_circle, color: Colors.white),
          onPressed: () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => User()));
          },
        ),
        title: Text('Хүргэлт', style: GoogleFonts.rubik(color: Colors.white, fontSize: 13)),
        backgroundColor: Colors.deepOrange,
        actions: [
          IconButton(
            icon: Icon(Icons.logout, color: Colors.white),
            onPressed: () async {
              SharedPreferences prefs = await SharedPreferences.getInstance();
              await prefs.clear();
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => Login()),
                    (route) => false,
              );
            },
          ),
        ],
      ),
      backgroundColor: Colors.white,
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(5),
            child: Text(
              'Нийт хүргэлт: ${deliveries.length}',
              style: GoogleFonts.rubik(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: ReorderableListView(
              onReorder: (oldIndex, newIndex) {
                setState(() {
                  if (newIndex > oldIndex) newIndex--;
                  final item = deliveries.removeAt(oldIndex);
                  deliveries.insert(newIndex, item);
                });
                saveOrderLocally(); // Save order after reordering
              },
              children: [
                for (int index = 0; index < deliveries.length; index++)
                  Card(
                    key: ValueKey(deliveries[index].id),
                    elevation: 4,
                    margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: ListTile(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                DeliveryDetailScreen(deliveryId: deliveries[index].id),
                          ),
                        );
                      },
                      title: Text(
                        '${index + 1}. Хүргэлтийн дугаар #${deliveries[index].id}',
                        style: GoogleFonts.rubik(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            deliveries[index].phone,
                            style: GoogleFonts.rubik(color: Colors.grey[700], fontSize: 12),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: statusColor(deliveries[index].status),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              deliveries[index].status,
                              style: GoogleFonts.rubik(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Created: ${formatDate(deliveries[index].createdDate)}',
                            style: GoogleFonts.rubik(color: Colors.grey[700], fontSize: 11),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Үнэ: ${deliveries[index].price}',
                            style: GoogleFonts.rubik(
                                color: Colors.orange,
                                fontSize: 16,
                                fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            deliveries[index].address,
                            style: GoogleFonts.rubik(
                              fontSize: 11,
                              color: Colors.grey[800],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
