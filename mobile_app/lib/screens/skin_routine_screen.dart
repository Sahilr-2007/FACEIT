import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config.dart';

class SkinRoutineScreen extends StatefulWidget {
  const SkinRoutineScreen({super.key});

  @override
  State<SkinRoutineScreen> createState() => _SkinRoutineScreenState();
}

class _SkinRoutineScreenState extends State<SkinRoutineScreen> {
  bool _isLoading = false;
  bool _hasRoutine = false;

  String _selectedSkinType = "Oily";
  final TextEditingController _goalsController = TextEditingController(text: "Clear acne & Glass skin glow");

  final List<String> _presetGoals = [
    "✨ Glass Skin & Glow",
    "🛡️ Acne & Breakout Control",
    "💧 Deep Hydration & Repair",
    "🌿 Redness & Sensitivity",
    "⏳ Anti-Aging & Firming"
  ];

  Map<String, dynamic> _routine = {};
  final Set<String> _completedSteps = {};

  @override
  void initState() {
    super.initState();
    _loadSavedRoutine();
  }

  Future<void> _loadSavedRoutine() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedRoutineStr = prefs.getString('saved_skin_routine');
      final savedSteps = prefs.getStringList('saved_completed_steps');

      if (savedRoutineStr != null && savedRoutineStr.isNotEmpty) {
        final decoded = jsonDecode(savedRoutineStr);
        if (decoded is Map<String, dynamic>) {
          setState(() {
            _routine = decoded;
            _hasRoutine = true;
            if (savedSteps != null) {
              _completedSteps.addAll(savedSteps);
            }
          });
        }
      }
    } catch (e) {
      debugPrint("Error loading saved routine: $e");
    }
  }

  Future<void> _saveRoutineLocally() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('saved_skin_routine', jsonEncode(_routine));
      await prefs.setStringList('saved_completed_steps', _completedSteps.toList());
    } catch (e) {
      debugPrint("Error saving routine: $e");
    }
  }

  Future<void> _generateRoutine() async {
    setState(() {
      _isLoading = true;
      _completedSteps.clear();
    });

    try {
      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/generate-routine'),
        headers: AppConfig.jsonHeaders,
        body: jsonEncode({
          "skin_type": _selectedSkinType,
          "goals": _goalsController.text
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          setState(() {
            _routine = decoded;
            _hasRoutine = true;
            _isLoading = false;
          });
          await _saveRoutineLocally();
        } else {
          throw Exception("Invalid response format");
        }
      } else {
        throw Exception("Server Error");
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _routine = {
            "am_routine": [
              {"step": "Gentle Foam Cleanser", "active": "Salicylic Acid 2%", "desc": "Cleanses excess oil without stripping barrier."},
              {"step": "Niacinamide Glow Serum", "active": "Niacinamide 10%", "desc": "Soothes redness and shrinks enlarged pores."},
              {"step": "Barrier Barrier Moisturizer", "active": "Ceramides & Hyaluronic Acid", "desc": "Locks in hydration and strengthens skin defense."},
              {"step": "Broad-Spectrum SPF 50", "active": "Zinc Oxide 15%", "desc": "Shields against UV dark spots and premature aging."}
            ],
            "pm_routine": [
              {"step": "Deep Cleansing Oil", "active": "Jojoba Oil", "desc": "Dissolves SPF, makeup, and daily pollution."},
              {"step": "Repairing Retinoid Serum", "active": "Encapsulated Retinol 0.3%", "desc": "Accelerates cell turnover for smooth texture."},
              {"step": "Night Hydration Balm", "active": "Centella Asiatica", "desc": "Deep overnight barrier recovery."}
            ],
            "weekly_treatment": {
              "schedule": "Tuesday & Friday Night",
              "treatment": "BHA 2% Pore Refining Mask",
              "benefit": "Unclogs deep blackheads and refines skin texture."
            },
            "advice": "Apply serums on slightly damp skin to boost active ingredient absorption by 30%!"
          };
          _hasRoutine = true;
          _isLoading = false;
        });
        await _saveRoutineLocally();
      }
    }
  }

  Future<void> _toggleStep(String stepKey, int totalSteps) async {
    final wasComplete = _completedSteps.length == totalSteps && totalSteps > 0;
    setState(() {
      if (_completedSteps.contains(stepKey)) {
        _completedSteps.remove(stepKey);
      } else {
        _completedSteps.add(stepKey);
      }
    });
    _saveRoutineLocally();

    final isNowComplete = _completedSteps.length == totalSteps && totalSteps > 0;
    if (!wasComplete && isNowComplete) {
      final prefs = await SharedPreferences.getInstance();
      final todayStr = DateTime.now().toIso8601String().split('T')[0];
      final lastClaimedDate = prefs.getString('last_xp_claimed_date');
      final alreadyClaimedToday = (lastClaimedDate == todayStr);

      _showDuolingoCelebrationDialog(alreadyClaimedToday: alreadyClaimedToday);
    }
  }

  void _showDuolingoCelebrationDialog({required bool alreadyClaimedToday}) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "Celebration",
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (context, anim1, anim2) => const SizedBox.shrink(),
      transitionBuilder: (context, anim1, anim2, child) {
        final scale = CurvedAnimation(parent: anim1, curve: Curves.elasticOut);
        return ScaleTransition(
          scale: scale,
          child: AlertDialog(
            backgroundColor: const Color(0xFF141414),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
              side: const BorderSide(color: Color(0xFF00FFCC), width: 2.5),
            ),
            contentPadding: const EdgeInsets.all(20),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: alreadyClaimedToday 
                          ? [Colors.amber, Colors.orangeAccent]
                          : [const Color(0xFF00FFCC), const Color(0xFFB300FF)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: (alreadyClaimedToday ? Colors.amber : const Color(0xFF00FFCC)).withOpacity(0.6),
                          blurRadius: 35,
                          spreadRadius: 6,
                        )
                      ],
                    ),
                    child: Icon(
                      alreadyClaimedToday ? Icons.verified_rounded : Icons.workspace_premium_rounded,
                      size: 68,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.amber),
                    ),
                    child: Text(
                      alreadyClaimedToday ? "🏆 COMPLETED TODAY!" : "🏆 UNSTOPPABLE STREAK!",
                      style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    alreadyClaimedToday ? "TODAY'S GOAL DONE! ✔️" : "ROUTINE MASTERED! 🔥",
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF00FFCC),
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    "100% Skin Barrier Shield Active",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    alreadyClaimedToday
                      ? "Awesome job! You've completed your daily routine and already claimed today's +50 Glow XP. Come back tomorrow for your next XP bonus!"
                      : "BOOM! You checked off all your AM & PM skincare steps today! Your skin barrier is officially locked, hydrated, and protected!",
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1F1F1F),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.amber.withOpacity(0.4)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.stars_rounded, color: Colors.amber, size: 24),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            alreadyClaimedToday 
                              ? "Today's XP Claimed • Come back tomorrow!" 
                              : "+50 GLOW XP • 1-Day Streak Added!",
                            style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 13),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  alreadyClaimedToday
                    ? ElevatedButton.icon(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.check_circle_rounded, color: Colors.black, size: 22),
                        label: const Text(
                          "DONE FOR TODAY ✔️",
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white38,
                          minimumSize: const Size.fromHeight(52),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                      )
                    : ElevatedButton.icon(
                        onPressed: _claimGlowXp,
                        icon: const Icon(Icons.bolt_rounded, color: Colors.black, size: 22),
                        label: const Text(
                          "CLAIM 50 GLOW XP ⚡",
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00FFCC),
                          minimumSize: const Size.fromHeight(52),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                      ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _claimGlowXp() async {
    Navigator.of(context).pop();
    try {
      final prefs = await SharedPreferences.getInstance();
      final todayStr = DateTime.now().toIso8601String().split('T')[0];
      final lastClaimedDate = prefs.getString('last_xp_claimed_date');

      if (lastClaimedDate == todayStr) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.workspace_premium_rounded, color: Colors.amber, size: 24),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "Today's +50 Glow XP already claimed! Come back tomorrow for your next streak bonus! 🏆",
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                ],
              ),
              backgroundColor: const Color(0xFF1E1E1E),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          );
        }
        return;
      }

      int currentXp = prefs.getInt('user_glow_xp') ?? 0;
      int masteredCount = prefs.getInt('user_mastered_routines') ?? 0;
      List<String> dates = prefs.getStringList('routine_completed_dates') ?? [];

      currentXp += 50;
      masteredCount += 1;
      if (!dates.contains(todayStr)) {
        dates.add(todayStr);
      }

      await prefs.setInt('user_glow_xp', currentXp);
      await prefs.setInt('user_mastered_routines', masteredCount);
      await prefs.setStringList('routine_completed_dates', dates);
      await prefs.setString('last_xp_claimed_date', todayStr);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.stars_rounded, color: Colors.black, size: 24),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "🎉 +50 GLOW XP CLAIMED! Total: $currentXp XP (Saved in Skin Tracker 📊)",
                    style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF00FFCC),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        );
      }
    } catch (e) {
      debugPrint("Error claiming XP: $e");
    }
  }

  void _syncToHabits() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: Colors.black),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                "Routine saved and synced to your Daily Aura Habits! 🎉",
                style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF00FFCC),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
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
          "AI Skin Routine Hub",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: _hasRoutine ? _buildRoutineView() : _buildSetupView(),
        ),
      ),
    );
  }

  Widget _buildSetupView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 10),
          Center(
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [const Color(0xFF00FFCC).withOpacity(0.2), const Color(0xFFB300FF).withOpacity(0.2)],
                ),
                boxShadow: [
                  BoxShadow(color: const Color(0xFF00FFCC).withOpacity(0.3), blurRadius: 30, spreadRadius: 5)
                ]
              ),
              child: const Icon(Icons.auto_awesome_rounded, size: 64, color: Color(0xFF00FFCC)),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            "AI Precision Skincare",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 8),
          const Text(
            "Custom dermatologist AM/PM regimen tailored with active ingredients & weekly specialty treatments.",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white54, fontSize: 14, height: 1.4),
          ),
          const SizedBox(height: 36),

          // Skin Type Selector
          const Text("1. Select Your Skin Type", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: const Color(0xFF121212),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                dropdownColor: const Color(0xFF1A1A1A),
                value: _selectedSkinType,
                isExpanded: true,
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                items: ["Oily", "Dry", "Combination", "Sensitive", "Normal"].map((String value) {
                  return DropdownMenuItem<String>(value: value, child: Text(value));
                }).toList(),
                onChanged: (newValue) => setState(() => _selectedSkinType = newValue!),
              ),
            ),
          ),
          const SizedBox(height: 28),

          // Preset Goal Chips
          const Text("2. Tap Your Primary Goals", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 10,
            children: _presetGoals.map((goal) {
              final cleanGoal = goal.replaceAll(RegExp(r'^[^\w\s]+'), '').trim();
              final isSelected = _goalsController.text.contains(cleanGoal);
              return ChoiceChip(
                label: Text(goal, overflow: TextOverflow.ellipsis),
                selected: isSelected,
                selectedColor: const Color(0xFF00FFCC),
                backgroundColor: const Color(0xFF161616),
                labelStyle: TextStyle(
                  color: isSelected ? Colors.black : Colors.white70,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                side: BorderSide(color: isSelected ? const Color(0xFF00FFCC) : Colors.white.withOpacity(0.1)),
                onSelected: (selected) {
                  setState(() {
                    _goalsController.text = cleanGoal;
                  });
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 20),

          // Custom Goal Input
          TextField(
            controller: _goalsController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: "Or type custom goal...",
              hintStyle: const TextStyle(color: Colors.white38),
              filled: true,
              fillColor: const Color(0xFF121212),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.white.withOpacity(0.1))),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFF00FFCC))),
            ),
          ),

          const SizedBox(height: 36),
          ElevatedButton.icon(
            onPressed: _isLoading ? null : _generateRoutine,
            icon: _isLoading
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                : const Icon(Icons.bolt_rounded, color: Colors.black),
            label: Text(
              _isLoading ? "Crafting Routine..." : "Generate AI Routine ⚡",
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black),
            ),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 18),
              backgroundColor: const Color(0xFF00FFCC),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoutineView() {
    final rawAm = _routine['am_routine'];
    final rawPm = _routine['pm_routine'];
    final weekly = _routine['weekly_treatment'] is Map ? _routine['weekly_treatment'] : null;
    final advice = _routine['advice'] ?? "Consistency is the key to healthy skin!";

    List<Map<String, String>> amList = [];
    if (rawAm is List) {
      for (var item in rawAm) {
        if (item is Map) {
          amList.add({
            'step': item['step']?.toString() ?? 'Step',
            'active': item['active']?.toString() ?? 'Derm Active',
            'desc': item['desc']?.toString() ?? ''
          });
        } else if (item is String) {
          amList.add({'step': item, 'active': 'Active Formula', 'desc': 'Essential morning care step.'});
        }
      }
    }

    List<Map<String, String>> pmList = [];
    if (rawPm is List) {
      for (var item in rawPm) {
        if (item is Map) {
          pmList.add({
            'step': item['step']?.toString() ?? 'Step',
            'active': item['active']?.toString() ?? 'Derm Active',
            'desc': item['desc']?.toString() ?? ''
          });
        } else if (item is String) {
          pmList.add({'step': item, 'active': 'Active Formula', 'desc': 'Essential evening repair step.'});
        }
      }
    }

    final totalSteps = amList.length + pmList.length;
    final completedCount = _completedSteps.length;
    final progress = totalSteps > 0 ? (completedCount / totalSteps).clamp(0.0, 1.0) : 0.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  "Active Routine Plan",
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.settings_rounded, color: Color(0xFF00FFCC), size: 16),
                label: const Text("Customize", style: TextStyle(color: Color(0xFF00FFCC), fontWeight: FontWeight.bold, fontSize: 13)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  side: BorderSide(color: const Color(0xFF00FFCC).withOpacity(0.5)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => setState(() => _hasRoutine = false),
              )
            ],
          ),
          const SizedBox(height: 16),

          // Daily Progress Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF161616), Color(0xFF0E0E0E)],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF00FFCC).withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 54,
                      height: 54,
                      child: CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 6,
                        backgroundColor: Colors.white10,
                        color: const Color(0xFF00FFCC),
                      ),
                    ),
                    Text(
                      "${(progress * 100).toInt()}%",
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                    )
                  ],
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "$completedCount of $totalSteps Steps Done Today",
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        completedCount == totalSteps ? "🎉 Routine complete! Perfect glow!" : "Tap checkmarks as you apply products.",
                        style: const TextStyle(color: Colors.white54, fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                      )
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // AM ROUTINE
          _buildRoutineSection(
            title: "Morning Regimen (AM)",
            icon: Icons.wb_sunny_rounded,
            color: Colors.amber,
            steps: amList,
            prefix: "am",
            totalSteps: totalSteps,
          ),

          const SizedBox(height: 24),

          // PM ROUTINE
          _buildRoutineSection(
            title: "Night Regimen (PM)",
            icon: Icons.nightlight_round,
            color: Colors.indigoAccent,
            steps: pmList,
            prefix: "pm",
            totalSteps: totalSteps,
          ),

          if (weekly != null) ...[
            const SizedBox(height: 24),
            // WEEKLY SPECIALTY TREATMENT
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [const Color(0xFFB300FF).withOpacity(0.15), const Color(0xFF121212)],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFB300FF).withOpacity(0.4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.science_rounded, color: Color(0xFFB300FF)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          weekly['schedule']?.toString() ?? "Weekly Specialty",
                          style: const TextStyle(color: Color(0xFFB300FF), fontSize: 16, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    weekly['treatment']?.toString() ?? "Specialty Treatment",
                    style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    weekly['benefit']?.toString() ?? "Exfoliates & deep cleanses pores.",
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 24),
          // Expert Dermatologist Tip
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF121212),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF00FFCC).withOpacity(0.2)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.tips_and_updates_rounded, color: Color(0xFF00FFCC), size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    advice,
                    style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.5),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 28),
          ElevatedButton.icon(
            onPressed: _syncToHabits,
            icon: const Icon(Icons.sync_rounded, color: Colors.black),
            label: const Text("Sync Routine to Aura Habits ➕", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black)),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: const Color(0xFF00FFCC),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoutineSection({
    required String title,
    required IconData icon,
    required Color color,
    required List<Map<String, String>> steps,
    required String prefix,
    required int totalSteps,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF121212),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...steps.asMap().entries.map((entry) {
            final idx = entry.key;
            final stepData = entry.value;
            final stepKey = "${prefix}_$idx";
            final isChecked = _completedSteps.contains(stepKey);

            return InkWell(
              onTap: () => _toggleStep(stepKey, totalSteps),
              borderRadius: BorderRadius.circular(14),
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isChecked ? color.withOpacity(0.1) : const Color(0xFF181818),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: isChecked ? color : Colors.transparent),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      isChecked ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                      color: isChecked ? color : Colors.white38,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            stepData['step'] ?? '',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              decoration: isChecked ? TextDecoration.lineThrough : null,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF00FFCC).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              stepData['active'] ?? '',
                              style: const TextStyle(color: Color(0xFF00FFCC), fontSize: 11, fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if ((stepData['desc'] ?? '').isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              stepData['desc']!,
                              style: const TextStyle(color: Colors.white54, fontSize: 12),
                            ),
                          ]
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
