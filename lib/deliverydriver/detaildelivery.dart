import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
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
  int? selectedStatusId;
  final TextEditingController commentController = TextEditingController();
  File? _capturedImage;
  final ImagePicker _picker = ImagePicker();
  bool _submitting = false;

  static const Color _orange = Color(0xFFFF6A1A);
  static const Color _navy = Color(0xFF0F2744);
  static const Color _bg = Color(0xFFF5F6F8);
  static const Color _muted = Color(0xFF7A8699);
  static const Color _line = Color(0xFFE8ECF1);

  @override
  void initState() {
    super.initState();
    fetchDelivery().then((_) => fetchItems());
  }

  @override
  void dispose() {
    commentController.dispose();
    super.dispose();
  }

  Future<void> fetchItems() async {
    final url = Uri.parse('${Url.url}/api/delivery/${widget.deliveryId}/items');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        if (jsonResponse['success'] == true) {
          setState(() => items = jsonResponse['data'] ?? []);
        }
      }
    } catch (e) {
      debugPrint('Item fetch error: $e');
    }
  }

  Future<void> fetchDelivery() async {
    final url = Uri.parse('${Url.url}/api/delivery/${widget.deliveryId}');
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
            error = 'Мэдээлэл ачаалж чадсангүй';
            isLoading = false;
          });
        }
      } else {
        setState(() {
          error = 'Серверийн алдаа: ${response.statusCode}';
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        error = 'Алдаа гарлаа';
        isLoading = false;
      });
    }
  }

  Future<void> _callPhoneNumber(String phoneNumber) async {
    final cleaned = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
    if (cleaned.isEmpty) {
      _toast('Утасны дугаар олдсонгүй');
      return;
    }
    final uri = Uri(scheme: 'tel', path: cleaned);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      _toast('Утасны дугаарыг дуудахад алдаа гарлаа');
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
      setState(() => _capturedImage = File(image.path));
    }
  }

  void _toast(String msg, {Color? color}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.rubik()),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _submitWithImage() async {
    if (selectedStatusId == null || _submitting) return;

    if (selectedStatusId == 3 && _capturedImage == null) {
      _toast('Зураг авах шаардлагатай', color: Colors.red);
      return;
    }

    setState(() => _submitting = true);
    try {
      final url = Uri.parse(
          '${Url.url}/api/mobile/delivery/complete/${delivery!['id']}');
      final request = http.MultipartRequest('POST', url);
      request.fields['status'] = selectedStatusId.toString();
      request.fields['driver_comment'] = commentController.text.trim();

      if (_capturedImage != null) {
        request.files.add(await http.MultipartFile.fromPath(
          'image',
          _capturedImage!.path,
          filename:
              'delivery_${delivery!['id']}_${DateTime.now().millisecondsSinceEpoch}.jpg',
        ));
      }

      final response = await request.send();
      final responseData = await response.stream.bytesToString();
      final jsonResponse = json.decode(responseData);

      if (response.statusCode == 200 && jsonResponse['success'] == true) {
        _toast('Хүргэлт амжилттай бүртгэгдлээ', color: Colors.green);
        final prefs = await SharedPreferences.getInstance();
        final userId = prefs.getInt('user_id');
        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => MainScreen(id: userId!)),
            (_) => false,
          );
        }
      } else {
        _toast(jsonResponse['message'] ?? 'Алдаа гарлаа', color: Colors.red);
      }
    } catch (e) {
      _toast('Алдаа гарлаа', color: Colors.red);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _markasDeclined() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('user_id');
    final url = Uri.parse(
        '${Url.url}/api/mobile/delivery/complete/${delivery!['id']}');

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'status': 4}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        _toast('Хүргэлт цуцлагдлаа', color: Colors.red);
        if (!mounted) return;
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => MainScreen(id: userId!)),
          (_) => false,
        );
      } else {
        _toast(data['message'] ?? 'Алдаа гарлаа', color: Colors.red);
      }
    } else {
      _toast('Сервертэй холбогдож чадсангүй', color: Colors.red);
    }
  }

  String formatDate(String? isoDate) {
    if (isoDate == null || isoDate.isEmpty) return '—';
    try {
      final dateTime = DateTime.parse(isoDate);
      return DateFormat('yyyy.MM.dd  HH:mm').format(dateTime);
    } catch (_) {
      return isoDate;
    }
  }

  String formatPrice(dynamic price) {
    final value = double.tryParse(price?.toString() ?? '0') ?? 0;
    if (value == 0) return '0₮';
    return '${NumberFormat('#,###').format(value)}₮';
  }

  void _openActionSheet(int statusId) {
    selectedStatusId = statusId;
    commentController.text = '';
    _capturedImage = null;
    _showActionSheet();
  }

  void _showActionSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 12,
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
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Text(
                    'Тайлбар нэмэх',
                    style: GoogleFonts.rubik(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: _navy,
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: commentController,
                    maxLines: 3,
                    style: GoogleFonts.rubik(fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Тайлбар бичих...',
                      hintStyle: GoogleFonts.rubik(color: _muted),
                      filled: true,
                      fillColor: _bg,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  if (_capturedImage != null) ...[
                    const SizedBox(height: 14),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.file(
                        _capturedImage!,
                        height: 110,
                        width: 110,
                        fit: BoxFit.cover,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () async {
                        await _takePicture();
                        setModalState(() {});
                      },
                      icon: const Icon(Icons.camera_alt, size: 16),
                      label: Text('Зураг дахин авах',
                          style: GoogleFonts.rubik()),
                    ),
                  ] else if (selectedStatusId == 3) ...[
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          await _takePicture();
                          setModalState(() {});
                        },
                        icon: const Icon(Icons.camera_alt_outlined),
                        label: Text('Зураг авах', style: GoogleFonts.rubik()),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _orange,
                          side: const BorderSide(color: _orange),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            setState(() => _capturedImage = null);
                            Navigator.pop(context);
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _muted,
                            side: const BorderSide(color: _line),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text('Болих', style: GoogleFonts.rubik()),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            if (selectedStatusId == 3 &&
                                _capturedImage == null) {
                              _toast('Зураг авах шаардлагатай',
                                  color: Colors.red);
                              return;
                            }
                            Navigator.pop(context);
                            await _submitWithImage();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _orange,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            'Хадгалах',
                            style: GoogleFonts.rubik(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<bool?> showConfirmationDialog(String message) {
    return showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'Анхааруулга',
            style: GoogleFonts.rubik(
              fontWeight: FontWeight.w700,
              fontSize: 17,
              color: _navy,
            ),
          ),
          content: Text(
            message,
            style: GoogleFonts.rubik(fontSize: 14, color: _muted),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Үгүй',
                  style: GoogleFonts.rubik(color: _muted)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(
                'Тийм',
                style: GoogleFonts.rubik(
                  color: _orange,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  PreferredSizeWidget _appBar() {
    return AppBar(
      elevation: 0,
      backgroundColor: _orange,
      iconTheme: const IconThemeData(color: Colors.white),
      title: Text(
        'Дэлгэрэнгүй',
        style: GoogleFonts.rubik(
          color: Colors.white,
          fontSize: 17,
          fontWeight: FontWeight.w600,
        ),
      ),
      centerTitle: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        backgroundColor: _bg,
        appBar: _appBar(),
        body: const Center(child: CircularProgressIndicator(color: _orange)),
      );
    }

    if (error != null) {
      return Scaffold(
        backgroundColor: _bg,
        appBar: _appBar(),
        body: Center(
          child: Text(error!, style: GoogleFonts.rubik(color: _muted)),
        ),
      );
    }

    final merchant = delivery!['merchant']?['username']?.toString() ?? '—';
    final phone = delivery!['phone']?.toString() ?? '';
    final address = delivery!['address']?.toString() ?? '—';
    final status = delivery!['status_name']?['status']?.toString() ?? '—';
    final comment = delivery!['comment']?.toString().trim() ?? '';

    return Scaffold(
      backgroundColor: _bg,
      appBar: _appBar(),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 28),
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _line),
            ),
            padding: const EdgeInsets.fromLTRB(14, 6, 14, 6),
            child: Column(
              children: [
                _infoRow(Icons.storefront_outlined, 'Дэлгүүр', merchant),
                _divider(),
                _infoRow(
                  Icons.phone_outlined,
                  'Утас',
                  phone.isEmpty ? '—' : phone,
                  valueColor: _orange,
                  onTap: phone.isEmpty ? null : () => _callPhoneNumber(phone),
                ),
                _divider(),
                _infoRow(Icons.location_on_outlined, 'Хаяг', address),
                _divider(),
                _infoRow(
                  Icons.schedule_outlined,
                  'Цаг',
                  formatDate(delivery!['createdAt']?.toString()),
                ),
                _divider(),
                _infoRow(
                  Icons.chat_bubble_outline_rounded,
                  'Тайлбар',
                  comment.isEmpty ? '—' : comment,
                ),
                _divider(),
                _infoRow(
                  Icons.local_shipping_outlined,
                  'Төлөв',
                  status,
                  valueColor: _orange,
                ),
                _divider(),
                _infoRow(
                  Icons.payments_outlined,
                  'Үнэ',
                  formatPrice(delivery!['price']),
                  valueColor: _orange,
                  bold: true,
                ),
              ],
            ),
          ),
          if (items.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'Бараанууд',
              style: GoogleFonts.rubik(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: _navy,
              ),
            ),
            const SizedBox(height: 8),
            ...items.map((item) {
              final name = item['good']?['name'] ?? 'Нэргүй бараа';
              final qty = item['quantity'] ?? 0;
              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _line),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        name.toString(),
                        style: GoogleFonts.rubik(fontSize: 13, color: _navy),
                      ),
                    ),
                    Text(
                      '×$qty',
                      style: GoogleFonts.rubik(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _muted,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
          const SizedBox(height: 18),
          Text(
            'Үйлдэл',
            style: GoogleFonts.rubik(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: _navy,
            ),
          ),
          const SizedBox(height: 8),
          _actionTile(
            Icons.check_circle_outline,
            'Хүргэсэн',
            const Color(0xFF1FA97A),
            () => _openActionSheet(3),
          ),
          _actionTile(
            Icons.phone_outlined,
            'Утсаар ярих',
            const Color(0xFF1B9BE4),
            () => _callPhoneNumber(phone),
          ),
          _actionTile(
            Icons.schedule_outlined,
            'Хойшлуулсан',
            const Color(0xFF0D9488),
            () => _openActionSheet(10),
          ),
          _actionTile(
            Icons.undo_rounded,
            'Хаяг дээр очсон боловч буцаасан',
            const Color(0xFFE67E22),
            () => _openActionSheet(11),
          ),
          _actionTile(
            Icons.cancel_outlined,
            'Авахаа больсон',
            const Color(0xFFE5484D),
            () async {
              final confirmed =
                  await showConfirmationDialog('Та итгэлтэй байна уу?');
              if (confirmed == true) await _markasDeclined();
            },
          ),
          if (_submitting) ...[
            const SizedBox(height: 16),
            const Center(
              child: CircularProgressIndicator(color: _orange),
            ),
          ],
        ],
      ),
    );
  }

  Widget _divider() => const Divider(height: 1, color: _line);

  Widget _infoRow(
    IconData icon,
    String label,
    String value, {
    Color? valueColor,
    bool bold = false,
    VoidCallback? onTap,
  }) {
    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: _muted),
          const SizedBox(width: 10),
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: GoogleFonts.rubik(fontSize: 13, color: _muted),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.rubik(
                fontSize: 13,
                fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
                color: valueColor ?? _navy,
              ),
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return row;
    return GestureDetector(onTap: onTap, child: row);
  }

  Widget _actionTile(
    IconData icon,
    String label,
    Color color,
    VoidCallback onTap,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _line),
      ),
      child: ListTile(
        onTap: _submitting ? null : onTap,
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        leading: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(
          label,
          style: GoogleFonts.rubik(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: _navy,
          ),
        ),
        trailing: Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400),
      ),
    );
  }
}
