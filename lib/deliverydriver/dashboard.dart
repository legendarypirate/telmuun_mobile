import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../color/color.dart';
import '../orderdriver/detail.dart';

class Dashboard extends StatefulWidget {
  @override
  _DashboardState createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  List<Map<String, dynamic>> orders = [];
  bool isLoading = true;

  static const Color _orange = Color(0xFFFF6A1A);
  static const Color _navy = Color(0xFF0F2744);
  static const Color _bg = Color(0xFFF5F6F8);
  static const Color _muted = Color(0xFF7A8699);

  @override
  void initState() {
    super.initState();
    fetchOrders();
  }

  Future<void> fetchOrders() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getInt('user_id');
    final url = Uri.parse('${Url.url}/api/mobile/order/driver/$id/status-2');

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        final List data = decoded['data'] ?? [];
        setState(() {
          orders = data
              .map((item) => {
                    'id': item['id'],
                    'merchant': item['merchant']?['username'] ?? '',
                    'phone': item['phone']?.toString() ?? '',
                    'address': item['address']?.toString() ?? '',
                    'comment': item['comment']?.toString() ?? '',
                    'status': item['status_text']?.toString() ?? '',
                  })
              .toList();
          isLoading = false;
        });
      } else {
        setState(() => isLoading = false);
      }
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: _orange,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          'Хянах самбар',
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
              fetchOrders();
            },
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: _orange))
          : RefreshIndicator(
              color: _orange,
              onRefresh: () async {
                setState(() => isLoading = true);
                await fetchOrders();
              },
              child: orders.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        const SizedBox(height: 120),
                        Center(
                          child: Text(
                            'Захиалга алга',
                            style:
                                GoogleFonts.rubik(fontSize: 15, color: _muted),
                          ),
                        ),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
                      itemCount: orders.length,
                      itemBuilder: (context, index) {
                        final order = orders[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border:
                                Border.all(color: const Color(0xFFE8ECF1)),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      OrderDetailScreen(orderId: order['id']),
                                ),
                              );
                            },
                            child: IntrinsicHeight(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Container(width: 4, color: _orange),
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                          12, 10, 10, 10),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Text(
                                                '${index + 1}. #${order['id']}',
                                                style: GoogleFonts.rubik(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w700,
                                                  color: _navy,
                                                ),
                                              ),
                                              const Spacer(),
                                              Flexible(
                                                child: Text(
                                                  order['merchant'] ?? '',
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: GoogleFonts.rubik(
                                                    fontSize: 12,
                                                    color: _muted,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 5),
                                          Text(
                                            (order['address'] ?? '')
                                                    .toString()
                                                    .isEmpty
                                                ? 'Хаяг байхгүй'
                                                : order['address'],
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
                                                (order['phone'] ?? '')
                                                        .toString()
                                                        .isEmpty
                                                    ? '—'
                                                    : order['phone'],
                                                style: GoogleFonts.rubik(
                                                  fontSize: 12,
                                                  color: _orange,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                              const Spacer(),
                                              Icon(Icons.chevron_right_rounded,
                                                  size: 18,
                                                  color: Colors.grey.shade400),
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
                      },
                    ),
            ),
    );
  }
}
