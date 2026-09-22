import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart' as intl;
import 'package:shared_preferences/shared_preferences.dart';
import '../config.dart';

class SkinTrackerScreen extends StatefulWidget {
  const SkinTrackerScreen({super.key});

  @override
  State<SkinTrackerScreen> createState() => _SkinTrackerScreenState();
}

class _SkinTrackerScreenState extends State<SkinTrackerScreen> {
  List<dynamic> _scans = [];
  bool _isLoading = true;
  int _selectedFilterDays = 30; // 7, 30, or 999 (All Time)

  int _userGlowXp = 0;
  int _masteredRoutines = 0;
  List<String> _completedDates = [];

  @override
  void initState() {
    super.initState();
    _fetchHistory();
    _loadGlowXpData();
  }

  Future<void> _loadGlowXpData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedScansRaw = prefs.getString('cached_facescans');
      List<dynamic> cachedScans = [];
      if (cachedScansRaw != null) {
        try {
          cachedScans = jsonDecode(cachedScansRaw);
        } catch (_) {}
      }

      setState(() {
        _userGlowXp = prefs.getInt('user_glow_xp') ?? 0;
        _masteredRoutines = prefs.getInt('user_mastered_routines') ?? 0;
        _completedDates = prefs.getStringList('routine_completed_dates') ?? [];
        if (cachedScans.isNotEmpty) {
          _scans = cachedScans;
          _isLoading = false;
        }
      });
    } catch (e) {
      debugPrint("Error loading Glow XP: $e");
    }
  }

  Future<void> _fetchHistory() async {
    if (_scans.isEmpty) {
      setState(() => _isLoading = true);
    }

    try {
      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}/history/facescans'),
        headers: AppConfig.headers,
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> results = data['results'] ?? [];
        results.sort((a, b) {
          try {
            return DateTime.parse(a['date']).compareTo(DateTime.parse(b['date']));
          } catch (_) {
            return 0;
          }
        });

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('cached_facescans', jsonEncode(results));

        if (mounted) {
          setState(() {
            _scans = results;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  double _parseDouble(dynamic val, [double defaultValue = 0.0]) {
    if (val == null) return defaultValue;
    if (val is num) return val.toDouble();
    if (val is String) {
      try {
        final clean = val.split('/')[0].replaceAll('%', '').trim();
        return double.parse(clean);
      } catch (_) {
        return defaultValue;
      }
    }
    return defaultValue;
  }

  int _calculateStreak() {
    final Set<String> dateStrings = {};

    for (var scan in _scans) {
      if (scan['date'] != null) {
        try {
          final dt = DateTime.parse(scan['date']);
          dateStrings.add("${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}");
        } catch (_) {}
      }
    }

    for (var dateStr in _completedDates) {
      dateStrings.add(dateStr);
    }

    if (dateStrings.isEmpty) return 0;

    final now = DateTime.now();
    final todayStr = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
    final yesterday = now.subtract(const Duration(days: 1));
    final yesterdayStr = "${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}";

    if (!dateStrings.contains(todayStr) && !dateStrings.contains(yesterdayStr)) {
      return 0;
    }

    int streak = 0;
    DateTime checkDate = dateStrings.contains(todayStr) ? now : yesterday;

    while (true) {
      final key = "${checkDate.year}-${checkDate.month.toString().padLeft(2, '0')}-${checkDate.day.toString().padLeft(2, '0')}";
      if (dateStrings.contains(key)) {
        streak++;
        checkDate = checkDate.subtract(const Duration(days: 1));
      } else {
        break;
      }
    }

    return streak;
  }

  List<dynamic> _getFilteredScans() {
    if (_scans.isEmpty) return [];
    if (_selectedFilterDays >= 900) return _scans;

    final cutoff = DateTime.now().subtract(Duration(days: _selectedFilterDays));
    final filtered = _scans.where((scan) {
      try {
        final d = DateTime.parse(scan['date']);
        return d.isAfter(cutoff);
      } catch (_) {
        return true;
      }
    }).toList();

    return filtered.isEmpty ? _scans : filtered;
  }

  @override
  Widget build(BuildContext context) {
    final filteredScans = _getFilteredScans();
    final streak = _calculateStreak();

    double latestScore = _scans.isNotEmpty ? _parseDouble(_scans.last['skin_health_score'] ?? _scans.last['skin_clarity'], 80.0) : 80.0;
    double earliestScore = _scans.isNotEmpty ? _parseDouble(_scans.first['skin_health_score'] ?? _scans.first['skin_clarity'], 80.0) : 80.0;
    double clarityGain = (latestScore - earliestScore);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("Skin Health & Recovery Tracker", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF00FFCC)),
            onPressed: _fetchHistory,
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF00FFCC)))
            : RefreshIndicator(
                color: const Color(0xFF00FFCC),
                backgroundColor: const Color(0xFF121212),
                onRefresh: _fetchHistory,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header Summary Stats Card
                      _buildStatsHeader(streak, clarityGain),
                      const SizedBox(height: 24),

                      // AI Skin Routine Mastery & Glow XP Card
                      _buildRoutineXpCard(),
                      const SizedBox(height: 24),

                      // Time Range Selector & Graph Section
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "Skin Clarity Trajectory",
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          _buildFilterChips(),
                        ],
                      ),
                      const SizedBox(height: 14),
                      _buildLineChartContainer(filteredScans),

                      const SizedBox(height: 28),

                      // Parameter Growth Deltas
                      if (_scans.length >= 2) ...[
                        const Text(
                          "Skin Recovery Deltas",
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        const SizedBox(height: 12),
                        _buildMetricDeltas(),
                        const SizedBox(height: 28),
                      ],

                      // History Log Header
                      const Text(
                        "Dermatological Scan History",
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      const SizedBox(height: 14),
                      _buildHistoryList(),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildRoutineXpCard() {
    final level = (_userGlowXp / 300).floor() + 1;
    final xpInCurrentLevel = _userGlowXp % 300;
    final progressRatio = (xpInCurrentLevel / 300.0).clamp(0.0, 1.0);

    String levelTitle = "Skincare Novice 🌿";
    if (level == 2) levelTitle = "Barrier Defender 🛡️";
    if (level == 3) levelTitle = "Glow Enthusiast ✨";
    if (level == 4) levelTitle = "Aesthetic Master 💎";
    if (level >= 5) levelTitle = "Glass Skin Master 👑";

    // Build last 7 days checkmarks
    final now = DateTime.now();
    final List<Widget> dayWidgets = [];

    for (int i = 6; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final dateStr = date.toIso8601String().split('T')[0];
      final dayName = ["M", "T", "W", "T", "F", "S", "S"][date.weekday - 1];
      final isDone = _completedDates.contains(dateStr);

      dayWidgets.add(
        Column(
          children: [
            Text(dayName, style: const TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDone ? const Color(0xFF00FFCC) : const Color(0xFF1F1F1F),
                border: Border.all(color: isDone ? const Color(0xFF00FFCC) : Colors.white10),
              ),
              child: Icon(
                isDone ? Icons.check_rounded : Icons.circle_outlined,
                color: isDone ? Colors.black : Colors.white24,
                size: 16,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF161616), Color(0xFF0E0E0E)],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF00FFCC).withOpacity(0.3)),
        boxShadow: [
          BoxShadow(color: const Color(0xFF00FFCC).withOpacity(0.08), blurRadius: 20, spreadRadius: -5)
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF00FFCC).withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.stars_rounded, color: Color(0xFF00FFCC), size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Level $level • $levelTitle",
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      "$_userGlowXp Total Glow XP Earned",
                      style: const TextStyle(color: Color(0xFF00FFCC), fontWeight: FontWeight.w900, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Next Level Progress",
                    style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    "$xpInCurrentLevel / 300 XP (Lvl ${level + 1})",
                    style: const TextStyle(color: Color(0xFF00FFCC), fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: progressRatio,
                  minHeight: 10,
                  backgroundColor: Colors.white10,
                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF00FFCC)),
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF181818),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.05)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.local_fire_department_rounded, color: Colors.amber, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      "$_masteredRoutines Daily Routines Mastered",
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text("7-Day Routine Consistency", style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: dayWidgets,
          ),
        ],
      ),
    );
  }

  Widget _buildStatsHeader(int streak, double clarityGain) {
    final gainText = clarityGain >= 0 ? "+${clarityGain.toInt()}%" : "${clarityGain.toInt()}%";

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF121212),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Expanded(child: _buildStatTile("STREAK", "🔥 $streak Days", const Color(0xFF00FFCC))),
          Container(width: 1, height: 36, color: Colors.white10),
          Expanded(child: _buildStatTile("TOTAL SCANS", "${_scans.length}", Colors.white)),
          Container(width: 1, height: 36, color: Colors.white10),
          Expanded(child: _buildStatTile("CLARITY GAIN", gainText, clarityGain >= 0 ? Colors.greenAccent : Colors.redAccent)),
        ],
      ),
    );
  }

  Widget _buildStatTile(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildFilterChips() {
    return Row(
      children: [7, 30, 999].map((days) {
        final label = days == 999 ? "ALL" : "${days}D";
        final isSelected = _selectedFilterDays == days;
        return GestureDetector(
          onTap: () => setState(() => _selectedFilterDays = days),
          child: Container(
            margin: const EdgeInsets.only(left: 6),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFF00FFCC) : const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isSelected ? const Color(0xFF00FFCC) : Colors.white10),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.black : Colors.white60,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildLineChartContainer(List<dynamic> scans) {
    if (scans.isEmpty) {
      return Container(
        height: 180,
        decoration: BoxDecoration(
          color: const Color(0xFF121212),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white10),
        ),
        alignment: Alignment.center,
        child: const Text("No scan history recorded yet.", style: TextStyle(color: Colors.white38, fontSize: 14)),
      );
    }

    if (scans.length == 1) {
      final singleScore = _parseDouble(scans[0]['skin_health_score'] ?? scans[0]['skin_clarity'], 82.0).toInt();
      return Container(
        height: 180,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF121212),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white10),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.auto_graph_rounded, color: Color(0xFF00FFCC), size: 36),
            const SizedBox(height: 10),
            Text(
              "Baseline Skin Health: $singleScore%",
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 6),
            const Text("Take another scan in a few days to track your skin barrier progress!", style: TextStyle(color: Colors.white54, fontSize: 12)),
          ],
        ),
      );
    }

    return Container(
      height: 220,
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      decoration: BoxDecoration(
        color: const Color(0xFF121212),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3)),
        boxShadow: [
          BoxShadow(color: const Color(0xFF10B981).withOpacity(0.08), blurRadius: 20, spreadRadius: -5)
        ],
      ),
      child: CustomPaint(
        size: Size.infinite,
        painter: _LineGraphPainter(scans: scans, parseDouble: _parseDouble),
      ),
    );
  }

  Widget _buildMetricDeltas() {
    final first = _scans.first;
    final last = _scans.last;

    final skin1 = _parseDouble(first['skin_health_score'] ?? first['skin_clarity'], 80);
    final skin2 = _parseDouble(last['skin_health_score'] ?? last['skin_clarity'], 80);
    final sym1 = _parseDouble(first['symmetry'], 80);
    final sym2 = _parseDouble(last['symmetry'], 80);

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      childAspectRatio: 2.2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      children: [
        _buildDeltaCard("Skin Clarity", skin1, skin2, "%"),
        _buildDeltaCard("Barrier Health", (skin1 * 0.95), (skin2 * 0.98), "%"),
        _buildDeltaCard("Breakout Control", 60.0, (60.0 + (skin2 - skin1) * 1.5).clamp(50.0, 98.0), "%"),
        _buildDeltaCard("Symmetry Balance", sym1, sym2, "%"),
      ],
    );
  }

  Widget _buildDeltaCard(String label, double val1, double val2, String unit) {
    final diff = val2 - val1;
    final isPos = diff >= 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("${val2.toInt()}$unit", style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isPos ? Colors.greenAccent.withOpacity(0.2) : Colors.redAccent.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isPos ? "+${diff.toInt()}$unit" : "${diff.toInt()}$unit",
                  style: TextStyle(color: isPos ? Colors.greenAccent : Colors.redAccent, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryList() {
    if (_scans.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: const Color(0xFF121212), borderRadius: BorderRadius.circular(20)),
        alignment: Alignment.center,
        child: const Text("No scan history recorded yet.", style: TextStyle(color: Colors.white38)),
      );
    }

    final reversedScans = _scans.reversed.toList();

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: reversedScans.length,
      itemBuilder: (context, index) {
        final scan = reversedScans[index];
        String dateStr = scan['date'] ?? '';
        try {
          final dt = DateTime.parse(dateStr);
          dateStr = intl.DateFormat('MMM d, yyyy • h:mm a').format(dt);
        } catch (_) {}

        final score = _parseDouble(scan['skin_health_score'] ?? scan['skin_clarity'], 80.0).toInt();
        final skinType = scan['skin_type'] ?? "Skin Scan";

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF121212),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(dateStr, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 4),
                    Text(
                      scan['overall_message'] ?? scan['message'] ?? '$skinType Diagnostic Assessment',
                      style: const TextStyle(color: Colors.white54, fontSize: 12),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF00FFCC), Color(0xFF10B981)]),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  "$score% Health",
                  style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 12),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _LineGraphPainter extends CustomPainter {
  final List<dynamic> scans;
  final double Function(dynamic, [double]) parseDouble;

  _LineGraphPainter({required this.scans, required this.parseDouble});

  @override
  void paint(Canvas canvas, Size size) {
    if (scans.isEmpty) return;

    final double marginB = 30;
    final double marginT = 10;
    final double graphH = size.height - marginB - marginT;

    // Determine min/max score values (0 to 100%)
    final scoreValues = scans.map((s) => parseDouble(s['skin_health_score'] ?? s['skin_clarity'], 80.0)).toList();
    double minScore = scoreValues.reduce((a, b) => a < b ? a : b) - 5;
    double maxScore = scoreValues.reduce((a, b) => a > b ? a : b) + 5;
    if (minScore < 0.0) minScore = 0.0;
    if (maxScore > 100.0) maxScore = 100.0;
    final scoreRange = (maxScore - minScore) <= 0 ? 1.0 : (maxScore - minScore);

    // Compute point coordinates
    final List<Offset> points = [];
    final double stepX = size.width / (scans.length - 1);

    for (int i = 0; i < scans.length; i++) {
      final x = i * stepX;
      final sc = scoreValues[i];
      final y = size.height - marginB - ((sc - minScore) / scoreRange * graphH);
      points.add(Offset(x, y));
    }

    // Grid lines
    final gridPaint = Paint()
      ..color = Colors.white12
      ..strokeWidth = 1;
    for (int i = 0; i < 3; i++) {
      final y = marginT + (graphH / 2 * i);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Line & Area paths
    final path = Path();
    final fillPath = Path();

    path.moveTo(points[0].dx, points[0].dy);
    fillPath.moveTo(points[0].dx, size.height - marginB);
    fillPath.lineTo(points[0].dx, points[0].dy);

    for (int i = 0; i < points.length - 1; i++) {
      final p1 = points[i];
      final p2 = points[i + 1];
      final controlP1 = Offset(p1.dx + (p2.dx - p1.dx) / 2, p1.dy);
      final controlP2 = Offset(p1.dx + (p2.dx - p1.dx) / 2, p2.dy);
      path.cubicTo(controlP1.dx, controlP1.dy, controlP2.dx, controlP2.dy, p2.dx, p2.dy);
      fillPath.cubicTo(controlP1.dx, controlP1.dy, controlP2.dx, controlP2.dy, p2.dx, p2.dy);
    }

    fillPath.lineTo(points.last.dx, size.height - marginB);
    fillPath.close();

    // Gradient Fill
    final fillGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        const Color(0xFF00FFCC).withOpacity(0.25),
        const Color(0xFF10B981).withOpacity(0.0),
      ],
    );
    final fillPaint = Paint()..shader = fillGradient.createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawPath(fillPath, fillPaint);

    // Neon Line
    final lineGradient = const LinearGradient(
      colors: [Color(0xFF00FFCC), Color(0xFF10B981)],
    );
    final linePaint = Paint()
      ..shader = lineGradient.createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke;
    canvas.drawPath(path, linePaint);

    // Draw Points & Labels
    final pointOuterPaint = Paint()..color = const Color(0xFF00FFCC);
    final pointInnerPaint = Paint()..color = Colors.black;
    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    for (int i = 0; i < points.length; i++) {
      final pt = points[i];
      final labelVal = "${scoreValues[i].toInt()}%";

      canvas.drawCircle(pt, 5, pointOuterPaint);
      canvas.drawCircle(pt, 2.5, pointInnerPaint);

      textPainter.text = TextSpan(
        text: labelVal,
        style: const TextStyle(color: Color(0xFF00FFCC), fontSize: 10, fontWeight: FontWeight.bold),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(pt.dx - textPainter.width / 2, pt.dy - 18));
    }
  }

  @override
  bool shouldRepaint(covariant _LineGraphPainter oldDelegate) => true;
}
