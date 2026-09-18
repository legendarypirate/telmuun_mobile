import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import '../color/color.dart';

enum RequestType {
  create,  // 1
  income,  // 2
  outcome, // 3
}

extension RequestTypeExtension on RequestType {
  int get value {
    switch (this) {
      case RequestType.create:
        return 1;
      case RequestType.income:
        return 2;
      case RequestType.outcome:
        return 3;
    }
  }
}

class GoodListScreen extends StatefulWidget {
  @override
  _GoodListScreenState createState() => _GoodListScreenState();
}

class _GoodListScreenState extends State<GoodListScreen> {
  List<dynamic> goods = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchGoods();
  }

  Future<void> fetchGoods() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    int? userId = prefs.getInt('user_id');
    try {
      final response = await http.get(
        Uri.parse(Url.url + '/api/mobile/good/merchant?user_id=$userId'),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonBody = json.decode(response.body);
        if (jsonBody['success'] == true) {
          setState(() {
            goods = jsonBody['data'];
            isLoading = false;
          });
        } else {
          setState(() => isLoading = false);
          print('API returned success: false');
        }
      } else {
        setState(() => isLoading = false);
        print('Failed to load goods, status: ${response.statusCode}');
      }
    } catch (e) {
      setState(() => isLoading = false);
      print('Error fetching goods: $e');
    }
  }

  static const Color _orange = Color(0xFFFF6A1A);
  static const Color _navy = Color(0xFF0F2744);
  static const Color _bg = Color(0xFFF5F6F8);
  static const Color _muted = Color(0xFF7A8699);
  static const Color _line = Color(0xFFE8ECF1);

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
          'Агуулах',
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
              fetchGoods();
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
                        'Нийт бараа',
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
                          '${goods.length}',
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
                      await fetchGoods();
                    },
                    child: goods.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: [
                              const SizedBox(height: 120),
                              Center(
                                child: Text(
                                  'Бараа олдсонгүй',
                                  style: GoogleFonts.rubik(
                                      fontSize: 15, color: _muted),
                                ),
                              ),
                            ],
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(12, 0, 12, 88),
                            itemCount: goods.length,
                            itemBuilder: (context, index) {
                              final item = goods[index];
                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: _line),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 36,
                                      height: 36,
                                      decoration: BoxDecoration(
                                        color: _orange.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Icon(
                                        Icons.inventory_2_outlined,
                                        color: _orange,
                                        size: 18,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        item['name'] ?? 'Нэргүй',
                                        style: GoogleFonts.rubik(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: _navy,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      '${item['stock'] ?? 0} ш',
                                      style: GoogleFonts.rubik(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: _orange,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'merchant_ware_fab',
        onPressed: () {
          showDialog(
            context: context,
            builder: (_) => _buildGoodFormDialog(),
          );
        },
        backgroundColor: _orange,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildGoodFormDialog() {
    final _formKey = GlobalKey<FormState>();
    final TextEditingController nameController = TextEditingController();
    final TextEditingController stockController = TextEditingController();
    RequestType _selectedType = RequestType.create;
    int? selectedGoodId;

    return StatefulBuilder(
      builder: (context, setState) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'Шинэ бараа нэмэх',
            style: GoogleFonts.rubik(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: Colors.deepOrange,
            ),
          ),
          content: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_selectedType == RequestType.create)
                    TextFormField(
                      controller: nameController,
                      decoration: InputDecoration(
                        labelText: 'Нэр',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      validator: (value) => value == null || value.isEmpty
                          ? 'Нэр оруулна уу'
                          : null,
                    )
                  else
                    DropdownButtonFormField<int>(
                      decoration: InputDecoration(
                        labelText: 'Бараа сонгох',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      items: goods.map<DropdownMenuItem<int>>((good) {
                        return DropdownMenuItem<int>(
                          value: good['id'],
                          child: Text(good['name']),
                        );
                      }).toList(),
                      onChanged: (int? value) {
                        setState(() => selectedGoodId = value);
                      },
                      validator: (value) =>
                      value == null ? 'Бараа сонгоно уу' : null,
                    ),
                  SizedBox(height: 12),
                  TextFormField(
                    controller: stockController,
                    decoration: InputDecoration(
                      labelText: 'Тоо/Ширхэг',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Stock оруулна уу';
                      if (int.tryParse(value) == null) return 'Тоон утга оруулна уу';
                      return null;
                    },
                  ),
                  SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Төрөл сонгох:',
                      style: GoogleFonts.rubik(
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  SizedBox(height: 4),
                  Column(
                    children: [
                      RadioListTile<RequestType>(
                        title: Text('Бараа үүсгэх'),
                        value: RequestType.create,
                        groupValue: _selectedType,
                        activeColor: Colors.deepOrange,
                        onChanged: (value) {
                          setState(() => _selectedType = value!);
                        },
                      ),
                      RadioListTile<RequestType>(
                        title: Text('Орлого'),
                        value: RequestType.income,
                        groupValue: _selectedType,
                        activeColor: Colors.green,
                        onChanged: (value) {
                          setState(() => _selectedType = value!);
                        },
                      ),
                      RadioListTile<RequestType>(
                        title: Text('Зарлага'),
                        value: RequestType.outcome,
                        groupValue: _selectedType,
                        activeColor: Colors.red,
                        onChanged: (value) {
                          setState(() => _selectedType = value!);
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actionsPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          actions: [
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: Colors.grey[700],
                textStyle: GoogleFonts.rubik(),
              ),
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Болих'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepOrange,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                textStyle: GoogleFonts.rubik(fontWeight: FontWeight.w500),
              ),
              onPressed: () async {
                if (_formKey.currentState!.validate()) {
                  final String name = nameController.text;
                  final int stock = int.parse(stockController.text);
                  SharedPreferences prefs = await SharedPreferences.getInstance();
                  int? userId = prefs.getInt('user_id');

                  final response = await http.post(
                    Uri.parse(Url.url + '/api/request/stock'),
                    headers: {'Content-Type': 'application/json'},
                    body: jsonEncode({
                      'ware_id': 1,
                      'merchant_id': userId,
                      'amount': stock,
                      'type': _selectedType.value,
                      if (_selectedType == RequestType.create)
                        'name': name
                      else
                        'good_id': selectedGoodId,
                    }),
                  );
                  print(Url.url + '/api/request/stock');
                    print(jsonEncode({
                      'ware_id': 1,
                      'merchant_id': userId,
                      'amount': stock,
                      'type': _selectedType.value,
                      if (_selectedType == RequestType.create)
                        'name': name
                      else
                        'good_id': selectedGoodId,
                    }),);
                    print(response.statusCode);
                  if (response.statusCode == 200 || response.statusCode == 201) {
                    Navigator.of(context).pop();
                    fetchGoods();
                  } else {
                    final resBody = jsonDecode(response.body);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Алдаа гарлаа: ${resBody['message'] ?? response.reasonPhrase}',
                          style: GoogleFonts.rubik(),
                        ),
                      ),
                    );
                  }
                }
              },
              child: Text('Хадгалах', style: GoogleFonts.rubik()),
            ),
          ],
        );
      },
    );
  }
}
