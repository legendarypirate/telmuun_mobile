import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../color/color.dart';

class Customersummary extends StatefulWidget {
  @override
  State<Customersummary> createState() => _CustomersummaryState();
}

class _CustomersummaryState extends State<Customersummary> {
  late Future<Map<String, dynamic>> futureStats;

  static const Color _orange = Color(0xFFFF6A1A);
  static const Color _navy = Color(0xFF0F2744);
  static const Color _bg = Color(0xFFF5F6F8);
  static const Color _muted = Color(0xFF7A8699);
  static const Color _line = Color(0xFFE8ECF1);

  Future<Map<String, dynamic>> fetchStats() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('user_id');

    if (userId == null) {
      throw Exception('Хэрэглэгч олдсонгүй');
    }

    final response = await http.get(
      Uri.parse('${Url.url}/api/delivery/statistic?merchant_id=$userId'),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['success'] == true) return data;
      throw Exception('Амжилтгүй статистик');
    }
    throw Exception('API алдаа');
  }

  @override
  void initState() {
    super.initState();
    futureStats = fetchStats();
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
          'Мэдээлэл',
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
              setState(() => futureStats = fetchStats());
            },
          ),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: futureStats,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: _orange));
          }
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Алдаа гарлаа',
                style: GoogleFonts.rubik(color: _muted),
              ),
            );
          }

          final data = snapshot.data!;
          final deliveries = data['deliveries_today'] ?? 0;
          final orders = data['orders_today'] ?? 0;
          final goods = data['goods_today'] ?? 0;
          final successRate = data['success_rate_percent'] ?? 0;

          return ListView(
            padding: const EdgeInsets.all(14),
            children: [
              Text(
                'Өнөөдрийн тойм',
                style: GoogleFonts.rubik(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: _navy,
                ),
              ),
              const SizedBox(height: 12),
              _statTile(
                Icons.local_shipping_outlined,
                'Хүргэлт',
                '$deliveries',
                const Color(0xFF1B9BE4),
              ),
              _statTile(
                Icons.receipt_long_outlined,
                'Захиалга',
                '$orders',
                const Color(0xFF1FA97A),
              ),
              _statTile(
                Icons.inventory_2_outlined,
                'Бараа',
                '$goods',
                const Color(0xFF7C3AED),
              ),
              _statTile(
                Icons.percent_rounded,
                'Амжилттай',
                '$successRate%',
                _orange,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _statTile(IconData icon, String label, String value, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _line),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.rubik(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: _navy,
              ),
            ),
          ),
          Text(
            value,
            style: GoogleFonts.rubik(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
