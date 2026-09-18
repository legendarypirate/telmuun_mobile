import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../color/color.dart';
import '../utils/date_picker.dart';

class SummaryScreen extends StatefulWidget {
  @override
  State<SummaryScreen> createState() => _SummaryScreenState();
}

class _SummaryScreenState extends State<SummaryScreen> {
  DateTime? startDate;
  DateTime? endDate;

  final DateFormat dateFormat = DateFormat('yyyy-MM-dd');
  final DateFormat displayFormat = DateFormat('MM.dd');
  Map<String, Map<String, dynamic>> dailyData = {};
  Set<String> selectedDates = {};
  bool loading = false;
  int? driverId;

  static const Color _orange = Color(0xFFFF6A1A);
  static const Color _navy = Color(0xFF0F2744);
  static const Color _bg = Color(0xFFF5F6F8);
  static const Color _muted = Color(0xFF7A8699);
  static const Color _line = Color(0xFFE8ECF1);

  @override
  void initState() {
    super.initState();
    _loadDriverId();
  }

  Future<void> _loadDriverId() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => driverId = prefs.getInt('user_id'));
    // Default last 7 days
    final now = DateTime.now();
    startDate = now.subtract(const Duration(days: 6));
    endDate = now;
    await fetchReport();
  }

  Future<void> fetchReport() async {
    if (startDate == null || endDate == null || driverId == null) return;

    setState(() => loading = true);

    final url = Uri.parse(
      '${Url.url}/api/mobile/delivery/report?driver_id=$driverId&start_date=${dateFormat.format(startDate!)}&end_date=${dateFormat.format(endDate!)}',
    );

    try {
      final res = await http.get(url);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final Map<String, Map<String, dynamic>> parsedData = {};
        for (var item in data['data'] ?? []) {
          parsedData[item['date']] = {
            'totalDelivery':
                int.tryParse(item['total_deliveries']?.toString() ?? '0') ?? 0,
            'deliveredDelivery':
                int.tryParse(item['delivered_count']?.toString() ?? '0') ?? 0,
            'totalAmount':
                (double.tryParse(item['delivered_total_price']?.toString() ?? '0') ??
                        0)
                    .toInt(),
            'driverSalary':
                (double.tryParse(item['for_driver']?.toString() ?? '0') ?? 0)
                    .toInt(),
            'difference':
                (double.tryParse(item['driver_margin']?.toString() ?? '0') ?? 0)
                    .toInt(),
          };
        }
        setState(() {
          dailyData = parsedData;
          selectedDates.clear();
        });
      }
    } catch (e) {
      debugPrint('Error: $e');
    } finally {
      setState(() => loading = false);
    }
  }

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final picked = await pickAppDateRange(
      context,
      firstDate: DateTime(2023),
      lastDate: now,
      initialDateRange: startDate != null && endDate != null
          ? DateTimeRange(start: startDate!, end: endDate!)
          : DateTimeRange(
              start: now.subtract(const Duration(days: 6)), end: now),
    );
    if (picked != null) {
      setState(() {
        startDate = picked.start;
        endDate = picked.end;
      });
      await fetchReport();
    }
  }

  Map<String, int> calculateSelectedTotals() {
    final source = selectedDates.isEmpty ? dailyData.keys.toSet() : selectedDates;
    final totals = {
      'totalDelivery': 0,
      'deliveredDelivery': 0,
      'totalAmount': 0,
      'driverSalary': 0,
      'difference': 0,
    };

    for (final date in source) {
      final stats = dailyData[date];
      if (stats == null) continue;
      totals['totalDelivery'] =
          totals['totalDelivery']! + (stats['totalDelivery'] as int);
      totals['deliveredDelivery'] =
          totals['deliveredDelivery']! + (stats['deliveredDelivery'] as int);
      totals['totalAmount'] =
          totals['totalAmount']! + (stats['totalAmount'] as int);
      totals['driverSalary'] =
          totals['driverSalary']! + (stats['driverSalary'] as int);
      totals['difference'] =
          totals['difference']! + (stats['difference'] as int);
    }
    return totals;
  }

  String money(int amount) {
    if (amount == 0) return '0₮';
    return '${NumberFormat('#,###').format(amount)}₮';
  }

  @override
  Widget build(BuildContext context) {
    final totals = calculateSelectedTotals();
    final days = dailyData.entries.toList()
      ..sort((a, b) => b.key.compareTo(a.key));

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        elevation: 0,
        automaticallyImplyLeading: false,
        backgroundColor: _orange,
        centerTitle: true,
        title: Text(
          'Мэдээлэл',
          style: GoogleFonts.rubik(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.date_range_outlined, color: Colors.white),
            onPressed: _pickRange,
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: fetchReport,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: GestureDetector(
              onTap: _pickRange,
              child: Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _line),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today_outlined,
                        size: 16, color: _orange),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        startDate != null && endDate != null
                            ? '${dateFormat.format(startDate!)}  →  ${dateFormat.format(endDate!)}'
                            : 'Огноо сонгох',
                        style: GoogleFonts.rubik(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: _navy,
                        ),
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded,
                        color: Colors.grey.shade400),
                  ],
                ),
              ),
            ),
          ),
          if (dailyData.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
              child: Row(
                children: [
                  Expanded(
                    child: _totalCard('Нийт дүн', money(totals['totalAmount']!),
                        const Color(0xFF1B9BE4)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _totalCard(
                        'Жолоочид',
                        money(totals['driverSalary']!),
                        const Color(0xFF1FA97A)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _totalCard('Зөрүү', money(totals['difference']!),
                        const Color(0xFFE5484D)),
                  ),
                ],
              ),
            ),
          Expanded(
            child: loading
                ? const Center(
                    child: CircularProgressIndicator(color: _orange))
                : days.isEmpty
                    ? Center(
                        child: Text(
                          'Өгөгдөл алга',
                          style: GoogleFonts.rubik(fontSize: 15, color: _muted),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(14, 4, 14, 24),
                        itemCount: days.length,
                        itemBuilder: (context, index) {
                          final day = days[index].key;
                          final stats = days[index].value;
                          final selected = selectedDates.contains(day);
                          return _dayCard(day, stats, selected);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _totalCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.rubik(fontSize: 11, color: _muted),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.rubik(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _dayCard(String day, Map<String, dynamic> stats, bool selected) {
    return GestureDetector(
      onTap: () {
        setState(() {
          if (selected) {
            selectedDates.remove(day);
          } else {
            selectedDates.add(day);
          }
        });
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? _orange : _line,
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  selected
                      ? Icons.check_box_rounded
                      : Icons.check_box_outline_blank_rounded,
                  size: 18,
                  color: selected ? _orange : _muted,
                ),
                const SizedBox(width: 8),
                Text(
                  day,
                  style: GoogleFonts.rubik(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _navy,
                  ),
                ),
                const Spacer(),
                Text(
                  money(stats['totalAmount'] as int),
                  style: GoogleFonts.rubik(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _orange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _miniStat('Хүргэлт', '${stats['totalDelivery']}'),
                _miniStat('Хүргэгдсэн', '${stats['deliveredDelivery']}'),
                _miniStat('Жолоочид', money(stats['driverSalary'] as int)),
                _miniStat('Зөрүү', money(stats['difference'] as int)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniStat(String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: GoogleFonts.rubik(fontSize: 10, color: _muted)),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.rubik(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _navy,
            ),
          ),
        ],
      ),
    );
  }
}
