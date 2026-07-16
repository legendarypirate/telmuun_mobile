import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sura_driver/deliverydriver/detaildelivery.dart';
import 'package:http/http.dart' as http;

import '../color/color.dart';
import '../deliverydriver/createDelivery.dart';
import '../screen/login.dart';
import '../deliverydriver/createDelivery.dart';

class Delivery {
  final int id;
  final String phone;
  String status;
  final DateTime createdDate;
  String comment;
  final String address;
  List<String> possibleStatuses;

  Delivery({
    required this.id,
    required this.phone,
    required this.status,
    required this.createdDate,
    required this.comment,
    required this.address,
    this.possibleStatuses = const [
      "Шинэ",
      "Жолоочид",
      "Хүргэсэн",
      "Цуцалсан"
    ],
  });

  factory Delivery.fromJson(Map<String, dynamic> json) {
    return Delivery(
      id: json['id'],
      phone: json['phone'],
      status: _statusFromCode(json['status']),
      createdDate: DateTime.parse(json['createdAt']),
      comment: json['comment'] ?? '',
      address: json['address'],
    );
  }

  static String _statusFromCode(int statusCode) {
    switch (statusCode) {
      case 1:
        return "Шинэ";
      case 2:
        return "Жолоочид";
      case 3:
        return "хүргэгдсэн";
      case 4:
        return "Цуцалсан";
      default:
        return "буцаасан";
    }
  }

  static int _codeFromStatus(String status) {
    switch (status) {
      case "Шинэ":
        return 1;
      case "жолоочид":
        return 2;
      case "хүргэгдсэн":
        return 3;
      case "Цуцалсан":
        return 4;
      default:
        return 0;
    }
  }

  int get statusCode => _codeFromStatus(status);
}

class DeliveryCustomer extends StatefulWidget {
  @override
  _DeliveryCustomerState createState() => _DeliveryCustomerState();
}

class _DeliveryCustomerState extends State<DeliveryCustomer> {
  List<Delivery> deliveries = [];
  int? expandedIndex;
  bool isLoading = true;

  List<String> statuses = [
    'Шинэ',
    'жолоочид',
    'хүргэгдсэн',
    'Цуцалсан',
  ];

  Future<void> fetchDeliveries() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    int? userId = prefs.getInt('user_id');
    final url =
    Uri.parse(Url.url + '/api/mobile/delivery/merchant?user_id=$userId');
    print(url);
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        final List data = jsonResponse['data'];

        setState(() {
          deliveries = data.map((item) => Delivery.fromJson(item)).toList();
          isLoading = false;
        });
        print(deliveries);
      } else {
        print('Error: ${response.statusCode}');
      }
    } catch (e) {
      print('Failed to load deliveries: $e');
    }
  }

  Future<void> updateStatus(int index, String newStatus) async {
    final delivery = deliveries[index];
    final url =
    Uri.parse(Url.url + '/api/mobile/delivery/${delivery.id}/status');

    try {
      final response = await http.put(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'status': Delivery._codeFromStatus(newStatus)}),
      );

      if (response.statusCode == 200) {
        setState(() {
          delivery.status = newStatus;
          expandedIndex = null;
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
      case 'Шинэ':
        return Colors.orange;
      case 'жолоочид':
        return Colors.blue;
      case 'хүргэгдсэн':
        return Colors.green;
      case 'Цуцалсан':
        return Colors.redAccent;
      default:
        return Colors.red;
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
        title: Text(
          'Хүргэлт',
          style: GoogleFonts.rubik(color: Colors.white, fontSize: 13),
        ),
        backgroundColor: Colors.deepOrange,
        actions: [
          IconButton(
            icon: Icon(Icons.logout, color: Colors.white),
            tooltip: 'Logout',
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
          : ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: deliveries.length,
        itemBuilder: (context, index) {
          final delivery = deliveries[index];
          final isExpanded = expandedIndex == index;

          return InkWell(
            onTap: () {

            },
            child: Card(
              elevation: 4,
              margin: const EdgeInsets.symmetric(vertical: 8),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ID and Phone
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Status badge
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              expandedIndex = isExpanded ? null : index;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: statusColor(delivery.status),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              delivery.status,
                              style: GoogleFonts.rubik(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),

                        if (isExpanded)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Wrap(
                              spacing: 6,
                              children: statuses.map((status) {
                                final selected =
                                    status == delivery.status;
                                return ChoiceChip(
                                  label: Text(
                                    status,
                                    style: GoogleFonts.rubik(
                                      fontSize: 11,
                                      color: selected
                                          ? Colors.white
                                          : Colors.black,
                                    ),
                                  ),
                                  selected: selected,
                                  selectedColor: Colors.blueAccent,
                                  onSelected: (selected) {
                                    if (selected) {
                                      updateStatus(index, status);
                                    }
                                  },
                                );
                              }).toList(),
                            ),
                          ),

                        Text(
                          delivery.phone,
                          style: GoogleFonts.rubik(
                              color: Colors.grey[700], fontSize: 12),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),

                    const SizedBox(height: 10),

                    Text(
                      'Үүссэн: ${formatDate(delivery.createdDate)}',
                      style: GoogleFonts.rubik(
                          color: Colors.grey[700], fontSize: 11),
                    ),

                    const SizedBox(height: 6),

                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 3,
                          child: Text(
                            delivery.comment,
                            style: GoogleFonts.rubik(
                                fontSize: 12,
                                fontStyle: FontStyle.italic),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    Text(
                      delivery.address,
                      style: GoogleFonts.rubik(
                        fontSize: 11,
                        color: Colors.grey[800],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => CreateDelivery()),
          );
        },
        backgroundColor: Colors.deepOrange,
        child: Icon(Icons.add, color: Colors.white),
        tooltip: 'Шинэ хүргэлт нэмэх',
      ),
    );
  }
}
