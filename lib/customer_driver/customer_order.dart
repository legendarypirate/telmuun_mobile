import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../color/color.dart';

class CustomerOrder extends StatefulWidget {
  @override
  _CustomerOrderState createState() => _CustomerOrderState();
}

class _CustomerOrderState extends State<CustomerOrder> {
  List<dynamic> orders = [];
  bool isLoading = true;

  static const Color _orange = Color(0xFFFF6A1A);
  static const Color _navy = Color(0xFF0F2744);
  static const Color _bg = Color(0xFFF5F6F8);
  static const Color _muted = Color(0xFF7A8699);
  static const Color _line = Color(0xFFE8ECF1);

  @override
  void initState() {
    super.initState();
    fetchOrders();
  }

  Future<void> fetchOrders() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('user_id');
    try {
      final response = await http.get(
        Uri.parse('${Url.url}/api/mobile/order/merchant?user_id=$userId'),
      );
      if (response.statusCode == 200) {
        final jsonBody = json.decode(response.body);
        if (jsonBody['success'] == true) {
          setState(() {
            orders = jsonBody['data'] ?? [];
            isLoading = false;
          });
          return;
        }
      }
      setState(() => isLoading = false);
    } catch (_) {
      setState(() => isLoading = false);
    }
  }

  Color statusColor(int status) {
    switch (status) {
      case 1:
        return const Color(0xFFE5484D);
      case 2:
        return const Color(0xFF1B9BE4);
      case 3:
        return const Color(0xFF1FA97A);
      case 4:
        return const Color(0xFF9AA5B1);
      default:
        return _muted;
    }
  }

  String statusText(int status) {
    switch (status) {
      case 1:
        return 'Шинэ';
      case 2:
        return 'Жолоочид';
      case 3:
        return 'Хүргэгдсэн';
      case 4:
        return 'Буцаасан';
      default:
        return '—';
    }
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
          'Захиалга',
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
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                  child: Row(
                    children: [
                      Text(
                        'Нийт захиалга',
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
                          '${orders.length}',
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
                                  style: GoogleFonts.rubik(
                                      fontSize: 15, color: _muted),
                                ),
                              ),
                            ],
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(12, 0, 12, 88),
                            itemCount: orders.length,
                            itemBuilder: (context, index) {
                              return _item(orders[index], index);
                            },
                          ),
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'merchant_order_fab',
        onPressed: () {
          showDialog(
            context: context,
            builder: (_) => _buildOrderFormDialog(),
          );
        },
        backgroundColor: _orange,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _item(dynamic order, int index) {
    final status = order['status'] is int
        ? order['status'] as int
        : int.tryParse('${order['status']}') ?? 0;
    final accent = statusColor(status);
    final comment = (order['comment'] ?? '').toString().trim();

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _line),
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
                          '${index + 1}. ${statusText(status)}',
                          style: GoogleFonts.rubik(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: accent,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          (order['phone'] ?? '—').toString(),
                          style: GoogleFonts.rubik(
                            fontSize: 12,
                            color: _muted,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      (order['address'] ?? '').toString().isEmpty
                          ? 'Хаяг байхгүй'
                          : order['address'].toString(),
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
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderFormDialog() {
    final formKey = GlobalKey<FormState>();
    final phoneController = TextEditingController();
    final addressController = TextEditingController();
    final commentController = TextEditingController();

    InputDecoration inputDecoration(String label) {
      return InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.rubik(color: _muted, fontSize: 13),
        filled: true,
        fillColor: _bg,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _orange),
        ),
      );
    }

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: Colors.white,
      title: Text(
        'Шинэ захиалга',
        style: GoogleFonts.rubik(
          fontWeight: FontWeight.w700,
          fontSize: 17,
          color: _navy,
        ),
      ),
      content: SingleChildScrollView(
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                style: GoogleFonts.rubik(fontSize: 14),
                decoration: inputDecoration('Утасны дугаар'),
                validator: (value) =>
                    value == null || value.isEmpty ? 'Утас оруулна уу' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: addressController,
                style: GoogleFonts.rubik(fontSize: 14),
                decoration: inputDecoration('Хаяг'),
                validator: (value) =>
                    value == null || value.isEmpty ? 'Хаяг оруулна уу' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: commentController,
                maxLines: 3,
                style: GoogleFonts.rubik(fontSize: 14),
                decoration: inputDecoration('Тайлбар'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Болих', style: GoogleFonts.rubik(color: _muted)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: _orange,
            foregroundColor: Colors.white,
            elevation: 0,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: () async {
            if (!(formKey.currentState?.validate() ?? false)) return;
            final prefs = await SharedPreferences.getInstance();
            final userId = prefs.getInt('user_id');
            final response = await http.post(
              Uri.parse('${Url.url}/api/order'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'merchant_id': userId,
                'phone': phoneController.text,
                'address': addressController.text,
                'comment': commentController.text,
              }),
            );
            if (response.statusCode == 200 || response.statusCode == 201) {
              if (!mounted) return;
              Navigator.pop(context);
              setState(() => isLoading = true);
              fetchOrders();
            }
          },
          child: Text('Хадгалах', style: GoogleFonts.rubik()),
        ),
      ],
    );
  }
}
