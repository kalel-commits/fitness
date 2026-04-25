import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'api_config.dart';
import 'ui/premium_widgets.dart';

enum ExerciseType { reps, time, distance }

class WorkoutScreen extends StatefulWidget {
  const WorkoutScreen({super.key});

  @override
  State<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends State<WorkoutScreen> {
  // Usage tracking (In-memory)
  static final Map<String, int> _usageCounts = {};
  static final List<ExerciseData> _customExercises = [];
  
  // Exercise Data with Types
  final List<ExerciseData> _baseExercises = [
    ExerciseData('Push-ups', Icons.front_hand_rounded, ExerciseType.reps),
    ExerciseData('Squats', Icons.directions_run_rounded, ExerciseType.reps),
    ExerciseData('Pull-ups', Icons.fitness_center_rounded, ExerciseType.reps),
    ExerciseData('Plank', Icons.accessibility_new_rounded, ExerciseType.time),
    ExerciseData('Lunges', Icons.airline_stops_rounded, ExerciseType.reps),
    ExerciseData('Jumping Jacks', Icons.bolt_rounded, ExerciseType.reps),
    ExerciseData('Burpees', Icons.keyboard_double_arrow_up_rounded, ExerciseType.reps),
    ExerciseData('Mountain Climbers', Icons.terrain_rounded, ExerciseType.reps),
    ExerciseData('Sit-ups', Icons.horizontal_rule_rounded, ExerciseType.reps),
    ExerciseData('Crunches', Icons.compress_rounded, ExerciseType.reps),
    ExerciseData('Deadlifts', Icons.unfold_more_rounded, ExerciseType.reps),
    ExerciseData('Bench Press', Icons.horizontal_distribute_rounded, ExerciseType.reps),
    ExerciseData('Shoulder Press', Icons.upload_rounded, ExerciseType.reps),
    ExerciseData('Bicep Curls', Icons.fitness_center_outlined, ExerciseType.reps),
    ExerciseData('Tricep Dips', Icons.vertical_align_bottom_rounded, ExerciseType.reps),
    ExerciseData('Leg Raises', Icons.vertical_align_top_rounded, ExerciseType.reps),
    ExerciseData('Russian Twists', Icons.sync_rounded, ExerciseType.reps),
    ExerciseData('High Knees', Icons.directions_run_outlined, ExerciseType.reps),
    ExerciseData('Running', Icons.run_circle_rounded, ExerciseType.distance),
    ExerciseData('Skipping Rope', Icons.all_inclusive_rounded, ExerciseType.time),
    ExerciseData('Cycling', Icons.pedal_bike_rounded, ExerciseType.distance),
  ];

  String _searchQuery = '';
  int _selectedExerciseIndex = -1; 
  
  // Input Controllers
  final TextEditingController _repsController = TextEditingController();
  final TextEditingController _setsController = TextEditingController();
  final TextEditingController _durationController = TextEditingController();
  final TextEditingController _distanceController = TextEditingController();
  final TextEditingController _timeController = TextEditingController();

  bool _isSaving = false;
  Map<String, dynamic>? _aiSuggestion;
  bool _isLoadingAi = false;

  @override
  void initState() {
    super.initState();
    _fetchAiSuggestion();
  }

  @override
  void dispose() {
    _repsController.dispose();
    _setsController.dispose();
    _durationController.dispose();
    _distanceController.dispose();
    _timeController.dispose();
    super.dispose();
  }

  Future<void> _fetchAiSuggestion() async {
    setState(() => _isLoadingAi = true);
    try {
      final response = await http.get(Uri.parse('$apiBaseUrl/ai-plan'));
      if (response.statusCode == 200) {
        setState(() => _aiSuggestion = jsonDecode(response.body));
      }
    } catch (e) {
      debugPrint('AI Plan Fetch Error: $e');
    } finally {
      if (mounted) setState(() => _isLoadingAi = false);
    }
  }

  void _incrementUsage(String name) {
    setState(() {
      _usageCounts[name] = (_usageCounts[name] ?? 0) + 1;
    });
  }

  void _addCustomExercise(String name) {
    if (name.isEmpty) return;
    if (_baseExercises.any((e) => e.name.toLowerCase() == name.toLowerCase()) || 
        _customExercises.any((e) => e.name.toLowerCase() == name.toLowerCase())) {
      return;
    }
    setState(() {
      _customExercises.add(ExerciseData(name, Icons.star_rounded, ExerciseType.reps));
    });
  }

  List<ExerciseData> get _allExercises => [..._baseExercises, ..._customExercises];

  List<ExerciseData> get _filteredExercises {
    var list = _allExercises;
    if (_searchQuery.isNotEmpty) {
      list = list.where((e) => e.name.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
    }
    return list;
  }

  List<ExerciseData> get _frequentExercises {
    var list = _filteredExercises.where((e) => (_usageCounts[e.name] ?? 0) > 0).toList();
    list.sort((a, b) => (_usageCounts[b.name] ?? 0).compareTo(_usageCounts[a.name] ?? 0));
    return list.take(5).toList();
  }

  List<ExerciseData> get _remainingExercises {
    final frequentNames = _frequentExercises.map((e) => e.name).toSet();
    return _filteredExercises.where((e) => !frequentNames.contains(e.name)).toList();
  }

  Future<void> _saveWorkout() async {
    if (_selectedExerciseIndex == -1) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select an exercise first!')));
      return;
    }

    final selectedExercise = _allExercises.firstWhere((e) => e.name == _allExercises[_selectedExerciseIndex].name);
    
    Map<String, dynamic> payload = {'exercise': selectedExercise.name};

    if (selectedExercise.type == ExerciseType.reps) {
      if (_repsController.text.isEmpty) {
        _showSnack('Please enter reps');
        return;
      }
      payload['reps'] = int.tryParse(_repsController.text) ?? 0;
      payload['sets'] = int.tryParse(_setsController.text) ?? 1;
    } else if (selectedExercise.type == ExerciseType.time) {
      if (_durationController.text.isEmpty) {
        _showSnack('Please enter duration');
        return;
      }
      payload['duration'] = _durationController.text;
    } else {
      if (_distanceController.text.isEmpty || _timeController.text.isEmpty) {
        _showSnack('Please enter distance and time');
        return;
      }
      payload['distance'] = double.tryParse(_distanceController.text) ?? 0.0;
      payload['time'] = _timeController.text;
    }

    setState(() => _isSaving = true);
    try {
      final response = await http.post(
        Uri.parse('$apiBaseUrl/log-workout'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );
      
      if (!mounted) return;
      if (response.statusCode == 200) {
        _incrementUsage(selectedExercise.name);
        _clearInputs();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Workout logged! 🔥'), backgroundColor: Color(0xFF00FFB2)),
        );
      }
    } catch (e) {
      debugPrint('Workout Save Error: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _clearInputs() {
    _repsController.clear();
    _setsController.clear();
    _durationController.clear();
    _distanceController.clear();
    _timeController.clear();
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
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
                    _buildSearchBar(),
                    const SizedBox(height: 24),
                    if (_frequentExercises.isNotEmpty) ...[
                      const Text('FREQUENTLY USED', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white54, letterSpacing: 1.2)),
                      const SizedBox(height: 12),
                      _buildExerciseGrid(_frequentExercises),
                      const SizedBox(height: 32),
                    ],
                    const Text('ALL EXERCISES', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white54, letterSpacing: 1.2)),
                    const SizedBox(height: 12),
                    _buildExerciseGrid(_remainingExercises),
                    const SizedBox(height: 32),
                    _buildAddCustomButton(),
                    const SizedBox(height: 32),
                    if (_selectedExerciseIndex != -1) _buildInputSection(),
                    const SizedBox(height: 32),
                    _buildAiCoachCard(),
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
          const Text('Workout Library', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return TextField(
      onChanged: (val) => setState(() => _searchQuery = val),
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: 'Search exercises...',
        hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
        prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF00FFB2)),
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
      ),
    );
  }

  Widget _buildExerciseGrid(List<ExerciseData> exercises) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 1.5,
      ),
      itemCount: exercises.length,
      itemBuilder: (context, index) {
        final exercise = exercises[index];
        final isSelected = _selectedExerciseIndex != -1 && _allExercises[_selectedExerciseIndex].name == exercise.name;
        
        return GestureDetector(
          onTap: () {
            setState(() {
              _selectedExerciseIndex = _allExercises.indexWhere((e) => e.name == exercise.name);
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFF00FFB2).withOpacity(0.1) : Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: isSelected ? const Color(0xFF00FFB2) : Colors.white.withOpacity(0.1), width: 1.5),
              boxShadow: isSelected ? [BoxShadow(color: const Color(0xFF00FFB2).withOpacity(0.2), blurRadius: 10, spreadRadius: 1)] : [],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(exercise.icon, color: isSelected ? const Color(0xFF00FFB2) : Colors.white54, size: 28),
                const SizedBox(height: 8),
                Text(
                  exercise.name,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.white70,
                    fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAddCustomButton() {
    return NeonButton(
      label: 'Add Your Exercise',
      icon: Icons.add_rounded,
      onPressed: () => _showAddCustomDialog(),
    );
  }

  void _showAddCustomDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0A0A0A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Color(0xFF00FFB2), width: 0.5)),
        title: const Text('New Exercise', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Enter name...',
            hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
            filled: true,
            fillColor: Colors.white.withOpacity(0.05),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
          TextButton(
            onPressed: () {
              _addCustomExercise(controller.text.trim());
              Navigator.pop(context);
            },
            child: const Text('Add', style: TextStyle(color: Color(0xFF00FFB2), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildInputSection() {
    final exercise = _allExercises[_selectedExerciseIndex];
    
    return PremiumCard(
      glowColor: const Color(0xFF00FFB2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(exercise.name.toUpperCase(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF00FFB2), letterSpacing: 2)),
          const SizedBox(height: 24),
          if (exercise.type == ExerciseType.reps) _buildRepsInput(),
          if (exercise.type == ExerciseType.time) _buildTimeInput(),
          if (exercise.type == ExerciseType.distance) _buildDistanceInput(),
          const SizedBox(height: 32),
          NeonButton(
            label: 'FINISH WORKOUT',
            onPressed: _saveWorkout,
            isLoading: _isSaving,
          ),
        ],
      ),
    );
  }

  Widget _buildRepsInput() {
    return Row(
      children: [
        Expanded(child: _buildTextField(_repsController, 'Reps', Icons.repeat_rounded, isNumber: true)),
        const SizedBox(width: 16),
        Expanded(child: _buildTextField(_setsController, 'Sets', Icons.layers_rounded, isNumber: true)),
      ],
    );
  }

  Widget _buildTimeInput() {
    return _buildTextField(_durationController, 'Duration (e.g. 5 min)', Icons.timer_rounded);
  }

  Widget _buildDistanceInput() {
    return Column(
      children: [
        _buildTextField(_distanceController, 'Distance (km)', Icons.map_rounded, isNumber: true),
        const SizedBox(height: 16),
        _buildTextField(_timeController, 'Time (minutes)', Icons.timer_outlined, isNumber: true),
      ],
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon, {bool isNumber = false}) {
    return TextField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white54),
        prefixIcon: Icon(icon, color: const Color(0xFF00FFB2), size: 20),
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.white.withOpacity(0.1))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFF00FFB2))),
      ),
    );
  }

  Widget _buildAiCoachCard() {
    if (_isLoadingAi) return const Center(child: CircularProgressIndicator(color: Color(0xFF00FFB2)));
    if (_aiSuggestion == null) return const SizedBox.shrink();

    final plan = _aiSuggestion!['plan'] ?? {};
    final nextStep = plan['next_step'] ?? 'Keep moving towards your goal!';
    final suggestion = plan['suggestion'] ?? 'Focus on consistency today.';

    return PremiumCard(
      glowColor: Colors.purpleAccent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.auto_awesome, color: Colors.purpleAccent, size: 20),
              SizedBox(width: 8),
              Text('AI COACH SUGGESTION', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.purpleAccent, letterSpacing: 1.2)),
            ],
          ),
          const SizedBox(height: 16),
          Text(nextStep, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.purpleAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
            child: Text(suggestion, style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.5)),
          ),
        ],
      ),
    );
  }
}

class ExerciseData {
  final String name;
  final IconData icon;
  final ExerciseType type;
  ExerciseData(this.name, this.icon, this.type);
}
