import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config.dart';

class DermatologistScreen extends StatefulWidget {
  const DermatologistScreen({super.key});

  @override
  State<DermatologistScreen> createState() => _DermatologistScreenState();
}

class _DermatologistScreenState extends State<DermatologistScreen> {
  List<dynamic> _dermatologists = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchDermatologists();
  }

  Future<void> _fetchDermatologists() async {
    try {
      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}/nearby-dermatologists?lat=0.0&lng=0.0'),
        headers: AppConfig.headers,
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _dermatologists = data['results'];
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = "Could not find nearby doctors right now.";
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = "Could not load nearby doctors. Make sure the backend is running.";
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("Find a Doctor", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        centerTitle: true,
        backgroundColor: Colors.black,
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Placeholder Map View
            Container(
              height: 200,
              margin: const EdgeInsets.symmetric(horizontal: 16.0),
              decoration: BoxDecoration(
                color: const Color(0xFF121212),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white10),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Mock Map Background
                    Container(
                      color: const Color(0xFF1A1A1A),
                      child: GridView.builder(
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 5,
                        ),
                        itemBuilder: (context, index) => Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.white10, width: 2),
                          ),
                        ),
                      ),
                    ),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.map_rounded,
                          size: 64,
                          color: const Color(0xFF00FFCC).withOpacity(0.8),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          "Map View (Coming Soon)",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white54,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // List View
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(child: Text(_error!))
                      : ListView.separated(
                          padding: const EdgeInsets.all(16.0),
                          itemCount: _dermatologists.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 16),
                          itemBuilder: (context, index) {
                            final doc = _dermatologists[index];
                            return _DoctorCard(doctor: doc);
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DoctorCard extends StatelessWidget {
  final Map<String, dynamic> doctor;

  const _DoctorCard({required this.doctor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF121212),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFCC80).withOpacity(0.3),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.local_hospital_rounded, color: Color(0xFFF57C00), size: 32),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      doctor['name'],
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.star_rounded, color: Colors.amber, size: 20),
                        const SizedBox(width: 4),
                        Text(
                          "${doctor['rating']}",
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 12),
                        Icon(Icons.location_on_rounded, color: Colors.grey.shade600, size: 18),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            doctor['distance'],
                            style: const TextStyle(color: Colors.white54),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            doctor['address'],
            style: const TextStyle(color: Colors.white54),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Opening Maps...")),
                );
              },
              icon: const Icon(Icons.directions_rounded),
              label: const Text("Get Directions", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4FC3F7),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
