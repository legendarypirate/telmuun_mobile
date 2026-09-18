import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sura_driver/deliverydriver/detaildelivery.dart';
import 'package:http/http.dart' as http;
import 'package:sura_driver/deliverydriver/user.dart';
import 'package:url_launcher/url_launcher.dart';

import '../color/color.dart';
import '../screen/login.dart';

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
    this.possibleStatuses = const [
      "Pending",
      "In Transit",
      "Delivered",
      "Cancelled"
    ],
  });

  factory Delivery.fromJson(Map<String, dynamic> json) {
    return Delivery(
      id: json['id'],
      phone: json['phone']?.toString() ?? '',
      status: _statusFromCode(json['status']),
      createdDate: DateTime.parse(json['createdAt']),
      comment: json['comment']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
      price: json['price']?.toString() ?? '0',
    );
  }

  double get priceValue => double.tryParse(price) ?? 0;

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

  static const Color _orange = Color(0xFFFF6A1A);
  static const Color _navy = Color(0xFF0F2744);
  static const Color _bg = Color(0xFFF5F6F8);
  static const Color _muted = Color(0xFF7A8699);

  Future<void> saveOrderLocally() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'delivery_order',
      deliveries.map((d) => d.id.toString()).toList(),
    );
  }

  Future<void> loadOrderLocally() async {
    final prefs = await SharedPreferences.getInstance();
    final savedOrder = prefs.getStringList('delivery_order');
    if (savedOrder == null || deliveries.isEmpty) return;

    deliveries.sort((a, b) {
      var indexA = savedOrder.indexOf(a.id.toString());
      var indexB = savedOrder.indexOf(b.id.toString());
      if (indexA == -1) indexA = deliveries.length;
      if (indexB == -1) indexB = deliveries.length;
      return indexA.compareTo(indexB);
    });
  }

  Future<void> fetchDeliveries({bool showLoader = true}) async {
    if (showLoader) setState(() => isLoading = true);

    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('user_id');
    final url =
        Uri.parse('${Url.url}/api/mobile/delivery/driver/$userId/status-2');

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        final List data = jsonResponse['data'] ?? [];
        setState(() {
          deliveries = data.map((item) => Delivery.fromJson(item)).toList();
        });
        await loadOrderLocally();
        if (mounted) setState(() {});
      }
    } catch (e) {
      debugPrint('Failed to load deliveries: $e');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Color statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return const Color(0xFFE6A700);
      case 'in transit':
        return const Color(0xFF1B9BE4);
      case 'delivered':
        return const Color(0xFF1FA97A);
      case 'cancelled':
        return const Color(0xFFE5484D);
      default:
        return _muted;
    }
  }

  String statusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'Хүлээгдэж буй';
      case 'in transit':
        return 'Хүргэлтэнд';
      case 'delivered':
        return 'Хүргэгдсэн';
      case 'cancelled':
        return 'Цуцлагдсан';
      default:
        return status;
    }
  }

  String formatPrice(num value) {
    if (value == 0) return '0₮';
    return '${NumberFormat('#,###').format(value)}₮';
  }

  Future<void> _call(String phone) async {
    final cleaned = phone.replaceAll(RegExp(r'[^\d+]'), '');
    if (cleaned.isEmpty) return;
    final uri = Uri.parse('tel:$cleaned');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
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
        backgroundColor: _orange,
        automaticallyImplyLeading: false,
        centerTitle: true,
        title: Text(
          'Хүргэлт',
          style: GoogleFonts.rubik(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.person_outline_rounded, color: Colors.white),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => User()),
            );
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: () => fetchDeliveries(),
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
                  padding:
                      const EdgeInsets.fromLTRB(16, 10, 16, 6),
                  child: Row(
                    children: [
                      Text(
                        'Нийт хүргэлт',
                        style: GoogleFonts.rubik(
                          fontSize: 13,
                          color: _muted,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
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
                    onRefresh: () => fetchDeliveries(showLoader: false),
                    child: deliveries.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: [
                              const SizedBox(height: 120),
                              Center(
                                child: Text(
                                  'Хүргэлт алга',
                                  style: GoogleFonts.rubik(
                                    fontSize: 15,
                                    color: _muted,
                                  ),
                                ),
                              ),
                            ],
                          )
                        : ReorderableListView.builder(
                            padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
                            buildDefaultDragHandles: false,
                            proxyDecorator: (child, index, animation) => child,
                            onReorderStart: (_) =>
                                HapticFeedback.selectionClick(),
                            onReorder: (oldIndex, newIndex) {
                              setState(() {
                                if (newIndex > oldIndex) newIndex--;
                                final item = deliveries.removeAt(oldIndex);
                                deliveries.insert(newIndex, item);
                              });
                              saveOrderLocally();
                            },
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

    return ReorderableDelayedDragStartListener(
      key: ValueKey(d.id),
      index: index,
      child: Container(
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
                            GestureDetector(
                              onTap:
                                  d.phone.isEmpty ? null : () => _call(d.phone),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.phone_rounded,
                                    size: 13,
                                    color: d.phone.isEmpty ? _muted : _orange,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    d.phone.isEmpty ? '—' : d.phone,
                                    style: GoogleFonts.rubik(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color:
                                          d.phone.isEmpty ? _muted : _orange,
                                    ),
                                  ),
                                ],
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
                            const SizedBox(width: 2),
                            Icon(
                              Icons.chevron_right_rounded,
                              size: 18,
                              color: Colors.grey.shade400,
                            ),
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
      ),
    );
  }
}
