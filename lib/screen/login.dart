import 'dart:convert';

import 'package:sura_driver/customerscreen.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

import '../color/color.dart';
import '../mainscreen.dart';

class Login extends StatefulWidget {
  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> {
  bool _passwordVisible = false;
  bool _isDriver = true;
  bool _rememberMe = false;
  bool _isLoading = false;

  final TextEditingController passcont = TextEditingController();
  final TextEditingController namecont = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  static const Color _navy = Color(0xFF0B2C5F);
  static const Color _fieldBg = Color(0xFFF5F6F8);
  static const Color _fieldBorder = Color(0xFFE6E8EC);
  static const Color _orange = Color(0xFFFF6A1A);
  static const Color _green = Color(0xFF4CAF50);

  @override
  void initState() {
    super.initState();
    _passwordVisible = false;
    _loadRememberMeStatus();
  }

  @override
  void dispose() {
    passcont.dispose();
    namecont.dispose();
    super.dispose();
  }

  Future<void> _loadRememberMeStatus() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _rememberMe = prefs.getBool('rememberMe') ?? false;
      if (_rememberMe) {
        namecont.text = prefs.getString('username') ?? '';
        passcont.text = prefs.getString('password') ?? '';
      }
    });
  }

  Future<void> _saveRememberMeStatus() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('rememberMe', _rememberMe);
    if (_rememberMe) {
      await prefs.setString('username', namecont.text);
      await prefs.setString('password', passcont.text);
    } else {
      await prefs.remove('username');
      await prefs.remove('password');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.rubik(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        backgroundColor: const Color(0xFFD32F2F),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  String? _messageFromBody(String body) {
    try {
      final data = jsonDecode(body);
      if (data is Map) {
        final msg = data['message'] ?? data['error'] ?? data['msg'];
        if (msg != null && msg.toString().trim().isNotEmpty) {
          return msg.toString().trim();
        }
      }
    } catch (_) {}
    return null;
  }

  String _errorForStatus(int statusCode, String? serverMessage) {
    final lower = (serverMessage ?? '').toLowerCase();

    if (statusCode == 401 ||
        lower.contains('invalid credentials') ||
        lower.contains('unauthorized')) {
      return 'Нэвтрэх нэр эсвэл нууц үг буруу байна';
    }
    if (statusCode == 400 ||
        lower.contains('required') ||
        lower.contains('invalid form')) {
      return 'Нэвтрэх нэр болон нууц үгээ бүрэн оруулна уу';
    }
    if (statusCode == 403) {
      return 'Танд нэвтрэх эрх байхгүй байна';
    }
    if (statusCode == 404) {
      return 'Серверийн хаяг олдсонгүй';
    }
    if (statusCode == 408 || statusCode == 504) {
      return 'Холболт удааширлаа. Дахин оролдоно уу';
    }
    if (statusCode >= 500) {
      return 'Серверийн алдаа гарлаа. Түр хүлээгээд дахин оролдоно уу';
    }
    if (serverMessage != null && serverMessage.isNotEmpty) {
      return serverMessage;
    }
    return 'Нэвтрэхэд алдаа гарлаа ($statusCode)';
  }

  String _extractToken(dynamic token) {
    if (token is String) return token;
    if (token is Map) {
      return (token['access_token'] ?? token['token'] ?? '').toString();
    }
    return '';
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    await _saveRememberMeStatus();

    try {
      final data = {
        'username': namecont.text.trim().toLowerCase(),
        'password': passcont.text.trim(),
      };

      final uri = Uri.parse(Url.url + "/api/auth/login");
      final response = await http
          .post(
            uri,
            headers: {"Content-Type": "application/json"},
            body: jsonEncode(data),
          )
          .timeout(const Duration(seconds: 20));

      final serverMessage = _messageFromBody(response.body);

      if (response.statusCode == 200) {
        Map<String, dynamic> responseData;
        try {
          responseData = jsonDecode(response.body) as Map<String, dynamic>;
        } catch (_) {
          _showError('Серверийн хариу буруу форматтай байна');
          return;
        }

        if (responseData['success'] == true) {
          final user = responseData['user'];
          if (user is! Map) {
            _showError('Хэрэглэгчийн мэдээлэл олдсонгүй');
            return;
          }

          final int role = user['role'] ?? -1;
          final int userId = user['id'] ?? -1;
          final bool roleMatches =
              (_isDriver && role == 3) || (!_isDriver && role == 2);

          if (!roleMatches) {
            final expected = _isDriver ? 'Жолооч' : 'Харилцагч';
            _showError(
              'Таны эрх "$expected" горимд тохирохгүй байна. Доорх сэлгүүрийг солиод дахин оролдоно уу',
            );
            return;
          }

          final token = _extractToken(responseData['token']);
          if (token.isEmpty) {
            _showError('Нэвтрэх токен авч чадсангүй');
            return;
          }

          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('token', token);
          await prefs.setString('username', namecont.text.trim());
          await prefs.setInt('role', role);
          await prefs.setInt('user_id', userId);

          if (!mounted) return;

          if (role == 3) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => MainScreen(id: userId),
              ),
            );
          } else if (role == 2) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => Customerscreen(id: userId),
              ),
            );
          } else {
            _showError('Энэ эрхээр апп руу нэвтрэх боломжгүй');
          }
        } else {
          _showError(
            _errorForStatus(
              401,
              serverMessage ?? 'Нэвтрэх нэр эсвэл нууц үг буруу байна',
            ),
          );
        }
      } else {
        _showError(_errorForStatus(response.statusCode, serverMessage));
      }
    } on http.ClientException {
      _showError('Сервертэй холбогдож чадсангүй. Интернетээ шалгана уу');
    } on FormatException {
      _showError('Серверийн хариу буруу форматтай байна');
    } catch (e) {
      final msg = e.toString().toLowerCase();
      if (msg.contains('socket') ||
          msg.contains('network') ||
          msg.contains('failed host lookup') ||
          msg.contains('connection')) {
        _showError('Интернет холболтоо шалгана уу');
      } else if (msg.contains('timeout')) {
        _showError('Холболт удааширлаа. Дахин оролдоно уу');
      } else {
        _showError('Алдаа гарлаа. Дахин оролдоно уу');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  InputDecoration _fieldDecoration({
    required String hint,
    required IconData prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.rubik(
        color: Colors.grey.shade400,
        fontSize: 15,
        fontWeight: FontWeight.w400,
      ),
      prefixIcon: Icon(prefixIcon, color: Colors.grey.shade400, size: 22),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: _fieldBg,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: _fieldBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: AppColors.primaryColor, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalWidth = MediaQuery.of(context).size.width;
    final fieldWidth = totalWidth * 0.86;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: totalWidth * 0.07),
            child: Column(
              children: [
                const SizedBox(height: 48),
                Image.asset('assets/telmuun.png', width: 180),
                const SizedBox(height: 36),
                SizedBox(
                  width: fieldWidth,
                  child: TextFormField(
                    controller: namecont,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Нэвтрэх нэрээ оруулна уу';
                      }
                      return null;
                    },
                    keyboardType: TextInputType.text,
                    style: GoogleFonts.rubik(fontSize: 15, color: _navy),
                    decoration: _fieldDecoration(
                      hint: 'Нэвтрэх нэр',
                      prefixIcon: Icons.person_outline,
                    ),
                    cursorColor: AppColors.primaryColor,
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: fieldWidth,
                  child: TextFormField(
                    controller: passcont,
                    obscureText: !_passwordVisible,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Нууц үгээ оруулна уу';
                      }
                      return null;
                    },
                    keyboardType: TextInputType.text,
                    style: GoogleFonts.rubik(fontSize: 15, color: _navy),
                    decoration: _fieldDecoration(
                      hint: 'Нууц үг',
                      prefixIcon: Icons.lock_outline,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _passwordVisible
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          color: Colors.grey.shade400,
                          size: 22,
                        ),
                        onPressed: () {
                          setState(() {
                            _passwordVisible = !_passwordVisible;
                          });
                        },
                      ),
                    ),
                    cursorColor: AppColors.primaryColor,
                  ),
                ),
                const SizedBox(height: 18),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: _fieldBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _fieldBorder),
                  ),
                  child: Text(
                    'v2.0.0',
                    style: GoogleFonts.rubik(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ),
                const SizedBox(height: 80),
                SizedBox(
                  width: fieldWidth,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _login,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _orange,
                      disabledBackgroundColor: _orange.withOpacity(0.7),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'НЭВТРЭХ',
                                style: GoogleFonts.rubik(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(
                                Icons.arrow_forward,
                                color: Colors.white,
                                size: 20,
                              ),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  width: fieldWidth,
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  decoration: BoxDecoration(
                    color: _isDriver ? _green : const Color(0xFF2196F3),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _isDriver ? 'Жолооч' : 'Харилцагч',
                          style: GoogleFonts.rubik(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      Switch.adaptive(
                        value: _isDriver,
                        activeColor: Colors.white,
                        activeTrackColor: Colors.white.withOpacity(0.35),
                        inactiveThumbColor: Colors.white,
                        inactiveTrackColor: Colors.white.withOpacity(0.35),
                        onChanged: (val) {
                          setState(() {
                            _isDriver = val;
                          });
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
