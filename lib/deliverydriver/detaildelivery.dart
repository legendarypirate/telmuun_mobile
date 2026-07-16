import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';

import '../color/color.dart';
import '../mainscreen.dart';

class DeliveryDetailScreen extends StatefulWidget {
  final int deliveryId;

  DeliveryDetailScreen({required this.deliveryId});

  @override
  State<DeliveryDetailScreen> createState() => _DeliveryDetailScreenState();
}

class _DeliveryDetailScreenState extends State<DeliveryDetailScreen> {
  Map<String, dynamic>? delivery;
  bool isLoading = true;
  String? error;
  List<dynamic> items = [];
  List<dynamic> statuses = [];
  int? selectedStatusId;
  TextEditingController commentController = TextEditingController();
  File? _capturedImage;
  final ImagePicker _picker = ImagePicker();

  Future<void> fetchItems() async {
    final url = Uri.parse('${Url.url}/api/delivery/${widget.deliveryId}/items');

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        if (jsonResponse['success'] == true) {
          setState(() {
            items = jsonResponse['data'];
          });
        }
      } else {
        print('Item fetch failed: ${response.statusCode}');
      }
    } catch (e) {
      print('Item fetch error: $e');
    }
  }

  Future<void> _callPhoneNumber(String phoneNumber) async {
    final Uri phoneUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(phoneUri)) {
      await launchUrl(phoneUri);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Утасны дугаарыг дуудахад алдаа гарлаа')),
      );
    }
  }

  Future<void> _takePicture() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 800,
      maxHeight: 600,
      imageQuality: 80,
    );

    if (image != null) {
      setState(() {
        _capturedImage = File(image.path);
      });
    }
  }


  Future<void> _submitWithImage() async {
    if (selectedStatusId == null) return;

    if (selectedStatusId == 3 && _capturedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Зураг авах шаардлагатай')),
      );
      return;
    }

    try {
      final url = Uri.parse('${Url.url}/api/mobile/delivery/complete/${delivery!['id']}');

      // Log for postpone button (status = 10)
      if (selectedStatusId == 10) {
        print('======= ХОЙШЛУУЛАХ REQUEST =======');
        print('URL: $url');
        print('Delivery ID: ${delivery!['id']}');
        print('Status ID: $selectedStatusId');
        print('Comment: ${commentController.text.trim()}');
        print('Image: ${_capturedImage?.path ?? "No image"}');
      }

      var request = http.MultipartRequest('POST', url);

      // Add text fields
      request.fields['status'] = selectedStatusId.toString();
      request.fields['driver_comment'] = commentController.text.trim();

      // Log headers and payload for postpone
      if (selectedStatusId == 10) {
        print('--- Request Headers ---');
        request.headers.forEach((key, value) {
          print('$key: $value');
        });

        print('--- Request Payload ---');
        print('status: ${selectedStatusId.toString()}');
        print('driver_comment: ${commentController.text.trim()}');
        print('--- End Payload ---');
      }

      // Add image if exists
      if (_capturedImage != null) {
        var multipartFile = await http.MultipartFile.fromPath(
          'image',
          _capturedImage!.path,
          filename: 'delivery_${delivery!['id']}_${DateTime.now().millisecondsSinceEpoch}.jpg',
        );
        request.files.add(multipartFile);

        // Log image info for postpone
        if (selectedStatusId == 10) {
          print('Image attached: ${_capturedImage!.path}');
          print('Image size: ${await _capturedImage!.length()} bytes');
        }
      }

      var response = await request.send();
      var responseData = await response.stream.bytesToString();
      var jsonResponse = json.decode(responseData);

      // Log response for postpone
      if (selectedStatusId == 10) {
        print('--- Response ---');
        print('Status Code: ${response.statusCode}');
        print('Response Body: $responseData');
        print('Parsed JSON: $jsonResponse');
        print('======= END REQUEST =======');
      }

      if (response.statusCode == 200 && jsonResponse['success'] == true) {
        // Log success for postpone
        if (selectedStatusId == 10) {
          print('✅ Хойшлуулах амжилттай!');
          if (jsonResponse['data'] != null) {
            print('New scheduled date: ${jsonResponse['data']['scheduled_delivery_date']}');
            print('Postponed from: ${jsonResponse['data']['postponed_from']}');
          }
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Хүргэлт амжилттай бүртгэгдлээ')),
        );

        final prefs = await SharedPreferences.getInstance();
        final userId = prefs.getInt('user_id');
        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => MainScreen(id: userId!)),
                (route) => false,
          );
        }
      } else {
        // Log error for postpone
        if (selectedStatusId == 10) {
          print('❌ Хойшлуулах алдаа гарлаа!');
          print('Error message: ${jsonResponse['message']}');
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(jsonResponse['message'] ?? 'Алдаа гарлаа')),
        );
      }
    } catch (e) {
      // Log exception for postpone
      if (selectedStatusId == 10) {
        print('❌ Хойшлуулах Exception: $e');
        print('Stack trace: ${e.toString()}');
      }

      print('Delivery completion error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Алдаа гарлаа: $e')),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    fetchDelivery();
    fetchDelivery().then((_) {
      fetchItems();
    });
  }

  Future<void> fetchDelivery() async {
    final url = Uri.parse(Url.url + '/api/delivery/${widget.deliveryId}');

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        if (jsonResponse['success'] == true) {
          setState(() {
            delivery = jsonResponse['data'];
            isLoading = false;
            error = null;
          });
        } else {
          setState(() {
            error = 'Failed to load delivery details';
            isLoading = false;
          });
        }
      } else {
        setState(() {
          error = 'Server error: ${response.statusCode}';
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        error = 'Error: $e';
        isLoading = false;
      });
    }
  }

  String formatDate(String isoDate) {
    try {
      final dateTime = DateTime.parse(isoDate);
      return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} '
          '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return isoDate;
    }
  }

  void _showPostponeSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text('Тайлбар нэмэх',
                  style: GoogleFonts.rubik(
                      fontSize: 18, fontWeight: FontWeight.w600)),
              const SizedBox(height: 16),
              TextField(
                controller: commentController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Тайлбар',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),

              if (_capturedImage != null) ...[
                const SizedBox(height: 16),
                Text(
                  'Авсан зураг:',
                  style: GoogleFonts.rubik(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                Container(
                  height: 100,
                  width: 100,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Image.file(
                    _capturedImage!,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  icon: Icon(Icons.camera_alt, size: 16),
                  label: Text('Зураг дахин авах'),
                  onPressed: _takePicture,
                ),
              ] else if (selectedStatusId == 3) ...[
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  icon: Icon(Icons.camera_alt),
                  label: Text('Зураг авах'),
                  onPressed: _takePicture,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],

              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.grey.shade700,
                        side: BorderSide(color: Colors.grey.shade400),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        setState(() {
                          _capturedImage = null;
                        });
                        Navigator.pop(context);
                      },
                      child: const Text('Болих'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepOrange,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () async {
                        if (selectedStatusId == 3 && _capturedImage == null) {
                          OverlayEntry entry = OverlayEntry(
                            builder: (context) => Positioned(
                              top: 50,
                              left: 20,
                              right: 20,
                              child: Material(
                                color: Colors.transparent,
                                child: Container(
                                  padding: EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.red,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    'Зураг авах шаардлагатай',
                                    style: TextStyle(color: Colors.white),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                            ),
                          );

                          Overlay.of(context).insert(entry);
                          await Future.delayed(Duration(seconds: 2));
                          entry.remove();
                          return;
                        }

                        Navigator.pop(context);
                        await _submitWithImage();
                      },
                      child: Text('Хадгалах',
                          style: GoogleFonts.rubik(color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _actionButton(
      String label, IconData icon, Color color, VoidCallback onPressed) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        textStyle: GoogleFonts.rubik(fontSize: 11),
      ),
    );
  }

  Future<bool?> showConfirmationDialog(BuildContext context, String message) {
    return showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.deepOrange),
              SizedBox(width: 8),
              Text(
                'Анхааруулга',
                style: GoogleFonts.rubik(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                  color: Colors.deepOrange,
                ),
              ),
            ],
          ),
          content: Text(
            message,
            style: GoogleFonts.rubik(
              fontSize: 16,
              color: Colors.black87,
            ),
          ),
          actionsPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          actions: [
            TextButton.icon(
              icon: Icon(Icons.close, color: Colors.red),
              label: Text(
                'Үгүй',
                style: GoogleFonts.rubik(
                  fontSize: 14,
                  color: Colors.red,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            TextButton.icon(
              icon: Icon(Icons.check_circle, color: Colors.green),
              label: Text(
                'Тийм',
                style: GoogleFonts.rubik(
                  fontSize: 14,
                  color: Colors.green,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    );
  }

  Future<void> _markasDeclined() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('user_id');

    final url =
    Uri.parse(Url.url + '/api/mobile/delivery/complete/${delivery!['id']}');

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'status': 4}),
    );
    print(url);
    print(jsonEncode({'status': 5}));
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Хүргэлт цуцлагдлаа'),
            backgroundColor: Colors.red,
          ),
        );

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MainScreen(id: userId!),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(data['message'] ?? 'Алдаа гарлаа'),
              backgroundColor: Colors.red),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Сервертэй холбогдож чадсангүй'),
            backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            'Хүргэлтийн дэлгэрэнгүй',
            style: GoogleFonts.rubik(color: Colors.white, fontSize: 13),
          ),
          backgroundColor: Colors.deepOrange,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (error != null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            'Хүргэлтийн дэлгэрэнгүй',
            style: GoogleFonts.rubik(color: Colors.white, fontSize: 13),
          ),
          backgroundColor: Colors.deepOrange,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: Center(child: Text(error!)),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Хүргэлтийн дэлгэрэнгүй',
          style: GoogleFonts.rubik(color: Colors.white, fontSize: 13),
        ),
        backgroundColor: Colors.deepOrange,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "👤 Дэлгүүр: ${(delivery!['merchant']?['username'] ?? 'N/A')} 📞 ${(delivery!['merchant']?['phone'] ?? 'N/A')}",
                      style: GoogleFonts.rubik(
                          fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "📞 Утас: ${delivery!['phone'] ?? 'N/A'}",
                      style: GoogleFonts.rubik(
                          fontSize: 14, color: Colors.black87),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "📍 Хаяг: ${delivery!['address'] ?? 'N/A'}",
                      style: GoogleFonts.rubik(
                          fontSize: 14, color: Colors.black87),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "⏰ Цаг: ${formatDate(delivery!['createdAt'] ?? '')}",
                      style: GoogleFonts.rubik(
                          fontSize: 14, color: Colors.black87),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "💬 Тайлбар: ${formatDate(delivery!['comment'] ?? '')}",
                      style: GoogleFonts.rubik(
                          fontSize: 14, color: Colors.black87),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "🚚 Төлөв: ${delivery!['status_name']?['status'] ?? 'N/A'}",
                      style: GoogleFonts.rubik(
                        fontSize: 14,
                        color: Colors.deepOrange,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "💰 Үнэ: ${delivery!['price']?.toString() ?? '0'}₮",
                      style: GoogleFonts.rubik(
                        fontSize: 14,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(height: 24),
            if (items.isNotEmpty) ...[
              Text(
                "📦 Бараанууд",
                style: GoogleFonts.rubik(
                    fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              ...items.map((item) {
                final name = item['good']?['name'] ?? 'Нэргүй бараа';
                final qty = item['quantity'] ?? 0;
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding:
                  const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        name.toString(),
                        style: GoogleFonts.rubik(fontSize: 14),
                      ),
                      Text(
                        "Тоо: $qty",
                        style: GoogleFonts.rubik(fontSize: 14),
                      ),
                    ],
                  ),
                );
              }).toList()
            ],
            const SizedBox(height: 24),
            GridView.count(
              shrinkWrap: true,
              crossAxisCount: 3,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.5,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _actionButton("Хүргэсэн", Icons.check_circle, Colors.green,
                        () async {
                      selectedStatusId = 3;
                      commentController.text = '';
                      _capturedImage = null;
                      _showPostponeSheet();
                    }),
                _actionButton("Авахаа больсон", Icons.cancel, Colors.red, () async {
                  final confirmed = await showConfirmationDialog(
                      context, 'Та итгэлтэй байна уу?');
                  if (confirmed == true) {
                    _markasDeclined();
                  }
                }),
                _actionButton("Утсаар ярих", Icons.phone, Colors.indigo, () {
                  final phone = delivery?['phone'] ?? '';
                  if (phone.isNotEmpty) {
                    _callPhoneNumber(phone);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Утасны дугаар олдсонгүй')));
                  }
                }),
                _actionButton("Хаягаар очсон боловч буцаасан", Icons.camera_alt, Colors.orange, () {
                  selectedStatusId = 11;
                  commentController.text = '';
                  _capturedImage = null;
                  _showPostponeSheet();
                }),
                _actionButton("Хойшлуулсан", Icons.map, Colors.teal, () {
                  selectedStatusId = 10;
                  commentController.text = '';
                  _capturedImage = null;
                  _showPostponeSheet();
                }),
              ],
            )
          ],
        ),
      ),
    );
  }
}