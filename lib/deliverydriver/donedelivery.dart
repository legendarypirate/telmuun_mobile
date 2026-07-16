import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sura_driver/deliverydriver/detaildelivery.dart';
import 'package:http/http.dart' as http;

import '../color/color.dart';
import '../screen/login.dart';
import 'createDelivery.dart';
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

  bool isPaid;
  bool isRural;

  Delivery({
    required this.id,
    required this.phone,
    required this.status,
    required this.createdDate,
    required this.price,
    required this.comment,
    required this.address,
    this.possibleStatuses = const [
      "Pending",
      "Хуваарилсан",
      "Delivered",
      "Cancelled"
    ],
    this.isPaid = false,
    this.isRural = false,
  });

  factory Delivery.fromJson(Map<String, dynamic> json) {
    return Delivery(
      id: json['id'],
      phone: json['phone'],
      status: _statusFromCode(json['status']),
      createdDate: DateTime.parse(json['createdAt']),
      comment: json['comment'] ?? '',
      price: json['price'] ?? '',
      address: json['address'],
      isPaid: json['is_paid'] ?? false,
      isRural: json['is_rural'] ?? false,
    );
  }

  static String _statusFromCode(int statusCode) {
    switch (statusCode) {
      case 1:
        return "Pending";
      case 2:
        return "Хуваарилсан";
      case 3:
        return "хүргэсэн";
      case 4:
        return "Cancelled";
      default:
        return "Буцаасан";
    }
  }

  static int _codeFromStatus(String status) {
    switch (status) {
      case "Pending":
        return 1;
      case "Хуваарилсан":
        return 2;
      case "хүргэсэн":
        return 3;
      case "Cancelled":
        return 4;
      default:
        return 0;
    }
  }

  int get statusCode => _codeFromStatus(status);
}

class Done extends StatefulWidget {
  const Done({Key? key}) : super(key: key);

  @override
  _DoneState createState() => _DoneState();
}

class _DoneState extends State<Done> {
  List<Delivery> deliveries = [];
  int? expandedIndex;
  bool isLoading = true;

  // Date filter state
  DateTime? _startDate;
  DateTime? _endDate;

  List<String> statuses = [
    'Pending',
    'Хуваарилсан',
    'хүргэсэн',
    'Cancelled',
  ];

  /// Fetch deliveries. If [startDate] and [endDate] are provided, include them as
  /// query parameters. Otherwise, backend defaults to the last 3 days.
  Future<void> fetchDeliveries({DateTime? startDate, DateTime? endDate}) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    int? userId = prefs.getInt('user_id');

    final DateFormat formatter = DateFormat('yyyy-MM-dd');
    String query = '';
    if (startDate != null && endDate != null) {
      query =
      '?startDate=${formatter.format(startDate)}&endDate=${formatter.format(endDate)}';
    }

    final url = Uri.parse(
        '${Url.url}/api/mobile/delivery/driver/$userId/status-3$query');
    debugPrint('Fetching deliveries from: $url');

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        final List data = jsonResponse['data'];

        setState(() {
          deliveries = data.map((item) => Delivery.fromJson(item)).toList();
          isLoading = false;
        });
      } else {
        debugPrint('Error: ${response.statusCode}');
        setState(() => isLoading = false);
      }
    } catch (e) {
      debugPrint('Failed to load deliveries: $e');
      setState(() => isLoading = false);
    }
  }

  Future<void> updateStatus(int index, String newStatus) async {
    final delivery = deliveries[index];
    final url =
    Uri.parse('${Url.url}/api/mobile/delivery/${delivery.id}/status');

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
        debugPrint('Failed to update status: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error updating status: $e');
    }
  }

  Color statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'хуваарилсан':
        return Colors.blue;
      case 'хүргэсэн':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  String formatDate(DateTime date) {
    return DateFormat('yyyy-MM-dd – kk:mm').format(date);
  }

  /// Opens a date-range picker and refreshes the delivery list according to the
  /// selected range.
  Future<void> _pickDateRange() async {
    final now = DateTime.now();

    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 1),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : DateTimeRange(
          start: now.subtract(const Duration(days: 2)), end: now),
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
        isLoading = true;
      });

      await fetchDeliveries(startDate: _startDate, endDate: _endDate);
    }
  }

  /// Clears the date filter, reverting to the backend default (last 3 days).
  Future<void> _clearDateFilter() async {
    setState(() {
      _startDate = null;
      _endDate = null;
      isLoading = true;
    });

    await fetchDeliveries();
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
          icon: const Icon(Icons.dashboard, color: Colors.white),
          tooltip: 'Dashboard',
          onPressed: () {
            Navigator.push(
                context, MaterialPageRoute(builder: (_) => Dashboard()));
          },
        ),
        title: Text('Хүргэлт',
            style: GoogleFonts.rubik(color: Colors.white, fontSize: 13)),
        backgroundColor: Colors.deepOrange,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_alt, color: Colors.white),
            tooltip: 'Date filter',
            onPressed: _pickDateRange,
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: 'Clear filter',
            onPressed: _clearDateFilter,
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
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
          ? const Center(child: CircularProgressIndicator())
          : Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Text(
              'Нийт хүргэлт: ${deliveries.length}',
              style: GoogleFonts.rubik(
                  fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          if (_startDate != null && _endDate != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Chip(
                    label: Text(
                      '${DateFormat('yyyy-MM-dd').format(_startDate!)} → ${DateFormat('yyyy-MM-dd').format(_endDate!)}',
                      style: GoogleFonts.rubik(
                          fontSize: 12, color: Colors.white),
                    ),
                    backgroundColor: Colors.blueGrey,
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: _clearDateFilter,
                  )
                ],
              ),
            ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: deliveries.length,
              itemBuilder: (context, index) {
                final delivery = deliveries[index];
                final isExpanded = expandedIndex == index;

                return InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            DeliveryDetailScreen(deliveryId: delivery.id),
                      ),
                    );
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
                                    fontSize: 12),
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
                                    label: Text(status,
                                        style: GoogleFonts.rubik(
                                            fontSize: 11,
                                            color: selected
                                                ? Colors.white
                                                : Colors.black)),
                                    selected: selected,
                                    selectedColor: Colors.blueAccent,
                                    onSelected: (selected) {
                                      if (selected)
                                        updateStatus(index, status);
                                    },
                                  );
                                }).toList(),
                              ),
                            ),
                          const SizedBox(height: 10),
                          Text(
                              'Үүсэн: ${formatDate(delivery.createdDate)}',
                              style: GoogleFonts.rubik(
                                  color: Colors.grey[700], fontSize: 11)),
                          const SizedBox(height: 10),
                          Text('Утас: ${delivery.phone}',
                              style: GoogleFonts.rubik(
                                  color: Colors.blue,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11)),
                          const SizedBox(height: 6),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 3,
                                child: Text(delivery.comment,
                                    style: GoogleFonts.rubik(
                                        fontSize: 12,
                                        fontStyle: FontStyle.italic)),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                flex: 2,
                                child: Text('₮ ${delivery.price}',
                                    textAlign: TextAlign.right,
                                    style: GoogleFonts.rubik(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.green[700])),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(delivery.address,
                              style: GoogleFonts.rubik(
                                  fontSize: 11, color: Colors.grey[800])),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
