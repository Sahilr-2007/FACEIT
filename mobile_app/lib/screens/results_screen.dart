import 'dart:io';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

class ResultsScreen extends StatelessWidget {
  final Map<String, dynamic> result;
  final XFile? imageFile;
  final VoidCallback onStartOver;
  final Function(int) onNavigateToTab;

  const ResultsScreen({
    super.key, 
    required this.result, 
    this.imageFile,
    required this.onStartOver,
    required this.onNavigateToTab,
  });

  void _shareReport(String condition, String confidencePct, String message) {
    final text = "FaceIT AI Clinical Skin Assessment Report\n\n"
        "Pattern Match: $condition ($confidencePct% Match)\n\n"
        "Clinical Observation: $message\n\n"
        "Clinical Pattern Analysis — Consult a board-certified dermatologist for medical evaluation.";
    Share.share(text);
  }

  @override
  Widget build(BuildContext context) {
    final condition = result['condition'] ?? 'Unknown Pattern';
    final rawConf = result['confidence'] ?? 0.0;
    final double confidenceNum = (rawConf is num) ? (rawConf > 1.0 ? rawConf / 100.0 : rawConf.toDouble()) : 0.0;
    final confidencePct = (confidenceNum * 100).toStringAsFixed(1);
    final message = result['message'] ?? 'No additional details provided.';
    
    List<dynamic> redFlags = result['red_flags'] is List ? result['red_flags'] : [
      "Rapid increase in size or border asymmetry",
      "Spontaneous bleeding, oozing, or persistent itching",
      "Lesion becomes painful, hard, or ulcerated"
    ];
    List<dynamic> atHomeCare = result['at_home_care'] is List ? result['at_home_care'] : [
      "Keep the skin area clean, dry, and un-irritated",
      "Avoid scratching, picking, or applying harsh chemical peels",
      "Apply a gentle, fragrance-free moisturizer and sunscreen"
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Medical Disclaimer Header Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.amber.withOpacity(0.15),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.amber.withOpacity(0.4)),
            ),
            child: const Row(
              children: [
                Icon(Icons.gavel_rounded, color: Colors.amber, size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "AI Clinical Pattern Report • Not a doctor's diagnosis.",
                    style: TextStyle(color: Colors.amber, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          const Icon(Icons.verified_rounded, size: 72, color: Color(0xFF00FFCC)),
          const SizedBox(height: 12),
          const Text(
            "Dual-Hybrid AI Assessment",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 24),

          // Main Result Card with Side-by-Side Photo Box
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF121212),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFF00FFCC).withOpacity(0.3)),
              boxShadow: [
                BoxShadow(color: const Color(0xFF00FFCC).withOpacity(0.08), blurRadius: 20, spreadRadius: -4)
              ],
            ),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Scanned Photo Thumbnail Box
                    Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFF00FFCC), width: 1.5),
                        color: const Color(0xFF1E1E1E),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: imageFile != null
                            ? Image.file(
                                File(imageFile!.path),
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => const Icon(Icons.camera_alt_rounded, color: Color(0xFF00FFCC), size: 36),
                              )
                            : const Icon(Icons.camera_alt_rounded, color: Color(0xFF00FFCC), size: 36),
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Condition Name & Confidence Match Badge
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            condition,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF00FFCC),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF00FFCC).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFF00FFCC).withOpacity(0.3)),
                            ),
                            child: Text(
                              "Pattern Match: $confidencePct%",
                              style: const TextStyle(color: Color(0xFF00FFCC), fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                const Divider(color: Colors.white10),
                const SizedBox(height: 12),
                Text(
                  message,
                  textAlign: TextAlign.start,
                  style: const TextStyle(fontSize: 14, height: 1.5, color: Colors.white70),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          
          // Red Flag Warning Signs
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1212),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.redAccent.withOpacity(0.4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 20),
                    SizedBox(width: 8),
                    Text(
                      "RED FLAG WARNING SIGNS",
                      style: TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ...redFlags.map((flag) => Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("• ", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                      Expanded(child: Text(flag.toString(), style: const TextStyle(color: Colors.white70, fontSize: 13))),
                    ],
                  ),
                )),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Actionable At-Home Care Tips
          const Text(
            "Recommended Next Steps & Care",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 12),
          ...atHomeCare.map((tip) => Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: _buildTipCard(tip.toString()),
          )),
          
          const SizedBox(height: 32),
          
          // Action Buttons
          ElevatedButton.icon(
            onPressed: () => onNavigateToTab(3),
            icon: const Icon(Icons.local_hospital_rounded, color: Colors.black),
            label: const Text("Consult a Dermatologist 📍", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 15)),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 56),
              backgroundColor: const Color(0xFF00FFCC),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => _shareReport(condition, confidencePct, message),
            icon: const Icon(Icons.share_rounded, color: Color(0xFF00FFCC)),
            label: const Text("Share Report for Doctor 📤", style: TextStyle(color: Color(0xFF00FFCC), fontWeight: FontWeight.bold, fontSize: 14)),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 52),
              side: const BorderSide(color: Color(0xFF00FFCC)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: onStartOver,
            child: const Text("Scan Another Skin Spot", style: TextStyle(color: Colors.white54, fontSize: 15)),
          ),
        ],
      ),
    );
  }

  Widget _buildTipCard(String text) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF121212),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline_rounded, color: Color(0xFF00FFCC), size: 18),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: const TextStyle(color: Colors.white70, fontSize: 13))),
        ],
      ),
    );
  }
}
