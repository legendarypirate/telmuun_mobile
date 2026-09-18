import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sura_driver/deliverydriver/detaildelivery.dart';
import 'package:http/http.dart' as http;

import '../color/color.dart';
import '../screen/login.dart';
import '../utils/date_picker.dart';
import 'dashboard.dart';

class Delivery {
  final int id;
  final String phone;
  String status;
  final DateTime createdDate;
  String comment;
  String price;
  final String address;
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
    this.isPaid = false,
    this.isRural = false,
  });

  factory Delivery.fromJson(Map<String, dynamic> json) {
    return Delivery(
      id: json['id'],
      phone: json['phone']?.toString() ?? '',
      status: _statusFromCode(json['status']),
      createdDate: DateTime.parse(json['createdAt']),
      comment: json['comment']?.toString() ?? '',
      price: json['price']?.toString() ?? '0',
      address: json['address']?.toString() ?? '',
      isPaid: json['is_paid'] ?? false,
      isRural: json['is_rural'] ?? false,
    );
  }

  double get priceValue => double.tryParse(price) ?? 0;

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
}

class Done extends StatefulWidget {
  const Done({Key? key}) : super(key: key);

  @override
  _DoneState createState() => _DoneState();
}

class _DoneState extends State<Done> {
  List<Delivery> deliveries = [];
  bool isLoading = true;
  DateTime? _startDate;
  DateTime? _endDate;

  static const Color _orange = Color(0xFFFF6A1A);
  static const Color _navy = Color(0xFF0F2744);
  static const Color _bg = Color(0xFFF5F6F8);
  static const Color _muted = Color(0xFF7A8699);

  Future<void> fetchDeliveries({DateTime? startDate, DateTime? endDate}) async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('user_id');
    final formatter = DateFormat('yyyy-MM-dd');
    var query = '';
    if (startDate != null && endDate != null) {
      query =
          '?startDate=${formatter.format(startDate)}&endDate=${formatter.format(endDate)}';
    }

    final url = Uri.parse(
        '${Url.url}/api/mobile/delivery/driver/$userId/status-3$query');

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
      case 'pending':
        return const Color(0xFFE6A700);
      case 'хуваарилсан':
        return const Color(0xFF1B9BE4);
      case 'хүргэсэн':
        return const Color(0xFF1FA97A);
      case 'cancelled':
        return const Color(0xFFE5484D);
      default:
        return _orange;
    }
  }

  String statusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'Хүлээгдэж буй';
      case 'хуваарилсан':
        return 'Хуваарилсан';
      case 'хүргэсэн':
        return 'Хүргэгдсэн';
      case 'cancelled':
        return 'Цуцлагдсан';
      default:
        return status;
    }
  }

  String formatDate(DateTime date) {
    return DateFormat('MM.dd  HH:mm').format(date);
  }

  String formatPrice(num value) {
    if (value == 0) return '0₮';
    return '${NumberFormat('#,###').format(value)}₮';
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final picked = await pickAppDateRange(
      context,
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

  Future<void> _clearDateFilter() async {
    setState(() {
      _startDate = null;
      _endDate = null;
      isLoading = true;
    });
    await fetchDeliveries();
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
        leading: IconButton(
          icon: const Icon(Icons.dashboard_outlined, color: Colors.white),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => Dashboard()),
            );
          },
        ),
        title: Text(
          'Дууссан',
          style: GoogleFonts.rubik(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_alt_outlined, color: Colors.white),
            onPressed: _pickDateRange,
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: _clearDateFilter,
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
                      if (_startDate != null && _endDate != null) ...[
                        const Spacer(),
                        GestureDetector(
                          onTap: _clearDateFilter,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFE8ECF1)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '${DateFormat('MM.dd').format(_startDate!)}–${DateFormat('MM.dd').format(_endDate!)}',
                                  style: GoogleFonts.rubik(
                                      fontSize: 11, color: _navy),
                                ),
                                const SizedBox(width: 4),
                                const Icon(Icons.close, size: 14, color: _muted),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Expanded(
                  child: RefreshIndicator(
                    color: _orange,
                    onRefresh: () async {
                      setState(() => isLoading = true);
                      await fetchDeliveries(
                        startDate: _startDate,
                        endDate: _endDate,
                      );
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
                            padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
                            itemCount: deliveries.length,
                            itemBuilder: (context, index) {
                              return _item(deliveries[index], index);
                            },
                          ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _item(Delivery d, int index) {
    final accent = statusColor(d.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8ECF1)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => DeliveryDetailScreen(deliveryId: d.id),
            ),
          );
        },
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 4, color: accent),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            '${index + 1}. #${d.id}',
                            style: GoogleFonts.rubik(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: _navy,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            statusLabel(d.status),
                            style: GoogleFonts.rubik(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: accent,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(
                        d.address.isEmpty ? 'Хаяг байхгүй' : d.address,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.rubik(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: _navy,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          Text(
                            d.phone.isEmpty ? '—' : d.phone,
                            style: GoogleFonts.rubik(
                              fontSize: 12,
                              color: _muted,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            formatDate(d.createdDate),
                            style: GoogleFonts.rubik(
                              fontSize: 12,
                              color: _muted,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            formatPrice(d.priceValue),
                            style: GoogleFonts.rubik(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: _orange,
                            ),
                          ),
                          Icon(Icons.chevron_right_rounded,
                              size: 18, color: Colors.grey.shade400),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
