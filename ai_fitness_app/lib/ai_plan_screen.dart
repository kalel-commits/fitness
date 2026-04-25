import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'api_config.dart';
import 'ui/premium_widgets.dart';

class AiPlanScreen extends StatefulWidget {
  const AiPlanScreen({super.key});

  @override
  State<AiPlanScreen> createState() => _AiPlanScreenState();
}

class _AiPlanScreenState extends State<AiPlanScreen> {
  bool _isLoading = false;
  String _rawPlan = '';
  String _workoutPlan = '';
  String _dietPlan = '';

  Future<void> _fetchAiPlan() async {
    setState(() => _isLoading = true);
    try {
      final response = await http.get(Uri.parse('$apiBaseUrl/ai-plan'));
      if (!mounted) return;
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final aiPlan = decoded['ai_plan']?.toString() ?? 'No plan returned.';
        final sections = _splitPlan(aiPlan);
        setState(() {
          _rawPlan = aiPlan;
          _workoutPlan = sections.workout;
          _dietPlan = sections.diet;
        });
        _showSnack('AI Plan Generated! 🧠', isSuccess: true);
      }
    } catch (e) {
      _showSnack('Error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
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

  _PlanSections _splitPlan(String plan) {
    final lower = plan.toLowerCase();
    final workoutIndex = lower.indexOf('workout');
    final dietIndex = lower.indexOf('diet');

    if (workoutIndex == -1 && dietIndex == -1) {
      return _PlanSections(workout: plan, diet: 'No dedicated diet section found.');
    }

    if (workoutIndex != -1 && dietIndex != -1) {
      if (workoutIndex < dietIndex) {
        return _PlanSections(
          workout: plan.substring(workoutIndex, dietIndex).trim(),
          diet: plan.substring(dietIndex).trim(),
        );
      }
      return _PlanSections(
        workout: plan.substring(workoutIndex).trim(),
        diet: plan.substring(dietIndex, workoutIndex).trim(),
      );
    }
    return _PlanSections(workout: plan, diet: 'Plan details follow...');
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
                    _buildTopAction(),
                    const SizedBox(height: 32),
                    if (_isLoading)
                      const _LoadingState()
                    else ...[
                      if (_workoutPlan.isNotEmpty) 
                        _PlanCard(title: 'Workout Strategy', icon: Icons.sports_gymnastics_rounded, content: _workoutPlan, color: const Color(0xFF00FFB2)),
                      const SizedBox(height: 16),
                      if (_dietPlan.isNotEmpty)
                        _PlanCard(title: 'Nutrition Strategy', icon: Icons.restaurant_rounded, content: _dietPlan, color: Colors.orange),
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
          const Text(
            'AI Coach',
            style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }

  Widget _buildTopAction() {
    return PremiumCard(
      glowColor: const Color(0xFF00FFB2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Need a new plan?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text('Your AI coach will analyze your progress and generate a custom strategy.', 
            style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13)),
          const SizedBox(height: 24),
          NeonButton(
            label: 'Generate My Plan',
            icon: Icons.auto_awesome_rounded,
            onPressed: _fetchAiPlan,
            isLoading: _isLoading,
          ),
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final String content;
  final Color color;

  const _PlanCard({required this.title, required this.icon, required this.content, required this.color});

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 10),
              Text(title, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 16),
          Text(content, style: const TextStyle(fontSize: 14, height: 1.6, color: Colors.white70)),
        ],
      ),
    );
  }
}

class _LoadingState extends Column {
  const _LoadingState() : super(children: const [
    SizedBox(height: 40),
    CircularProgressIndicator(color: Color(0xFF00FFB2)),
    SizedBox(height: 20),
    Text('Consulting with AI Coach...', style: TextStyle(color: Colors.white38)),
  ]);
}

class _PlanSections {
  final String workout;
  final String diet;
  const _PlanSections({required this.workout, required this.diet});
}
