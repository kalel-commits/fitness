import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'api_config.dart';
import 'ui/premium_widgets.dart';

class DietScreen extends StatefulWidget {
  const DietScreen({super.key});

  @override
  State<DietScreen> createState() => _DietScreenState();
}

class _DietScreenState extends State<DietScreen> {
  final TextEditingController _foodController = TextEditingController();
  bool _isSubmitting = false;
  bool _isLoadingQuestions = false;
  bool _isGeneratingPlan = false;
  
  int _lastEstimatedCalories = 0;
  int _lastEstimatedProtein = 0;
  bool _showLatestResult = false;

  final List<_DietEntry> _entries = <_DietEntry>[];

  final TextEditingController _dietAnswerController = TextEditingController();
  final List<String> _dietQuestions = <String>[];
  final List<_ChatTurn> _dietChat = <_ChatTurn>[];

  int _dietQuestionIndex = 0;
  String _generatedDietPlan = '';

  int get _dailyCalories => _entries.fold<int>(0, (sum, e) => sum + e.calories);
  int get _dailyProtein => _entries.fold<int>(0, (sum, e) => sum + e.protein);

  @override
  void initState() {
    super.initState();
    _fetchDietQuestions();
  }

  @override
  void dispose() {
    _foodController.dispose();
    _dietAnswerController.dispose();
    super.dispose();
  }

  Future<void> _fetchDietQuestions() async {
    setState(() => _isLoadingQuestions = true);
    debugPrint('Calling Diet Questions API: $apiBaseUrl/diet-chat-questions');
    try {
      final response = await http.get(Uri.parse('$apiBaseUrl/diet-chat-questions'));
      if (!mounted) return;
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final List<String> questions = List<String>.from(decoded['questions'] ?? []);
        setState(() {
          _dietQuestions.clear();
          _dietQuestions.addAll(questions);
          _dietChat.clear();
          _dietQuestionIndex = 0;
          if (_dietQuestions.isNotEmpty) {
            _dietChat.add(_ChatTurn(text: _dietQuestions.first, isAi: true));
          }
        });
      }
    } catch (_) {} finally {
      if (mounted) setState(() => _isLoadingQuestions = false);
    }
  }

  void _sendDietAnswer() {
    final answer = _dietAnswerController.text.trim();
    if (answer.isEmpty || _dietQuestionIndex >= _dietQuestions.length) return;
    setState(() {
      _dietChat.add(_ChatTurn(text: answer, isAi: false));
      _dietAnswerController.clear();
      _dietQuestionIndex++;
      if (_dietQuestionIndex < _dietQuestions.length) {
        _dietChat.add(_ChatTurn(text: _dietQuestions[_dietQuestionIndex], isAi: true));
      }
    });
  }

  Future<void> _saveDiet() async {
    final food = _foodController.text.trim();
    if (food.isEmpty) {
      _showSnack('Please describe your food first!');
      return;
    }
    setState(() {
      _isSubmitting = true;
      _showLatestResult = false;
    });
    try {
      final response = await http.post(
        Uri.parse('$apiBaseUrl/log-diet'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'food': food}),
      );
      
      debugPrint('API Response (/log-diet): ${response.body}');
      
      if (!mounted) return;
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final estimated = decoded['estimated_nutrition'] ?? {};
        final int cal = (estimated['calories'] as num?)?.toInt() ?? 0;
        final int pro = (estimated['protein'] as num?)?.toInt() ?? 0;
        setState(() {
          _entries.insert(0, _DietEntry(food: food, calories: cal, protein: pro));
          _lastEstimatedCalories = cal;
          _lastEstimatedProtein = pro;
          _showLatestResult = true;
          _foodController.clear();
        });
        _showSnack('Nutrition estimated by AI! 🔥', isSuccess: true);
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
                    _buildSummaryCards(),
                    const SizedBox(height: 32),
                    _buildLogSection(),
                    const SizedBox(height: 32),
                    _buildRecentSection(),
                    const SizedBox(height: 32),
                    _buildChatSection(),
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
            'Nutrition Lab',
            style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards() {
    return Row(
      children: [
        Expanded(
          child: StatCard(
            title: 'Calories',
            value: '$_dailyCalories kcal',
            icon: Icons.local_fire_department_rounded,
            color: Colors.orange,
            progress: _dailyCalories / 2000,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: StatCard(
            title: 'Protein',
            value: '${_dailyProtein}g',
            icon: Icons.egg_alt_rounded,
            color: const Color(0xFF00FFB2),
            progress: _dailyProtein / 150,
          ),
        ),
      ],
    );
  }

  Widget _buildLogSection() {
    return PremiumCard(
      glowColor: const Color(0xFF00FFB2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'What did you eat?',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _foodController,
            maxLines: 3,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'e.g., 2 paneer parathas with curd...',
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
              filled: true,
              fillColor: Colors.white.withOpacity(0.05),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          if (_showLatestResult) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF00FFB2).withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF00FFB2).withOpacity(0.2)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _resultItem('Calories', '$_lastEstimatedCalories', 'kcal', Colors.orange),
                  _resultItem('Protein', '$_lastEstimatedProtein', 'g', const Color(0xFF00FFB2)),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
          NeonButton(
            label: 'Estimate with AI',
            icon: Icons.auto_awesome_rounded,
            isLoading: _isSubmitting,
            onPressed: _saveDiet,
          ),
        ],
      ),
    );
  }

  Widget _resultItem(String label, String value, String unit, Color color) {
    return Column(
      children: [
        Text(label, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)),
        const SizedBox(height: 4),
        RichText(
          text: TextSpan(
            children: [
              TextSpan(text: value, style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.w900)),
              TextSpan(text: ' $unit', style: const TextStyle(color: Colors.white, fontSize: 12)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRecentSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Recent Entries', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 16),
        if (_entries.isEmpty)
          Text('No entries today.', style: TextStyle(color: Colors.white.withOpacity(0.4))),
        ..._entries.map((e) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: PremiumCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.restaurant_rounded, color: Color(0xFF00FFB2), size: 20),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(e.food, style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text('${e.calories} kcal • ${e.protein}g protein', 
                        style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        )),
      ],
    );
  }

  Widget _buildChatSection() {
    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('AI Diet Coach', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: ListView.builder(
              itemCount: _dietChat.length,
              itemBuilder: (context, index) {
                final turn = _dietChat[index];
                return Align(
                  alignment: turn.isAi ? Alignment.centerLeft : Alignment.centerRight,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: turn.isAi ? Colors.white.withOpacity(0.05) : const Color(0xFF00FFB2).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: turn.isAi ? Colors.white.withOpacity(0.1) : const Color(0xFF00FFB2).withOpacity(0.2)),
                    ),
                    child: Text(turn.text, style: TextStyle(color: turn.isAi ? Colors.white : const Color(0xFF00FFB2))),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _dietAnswerController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Ask or answer...',
                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.05),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              IconButton.filled(
                onPressed: _sendDietAnswer,
                style: IconButton.styleFrom(backgroundColor: const Color(0xFF00FFB2), foregroundColor: Colors.black),
                icon: const Icon(Icons.send_rounded),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DietEntry {
  final String food;
  final int calories;
  final int protein;
  _DietEntry({required this.food, required this.calories, required this.protein});
}

class _ChatTurn {
  final String text;
  final bool isAi;
  _ChatTurn({required this.text, required this.isAi});
}