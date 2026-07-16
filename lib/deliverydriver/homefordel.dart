import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../color/color.dart';

class SummaryScreen extends StatefulWidget {


  @override
  State<SummaryScreen> createState() => _SummaryScreenState();
}

class _SummaryScreenState extends State<SummaryScreen> {
  DateTime? startDate;
  DateTime? endDate;

  final DateFormat dateFormat = DateFormat('yyyy-MM-dd');
  Map<String, Map<String, dynamic>> dailyData = {};
  Set<String> selectedDates = {};
  bool loading = false;
  int? driverId;

  @override
  void initState() {
    super.initState();
    _loadDriverId();
  }

  Future<void> _loadDriverId() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('user_id');
    setState(() {
      driverId = userId;
    });
  }
  Future<void> fetchReport() async {
    if (startDate == null || endDate == null) return;

    setState(() => loading = true);

    final url = Uri.parse(
      Url.url+ '/api/mobile/delivery/report?driver_id=$driverId&start_date=${dateFormat.format(startDate!)}&end_date=${dateFormat.format(endDate!)}',
    );
    print(url);
    try {
      final res = await http.get(url);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final Map<String, Map<String, dynamic>> parsedData = {};
        for (var item in data['data']) {
          final totalDeliveries = int.tryParse(item['total_deliveries'] ?? '0') ?? 0;
          final deliveredCount = int.tryParse(item['delivered_count'] ?? '0') ?? 0;
          final deliveredTotalPrice = double.tryParse(item['delivered_total_price'] ?? '0') ?? 0;
          final forDriver = double.tryParse(item['for_driver'] ?? '0') ?? 0;
          final driverMargin = double.tryParse(item['driver_margin'] ?? '0') ?? 0;

          parsedData[item['date']] = {
            'totalDelivery': totalDeliveries,
            'deliveredDelivery': deliveredCount,
            'totalAmount': deliveredTotalPrice.toInt(),
            'driverSalary': forDriver.toInt(),
            'difference': driverMargin.toInt(),
          };
        }

        setState(() {
          dailyData = parsedData;
        });
      } else {
        print('Failed to fetch: ${res.statusCode}');
      }
    } catch (e) {
      print('Error: $e');
    } finally {
      setState(() => loading = false);
    }
  }

  Future<void> pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: startDate ?? DateTime.now(),
      firstDate: DateTime(2023, 1, 1),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        startDate = picked;
        selectedDates.clear();
        if (endDate != null && endDate!.isBefore(startDate!)) {
          endDate = null;
          dailyData.clear();
        }
      });
      if (endDate != null) await fetchReport();
    }
  }

  Future<void> pickEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: endDate ?? DateTime.now(),
      firstDate: startDate ?? DateTime(2023, 1, 1),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        endDate = picked;
        selectedDates.clear();
      });
      if (startDate != null) await fetchReport();
    }
  }

  Map<String, int> calculateSelectedTotals() {
    final totals = {
      'totalDelivery': 0,
      'deliveredDelivery': 0,
      'totalAmount': 0,
      'driverSalary': 0,
      'difference': 0,
    };

    for (var date in selectedDates) {
      final stats = dailyData[date];
      if (stats != null) {
        totals['totalDelivery'] =
            totals['totalDelivery']! + ((stats['totalDelivery'] ?? 0) as num).toInt();
        totals['deliveredDelivery'] =
            totals['deliveredDelivery']! + ((stats['deliveredDelivery'] ?? 0) as num).toInt();
        totals['totalAmount'] =
            totals['totalAmount']! + ((stats['totalAmount'] ?? 0) as num).toInt();
        totals['driverSalary'] =
            totals['driverSalary']! + ((stats['driverSalary'] ?? 0) as num).toInt();
        totals['difference'] =
            totals['difference']! + ((stats['difference'] ?? 0) as num).toInt();
      }
    }

    return totals;
  }

  @override
  Widget build(BuildContext context) {
    final totals = calculateSelectedTotals();

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text('Нийт мэдээлэл', style: GoogleFonts.rubik(color: Colors.white, fontSize: 15)),
        backgroundColor: Colors.deepOrange,
      ),
      backgroundColor: Colors.white,
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Date pickers row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ElevatedButton(
                  onPressed: pickStartDate,
                  child: Text(
                    startDate != null ? 'Start: ${dateFormat.format(startDate!)}' : 'Start Date',
                    style: GoogleFonts.rubik(),
                  ),
                ),
                ElevatedButton(
                  onPressed: startDate == null ? null : pickEndDate,
                  child: Text(
                    endDate != null ? 'End: ${dateFormat.format(endDate!)}' : 'End Date',
                    style: GoogleFonts.rubik(),
                  ),
                ),
              ],
            ),
            SizedBox(height: 24),

            if (loading)
              CircularProgressIndicator()
            else if (startDate != null && endDate != null && dailyData.isNotEmpty)
              Expanded(
                child: Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          columns: [
                            DataColumn(label: Text('Огноо', style: GoogleFonts.rubik(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Хүргэлт', style: GoogleFonts.rubik(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Хүргэгдсэн', style: GoogleFonts.rubik(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Дүн', style: GoogleFonts.rubik(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Жолоочид', style: GoogleFonts.rubik(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Зөрүү', style: GoogleFonts.rubik(fontWeight: FontWeight.bold))),
                          ],
                          rows: dailyData.entries.map((entry) {
                            final day = entry.key;
                            final stats = entry.value;
                            final isSelected = selectedDates.contains(day);
                            return DataRow(
                              selected: isSelected,
                              onSelectChanged: (selected) {
                                setState(() {
                                  if (selected == true) {
                                    selectedDates.add(day);
                                  } else {
                                    selectedDates.remove(day);
                                  }
                                });
                              },
                              cells: [
                                DataCell(Text(day, style: GoogleFonts.rubik())),
                                DataCell(Text(stats['totalDelivery'].toString(), style: GoogleFonts.rubik())),
                                DataCell(Text(stats['deliveredDelivery'].toString(), style: GoogleFonts.rubik())),
                                DataCell(Text('${stats['totalAmount']}₮', style: GoogleFonts.rubik())),
                                DataCell(Text('${stats['driverSalary']}₮', style: GoogleFonts.rubik())),
                                DataCell(Text('${stats['difference']}₮', style: GoogleFonts.rubik())),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                    SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildAmountContainer('Нийт дүн', totals['totalAmount']!, Colors.blue.shade100),
                        _buildAmountContainer('Жолоочийн цалин', totals['driverSalary']!, Colors.green.shade100),
                        _buildAmountContainer('Зөрүү', totals['difference']!, Colors.red.shade100),
                      ],
                    ),
                  ],
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.only(top: 24),
                child: Text(
                  'Өдөр сонгоно уу',
                  style: GoogleFonts.rubik(fontSize: 16, color: Colors.grey),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAmountContainer(String label, int amount, Color bgColor) {
    return Container(
      width: 110,
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: bgColor.withOpacity(0.8)),
      ),
      child: Column(
        children: [
          Text(label, style: GoogleFonts.rubik(fontWeight: FontWeight.w600, fontSize: 12)),
          SizedBox(height: 8),
          Text('${amount}₮', style: GoogleFonts.rubik(fontSize: 14, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
