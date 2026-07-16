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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF5F5F5),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.deepOrange,
        title: Text('Барааны жагсаалт',
            style: GoogleFonts.rubik(fontSize: 15, color: Colors.white)),
        centerTitle: true,
        elevation: 2,
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator(color: Colors.deepOrange))
          : goods.isEmpty
          ? Center(
        child: Text(
          'Бараа олдсонгүй',
          style: GoogleFonts.rubik(fontSize: 16, color: Colors.grey),
        ),
      )
          : ListView.builder(
        padding: EdgeInsets.all(16),
        itemCount: goods.length,
        itemBuilder: (context, index) {
          final item = goods[index];
          return Container(
            margin: EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 8,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: ListTile(
              contentPadding:
              EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              leading: CircleAvatar(
                backgroundColor: Colors.deepOrange.withOpacity(0.2),
                child: Icon(Icons.shopping_basket,
                    color: Colors.deepOrange),
              ),
              title: Text(
                item['name'] ?? 'No name',
                style: GoogleFonts.rubik(
                    fontSize: 16, fontWeight: FontWeight.w500),
              ),
              trailing: Container(
                padding:
                EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.deepOrange,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${item['stock'] ?? 0} ш',
                  style: GoogleFonts.rubik(
                      color: Colors.white, fontSize: 14),
                ),
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showDialog(
            context: context,
            builder: (context) => _buildGoodFormDialog(),
          );
        },
        backgroundColor: Colors.deepOrange,
        child: Icon(Icons.add, color: Colors.white),
        tooltip: 'Шинэ бараа нэмэх',
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
