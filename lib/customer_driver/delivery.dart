import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

import '../color/color.dart';
import '../deliverydriver/createDelivery.dart';
import '../screen/login.dart';

class Delivery {
  final int id;
  final String phone;
  String status;
  final DateTime createdDate;
  String comment;
  final String address;

  Delivery({
    required this.id,
    required this.phone,
    required this.status,
    required this.createdDate,
    required this.comment,
    required this.address,
  });

  factory Delivery.fromJson(Map<String, dynamic> json) {
    return Delivery(
      id: json['id'],
      phone: json['phone']?.toString() ?? '',
      status: _statusFromCode(json['status']),
      createdDate: DateTime.parse(json['createdAt']),
      comment: json['comment']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
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
}

class DeliveryCustomer extends StatefulWidget {
  @override
  _DeliveryCustomerState createState() => _DeliveryCustomerState();
}

class _DeliveryCustomerState extends State<DeliveryCustomer> {
  List<Delivery> deliveries = [];
  bool isLoading = true;

  static const Color _orange = Color(0xFFFF6A1A);
  static const Color _navy = Color(0xFF0F2744);
  static const Color _bg = Color(0xFFF5F6F8);
  static const Color _muted = Color(0xFF7A8699);

  Future<void> fetchDeliveries() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('user_id');
    final url =
        Uri.parse('${Url.url}/api/mobile/delivery/merchant?user_id=$userId');

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        final List data = jsonResponse['data'] ?? [];
        setState(() {
          deliveries = data.map((item) => Delivery.fromJson(item)).toList();
          isLoading = false;
        });
      } else {
        setState(() => isLoading = false);
      }
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  Color statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'шинэ':
        return const Color(0xFFE5484D);
      case 'жолоочид':
        return const Color(0xFF1B9BE4);
      case 'хүргэгдсэн':
        return const Color(0xFF1FA97A);
      case 'цуцалсан':
        return const Color(0xFF9AA5B1);
      default:
        return _orange;
    }
  }

  String formatDate(DateTime date) {
    return DateFormat('MM.dd  HH:mm').format(date);
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => Login()),
      (_) => false,
    );
  }

  @override
  void initState() {
    super.initState();
    fetchDeliveries();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        elevation: 0,
        automaticallyImplyLeading: false,
        backgroundColor: _orange,
        centerTitle: true,
        title: Text(
          'Хүргэлт',
          style: GoogleFonts.rubik(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: () {
              setState(() => isLoading = true);
              fetchDeliveries();
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.white),
            onPressed: _logout,
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: _orange))
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                  child: Row(
                    children: [
                      Text(
                        'Нийт хүргэлт',
                        style: GoogleFonts.rubik(fontSize: 13, color: _muted),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: _orange.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${deliveries.length}',
                          style: GoogleFonts.rubik(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: _orange,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: RefreshIndicator(
                    color: _orange,
                    onRefresh: () async {
                      setState(() => isLoading = true);
                      await fetchDeliveries();
                    },
                    child: deliveries.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: [
                              const SizedBox(height: 120),
                              Center(
                                child: Text(
                                  'Хүргэлт алга',
                                  style: GoogleFonts.rubik(
                                      fontSize: 15, color: _muted),
                                ),
                              ),
                            ],
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(12, 0, 12, 88),
                            itemCount: deliveries.length,
                            itemBuilder: (context, index) {
                              return _item(deliveries[index], index);
                            },
                          ),
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'merchant_delivery_fab',
        onPressed: () async {
          final created = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CreateDelivery()),
          );
          if (created == true) {
            setState(() => isLoading = true);
            fetchDeliveries();
          }
        },
        backgroundColor: _orange,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _item(Delivery d, int index) {
    final accent = statusColor(d.status);
    final comment = d.comment.trim();

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8ECF1)),
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 4, color: accent),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          statusLabel(d.status),
                          style: GoogleFonts.rubik(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: accent,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          d.phone.isEmpty ? '#${d.id}' : d.phone,
                          style: GoogleFonts.rubik(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: _muted,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      d.address.isEmpty ? 'Хаяг байхгүй' : d.address,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.rubik(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: _navy,
                      ),
                    ),
                    if (comment.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        comment,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.rubik(
                          fontSize: 12,
                          color: _muted,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                    const SizedBox(height: 5),
                    Text(
                      formatDate(d.createdDate),
                      style: GoogleFonts.rubik(fontSize: 11, color: _muted),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String statusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'шинэ':
        return 'Шинэ';
      case 'жолоочид':
        return 'Жолоочид';
      case 'хүргэгдсэн':
        return 'Хүргэгдсэн';
      case 'цуцалсан':
        return 'Цуцалсан';
      default:
        return status;
    }
  }
}
