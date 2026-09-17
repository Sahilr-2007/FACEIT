import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config.dart';
import '../widgets/aura_mascot_widget.dart';
import 'facial_analyzer_screen.dart';
import 'check_skin_flow.dart';
import 'chatbot_screen.dart';
import 'skin_tracker_screen.dart';
import 'ingredient_scanner_screen.dart';
import 'skin_routine_screen.dart';

class HomeScreen extends StatefulWidget {
  final Function(int) onNavigate;

  const HomeScreen({super.key, required this.onNavigate});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _streak = 0;
  List<dynamic> _customHabits = [];
  bool _isLoading = true;

  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(() {
      if (mounted) setState(() {});
    });
    _fetchHabits();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  double get _scrollOffset => _scrollController.hasClients ? _scrollController.offset : 0.0;
  
  // Hero section smoothly minimizes from 225 down to 160 as user scrolls down towards features
  double get _heroHeight {
    if (!_scrollController.hasClients) return 225.0;
    final double scrollProgress = (_scrollOffset / 160.0).clamp(0.0, 1.0);
    return 225.0 - (scrollProgress * 65.0);
  }

  Future<void> _fetchHabits() async {
    try {
      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}/habits'),
        headers: AppConfig.headers,
      ).timeout(const Duration(seconds: 5));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _streak = data['streak'];
          _customHabits = data['custom_habits'] ?? [];
          _isLoading = false;
        });
      } else {
        throw Exception("Server Error");
      }
    } catch (e) {
      setState(() {
        _streak = 0;
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleCustomHabit(int id, bool currentValue) async {
    final index = _customHabits.indexWhere((h) => h['id'] == id);
    if (index == -1) return;

    setState(() {
      _customHabits[index]['completed'] = !currentValue;
    });

    try {
      final res = await http.post(
        Uri.parse('${AppConfig.baseUrl}/habits/custom/$id/toggle'),
        headers: AppConfig.headers,
      );
      if (res.statusCode == 200) {
        setState(() {
          _customHabits[index]['completed'] = jsonDecode(res.body)['completed'];
        });
      }
    } catch (e) {
      setState(() {
        _customHabits[index]['completed'] = currentValue;
      });
    }
  }

  Future<void> _addCustomHabit(String label) async {
    try {
      final res = await http.post(
        Uri.parse('${AppConfig.baseUrl}/habits/custom'),
        headers: AppConfig.jsonHeaders,
        body: jsonEncode({"label": label, "icon_name": "check_circle"}),
      );
      if (res.statusCode == 200) {
        _fetchHabits();
      }
    } catch (e) {
      // Ignore
    }
  }

  Future<void> _deleteCustomHabit(int id) async {
    setState(() {
      _customHabits.removeWhere((h) => h['id'] == id);
    });
    try {
      await http.delete(
        Uri.parse('${AppConfig.baseUrl}/habits/custom/$id'),
        headers: AppConfig.headers,
      );
    } catch (e) {
      _fetchHabits();
    }
  }

  Future<void> _renameCustomHabit(int id, String newLabel) async {
    try {
      await http.patch(
        Uri.parse('${AppConfig.baseUrl}/habits/custom/$id'),
        headers: AppConfig.jsonHeaders,
        body: jsonEncode({'label': newLabel}),
      );
      _fetchHabits();
    } catch (e) {
      // Ignore
    }
  }

  void _showAddHabitSheet() {
    final TextEditingController controller = TextEditingController();
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF121212),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      isScrollControlled: true,
      builder: (context) {
        return SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              left: 24, right: 24, top: 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text("Add Custom Habit", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 16),
                TextField(
                  controller: controller,
                  style: const TextStyle(color: Colors.white),
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: "e.g., Take Supplements",
                    hintStyle: const TextStyle(color: Colors.white54),
                    filled: true,
                    fillColor: const Color(0xFF1A1A1A),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    if (controller.text.trim().isNotEmpty) {
                      _addCustomHabit(controller.text.trim());
                      Navigator.pop(context);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00FFCC),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text("Save Habit", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        );
      }
    );
  }

  void _showStreakDetailSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF121212),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      isScrollControlled: true,
      builder: (context) {
        return SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [Color(0xFF00FFCC), Color(0xFFB300FF)],
                  ).createShader(bounds),
                  child: const Icon(Icons.local_fire_department_rounded, size: 80, color: Colors.white),
                ),
                const SizedBox(height: 16),
                Text("$_streak Day Streak!", style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 8),
                Text(
                  _streak > 3 ? "You are on fire! Keep the momentum going." : "Great start! Consistency is key.",
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 16),
                ),
                const SizedBox(height: 32),
                // Mini 7-day calendar
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(7, (index) {
                    bool isCompleted = index < (_streak > 7 ? 7 : _streak);
                    return Column(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: isCompleted ? const Color(0xFF00FFCC) : const Color(0xFF1A1A1A),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isCompleted ? Icons.check : Icons.close,
                            size: 16,
                            color: isCompleted ? Colors.black : Colors.white30,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text("Day ${index+1}", style: const TextStyle(color: Colors.white54, fontSize: 10)),
                      ],
                    );
                  }),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, 
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: const Text(
          "A U R A",
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 4.0, color: Colors.white),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: CustomScrollView(
          controller: _scrollController,
          physics: const BouncingScrollPhysics(),
          slivers: [
            // TOP HERO SECTION (COLLAPSIBLE MASCOT & STREAK)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: SizedBox(
                  height: _heroHeight,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // MASCOT LEFT BOX
                      Expanded(
                        flex: 1,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF121212),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white.withOpacity(0.1)),
                          ),
                          child: Center(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.center,
                              child: AuraMascotWidget(
                                streak: _streak,
                                isCompletedToday: _customHabits.isNotEmpty && _customHabits.every((h) => h['completed'] == true),
                                onDoubleTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const ChatbotScreen()),
                                ),
                                onNavigateToChat: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const ChatbotScreen()),
                                ),
                                onNavigateToScan: () => widget.onNavigate(1),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),

                      // STREAK RIGHT BOX
                      Expanded(
                        flex: 1,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF121212),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white.withOpacity(0.1)),
                          ),
                          child: _isLoading 
                            ? const Center(child: CircularProgressIndicator(color: Color(0xFF00FFCC)))
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.topLeft,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        GestureDetector(
                                          onTap: _showStreakDetailSheet,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF1E1E1E),
                                              borderRadius: BorderRadius.circular(12),
                                              border: Border.all(color: const Color(0xFF00FFCC).withOpacity(0.35)),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: const Color(0xFF00FFCC).withOpacity(0.15),
                                                  blurRadius: 10,
                                                ),
                                              ],
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  "$_streak Day",
                                                  style: const TextStyle(
                                                    fontSize: 20,
                                                    fontWeight: FontWeight.w900,
                                                    color: Colors.white,
                                                    letterSpacing: 0.5,
                                                  ),
                                                ),
                                                const SizedBox(width: 6),
                                                ShaderMask(
                                                  shaderCallback: (bounds) => const LinearGradient(
                                                    colors: [Color(0xFF00FFCC), Color(0xFFB300FF)],
                                                  ).createShader(bounds),
                                                  child: const Icon(
                                                    Icons.local_fire_department_rounded,
                                                    color: Colors.white,
                                                    size: 22,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        const Text(
                                          "Streak (Tap for Details)",
                                          style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.w500),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Expanded(
                                    child: SingleChildScrollView(
                                      physics: const BouncingScrollPhysics(),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          if (_customHabits.isEmpty)
                                            const Padding(
                                              padding: EdgeInsets.symmetric(vertical: 4.0),
                                              child: Text("No habits added yet.", style: TextStyle(color: Colors.white38, fontSize: 11)),
                                            ),
                                          for (var h in _customHabits)
                                            _buildCustomHabitRow(h),
                                          const SizedBox(height: 6),
                                          GestureDetector(
                                            onTap: _showAddHabitSheet,
                                            child: Row(
                                              children: const [
                                                Icon(Icons.add_circle_outline, color: Color(0xFF00FFCC), size: 14),
                                                SizedBox(width: 6),
                                                Text("Add Habit", style: TextStyle(color: Color(0xFF00FFCC), fontSize: 11, fontWeight: FontWeight.bold)),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // FEATURES HEADER
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
                child: Row(
                  children: [
                    const Text(
                      "Features",
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const Spacer(),
                    if (_scrollOffset > 30)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.keyboard_arrow_up_rounded, size: 14, color: Colors.white.withOpacity(0.4)),
                          const SizedBox(width: 2),
                          Text(
                            "Scroll up to expand",
                            style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.4)),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),

            // 6 FEATURES GRID
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                  childAspectRatio: 1.2,
                ),
                delegate: SliverChildListDelegate([
                  _buildFeatureCard(
                    context, "Face Analyzer", Icons.face_retouching_natural_rounded, Colors.purpleAccent,
                    () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FacialAnalyzerScreen())),
                  ),
                  _buildFeatureCard(
                    context, "Skin Tracker", Icons.insights_rounded, Colors.blueAccent,
                    () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SkinTrackerScreen())), 
                  ),
                  _buildFeatureCard(
                    context, "Aura Coach", Icons.spa_rounded, Colors.greenAccent,
                    () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ChatbotScreen())),
                  ),
                  _buildFeatureCard(
                    context, "Disease Detector", Icons.medical_services_rounded, Colors.redAccent,
                    () => Navigator.push(context, MaterialPageRoute(builder: (_) => CheckSkinFlow(onNavigateToTab: widget.onNavigate))),
                  ),
                  _buildFeatureCard(
                    context, "AI Skin Routine", Icons.calendar_month_rounded, Colors.orangeAccent,
                    () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SkinRoutineScreen())),
                  ),
                  _buildFeatureCard(
                    context, "Toxicity Scanner", Icons.qr_code_scanner_rounded, Colors.pinkAccent,
                    () => Navigator.push(context, MaterialPageRoute(builder: (_) => const IngredientScannerScreen())),
                  ),
                ]),
              ),
            ),

            // BOTTOM SPACING TO ENSURE SMOOTH GLIDE
            const SliverToBoxAdapter(
              child: SizedBox(height: 32),
            ),
          ],
        ),
      ),
    );
  }



  Widget _buildCustomHabitRow(Map<String, dynamic> habit) {
    bool isCompleted = habit['completed'] ?? false;
    return GestureDetector(
      onTap: () => _toggleCustomHabit(habit['id'], isCompleted),
      onLongPress: () {
        showDialog(
          context: context,
          builder: (context) {
            final editController = TextEditingController(text: habit['label']);
            return AlertDialog(
              backgroundColor: const Color(0xFF1A1A1A),
              title: const Text("Manage Habit", style: TextStyle(color: Colors.white)),
              content: TextField(
                controller: editController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: "Rename habit...",
                  hintStyle: const TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: const Color(0xFF2A2A2A),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel", style: TextStyle(color: Colors.white54)),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _deleteCustomHabit(habit['id']);
                  },
                  child: const Text("Delete", style: TextStyle(color: Colors.redAccent)),
                ),
                TextButton(
                  onPressed: () {
                    final newLabel = editController.text.trim();
                    if (newLabel.isNotEmpty && newLabel != habit['label']) {
                      _renameCustomHabit(habit['id'], newLabel);
                    }
                    Navigator.pop(context);
                  },
                  child: const Text("Save", style: TextStyle(color: Color(0xFF00FFCC))),
                ),
              ],
            );
          },
        );
      },
      child: Padding(
        padding: const EdgeInsets.only(top: 8.0),
        child: Row(
          children: [
            Icon(
              isCompleted ? Icons.check_circle_rounded : Icons.circle_outlined,
              color: isCompleted ? const Color(0xFF00FFCC) : Colors.white30,
              size: 16,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                habit['label'],
                style: TextStyle(
                  color: isCompleted ? Colors.white : Colors.white54,
                  fontSize: 12,
                  decoration: isCompleted ? TextDecoration.lineThrough : null,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            GestureDetector(
              onTap: () => _deleteCustomHabit(habit['id']),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4.0),
                child: Icon(Icons.close_rounded, color: Colors.white24, size: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureCard(
    BuildContext context, String title, IconData icon, Color accentColor, VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF121212),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.06)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 10, offset: const Offset(0, 4),
            )
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              Positioned(
                top: -15, right: -15,
                child: Container(
                  width: 65, height: 65,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: accentColor.withOpacity(0.12),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Icon(icon, color: accentColor, size: 28),
                    Flexible(
                      child: Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13, height: 1.2),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
