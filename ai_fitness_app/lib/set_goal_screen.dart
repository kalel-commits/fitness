import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'api_config.dart';
import 'ui/premium_widgets.dart';

class SetGoalScreen extends StatefulWidget {
  const SetGoalScreen({super.key});

  @override
  State<SetGoalScreen> createState() => _SetGoalScreenState();
}

class _SetGoalScreenState extends State<SetGoalScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _goalController = TextEditingController();
  final TextEditingController _targetWeightController = TextEditingController();
  final TextEditingController _humanGoalController = TextEditingController();

  bool _isSubmitting = false;
  bool _isDecoding = false;
  DecodedGoal? _decodedGoal;

  @override
  void dispose() {
    _nameController.dispose();
    _goalController.dispose();
    _targetWeightController.dispose();
    _humanGoalController.dispose();
    super.dispose();
  }

  Future<void> _decodeHumanGoal() async {
    final String text = _humanGoalController.text.trim();
    if (text.length < 3) {
      _showSnack('Please describe your goal in a sentence.');
      return;
    }

    setState(() => _isDecoding = true);

    try {
      final response = await http.post(
        Uri.parse('$apiBaseUrl/decode-goal'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'text': text}),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded['decoded_goal'] != null) {
          final parsed = DecodedGoal.fromJson(decoded['decoded_goal']);
          setState(() {
            _decodedGoal = parsed;
            // FILL SUMMARY INTO GOAL FIELD as requested
            _goalController.text = parsed.summary;
            if (parsed.targetWeight != null) {
              _targetWeightController.text = parsed.targetWeight.toString();
            }
          });
          _showSnack('AI analyzed your goal! 🔥', isSuccess: true);
        }
      }
    } catch (e) {
      _showSnack('Error: $e');
    } finally {
      if (mounted) setState(() => _isDecoding = false);
    }
  }

  Future<void> _submitGoal() async {
    final String name = _nameController.text.trim();
    final String goal = _goalController.text.trim();
    final int? targetWeight = int.tryParse(_targetWeightController.text.trim());

    if (name.isEmpty || goal.isEmpty) {
      _showSnack('Name and Goal are required.');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final response = await http.post(
        Uri.parse('$apiBaseUrl/set-goal'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': name,
          'goal': goal,
          'target_weight': targetWeight,
          'goal_type': _decodedGoal?.goalType,
          'target_value': _decodedGoal?.targetValue,
          'target_unit': _decodedGoal?.targetUnit,
        }),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        _showSnack('Goal Locked In! 🚀', isSuccess: true);
        Navigator.pop(context);
      }
    } catch (e) {
      _showSnack('Error: $e');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showSnack(String msg, {bool isSuccess = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: isSuccess ? const Color(0xFF00FFB2) : Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
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
                  padding: const EdgeInsets.all(24),
                  children: [
                    _buildAISection(),
                    const SizedBox(height: 32),
                    const Divider(color: Colors.white10),
                    const SizedBox(height: 32),
                    _buildManualSection(),
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
          const Text(
            'Target Setting',
            style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }

  Widget _buildAISection() {
    return PremiumCard(
      glowColor: const Color(0xFF00FFB2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.auto_awesome_rounded, color: Color(0xFF00FFB2), size: 20),
              SizedBox(width: 8),
              Text('AI Decoder', style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF00FFB2))),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _humanGoalController,
            maxLines: 2,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'e.g., I want to lose 5kg and build abs...',
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
              filled: true,
              fillColor: Colors.white.withOpacity(0.05),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 16),
          NeonButton(
            label: 'Decode My Goal',
            onPressed: _decodeHumanGoal,
            isLoading: _isDecoding,
          ),
          if (_decodedGoal != null) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF00FFB2).withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Analysis Result:', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)),
                  const SizedBox(height: 4),
                  Text(_decodedGoal!.summary, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 8),
                  Text('Category: ${_decodedGoal!.goalType.replaceAll('_', ' ')}', style: const TextStyle(color: Color(0xFF00FFB2), fontSize: 12, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildManualSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Confirm Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 24),
        _labeledField('Full Name', _nameController, Icons.person_rounded),
        const SizedBox(height: 20),
        _labeledField('Target Goal', _goalController, Icons.emoji_events_rounded),
        const SizedBox(height: 20),
        _labeledField('Target Weight (kg)', _targetWeightController, Icons.monitor_weight_rounded, isNumber: true),
        const SizedBox(height: 40),
        NeonButton(
          label: 'Lock In Goal',
          onPressed: _submitGoal,
          isLoading: _isSubmitting,
          icon: Icons.lock_rounded,
        ),
      ],
    );
  }

  Widget _labeledField(String label, TextEditingController controller, IconData icon, {bool isNumber = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: isNumber ? TextInputType.number : TextInputType.text,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: const Color(0xFF00FFB2), size: 20),
            filled: true,
            fillColor: Colors.white.withOpacity(0.05),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
          ),
        ),
      ],
    );
  }
}

class DecodedGoal {
  final String goalType;
  final String normalizedGoal;
  final String summary;
  final double? targetValue;
  final String? targetUnit;
  final int? targetWeight;

  DecodedGoal({
    required this.goalType,
    required this.normalizedGoal,
    required this.summary,
    this.targetValue,
    this.targetUnit,
    this.targetWeight,
  });

  factory DecodedGoal.fromJson(Map<String, dynamic> json) {
    return DecodedGoal(
      goalType: json['goal_type']?.toString() ?? 'general_fitness',
      normalizedGoal: json['normalized_goal']?.toString() ?? 'Improve overall fitness',
      summary: json['summary']?.toString() ?? 'Goal decoded',
      targetValue: (json['target_value'] as num?)?.toDouble(),
      targetUnit: json['target_unit']?.toString(),
      targetWeight: (json['target_weight'] as num?)?.toInt(),
    );
  }
}