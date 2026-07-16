import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

import '../color/color.dart';
import '../screen/login.dart';

class User extends StatefulWidget {
  const User({Key? key}) : super(key: key);

  @override
  State<User> createState() => _UserState();
}

class _UserState extends State<User> {
  bool isLoading = true;
  bool isSaving = false;

  final TextEditingController _usernameCtrl = TextEditingController();
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _phoneCtrl = TextEditingController();
  final TextEditingController _addressCtrl = TextEditingController();
  final TextEditingController _accountCtrl = TextEditingController();
  final TextEditingController _passwordCtrl = TextEditingController();
  final TextEditingController _confirmPassCtrl = TextEditingController();

  int? userId;

  Future<void> fetchUser() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    userId = prefs.getInt("user_id");

    if (userId == null) return;

    final url = Uri.parse("${Url.url}/api/user/$userId");
    print(url);
    try {
      final res = await http.get(url);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() {
          _usernameCtrl.text = data["username"] ?? "";
          _emailCtrl.text = data["email"] ?? "";
          _phoneCtrl.text = data["phone"] ?? "";
          _addressCtrl.text = data["address"] ?? "";
          _accountCtrl.text = data["account_number"] ?? "";
          isLoading = false;
        });
      } else {
        print("Failed to fetch user: ${res.statusCode}");
      }
    } catch (e) {
      print("Error: $e");
    }
  }

  Future<void> updateUser() async {
    if (userId == null) return;

    if (_passwordCtrl.text.isNotEmpty &&
        _passwordCtrl.text != _confirmPassCtrl.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Passwords do not match")),
      );
      return;
    }

    setState(() => isSaving = true);

    final url = Uri.parse("${Url.url}/api/user/$userId");
    final body = {
      "phone": _phoneCtrl.text,
      "address": _addressCtrl.text,
      "account_number": _accountCtrl.text,
    };

    if (_passwordCtrl.text.isNotEmpty) {
      body["password"] = _passwordCtrl.text;
    }

    try {
      final res = await http.put(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(body),
      );

      if (res.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("✅ Profile updated successfully")),
        );
        _passwordCtrl.clear();
        _confirmPassCtrl.clear();
      } else {
        print("Update failed: ${res.body}");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("❌ Failed to update profile")),
        );
      }
    } catch (e) {
      print("Error updating user: $e");
    } finally {
      setState(() => isSaving = false);
    }
  }

  @override
  void initState() {
    super.initState();
    fetchUser();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("User Profile", style: GoogleFonts.rubik(fontSize: 16)),
        backgroundColor: Colors.deepOrange,
        actions: [
          IconButton(
            icon: Icon(Icons.logout, color: Colors.white),
            onPressed: () async {
              SharedPreferences prefs = await SharedPreferences.getInstance();
              await prefs.clear();
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => Login()),
                    (_) => false,
              );
            },
          )
        ],
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            _buildTextField("Username", _usernameCtrl, readOnly: true),
            _buildTextField("Email", _emailCtrl, readOnly: true),
            _buildTextField("Phone", _phoneCtrl),
            _buildTextField("Address", _addressCtrl),
            _buildTextField("Account Number", _accountCtrl),
            SizedBox(height: 20),
            _buildTextField("New Password", _passwordCtrl,
                isPassword: true),
            _buildTextField("Confirm Password", _confirmPassCtrl,
                isPassword: true),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: isSaving ? null : updateUser,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepOrange,
                padding: EdgeInsets.symmetric(vertical: 14, horizontal: 30),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: isSaving
                  ? CircularProgressIndicator(color: Colors.white)
                  : Text("Save Changes",
                  style: GoogleFonts.rubik(
                      fontSize: 15, color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller,
      {bool isPassword = false, bool readOnly = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: controller,
        readOnly: readOnly,
        obscureText: isPassword,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
      ),
    );
  }
}
