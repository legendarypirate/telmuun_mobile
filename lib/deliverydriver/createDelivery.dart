import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../color/color.dart';

const List<Map<String, dynamic>> kDistricts = [
  {'id': 1, 'name': 'Баянзүрх'},
  {'id': 2, 'name': 'Сүхбаатар'},
  {'id': 3, 'name': 'Хан Уул'},
  {'id': 4, 'name': 'Баянгол'},
  {'id': 5, 'name': 'Чингэлтэй'},
  {'id': 6, 'name': 'Сонгинохайрхан'},
  {'id': 7, 'name': 'Ороннутаг'},
];

class CreateDelivery extends StatefulWidget {
  const CreateDelivery({Key? key}) : super(key: key);

  @override
  State<CreateDelivery> createState() => _CreateDeliveryState();
}

class _CreateDeliveryState extends State<CreateDelivery> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _commentController = TextEditingController();
  final _priceController = TextEditingController();
  final _qtyController = TextEditingController(text: '1');
  final _unitPriceController = TextEditingController();

  static const Color _orange = Color(0xFFFF6A1A);
  static const Color _navy = Color(0xFF0F2744);
  static const Color _bg = Color(0xFFF3F5F8);
  static const Color _muted = Color(0xFF7A8699);
  static const Color _line = Color(0xFFE6EAF0);

  int? _districtId;
  bool _loadGoods = false;
  bool _isSubmitting = false;
  bool _loadingGoods = false;
  List<dynamic> _goods = [];
  List<Map<String, dynamic>> _cartItems = [];
  int? _selectedGoodId;

  @override
  void dispose() {
    _phoneController.dispose();
    _addressController.dispose();
    _commentController.dispose();
    _priceController.dispose();
    _qtyController.dispose();
    _unitPriceController.dispose();
    super.dispose();
  }

  InputDecoration _field(
    String label, {
    IconData? icon,
    String? suffixText,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.rubik(color: _muted, fontSize: 12),
      prefixIcon: icon == null
          ? null
          : Icon(icon, size: 18, color: _muted),
      suffixText: suffixText,
      suffixStyle: GoogleFonts.rubik(
        color: _muted,
        fontWeight: FontWeight.w600,
        fontSize: 13,
      ),
      filled: true,
      fillColor: _bg,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _orange, width: 1.3),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
    );
  }

  Future<void> _fetchGoods(int merchantId) async {
    setState(() => _loadingGoods = true);
    try {
      final res = await http.get(
        Uri.parse('${Url.url}/api/good?merchant_id=$merchantId'),
      );
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        if (body['success'] == true) {
          setState(() => _goods = body['data'] ?? []);
        }
      }
    } catch (_) {
      if (mounted) _toast('Бараа ачаалж чадсангүй');
    } finally {
      if (mounted) setState(() => _loadingGoods = false);
    }
  }

  double get _cartTotal => _cartItems.fold(
        0.0,
        (sum, item) =>
            sum + ((item['unit_price'] as num) * (item['quantity'] as num)),
      );

  void _syncPriceFromCart() {
    if (_cartItems.isEmpty) return;
    _priceController.text = _cartTotal.toStringAsFixed(0);
  }

  void _addToCart() {
    if (_selectedGoodId == null) {
      _toast('Бараа сонгоно уу');
      return;
    }
    final qty = int.tryParse(_qtyController.text.trim()) ?? 0;
    final unitPrice = double.tryParse(_unitPriceController.text.trim()) ?? 0;
    if (qty < 1) {
      _toast('Тоо ширхэг оруулна уу');
      return;
    }

    final good = _goods.firstWhere(
      (g) => g['id'] == _selectedGoodId,
      orElse: () => null,
    );
    if (good == null) return;

    setState(() {
      final existing =
          _cartItems.indexWhere((e) => e['good_id'] == _selectedGoodId);
      if (existing >= 0) {
        _cartItems[existing]['quantity'] =
            (_cartItems[existing]['quantity'] as int) + qty;
        if (unitPrice > 0) _cartItems[existing]['unit_price'] = unitPrice;
      } else {
        _cartItems.add({
          'good_id': good['id'],
          'name': good['name'],
          'quantity': qty,
          'unit_price': unitPrice,
        });
      }
      _selectedGoodId = null;
      _qtyController.text = '1';
      _unitPriceController.clear();
      _syncPriceFromCart();
    });
    HapticFeedback.selectionClick();
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.rubik(fontSize: 13)),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _saveDelivery() async {
    if (!_formKey.currentState!.validate() || _isSubmitting) return;
    if (_districtId == null) {
      _toast('Дүүрэг сонгоно уу');
      return;
    }

    setState(() => _isSubmitting = true);
    final prefs = await SharedPreferences.getInstance();
    final merchantId = prefs.getInt('user_id');
    final token = prefs.getString('token');

    final payload = {
      'merchant_id': merchantId,
      'phone': _phoneController.text.trim(),
      'address': _addressController.text.trim(),
      'status': 1,
      'price': double.tryParse(_priceController.text.trim()) ?? 0,
      'comment': _commentController.text.trim(),
      'district_id': _districtId,
      'items': _cartItems
          .map((e) => {
                'good_id': e['good_id'],
                'quantity': e['quantity'],
              })
          .toList(),
    };

    try {
      final res = await http.post(
        Uri.parse('${Url.url}/api/delivery'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null && token.isNotEmpty)
            'Authorization': 'Bearer $token',
        },
        body: jsonEncode(payload),
      );

      final body = jsonDecode(res.body);
      if ((res.statusCode == 200 || res.statusCode == 201) &&
          (body['success'] == true || body['success'] == null)) {
        if (!mounted) return;
        _toast('Хүргэлт амжилттай үүслээ');
        Navigator.pop(context, true);
      } else {
        _toast(body['message']?.toString() ?? 'Алдаа гарлаа');
      }
    } catch (_) {
      _toast('Сервертэй холбогдож чадсангүй');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: _orange,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          'Шинэ хүргэлт',
          style: GoogleFonts.rubik(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          style: GoogleFonts.rubik(fontSize: 14, color: _navy),
                          decoration: _field('Утас', icon: Icons.phone_outlined),
                          validator: (v) => v == null || v.trim().isEmpty
                              ? 'Оруулна уу'
                              : null,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          value: _districtId,
                          isDense: true,
                          isExpanded: true,
                          decoration:
                              _field('Дүүрэг', icon: Icons.map_outlined),
                          hint: Text(
                            'Сонгох',
                            style: GoogleFonts.rubik(
                                color: _muted, fontSize: 13),
                          ),
                          items: kDistricts
                              .map(
                                (d) => DropdownMenuItem<int>(
                                  value: d['id'] as int,
                                  child: Text(
                                    d['name'] as String,
                                    style: GoogleFonts.rubik(fontSize: 13),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (v) => setState(() => _districtId = v),
                          validator: (v) => v == null ? 'Сонгоно уу' : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _addressController,
                    style: GoogleFonts.rubik(fontSize: 14, color: _navy),
                    maxLines: 2,
                    decoration:
                        _field('Хаяг', icon: Icons.location_on_outlined),
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Хаяг оруулна уу' : null,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _priceController,
                    keyboardType: TextInputType.number,
                    style: GoogleFonts.rubik(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: _navy,
                    ),
                    decoration: _field(
                      'Үнэ',
                      icon: Icons.payments_outlined,
                      suffixText: '₮',
                    ),
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Үнэ оруулна уу' : null,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _commentController,
                    maxLines: 2,
                    style: GoogleFonts.rubik(fontSize: 14, color: _navy),
                    decoration: _field(
                      'Тайлбар',
                      icon: Icons.chat_bubble_outline_rounded,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.fromLTRB(10, 4, 6, 4),
                    decoration: BoxDecoration(
                      color: _bg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      secondary: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.inventory_2_outlined,
                          size: 16,
                          color: _orange,
                        ),
                      ),
                      title: Text(
                        'Агуулахаас бараа',
                        style: GoogleFonts.rubik(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _navy,
                        ),
                      ),
                      subtitle: Text(
                        'Бараа сонгож нэмэх',
                        style: GoogleFonts.rubik(fontSize: 11, color: _muted),
                      ),
                      activeTrackColor: _orange.withValues(alpha: 0.4),
                      activeThumbColor: _orange,
                      value: _loadGoods,
                      onChanged: (val) async {
                        setState(() => _loadGoods = val);
                        if (val) {
                          final prefs = await SharedPreferences.getInstance();
                          final merchantId = prefs.getInt('user_id');
                          if (merchantId != null) await _fetchGoods(merchantId);
                        } else {
                          setState(() {
                            _cartItems.clear();
                            _selectedGoodId = null;
                          });
                        }
                      },
                    ),
                  ),
                  if (_loadGoods) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _line),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_loadingGoods)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 14),
                              child: Center(
                                child: SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: _orange,
                                  ),
                                ),
                              ),
                            )
                          else if (_goods.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Text(
                                'Бараа олдсонгүй',
                                style: GoogleFonts.rubik(
                                    fontSize: 13, color: _muted),
                              ),
                            )
                          else ...[
                            DropdownButtonFormField<int>(
                              value: _selectedGoodId,
                              isDense: true,
                              isExpanded: true,
                              decoration: _field('Бараа',
                                  icon: Icons.shopping_bag_outlined),
                              hint: Text(
                                'Бараа сонгох',
                                style: GoogleFonts.rubik(
                                    color: _muted, fontSize: 13),
                              ),
                              items: _goods
                                  .map(
                                    (g) => DropdownMenuItem<int>(
                                      value: g['id'] as int,
                                      child: Text(
                                        '${g['name']} · ${g['stock'] ?? 0}ш',
                                        style: GoogleFonts.rubik(fontSize: 13),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (v) =>
                                  setState(() => _selectedGoodId = v),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: TextFormField(
                                    controller: _qtyController,
                                    keyboardType: TextInputType.number,
                                    style: GoogleFonts.rubik(fontSize: 14),
                                    decoration: _field('Тоо'),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  flex: 3,
                                  child: TextFormField(
                                    controller: _unitPriceController,
                                    keyboardType: TextInputType.number,
                                    style: GoogleFonts.rubik(fontSize: 14),
                                    decoration:
                                        _field('Нэгж үнэ', suffixText: '₮'),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                SizedBox(
                                  height: 42,
                                  width: 42,
                                  child: ElevatedButton(
                                    onPressed: _addToCart,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: _orange,
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      padding: EdgeInsets.zero,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                    child: const Icon(Icons.add, size: 20),
                                  ),
                                ),
                              ],
                            ),
                          ],
                          if (_cartItems.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Text(
                                  'Сонгосон',
                                  style: GoogleFonts.rubik(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: _muted,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  NumberFormat('#,###').format(_cartTotal) +
                                      '₮',
                                  style: GoogleFonts.rubik(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: _orange,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            ..._cartItems.asMap().entries.map((entry) {
                              final i = entry.key;
                              final item = entry.value;
                              return Container(
                                margin: const EdgeInsets.only(bottom: 6),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 8),
                                decoration: BoxDecoration(
                                  color: _bg,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        '${item['name'] ?? item['good_id']}',
                                        style: GoogleFonts.rubik(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                          color: _navy,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      '×${item['quantity']}',
                                      style: GoogleFonts.rubik(
                                        fontSize: 12,
                                        color: _muted,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      '${NumberFormat('#,###').format((item['unit_price'] as num) * (item['quantity'] as num))}₮',
                                      style: GoogleFonts.rubik(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: _orange,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          _cartItems.removeAt(i);
                                          _syncPriceFromCart();
                                        });
                                      },
                                      child: const Icon(Icons.close_rounded,
                                          size: 16, color: _muted),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          Container(
            padding: EdgeInsets.fromLTRB(
              12,
              10,
              12,
              10 + MediaQuery.of(context).padding.bottom,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: _line)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _saveDelivery,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _orange,
                  disabledBackgroundColor: _orange.withValues(alpha: 0.55),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        'Үүсгэх',
                        style: GoogleFonts.rubik(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
