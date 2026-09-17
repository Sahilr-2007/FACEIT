import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<dynamic> _scans = [];
  List<dynamic> _faceScans = [];
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _fetchHistory();
  }

  Future<void> _fetchHistory() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final resScans = await http.get(
        Uri.parse('${AppConfig.baseUrl}/history/scans'),
        headers: AppConfig.headers,
      ).timeout(const Duration(seconds: 5));
      final resFaceScans = await http.get(
        Uri.parse('${AppConfig.baseUrl}/history/facescans'),
        headers: AppConfig.headers,
      ).timeout(const Duration(seconds: 5));

      if (resScans.statusCode == 200 && resFaceScans.statusCode == 200) {
        final List<dynamic> scansData = jsonDecode(resScans.body)['results'] ?? [];
        final List<dynamic> faceScansData = jsonDecode(resFaceScans.body)['results'] ?? [];

        scansData.sort((a, b) => DateTime.parse(b['date']).compareTo(DateTime.parse(a['date'])));
        faceScansData.sort((a, b) => DateTime.parse(b['date']).compareTo(DateTime.parse(a['date'])));

        setState(() {
          _scans = scansData;
          _faceScans = faceScansData;
          _isLoading = false;
        });
      } else {
        setState(() {
          _hasError = true;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _hasError = true;
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteItem(String type, int id) async {
    final endpoint = type == 'scan' ? '/history/scans/$id' : '/history/facescans/$id';
    try {
      final res = await http.delete(Uri.parse('${AppConfig.baseUrl}$endpoint'), headers: AppConfig.headers);
      if (res.statusCode == 200) {
        _fetchHistory();
      }
    } catch (e) {
      // Ignore
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          title: const Text("My History", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
          centerTitle: true,
          backgroundColor: Colors.black,
          elevation: 0,
          leading: const BackButton(color: Colors.white),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white70),
              onPressed: _fetchHistory,
            )
          ],
          bottom: const TabBar(
            indicatorColor: Color(0xFF00FFCC),
            labelColor: Color(0xFF00FFCC),
            unselectedLabelColor: Colors.white54,
            tabs: [
              Tab(text: "Disease Scans"),
              Tab(text: "Face Analysis"),
            ],
          ),
        ),
        body: SafeArea(
          child: _buildBody(),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF00FFCC)));
    }
    
    if (_hasError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.white24),
            const SizedBox(height: 16),
            const Text("Could not load history.", style: TextStyle(fontSize: 18, color: Colors.white54)),
            const SizedBox(height: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00FFCC)),
              onPressed: _fetchHistory,
              child: const Text("Try Again", style: TextStyle(color: Colors.black)),
            )
          ],
        ),
      );
    }

    return TabBarView(
      children: [
        _buildList(_scans, 'scan'),
        _buildList(_faceScans, 'facescan'),
      ],
    );
  }

  Widget _buildList(List<dynamic> items, String type) {
    if (items.isEmpty) {
      return const Center(
        child: Text("No scans found yet. Try taking a picture!", style: TextStyle(fontSize: 16, color: Colors.white54)),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(24.0),
      itemCount: items.length,
      separatorBuilder: (context, index) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final item = items[index];
        return Dismissible(
          key: Key("${type}_${item['id']}"),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            decoration: BoxDecoration(
              color: Colors.redAccent,
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(Icons.delete, color: Colors.white),
          ),
          onDismissed: (direction) {
            setState(() {
              if (type == 'scan') {
                _scans.removeWhere((x) => x['id'] == item['id']);
              } else {
                _faceScans.removeWhere((x) => x['id'] == item['id']);
              }
            });
            _deleteItem(type, item['id']);
          },
          child: type == 'scan' ? _HistoryCard(item: item) : _FaceScanCard(item: item),
        );
      },
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final dynamic item;

  const _HistoryCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final condition = item['condition'] ?? 'Unknown';
    String dateStr = item['date'] ?? '';
    if (dateStr.contains('T')) {
      dateStr = dateStr.split('T')[0];
    }
    
    Color color;
    IconData icon;
    if (condition.toLowerCase().contains("eczema")) {
      color = const Color(0xFF81D4FA);
      icon = Icons.health_and_safety_rounded;
    } else if (condition.toLowerCase().contains("normal")) {
      color = const Color(0xFFA5D6A7);
      icon = Icons.thumb_up_rounded;
    } else if (condition.toLowerCase().contains("model missing")) {
      color = Colors.grey.shade400;
      icon = Icons.warning_amber_rounded;
    } else {
      color = const Color(0xFFFFCC80);
      icon = Icons.healing_rounded;
    }
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF121212),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: color.withOpacity(0.3),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 32),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dateStr,
                  style: const TextStyle(fontSize: 14, color: Colors.white54, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  condition,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FaceScanCard extends StatelessWidget {
  final dynamic item;

  const _FaceScanCard({required this.item});

  @override
  Widget build(BuildContext context) {
    String dateStr = item['date'] ?? '';
    if (dateStr.contains('T')) {
      dateStr = dateStr.split('T')[0];
    }
    
    final double score = (item['psl_score'] ?? 0.0).toDouble();
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF121212),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF00FFCC), Color(0xFFB300FF)]),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              score.toStringAsFixed(1),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dateStr,
                  style: const TextStyle(fontSize: 14, color: Colors.white54, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  item['overall_message'] ?? 'Analysis complete.',
                  style: const TextStyle(fontSize: 14, color: Colors.white),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
