import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import '../customerscreen.dart';

class CreateDelivery extends StatefulWidget {
  const CreateDelivery({Key? key}) : super(key: key);

  @override
  State<CreateDelivery> createState() => _CreateDeliveryState();
}

class _CreateDeliveryState extends State<CreateDelivery> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _commentController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();

  final _formKey = GlobalKey<FormState>();

  bool _loadGoods = false;
  List<dynamic> _goods = [];
  List<Map<String, dynamic>> _cartItems = [];
  bool _isSubmitting = false; // Added loading state

  @override
  void dispose() {
    _phoneController.dispose();
    _addressController.dispose();
    _commentController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _fetchGoods(int merchantId) async {
    final res = await http.get(
        Uri.parse('https://api.teensclub.mn/api/good?merchant_id=$merchantId'));
    if (res.statusCode == 200) {
      final body = jsonDecode(res.body);
      if (body['success'] == true) {
        setState(() => _goods = body['data']);
      }
    }
  }

  double calculateTotalPrice() {
    return _cartItems.fold(
        0.0, (sum, item) => sum + (item['unit_price'] * item['quantity']));
  }

  void _saveDelivery() async {
    if (_formKey.currentState!.validate() && !_isSubmitting) {
      setState(() {
        _isSubmitting = true; // Start loading
      });

      final prefs = await SharedPreferences.getInstance();
      final merchantId = prefs.getInt('user_id');

      final payload = {
        'merchant_id': merchantId,
        'phone': _phoneController.text.trim(),
        'address': _addressController.text.trim(),
        'price': double.tryParse(_priceController.text.trim()) ?? 0,
        'comment': _commentController.text.trim(),
        'items': _cartItems
            .map((e) => {
          'good_id': e['good_id'],
          'quantity': e['quantity'],
        })
            .toList(),
      };

      print(payload);
      try {
        final res = await http.post(
          Uri.parse('https://api.teensclub.mn/api/delivery'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(payload),
        );

        if (res.statusCode == 200 || res.statusCode == 201) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => Customerscreen(
                id: int.parse(merchantId.toString()),
              ),
            ),
          );
        } else {
          final body = jsonDecode(res.body);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(body['message'] ?? 'Алдаа гарлаа')),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Алдаа гарлаа: $e')),
        );
      } finally {
        setState(() {
          _isSubmitting = false; // Stop loading regardless of success/failure
        });
      }
    }
  }

  Widget _buildGoodsCard() {
    return Column(
      children: _goods.map((good) {
        final pricePerUnitController = TextEditingController();
        final quantityController = TextEditingController(text: '1');

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(good['name'],
                    style: GoogleFonts.rubik(fontWeight: FontWeight.bold)),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: pricePerUnitController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Нэгж үнэ'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: quantityController,
                        keyboardType: TextInputType.number,
                        decoration:
                        const InputDecoration(labelText: 'Тоо ширхэг'),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle, color: Colors.green),
                      onPressed: () {
                        final unitPrice =
                            double.tryParse(pricePerUnitController.text) ?? 0;
                        final qty =
                            int.tryParse(quantityController.text) ?? 1;

                        if (unitPrice > 0 && qty > 0) {
                          setState(() {
                            _cartItems.add({
                              'good_id': good['id'],
                              'quantity': qty,
                              'unit_price': unitPrice,
                            });

                            final total = calculateTotalPrice();
                            _priceController.text =
                                total.toStringAsFixed(2);

                            print('🛒 Сагсанд нэмэгдсэн бараа: ${good['name']}');
                            for (var item in _cartItems) {
                              print(
                                  '📦 ID: ${item['good_id']}, Qty: ${item['quantity']}, ₮: ${item['unit_price']}');
                            }
                          });
                        }
                      },
                    )
                  ],
                )
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCartList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Text('Сагсанд нэмэгдсэн бараанууд:',
            style: GoogleFonts.rubik(fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        ListView.builder(
          itemCount: _cartItems.length,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemBuilder: (context, index) {
            final item = _cartItems[index];
            final good = _goods.firstWhere((g) => g['id'] == item['good_id'],
                orElse: () => null);
            return ListTile(
              leading: const Icon(Icons.inventory, color: Colors.deepOrange),
              title: Text(
                  good != null
                      ? good['name']
                      : 'ID: ${item['good_id']}',
                  style: GoogleFonts.rubik()),
              subtitle: Text(
                  'Тоо: ${item['quantity']} | Нэгж үнэ: ₮${item['unit_price']}'),
              trailing: Text(
                  '₮${(item['unit_price'] * item['quantity']).toStringAsFixed(2)}'),
            );
          },
        )
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true, // ✅ Keyboard гарсан ч дээр гарна
      appBar: AppBar(
        title: Text('Шинэ хүргэлт нэмэх',
            style: GoogleFonts.rubik(color: Colors.white, fontSize: 15)),
        backgroundColor: Colors.deepOrange,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: ListView(
              children: [
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  style: GoogleFonts.rubik(),
                  decoration: InputDecoration(
                    labelText: 'Утасны дугаар',
                    labelStyle: GoogleFonts.rubik(),
                  ),
                  validator: (value) =>
                  value == null || value.isEmpty ? 'Утас оруулна уу' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _addressController,
                  style: GoogleFonts.rubik(),
                  decoration: InputDecoration(
                    labelText: 'Хаяг',
                    labelStyle: GoogleFonts.rubik(),
                  ),
                  validator: (value) =>
                  value == null || value.isEmpty ? 'Хаяг оруулна уу' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _priceController,
                  keyboardType: TextInputType.number,
                  style: GoogleFonts.rubik(),
                  decoration: InputDecoration(
                    labelText: 'Үнэ (нийт)',
                    labelStyle: GoogleFonts.rubik(),
                  ),
                  validator: (value) =>
                  value == null || value.isEmpty ? 'Үнэ оруулна уу' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _commentController,
                  maxLines: 2,
                  style: GoogleFonts.rubik(),
                  decoration: InputDecoration(
                    labelText: 'Тайлбар',
                    labelStyle: GoogleFonts.rubik(),
                  ),
                ),
                const SizedBox(height: 12),
                CheckboxListTile(
                  title: Text('Агуулахаас бараа дуудах',
                      style: GoogleFonts.rubik()),
                  value: _loadGoods,
                  onChanged: (val) async {
                    setState(() => _loadGoods = val!);
                    if (val!) {
                      final prefs = await SharedPreferences.getInstance();
                      final merchantId = prefs.getInt('user_id');
                      if (merchantId != null) await _fetchGoods(merchantId);
                    }
                  },
                ),
                if (_loadGoods) _buildGoodsCard(),
                if (_cartItems.isNotEmpty) _buildCartList(),
                const SizedBox(height: 20),
                SafeArea(
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _saveDelivery, // Disable when submitting
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepOrange),
                    child: _isSubmitting
                        ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                        : Text('Хадгалах',
                        style: GoogleFonts.rubik(color: Colors.white)),
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