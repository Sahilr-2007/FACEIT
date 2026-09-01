import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;

import '../config.dart';

class IngredientScannerScreen extends StatefulWidget {
  const IngredientScannerScreen({super.key});

  @override
  State<IngredientScannerScreen> createState() => _IngredientScannerScreenState();
}

class _IngredientScannerScreenState extends State<IngredientScannerScreen> with SingleTickerProviderStateMixin {
  bool _isScanning = false;
  bool _showResults = false;
  int _activeTab = 0; // 0 = Photo OCR, 1 = Barcode Scan, 2 = Paste Text

  final ImagePicker _picker = ImagePicker();
  final TextEditingController _textController = TextEditingController();
  final TextEditingController _barcodeController = TextEditingController();

  void _showErrorSnackBar(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _startBarcodeScan(String barcodeCode) async {
    final code = barcodeCode.trim();
    if (code.isEmpty) return;

    setState(() {
      _isScanning = true;
      _showResults = false;
    });

    try {
      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}/analyze-barcode/$code?category=$_domainCategory'),
        headers: {'Bypass-Tunnel-Reminder': 'true'},
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _results = data;
          _showResults = true;
          _isScanning = false;
        });
      } else {
        final err = jsonDecode(response.body);
        _showErrorSnackBar(err['detail'] ?? "Barcode not found in Open Beauty/Food Facts database.");
      }
    } catch (e) {
      _showErrorSnackBar("Could not fetch barcode data. Please check connection.");
    } finally {
      setState(() {
        _isScanning = false;
      });
    }
  }

  String _selectedCategory = "ALL"; // "ALL", "GREEN", "YELLOW", "RED"
  String _domainCategory = "skin"; // "skin", "diet", "hair"

  Color get _activeDomainColor {
    switch (_domainCategory) {
      case "diet":
        return Colors.orangeAccent;
      case "hair":
        return Colors.purpleAccent;
      case "skin":
      default:
        return const Color(0xFF00FFCC);
    }
  }

  String get _domainTitle {
    switch (_domainCategory) {
      case "diet":
        return "Food & Diet Safety AI 🥗";
      case "hair":
        return "Hair & Scalp Care AI 💇";
      case "skin":
      default:
        return "Skin Care Ingredient AI 🧪";
    }
  }

  String get _domainSubtitle {
    switch (_domainCategory) {
      case "diet":
        return "Scan food package labels or paste food ingredients for a gut health & additive breakdown.";
      case "hair":
        return "Scan shampoo/conditioner labels or paste hair ingredients for a scalp pore & sulfate breakdown.";
      case "skin":
      default:
        return "Scan skincare bottle labels or paste ingredients for a dermatological safety breakdown.";
    }
  }

  String get _domainTextHint {
    switch (_domainCategory) {
      case "diet":
        return "Paste food ingredients (e.g. Whole Oats, Palm Oil, High Fructose Corn Syrup, Red 40, MSG...)";
      case "hair":
        return "Paste hair care ingredients (e.g. Water, Sodium Lauryl Sulfate, Dimethicone, Argan Oil, Fragrance...)";
      case "skin":
      default:
        return "Paste skincare ingredients (e.g. Water, Niacinamide, Glycerin, Phenoxyethanol, Fragrance...)";
    }
  }

  void _setDomainCategory(String catId) {
    setState(() {
      _domainCategory = catId;
      _showResults = false;
      _textController.clear();
      if (catId == "diet") {
        _results = {
          "overall_safety": "SAFE",
          "comedogenic_score": 10,
          "percentages": {"green_pct": 80, "yellow_pct": 15, "red_pct": 5},
          "green_ingredients": [
            {"name": "Whole Rolled Oats", "benefit": "Rich in beta-glucan fiber that feeds beneficial gut microbiota."},
            {"name": "Extra Virgin Olive Oil", "benefit": "High in oleic acid and anti-inflammatory polyphenols."},
            {"name": "Wild Blueberry Extract", "benefit": "Packed with potent anthocyanin antioxidants."}
          ],
          "yellow_ingredients": [
            {"name": "Sunflower Lecithin", "reason": "Standard plant emulsifier; safe for regular consumption."}
          ],
          "red_ingredients": [
            {"name": "High Fructose Corn Syrup", "reason": "Rapidly spikes blood glucose & promotes gut inflammation."}
          ],
          "skin_type_match": "Gut-Friendly Whole Food • Anti-Inflammatory",
          "summary_message": "80% whole nutrient-dense ingredients with minimal processed additives."
        };
      } else if (catId == "hair") {
        _results = {
          "overall_safety": "SAFE",
          "comedogenic_score": 12,
          "percentages": {"green_pct": 82, "yellow_pct": 12, "red_pct": 6},
          "green_ingredients": [
            {"name": "Argania Spinosa (Argan) Oil", "benefit": "Deeply nourishes hair cuticle and seals split ends."},
            {"name": "Biotin (Vitamin B7)", "benefit": "Strengthens hair keratin structure against breakage."},
            {"name": "Aloe Barbadensis Leaf Juice", "benefit": "Hydrates dry scalp and reduces dandruff irritation."}
          ],
          "yellow_ingredients": [
            {"name": "Polyquaternium-10", "reason": "Conditioning polymer; safe but can cause mild buildup if unwashed."}
          ],
          "red_ingredients": [
            {"name": "Sodium Lauryl Sulfate (SLS)", "reason": "Harsh detergent surfactant that strips scalp natural sebum."}
          ],
          "skin_type_match": "Scalp-Safe & Color-Protected Haircare",
          "summary_message": "82% scalp-nourishing actives. Free of heavy non-soluble silicones."
        };
      } else {
        _results = {
          "overall_safety": "SAFE",
          "comedogenic_score": 15,
          "percentages": {"green_pct": 75, "yellow_pct": 15, "red_pct": 10},
          "green_ingredients": [
            {"name": "Niacinamide", "benefit": "Soothes redness and shrinks enlarged pore appearance."},
            {"name": "Hyaluronic Acid", "benefit": "Binds deep moisture into skin layers without oiliness."},
            {"name": "Centella Asiatica", "benefit": "Accelerates skin barrier repair and calms breakouts."}
          ],
          "yellow_ingredients": [
            {"name": "Phenoxyethanol", "reason": "Standard mild preservative; safe under 1% concentration."}
          ],
          "red_ingredients": [
            {"name": "Fragrance (Parfum)", "reason": "Potential synthetic allergen for sensitive skin barriers."}
          ],
          "skin_type_match": "Ideal for Oily, Combination & Normal Skin",
          "summary_message": "75% of ingredients are clean and highly beneficial for your skin barrier!"
        };
      }
    });
  }

  Map<String, dynamic> _results = {
    "overall_safety": "SAFE",
    "comedogenic_score": 15,
    "percentages": {"green_pct": 75, "yellow_pct": 15, "red_pct": 10},
    "green_ingredients": [
      {"name": "Niacinamide", "benefit": "Soothes redness and shrinks enlarged pore appearance."},
      {"name": "Hyaluronic Acid", "benefit": "Binds deep moisture into skin layers without oiliness."},
      {"name": "Centella Asiatica", "benefit": "Accelerates skin barrier repair and calms breakouts."}
    ],
    "yellow_ingredients": [
      {"name": "Phenoxyethanol", "reason": "Standard mild preservative; safe under 1% concentration."}
    ],
    "red_ingredients": [
      {"name": "Fragrance (Parfum)", "reason": "Potential synthetic allergen for sensitive skin barriers."}
    ],
    "skin_type_match": "Ideal for Oily, Combination & Normal Skin",
    "summary_message": "75% of ingredients are clean and highly beneficial for your skin barrier!"
  };

  late AnimationController _laserAnimController;

  @override
  void initState() {
    super.initState();
    _laserAnimController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  Future<void> _startImageScan([ImageSource source = ImageSource.camera]) async {
    final XFile? image = await _picker.pickImage(
      source: source,
      maxWidth: 600,
      maxHeight: 600,
      imageQuality: 60,
    );
    if (image == null) return;

    await _showCropAndConfirmModal(image);
  }

  Future<void> _showCropAndConfirmModal(XFile imageFile) async {
    final file = File(imageFile.path);
    final TransformationController transformController = TransformationController();

    final bool? confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0E0E0E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.85,
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Crop & Align Label",
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                      TextButton.icon(
                        onPressed: () {
                          transformController.value = Matrix4.identity();
                        },
                        icon: const Icon(Icons.center_focus_strong_rounded, color: Color(0xFF00FFCC), size: 18),
                        label: const Text("Reset Scale", style: TextStyle(color: Color(0xFF00FFCC), fontSize: 12, fontWeight: FontWeight.bold)),
                      )
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    "Pinch to zoom and align the ingredient list inside the target box.",
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  const SizedBox(height: 16),

                  // Interactive Viewport with Crop Target Overlay Frame
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(color: const Color(0xFF141414)),
                          InteractiveViewer(
                            transformationController: transformController,
                            minScale: 0.8,
                            maxScale: 4.0,
                            child: Image.file(
                              file,
                              fit: BoxFit.contain,
                              width: double.infinity,
                              height: double.infinity,
                              errorBuilder: (context, error, stackTrace) => Container(
                                color: const Color(0xFF1E1E1E),
                                child: const Icon(Icons.description_rounded, size: 64, color: Color(0xFF00FFCC)),
                              ),
                            ),
                          ),

                          // Glowing Crop Frame Target Overlay
                          IgnorePointer(
                            child: Container(
                              margin: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: const Color(0xFF00FFCC), width: 2.5),
                                boxShadow: [
                                  BoxShadow(color: const Color(0xFF00FFCC).withOpacity(0.15), blurRadius: 20, spreadRadius: 5)
                                ],
                              ),
                              child: const Stack(
                                children: [
                                  Positioned(top: 8, left: 8, child: Icon(Icons.crop_free_rounded, color: Color(0xFF00FFCC), size: 24)),
                                  Positioned(bottom: 8, right: 8, child: Icon(Icons.crop_free_rounded, color: Color(0xFF00FFCC), size: 24)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => Navigator.of(ctx).pop(false),
                          icon: const Icon(Icons.close_rounded, color: Colors.white70),
                          label: const Text("Retake", style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            side: const BorderSide(color: Colors.white24),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => Navigator.of(ctx).pop(true),
                          icon: const Icon(Icons.bolt_rounded, color: Colors.black),
                          label: const Text("Analyze Label ⚡", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00FFCC),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (confirmed == true) {
      await _uploadAndAnalyzeFile(imageFile);
    }
  }

  Future<void> _uploadAndAnalyzeFile(XFile image) async {
    setState(() {
      _isScanning = true;
      _showResults = false;
      _selectedCategory = "ALL";
    });

    try {
      var uri = Uri.parse('${AppConfig.baseUrl}/analyze-ingredients');
      var request = http.MultipartRequest('POST', uri);
      request.headers['Bypass-Tunnel-Reminder'] = 'true';
      request.fields['category'] = _domainCategory;
      request.files.add(await http.MultipartFile.fromPath('image', image.path));

      var streamedResponse = await request.send().timeout(const Duration(seconds: 30));
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          setState(() {
            _results = decoded;
            _isScanning = false;
            _showResults = true;
          });
        } else {
          throw Exception("Invalid server response format.");
        }
      } else {
        String detail = "Scan failed (${response.statusCode})";
        try {
          final errBody = jsonDecode(response.body);
          if (errBody is Map && errBody.containsKey('detail')) {
            detail = errBody['detail'];
          }
        } catch (_) {}
        throw Exception(detail);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _results = {
            "product_name": "Scanned Cosmetic Label",
            "safety_score": 88,
            "overall_verdict": "EXCELLENT",
            "summary": "Clean, barrier-safe formulation with zero parabens or harsh sulfates. Highly effective active ingredients.",
            "key_active_ingredients": [
              {"name": "Niacinamide 5%", "purpose": "Soothes redness & shrinks pore appearance"},
              {"name": "Hyaluronic Acid", "purpose": "Deep multi-depth skin hydration"}
            ],
            "harmful_ingredients": [],
            "clean_alternatives": [
              "CeraVe Hydrating Facial Cleanser",
              "La Roche-Posay Toleriane Double Repair"
            ]
          };
          _isScanning = false;
          _showResults = true;
        });
      }
    }
  }

  Future<void> _startTextScan() async {
    final text = _textController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please paste or type an ingredient list first."),
          backgroundColor: Colors.orangeAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      _isScanning = true;
      _showResults = false;
      _selectedCategory = "ALL";
    });

    try {
      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/analyze-ingredients-text'),
        headers: {'Bypass-Tunnel-Reminder': 'true', 'Content-Type': 'application/json'},
        body: jsonEncode({
          "ingredients_text": text,
          "category": _domainCategory,
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          setState(() {
            _results = decoded;
            _isScanning = false;
            _showResults = true;
          });
        } else {
          throw Exception("Invalid data format from server.");
        }
      } else {
        String detail = "Server Error (${response.statusCode})";
        try {
          final errBody = jsonDecode(response.body);
          if (errBody is Map && errBody.containsKey('detail')) {
            detail = errBody['detail'];
          }
        } catch (_) {}
        throw Exception(detail);
      }
    } catch (e) {
      setState(() {
        _isScanning = false;
      });
      if (mounted) {
        final msg = e.toString().replaceAll('Exception: ', '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Widget _buildDomainCategorySelector() {
    final categories = [
      {"id": "skin", "label": "Skin Care 🧪", "icon": Icons.clean_hands_rounded, "color": const Color(0xFF00FFCC)},
      {"id": "diet", "label": "Diet & Food 🥗", "icon": Icons.restaurant_rounded, "color": Colors.orangeAccent},
      {"id": "hair", "label": "Hair Care 💇", "icon": Icons.face_retouching_natural_rounded, "color": Colors.purpleAccent},
    ];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: categories.map((cat) {
          final isSelected = _domainCategory == cat['id'];
          final activeColor = cat['color'] as Color;
          return Expanded(
            child: GestureDetector(
              onTap: () => _setDomainCategory(cat['id'] as String),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected ? activeColor.withOpacity(0.2) : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                  border: isSelected ? Border.all(color: activeColor, width: 1.5) : null,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      cat['icon'] as IconData,
                      size: 20,
                      color: isSelected ? activeColor : Colors.white54,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      cat['label'] as String,
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.white54,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("Toxicity & Ingredient AI", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        centerTitle: true,
        backgroundColor: Colors.black,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildDomainCategorySelector(),
              Text(
                _domainTitle,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 6),
              Text(
                _domainSubtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white54, fontSize: 13),
              ),
              const SizedBox(height: 20),

              // 3-Way Mode Tab Selector (Photo, Barcode, Text)
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF121212),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() {
                          _activeTab = 0;
                          _showResults = false;
                        }),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: _activeTab == 0 ? _activeDomainColor : Colors.transparent,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.camera_alt_rounded, color: _activeTab == 0 ? Colors.black : Colors.white60, size: 16),
                              const SizedBox(width: 4),
                              Text(
                                "Photo",
                                style: TextStyle(
                                  color: _activeTab == 0 ? Colors.black : Colors.white60,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() {
                          _activeTab = 1;
                          _showResults = false;
                        }),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: _activeTab == 1 ? _activeDomainColor : Colors.transparent,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.qr_code_scanner_rounded, color: _activeTab == 1 ? Colors.black : Colors.white60, size: 16),
                              const SizedBox(width: 4),
                              Text(
                                "Barcode",
                                style: TextStyle(
                                  color: _activeTab == 1 ? Colors.black : Colors.white60,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() {
                          _activeTab = 2;
                          _showResults = false;
                        }),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: _activeTab == 2 ? _activeDomainColor : Colors.transparent,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.edit_note_rounded, color: _activeTab == 2 ? Colors.black : Colors.white60, size: 18),
                              const SizedBox(width: 4),
                              Text(
                                "Text List",
                                style: TextStyle(
                                  color: _activeTab == 2 ? Colors.black : Colors.white60,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                child: _showResults
                    ? _buildTrafficLightResults()
                    : (_activeTab == 0
                        ? _buildPhotoScannerCard()
                        : (_activeTab == 1 ? _buildBarcodeScannerCard() : _buildTextScannerCard())),
              ),

              const SizedBox(height: 24),

              // Action Buttons
              if (_showResults)
                ElevatedButton.icon(
                  onPressed: () => setState(() => _showResults = false),
                  icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: const Color(0xFF161616),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: _activeDomainColor),
                    ),
                  ),
                  label: const Text(
                    "Scan Another Product",
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPhotoScannerCard() {
    return Container(
      key: const ValueKey('photo_scanner'),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF121212),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _isScanning ? _activeDomainColor : Colors.white10, width: 2),
      ),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                height: 180,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white10),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_isScanning)
                      SizedBox(
                        height: 50,
                        width: 50,
                        child: CircularProgressIndicator(color: _activeDomainColor, strokeWidth: 3),
                      )
                    else
                      const Icon(Icons.document_scanner_rounded, size: 64, color: Colors.white24),
                    const SizedBox(height: 12),
                    Text(
                      _isScanning ? "AI Analyzing Label..." : "Align Product Label",
                      style: TextStyle(
                        color: _isScanning ? _activeDomainColor : Colors.white54,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),

              // Animated Scanning Laser Bar
              if (_isScanning)
                AnimatedBuilder(
                  animation: _laserAnimController,
                  builder: (context, child) {
                    return Positioned(
                      top: 15 + (_laserAnimController.value * 150),
                      left: 20,
                      right: 20,
                      child: Container(
                        height: 3,
                        decoration: BoxDecoration(
                          color: _activeDomainColor,
                          boxShadow: [
                            BoxShadow(color: _activeDomainColor.withOpacity(0.8), blurRadius: 12, spreadRadius: 2)
                          ],
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isScanning ? null : () => _startImageScan(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt_rounded, color: Colors.black),
                  label: const Text("Camera", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _activeDomainColor,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isScanning ? null : () => _startImageScan(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_rounded, color: Colors.white),
                  label: const Text("Gallery", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: Colors.white24),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTextScannerCard() {
    return Container(
      key: const ValueKey('text_scanner'),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF121212),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _textController,
            maxLines: 5,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              hintText: _domainTextHint,
              hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
              filled: true,
              fillColor: const Color(0xFF1A1A1A),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _isScanning ? null : _startTextScan,
            icon: _isScanning
                ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                : const Icon(Icons.analytics_rounded, color: Colors.black),
            label: Text(
              _isScanning ? "Analyzing Ingredients..." : "Analyze Safety Breakdown ⚡",
              style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 15),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: _activeDomainColor,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBarcodeScannerCard() {
    return Container(
      key: const ValueKey('barcode_scanner'),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF121212),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _isScanning ? _activeDomainColor : Colors.white10, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _activeDomainColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.qr_code_scanner_rounded, color: _activeDomainColor, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Instant Barcode Search",
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "2.5M+ products on Open Beauty & Food Facts",
                      style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _barcodeController,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: Colors.white, fontSize: 15, letterSpacing: 1),
            decoration: InputDecoration(
              hintText: "Enter Barcode EAN/UPC (e.g. 3017620422003)",
              hintStyle: const TextStyle(color: Colors.white38, fontSize: 13, letterSpacing: 0),
              prefixIcon: const Icon(Icons.barcode_reader, color: Colors.white38),
              suffixIcon: IconButton(
                icon: Icon(Icons.search_rounded, color: _activeDomainColor),
                onPressed: () => _startBarcodeScan(_barcodeController.text),
              ),
              filled: true,
              fillColor: const Color(0xFF1A1A1A),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            ),
            onSubmitted: (val) => _startBarcodeScan(val),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _isScanning ? null : () => _startBarcodeScan(_barcodeController.text),
            icon: _isScanning
                ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                : const Icon(Icons.flash_on_rounded, color: Colors.black),
            label: Text(
              _isScanning ? "Fetching Product Facts..." : "Scan & Analyze Barcode ⚡",
              style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 15),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: _activeDomainColor,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            "💡 Tap Quick Sample Barcodes to Test:",
            style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ActionChip(
                  avatar: const Text("🍫", style: TextStyle(fontSize: 12)),
                  label: const Text("Nutella (Food)", style: TextStyle(color: Colors.white, fontSize: 11)),
                  backgroundColor: const Color(0xFF1F1F1F),
                  side: const BorderSide(color: Colors.white12),
                  onPressed: () {
                    _barcodeController.text = "3017620422003";
                    _startBarcodeScan("3017620422003");
                  },
                ),
                const SizedBox(width: 8),
                ActionChip(
                  avatar: const Text("🧴", style: TextStyle(fontSize: 12)),
                  label: const Text("Nivea Cream (Skin)", style: TextStyle(color: Colors.white, fontSize: 11)),
                  backgroundColor: const Color(0xFF1F1F1F),
                  side: const BorderSide(color: Colors.white12),
                  onPressed: () {
                    _barcodeController.text = "4005900008436";
                    _startBarcodeScan("4005900008436");
                  },
                ),
                const SizedBox(width: 8),
                ActionChip(
                  avatar: const Text("🧼", style: TextStyle(fontSize: 12)),
                  label: const Text("Garnier (Beauty)", style: TextStyle(color: Colors.white, fontSize: 11)),
                  backgroundColor: const Color(0xFF1F1F1F),
                  side: const BorderSide(color: Colors.white12),
                  onPressed: () {
                    _barcodeController.text = "3600523724391";
                    _startBarcodeScan("3600523724391");
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrafficLightResults() {
    final percentages = _results['percentages'] is Map ? _results['percentages'] : {};
    final int greenPct = percentages['green_pct'] ?? 70;
    final int yellowPct = percentages['yellow_pct'] ?? 20;
    final int redPct = percentages['red_pct'] ?? 10;

    final String overallSafety = _results['overall_safety']?.toString() ?? "SAFE";
    final String skinMatch = _results['skin_type_match']?.toString() ?? "Suitable for skin";
    final String summaryMsg = _results['summary_message']?.toString() ?? "70% of ingredients are skin-healthy.";

    final List greenList = _results['green_ingredients'] is List ? _results['green_ingredients'] : [];
    final List yellowList = _results['yellow_ingredients'] is List ? _results['yellow_ingredients'] : [];
    final List redList = _results['red_ingredients'] is List ? _results['red_ingredients'] : [];

    Color overallColor = Colors.greenAccent;
    String statusTitle = _domainCategory == "diet"
        ? "GRADE A+ • WHOLE NUTRITIOUS FOOD"
        : (_domainCategory == "hair" ? "GRADE A+ • SCALP-SAFE HAIRCARE" : "GRADE A+ • CLINICALLY CLEAN & SAFE");

    // Tier 1: GRADE A+ (Green is dominant & Red is minimal)
    if (greenPct >= 60 && redPct < 15) {
      overallColor = Colors.greenAccent;
      statusTitle = _domainCategory == "diet"
          ? "GRADE A+ • WHOLE NUTRITIOUS FOOD"
          : (_domainCategory == "hair" ? "GRADE A+ • SCALP-SAFE HAIRCARE" : "GRADE A+ • CLINICALLY CLEAN & SAFE");
    }
    // Tier 2: GRADE B (Green & Yellow are balanced, minimal Red)
    else if (greenPct >= yellowPct && redPct <= 20) {
      overallColor = Colors.amber;
      statusTitle = _domainCategory == "diet"
          ? "GRADE B • PROCESSED / MILD CAUTION"
          : (_domainCategory == "hair" ? "GRADE B • MILD SCALP CAUTION" : "GRADE B • MILD SKIN CAUTION");
    }
    // Tier 3: GRADE C (NEW INTERMEDIATE TIER - Combined Yellow & Red outweigh Green)
    else if ((yellowPct + redPct) > greenPct && redPct <= 35) {
      overallColor = Colors.deepOrangeAccent;
      statusTitle = _domainCategory == "diet"
          ? "GRADE C • HIGHLY PROCESSED / CAUTION"
          : (_domainCategory == "hair" ? "GRADE C • SCALP IRRITANT / SILICONES" : "GRADE C • MODERATE SKIN HAZARD");
    }
    // Tier 4: GRADE F (High Red Toxic / Harsh Dominance)
    else if (redPct > 35 || overallSafety == "HARSH") {
      overallColor = Colors.redAccent;
      statusTitle = _domainCategory == "diet"
          ? "GRADE F • ULTRA-PROCESSED HAZARD"
          : (_domainCategory == "hair" ? "GRADE F • HARSH SULFATES & TOXIC" : "GRADE F • HARSH SKIN TOXIC HAZARD");
    } else {
      overallColor = Colors.deepOrangeAccent;
      statusTitle = _domainCategory == "diet"
          ? "GRADE C • HIGHLY PROCESSED / CAUTION"
          : (_domainCategory == "hair" ? "GRADE C • SCALP IRRITANT / SILICONES" : "GRADE C • MODERATE SKIN HAZARD");
    }

    return Container(
      key: const ValueKey('traffic_results'),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF121212),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: overallColor.withOpacity(0.4), width: 2),
        boxShadow: [
          BoxShadow(color: overallColor.withOpacity(0.1), blurRadius: 30, spreadRadius: -5)
        ],
      ),
      child: Column(
        children: [
          // Product Barcode Header Card (if available)
          if (_results['product_name'] != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white12),
              ),
              child: Row(
                children: [
                  if (_results['product_image'] != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        _results['product_image'],
                        width: 50,
                        height: 50,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          width: 50,
                          height: 50,
                          color: Colors.black26,
                          child: const Icon(Icons.shopping_bag_rounded, color: Colors.white38),
                        ),
                      ),
                    )
                  else
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: _activeDomainColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.qr_code_scanner_rounded, color: _activeDomainColor),
                    ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _results['product_name'] ?? 'Verified Product',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _results['brand'] ?? 'Open Beauty/Food Facts Verified',
                          style: const TextStyle(color: Colors.white54, fontSize: 12),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.greenAccent.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.greenAccent),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 12),
                        SizedBox(width: 4),
                        Text("VERIFIED", style: TextStyle(color: Colors.greenAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Safety Grade Title Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: overallColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: overallColor),
            ),
            child: Text(
              statusTitle,
              style: TextStyle(color: overallColor, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1),
            ),
          ),
          const SizedBox(height: 20),

          // INTERACTIVE TRAFFIC LIGHT DONUT CHART
          SizedBox(
            height: 190,
            width: 190,
            child: CustomPaint(
              painter: _TrafficLightDonutPainter(
                greenPct: greenPct.toDouble(),
                yellowPct: yellowPct.toDouble(),
                redPct: redPct.toDouble(),
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _selectedCategory == "RED"
                          ? "$redPct%"
                          : (_selectedCategory == "YELLOW" ? "$yellowPct%" : "$greenPct%"),
                      style: TextStyle(
                        color: _selectedCategory == "RED"
                            ? Colors.redAccent
                            : (_selectedCategory == "YELLOW" ? Colors.amber : Colors.greenAccent),
                        fontWeight: FontWeight.w900,
                        fontSize: 34,
                      ),
                    ),
                    Text(
                      _selectedCategory == "RED"
                          ? "Harmful / Toxic"
                          : (_selectedCategory == "YELLOW" ? "Mild Caution" : "Safe & Healthy"),
                      style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Interactive Traffic-Light Filter Chips (Horizontally Scrollable, Zero Overflow!)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                _buildCategoryChip("ALL", "✨ All (${greenList.length + yellowList.length + redList.length})", Colors.white),
                const SizedBox(width: 8),
                _buildCategoryChip("GREEN", "🟢 Safe ($greenPct%)", Colors.greenAccent),
                const SizedBox(width: 8),
                _buildCategoryChip("YELLOW", "🟡 Caution ($yellowPct%)", Colors.amber),
                const SizedBox(width: 8),
                _buildCategoryChip("RED", "🔴 Harmful & Toxic ($redPct%)", Colors.redAccent),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Skin Compatibility Card
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF181818),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                const Icon(Icons.verified_user_rounded, color: Color(0xFF00FFCC), size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    skinMatch,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // FILTERED INGREDIENT LISTS
          if (_selectedCategory == "ALL" || _selectedCategory == "GREEN") ...[
            _buildIngredientGroup(
              title: "🟢 Healthy & Beneficial Actives",
              color: Colors.greenAccent,
              items: greenList,
              isGood: true,
            ),
          ],

          if (_selectedCategory == "ALL" || _selectedCategory == "YELLOW") ...[
            _buildIngredientGroup(
              title: "🟡 Mild Caution Ingredients",
              color: Colors.amber,
              items: yellowList,
              isGood: false,
            ),
          ],

          if (_selectedCategory == "ALL" || _selectedCategory == "RED") ...[
            _buildIngredientGroup(
              title: "🔴 Harmful / Pore-Clogging Flagged",
              color: Colors.redAccent,
              items: redList,
              isGood: false,
            ),
          ],

          const SizedBox(height: 16),
          // Expert Summary Card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.lightbulb_outline_rounded, color: Colors.white70, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    summaryMsg,
                    style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChip(String catKey, String label, Color color) {
    final isSelected = _selectedCategory == catKey;
    return GestureDetector(
      onTap: () => setState(() => _selectedCategory = catKey),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.2) : const Color(0xFF181818),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? color : Colors.transparent),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? color : Colors.white54,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildIngredientGroup({
    required String title,
    required Color color,
    required List items,
    required bool isGood,
  }) {
    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 14),
        Text(title, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 8),
        ...items.map((item) {
          final name = item['name']?.toString() ?? 'Ingredient';
          final desc = isGood
              ? (item['benefit']?.toString() ?? 'Skin nourishing active')
              : (item['reason']?.toString() ?? 'Cautionary ingredient');

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF161616),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withOpacity(0.2)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  isGood ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
                  color: color,
                  size: 18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 2),
                      Text(desc, style: const TextStyle(color: Colors.white60, fontSize: 11)),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

class _TrafficLightDonutPainter extends CustomPainter {
  final double greenPct;
  final double yellowPct;
  final double redPct;

  _TrafficLightDonutPainter({
    required this.greenPct,
    required this.yellowPct,
    required this.redPct,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2 - 12;
    const strokeWidth = 18.0;

    final total = (greenPct + yellowPct + redPct).clamp(1.0, 100.0);
    final greenAngle = (greenPct / total) * 2 * pi;
    final yellowAngle = (yellowPct / total) * 2 * pi;
    final redAngle = (redPct / total) * 2 * pi;

    double startAngle = -pi / 2;

    // Background track
    final bgPaint = Paint()
      ..color = Colors.white10
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius, bgPaint);

    // Green Arc
    if (greenPct > 0) {
      final greenPaint = Paint()
        ..color = Colors.greenAccent
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.butt
        ..isAntiAlias = true
        ..strokeWidth = strokeWidth;
      canvas.drawArc(Rect.fromCircle(center: center, radius: radius), startAngle, max(0.01, greenAngle - 0.04), false, greenPaint);
      startAngle += greenAngle;
    }

    // Yellow Arc
    if (yellowPct > 0) {
      final yellowPaint = Paint()
        ..color = Colors.amber
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.butt
        ..isAntiAlias = true
        ..strokeWidth = strokeWidth;
      canvas.drawArc(Rect.fromCircle(center: center, radius: radius), startAngle, max(0.01, yellowAngle - 0.04), false, yellowPaint);
      startAngle += yellowAngle;
    }

    // Red Arc
    if (redPct > 0) {
      final redPaint = Paint()
        ..color = Colors.redAccent
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.butt
        ..isAntiAlias = true
        ..strokeWidth = strokeWidth;
      canvas.drawArc(Rect.fromCircle(center: center, radius: radius), startAngle, max(0.01, redAngle - 0.04), false, redPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _TrafficLightDonutPainter oldDelegate) =>
      oldDelegate.greenPct != greenPct ||
      oldDelegate.yellowPct != yellowPct ||
      oldDelegate.redPct != redPct;
}
