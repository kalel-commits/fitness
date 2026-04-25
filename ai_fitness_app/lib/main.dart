import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'diet_screen.dart';
import 'planner_screen.dart';
import 'report_screen.dart';
import 'set_goal_screen.dart';
import 'ui/premium_widgets.dart';
import 'workout_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
  runApp(const FitnessApp());
}

class FitnessApp extends StatelessWidget {
  const FitnessApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'AI Fitness Coach',
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        primaryColor: const Color(0xFF00FFB2),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF00FFB2),
          brightness: Brightness.dark,
          primary: const Color(0xFF00FFB2),
          secondary: const Color(0xFF00FFB2),
          surface: const Color(0xFF1A1A1A),
        ),
        scaffoldBackgroundColor: const Color(0xFF0D0D0D),
        fontFamily: 'Outfit', // A modern font (assuming available or defaults to sans-serif)
        textTheme: const TextTheme(
          headlineMedium: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
          titleLarge: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
          bodyLarge: TextStyle(color: Colors.white70),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  void _openScreen(BuildContext context, Widget child) {
    Navigator.push(
      context,
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 400),
        reverseTransitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (context, animation, secondaryAnimation) => child,
        transitionsBuilder: (context, animation, secondaryAnimation, page) {
          return FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.95, end: 1.0).animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
              ),
              child: page,
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PremiumGradientBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            children: <Widget>[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const StreakIndicator(days: 7),
                  IconButton(
                    onPressed: () => _openScreen(context, const SetGoalScreen()),
                    icon: const Icon(Icons.settings_outlined, color: Colors.white70),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Level Up,',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Text(
                    'Prajwal!',
                    style: TextStyle(
                      color: Color(0xFF00FFB2),
                      fontSize: 40,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 30),
              const Text(
                'Today\'s Stats',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 16),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 1.4,
                children: const [
                  StatCard(
                    title: 'Calories',
                    value: '1,240',
                    icon: Icons.local_fire_department_rounded,
                    color: Colors.orange,
                    progress: 0.65,
                  ),
                  StatCard(
                    title: 'Protein',
                    value: '82g',
                    icon: Icons.egg_alt_rounded,
                    color: Color(0xFF00FFB2),
                    progress: 0.8,
                  ),
                ],
              ),
              const SizedBox(height: 32),
              const Text(
                'Workout & Diet',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 16),
              ActionTile(
                title: 'Training Room',
                subtitle: 'Next: Full Body HIIT',
                icon: Icons.fitness_center_rounded,
                accent: const Color(0xFF00FFB2),
                onTap: () => _openScreen(context, const WorkoutScreen()),
              ),
              const SizedBox(height: 16),
              ActionTile(
                title: 'Nutrition Lab',
                subtitle: 'Log your meals with AI',
                icon: Icons.restaurant_rounded,
                accent: Colors.orange,
                onTap: () => _openScreen(context, const DietScreen()),
              ),
              const SizedBox(height: 16),
              ActionTile(
                title: 'Analytics',
                subtitle: 'Weekly progress report',
                icon: Icons.bar_chart_rounded,
                accent: Colors.blueAccent,
                onTap: () => _openScreen(context, const ReportScreen()),
              ),
              const SizedBox(height: 16),
              ActionTile(
                title: 'Workout Planner',
                subtitle: 'AI-generated 7-day routine',
                icon: Icons.auto_awesome_rounded,
                accent: Colors.purpleAccent,
                onTap: () => _openScreen(context, const PlannerScreen()),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}