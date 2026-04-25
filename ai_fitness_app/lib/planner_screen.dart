import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'api_config.dart';
import 'ui/premium_widgets.dart';

class PlannerScreen extends StatefulWidget {
  const PlannerScreen({super.key});

  @override
  State<PlannerScreen> createState() => _PlannerScreenState();
}

class _PlannerScreenState extends State<PlannerScreen> {
  String _goal = 'Muscle Gain';
  String _location = 'Gym';
  double _timePerDay = 45; // Minutes
  String _experience = 'Beginner';
  final TextEditingController _prefsController = TextEditingController();

  bool _isGenerating = false;
  String? _generatedPlan;

  Future<void> _generatePlan() async {
    setState(() {
      _isGenerating = true;
      _generatedPlan = null;
    });

    debugPrint('Calling Planner API: $apiBaseUrl/generate-workout-plan');
    try {
      final response = await http.post(
        Uri.parse('$apiBaseUrl/generate-workout-plan'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'goal': _goal,
          'location': _location,
          'time_per_day': '${_timePerDay.toInt()} minutes',
          'experience': _experience,
          'preferences': _prefsController.text,
        }),
      ).timeout(const Duration(minutes: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() => _generatedPlan = data['plan']);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${response.statusCode}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Connection failed: $e')),
      );
    } finally {
      setState(() => _isGenerating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
                    if (_generatedPlan == null) ...[
                      _buildInputForm(),
                      const SizedBox(height: 32),
                      NeonButton(
                        label: 'GENERATE AI PLAN',
                        icon: Icons.auto_awesome_rounded,
                        onPressed: _generatePlan,
                        isLoading: _isGenerating,
                      ),
                    ] else ...[
                      _buildPlanDisplay(),
                      const SizedBox(height: 32),
                      OutlinedButton(
                        onPressed: () => setState(() => _generatedPlan = null),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white70,
                          side: const BorderSide(color: Colors.white24),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text('CREATE NEW PLAN'),
                      ),
                    ],
                    const SizedBox(height: 40),
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
          const Text('Workout Planner', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }

  Widget _buildInputForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('YOUR GOAL'),
        _buildDropdown(['Muscle Gain', 'Fat Loss', 'General Fitness', 'Strength'], _goal, (v) => setState(() => _goal = v!)),
        const SizedBox(height: 24),
        
        _buildSectionTitle('LOCATION'),
        Row(
          children: [
            _buildChoiceChip('Gym', _location == 'Gym', () => setState(() => _location = 'Gym')),
            const SizedBox(width: 12),
            _buildChoiceChip('Home', _location == 'Home', () => setState(() => _location = 'Home')),
            const SizedBox(width: 12),
            _buildChoiceChip('Mixed', _location == 'Mixed', () => setState(() => _location = 'Mixed')),
          ],
        ),
        const SizedBox(height: 24),

        _buildSectionTitle('TIME PER DAY (${_timePerDay.toInt()} MIN)'),
        Slider(
          value: _timePerDay,
          min: 15,
          max: 120,
          divisions: 7,
          activeColor: const Color(0xFF00FFB2),
          inactiveColor: Colors.white10,
          onChanged: (v) => setState(() => _timePerDay = v),
        ),
        const SizedBox(height: 24),

        _buildSectionTitle('EXPERIENCE LEVEL'),
        _buildDropdown(['Beginner', 'Intermediate', 'Advanced'], _experience, (v) => setState(() => _experience = v!)),
        const SizedBox(height: 24),

        _buildSectionTitle('SPECIAL PREFERENCES'),
        TextField(
          controller: _prefsController,
          maxLines: 2,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'e.g. Focus on abs, No equipment...',
            hintStyle: TextStyle(color: Colors.white.withOpacity(0.2)),
            filled: true,
            fillColor: Colors.white.withOpacity(0.05),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white54, letterSpacing: 1.5)),
    );
  }

  Widget _buildDropdown(List<String> items, String current, ValueChanged<String?> onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(16)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: current,
          isExpanded: true,
          dropdownColor: const Color(0xFF0A0A0A),
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildChoiceChip(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF00FFB2) : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(label, style: TextStyle(color: isSelected ? Colors.black : Colors.white70, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildPlanDisplay() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.auto_awesome_rounded, color: Color(0xFF00FFB2), size: 24),
            SizedBox(width: 12),
            Text('7-DAY AI PLAN', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white)),
          ],
        ),
        const SizedBox(height: 24),
        PremiumCard(
          glowColor: const Color(0xFF00FFB2),
          child: Text(
            _generatedPlan!,
            style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.8),
          ),
        ),
      ],
    );
  }
}
