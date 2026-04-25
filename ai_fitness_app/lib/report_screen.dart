import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'api_config.dart';
import 'ui/premium_widgets.dart';

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  bool _isLoading = false;
  String? _errorMessage;
  DateTime _selectedDate = DateTime.now();
  Map<String, dynamic>? _report;

  static const List<String> _weekdayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  void initState() {
    super.initState();
    _fetchReport();
  }

  Future<void> _fetchReport() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final dateText = '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';
      final response = await http.get(Uri.parse('$apiBaseUrl/report?date=$dateText')).timeout(const Duration(seconds: 15));
      
      if (!mounted) return;
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        setState(() => _report = decoded);
      } else {
        setState(() => _errorMessage = 'Server Error: ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) setState(() => _errorMessage = 'Connection failed.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<DateTime> _calendarDays() {
    final now = DateTime.now();
    return List.generate(7, (index) => now.subtract(Duration(days: 6 - index)));
  }

  @override
  Widget build(BuildContext context) {
    final workouts = (_report?['workouts'] as List?) ?? [];
    final diet = (_report?['diet'] as List?) ?? [];
    final aiSummary = _report?['ai_summary']?.toString() ?? '';
    final totalCals = _report?['total_calories'] ?? 0;
    final totalProtein = _report?['total_protein'] ?? 0;

    return Scaffold(
      body: PremiumGradientBackground(
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  children: [
                    _buildCalendar(),
                    const SizedBox(height: 32),
                    if (_isLoading)
                      const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator(color: Color(0xFF00FFB2))))
                    else if (_errorMessage != null)
                      _buildError()
                    else ...[
                      _buildStatsOverview(totalCals, totalProtein),
                      const SizedBox(height: 32),
                      if (aiSummary.isNotEmpty) _buildAiReview(aiSummary),
                      const SizedBox(height: 32),
                      _buildLogsSection('DAILY WORKOUTS', workouts, Icons.fitness_center_rounded, const Color(0xFF00FFB2)),
                      const SizedBox(height: 32),
                      _buildLogsSection('NUTRITION LOGS', diet, Icons.restaurant_rounded, Colors.orangeAccent),
                      const SizedBox(height: 40),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          ),
          const Text('Analytics', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }

  Widget _buildCalendar() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(24)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: _calendarDays().map((date) {
          final isSelected = date.day == _selectedDate.day && date.month == _selectedDate.month;
          return GestureDetector(
            onTap: () {
              setState(() => _selectedDate = date);
              _fetchReport();
            },
            child: Column(
              children: [
                Text(_weekdayLabels[date.weekday - 1], style: TextStyle(color: isSelected ? const Color(0xFF00FFB2) : Colors.white38, fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFF00FFB2) : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    border: isSelected ? null : Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  child: Text('${date.day}', style: TextStyle(color: isSelected ? Colors.black : Colors.white, fontWeight: FontWeight.w900)),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildStatsOverview(dynamic cals, dynamic pro) {
    return Row(
      children: [
        Expanded(child: _statCard('CALORIES', '$cals', 'kcal', Colors.orangeAccent)),
        const SizedBox(width: 16),
        Expanded(child: _statCard('PROTEIN', '$pro', 'grams', const Color(0xFF00FFB2))),
      ],
    );
  }

  Widget _statCard(String label, String value, String unit, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white)),
              const SizedBox(width: 4),
              Text(unit, style: TextStyle(fontSize: 10, color: Colors.white.withOpacity(0.4))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAiReview(String summary) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('AI COACH REVIEW', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white54, letterSpacing: 1.5)),
        const SizedBox(height: 16),
        PremiumCard(
          glowColor: const Color(0xFF00FFB2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.auto_awesome_rounded, color: Color(0xFF00FFB2), size: 18),
                  SizedBox(width: 8),
                  Text('DAILY INSIGHTS', style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white, fontSize: 14)),
                ],
              ),
              const SizedBox(height: 16),
              Text(summary, style: const TextStyle(fontSize: 14, height: 1.6, color: Colors.white70)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLogsSection(String title, List logs, IconData icon, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white54, letterSpacing: 1.5)),
        const SizedBox(height: 16),
        if (logs.isEmpty)
          const Text('No data recorded for this day.', style: TextStyle(color: Colors.white24, fontSize: 12)),
        ...logs.map((log) => Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  _formatLog(title, log),
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white),
                ),
              ),
            ],
          ),
        )),
      ],
    );
  }

  String _formatLog(String section, dynamic log) {
    if (section.contains('WORKOUT')) {
      final exercise = log['exercise'] ?? 'Unknown';
      if (log['distance'] != null) return '$exercise: ${log['distance']} km in ${log['time']} min';
      if (log['duration'] != null) return '$exercise: ${log['duration']}';
      return '$exercise: ${log['sets']} sets • ${log['reps']} reps';
    }
    return '${log['food']}: ${log['calories']} kcal • ${log['protein']}g protein';
  }

  Widget _buildError() {
    return Center(
      child: Column(
        children: [
          const SizedBox(height: 40),
          Icon(Icons.cloud_off_rounded, size: 48, color: Colors.white24),
          const SizedBox(height: 16),
          Text(_errorMessage!, style: const TextStyle(color: Colors.white38)),
        ],
      ),
    );
  }
}
