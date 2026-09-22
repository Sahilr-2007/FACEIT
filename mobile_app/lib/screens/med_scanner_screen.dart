import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';

import '../config.dart';

class MedScannerScreen extends StatefulWidget {
  final String? initialQuery;

  const MedScannerScreen({super.key, this.initialQuery});

  @override
  State<MedScannerScreen> createState() => _MedScannerScreenState();
}

class _MedScannerScreenState extends State<MedScannerScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  bool _isLoading = false;
  File? _pickedImage;
  Map<String, dynamic>? _scanResult;
  List<Map<String, dynamic>> _quickSalts = [];
  List<Map<String, dynamic>> _history = [];

  @override
  void initState() {
    super.initState();
    _loadPopularSalts();
    if (widget.initialQuery != null && widget.initialQuery!.trim().isNotEmpty) {
      _searchController.text = widget.initialQuery!.trim();
      _executeSearch(widget.initialQuery!.trim());
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadPopularSalts() async {
    try {
      final res = await http.get(
        Uri.parse('${AppConfig.baseUrl}/med-scanner/popular-salts'),
        headers: AppConfig.headers,
      ).timeout(const Duration(seconds: 8));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['salts'] != null && mounted) {
          setState(() {
            _quickSalts = List<Map<String, dynamic>>.from(data['salts']);
          });
        }
      }
    } catch (_) {
      // Offline fallback chips
      if (mounted) {
        setState(() {
          _quickSalts = [
            {"name": "Clindamycin 1%", "salt": "Clindamycin Phosphate 1% + Nicotinamide 4%"},
            {"name": "Tretinoin 0.04%", "salt": "Tretinoin Microsphere 0.04% / 0.025%"},
            {"name": "Adapalene + BPO", "salt": "Adapalene 0.1% + Benzoyl Peroxide 2.5%"},
            {"name": "Salicylic Acid 2%", "salt": "Salicylic Acid 2% Ointment / Face Wash"},
            {"name": "Azelaic Acid 10%", "salt": "Azelaic Acid 10% / 20%"},
            {"name": "Ketoconazole 2%", "salt": "Ketoconazole 2% Topical"},
            {"name": "Minoxidil 5%", "salt": "Minoxidil 5% Topical Solution"},
            {"name": "Ceramide Barrier", "salt": "Ceramide III + Hyaluronic Acid + Niacinamide Barrier Moisturizer"}
          ];
        });
      }
    }
  }

  Future<void> _pickAndScanImage(ImageSource source) async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1200,
      );

      if (picked == null) return;

      setState(() {
        _pickedImage = File(picked.path);
        _isLoading = true;
        _scanResult = null;
      });

      var request = http.MultipartRequest(
        'POST',
        Uri.parse('${AppConfig.baseUrl}/med-scanner/scan'),
      );
      request.headers.addAll(AppConfig.headers);

      request.files.add(
        await http.MultipartFile.fromPath('image', picked.path),
      );

      if (_searchController.text.trim().isNotEmpty) {
        request.fields['query'] = _searchController.text.trim();
      }

      final streamedResponse = await request.send().timeout(const Duration(seconds: 40));
      final res = await http.Response.fromStream(streamedResponse);

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (mounted) {
          setState(() {
            _scanResult = data;
            _isLoading = false;
          });
        }
      } else {
        _handleScanError("Could not extract medicine details. Try searching by name.");
      }
    } catch (e) {
      _handleScanError("Network connection error. Showing offline price database.");
      _executeSearch(_searchController.text.isNotEmpty ? _searchController.text : "Tretinoin");
    }
  }

  Future<void> _executeSearch(String query) async {
    final cleanQ = query.trim();
    if (cleanQ.isEmpty) return;

    setState(() {
      _isLoading = true;
      _scanResult = null;
    });

    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('${AppConfig.baseUrl}/med-scanner/scan'),
      );
      request.headers.addAll(AppConfig.headers);
      request.fields['query'] = cleanQ;

      final streamedResponse = await request.send().timeout(const Duration(seconds: 25));
      final res = await http.Response.fromStream(streamedResponse);

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (mounted) {
          setState(() {
            _scanResult = data;
            _isLoading = false;
          });
        }
      } else {
        _handleScanError("Medicine not found in catalog. Try searching the active chemical salt.");
      }
    } catch (e) {
      _handleScanError("Connection issue. Please verify backend server.");
    }
  }

  void _handleScanError(String message) {
    if (!mounted) return;
    setState(() => _isLoading = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent.shade700,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _showHistorySheet() async {
    try {
      final res = await http.get(
        Uri.parse('${AppConfig.baseUrl}/med-scanner/history'),
        headers: AppConfig.headers,
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        _history = List<Map<String, dynamic>>.from(data['history'] ?? []);
      }
    } catch (_) {}

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF121212),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(20),
          height: MediaQuery.of(ctx).size.height * 0.65,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Recent Rx & Med Scans",
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70),
                    onPressed: () => Navigator.pop(ctx),
                  )
                ],
              ),
              const SizedBox(height: 12),
              if (_history.isEmpty)
                const Expanded(
                  child: Center(
                    child: Text(
                      "No previous scans saved yet.\nScan a prescription or search a salt!",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white54, fontSize: 13),
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView.separated(
                    itemCount: _history.length,
                    separatorBuilder: (ctx, idx) => const Divider(color: Colors.white12),
                    itemBuilder: (context, i) {
                      final h = _history[i];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF00FFCC).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.medication_rounded, color: Color(0xFF00FFCC), size: 22),
                        ),
                        title: Text(
                          h['brand_name'] ?? h['salt_name'] ?? 'Medication',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                        subtitle: Text(
                          "${h['salt_name']} • Save ${h['savings_percent'] ?? 0}%",
                          style: const TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                        trailing: Text(
                          "₹${h['jan_aushadhi_price'] ?? 0}",
                          style: const TextStyle(color: Color(0xFF00FFCC), fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        onTap: () {
                          Navigator.pop(ctx);
                          _searchController.text = h['salt_name'] ?? h['brand_name'] ?? '';
                          _executeSearch(_searchController.text);
                        },
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  void _shareSavings(Map<String, dynamic> result) {
    final drug = result['detected_drug'] ?? {};
    final ja = result['jan_aushadhi'] ?? {};
    final brand = drug['brand_name'] ?? 'Prescribed Medicine';
    final salt = drug['salt_name'] ?? '';
    final brandMrp = drug['branded_mrp'] ?? 0;
    final govPrice = ja['gov_price'] ?? 0;
    final savings = ja['savings_inr'] ?? (brandMrp - govPrice);
    final pct = ja['savings_percent'] ?? 80;

    final text = """
FaceIT Med Scanner - Generic & Lowest Price Comparison:
Medicine / Salt: $brand ($salt)
Branded MRP: ₹$brandMrp
Jan Aushadhi (PMBJP Subsidized): ₹$govPrice
Maximum Savings: ₹$savings ($pct% Lower)

Quality Standard: WHO-GMP & Indian Pharmacopoeia (IP).
Find Nearest Jan Aushadhi Kendra: https://janaushadhi.gov.in
Shared via FaceIT - Facial & Dermatological Health
""";
    Share.share(text.trim());
  }

  void _showLocatorDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161618),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Icon(Icons.location_on_rounded, color: Color(0xFF00FFCC), size: 22),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                "Jan Aushadhi Kendra Locator",
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Over 10,000+ Government Jan Aushadhi Kendras operate across India, dispensing certified bio-equivalent formulations at government-subsidized rates.",
              style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.04),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF00FFCC).withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text("Official PMBJP Portal:", style: TextStyle(color: Colors.white54, fontSize: 11)),
                  SizedBox(height: 4),
                  Text("https://janaushadhi.gov.in", style: TextStyle(color: Color(0xFF00FFCC), fontSize: 13, fontWeight: FontWeight.bold)),
                  SizedBox(height: 8),
                  Text("Tip: Search 'Jan Aushadhi Kendra near me' on Google Maps for real-time inventory and directions.", style: TextStyle(color: Colors.white70, fontSize: 11)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Got it", style: TextStyle(color: Color(0xFF00FFCC), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0B),
      appBar: AppBar(
        backgroundColor: const Color(0xFF101012),
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              "Med Scanner",
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              "Price Comparison & Generic Matcher",
              style: TextStyle(color: Color(0xFF00FFCC), fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.history_rounded, color: Colors.white70),
            tooltip: "Scan History",
            onPressed: _showHistorySheet,
          ),
          if (_scanResult != null)
            IconButton(
              icon: const Icon(Icons.ios_share_rounded, color: Colors.white70),
              tooltip: "Share Report",
              onPressed: () => _shareSavings(_scanResult!),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // SEARCH BAR
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF161618),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              child: TextField(
                controller: _searchController,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                textInputAction: TextInputAction.search,
                onSubmitted: _executeSearch,
                decoration: InputDecoration(
                  hintText: "Search Brand (e.g. Supatret, Clindac) or Salt...",
                  hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                  prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF00FFCC), size: 20),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, color: Colors.white38, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {});
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // SCAN ACTION BUTTONS
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => _pickAndScanImage(ImageSource.camera),
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF161618),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFF00FFCC).withOpacity(0.25)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.document_scanner_rounded, color: Color(0xFF00FFCC), size: 18),
                          SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              "Scan Prescription",
                              style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: InkWell(
                    onTap: () => _pickAndScanImage(ImageSource.gallery),
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF161618),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white.withOpacity(0.1)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.photo_library_rounded, color: Colors.white70, size: 18),
                          SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              "Upload Box / Tube",
                              style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // POPULAR DERM SALTS CHIPS
            SizedBox(
              height: 34,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _quickSalts.length,
                separatorBuilder: (ctx, idx) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final salt = _quickSalts[i];
                  return InkWell(
                    onTap: () {
                      _searchController.text = salt['salt'] ?? salt['name'] ?? '';
                      _executeSearch(_searchController.text);
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF161618),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withOpacity(0.08)),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        salt['name'] ?? '',
                        style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w500),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 18),

            // CONTENT STATE: LOADING vs RESULTS vs INTRO BANNER
            if (_isLoading)
              _buildLoadingState()
            else if (_scanResult != null)
              _buildResultView(_scanResult!)
            else
              _buildIntroView(),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 20),
      decoration: BoxDecoration(
        color: const Color(0xFF141416),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        children: [
          if (_pickedImage != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(_pickedImage!, height: 120, width: 120, fit: BoxFit.cover),
            ),
          const SizedBox(height: 20),
          const CircularProgressIndicator(
            color: Color(0xFF00FFCC),
            strokeWidth: 3,
          ),
          const SizedBox(height: 18),
          const Text(
            "Analyzing Prescription & Formulations...",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          const Text(
            "Comparing lowest prices across Jan Aushadhi and major pharmacies...",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildResultView(Map<String, dynamic> result) {
    final drug = result['detected_drug'] ?? {};
    final ja = result['jan_aushadhi'] ?? {};
    final pharmacies = List<Map<String, dynamic>>.from(result['e_pharmacies'] ?? []);
    final guide = result['clinical_guide'] ?? {};
    final disclaimer = result['statutory_disclaimer'] ?? '';

    final brandName = drug['brand_name'] ?? 'Prescribed Medicine';
    final saltName = drug['salt_name'] ?? 'Active Pharmaceutical Ingredient';
    final form = drug['form'] ?? 'Topical Formulation';
    final category = drug['category'] ?? 'Dermatology Medicine';
    final brandedMrp = (drug['branded_mrp'] ?? 0).toDouble();

    final govPrice = (ja['gov_price'] ?? 0).toDouble();
    final savingsInr = (ja['savings_inr'] ?? (brandedMrp - govPrice)).toDouble();
    final savingsPct = (ja['savings_percent'] ?? 80).toDouble();
    final pmbjpCode = ja['pmbjp_code'] ?? 'PMBJP-GENERIC-MATCH';

    // Identify cheapest commercial pharmacy
    Map<String, dynamic>? cheapestPharmacy;
    if (pharmacies.isNotEmpty) {
      cheapestPharmacy = pharmacies.first;
    }

    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    if (isLandscape) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDetectedMedicineHeader(brandName, saltName, category, form, brandedMrp),
          const SizedBox(height: 16),
          // Side-by-side layout: Jan Aushadhi on left, Comparison on right (both spacious)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 5,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildJanAushadhiCard(ja, saltName, govPrice, brandedMrp, savingsPct, savingsInr, pmbjpCode),
                    if (guide['clinical_action'] != null) ...[
                      const SizedBox(height: 16),
                      _buildClinicalGuide(guide),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 5,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (cheapestPharmacy != null) ...[
                      _buildBrandedSpotlight(cheapestPharmacy),
                      const SizedBox(height: 16),
                    ],
                    _buildPharmaciesList(pharmacies),
                    const SizedBox(height: 16),
                    _buildDisclaimer(disclaimer),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
        ],
      );
    }

    // Portrait view
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildDetectedMedicineHeader(brandName, saltName, category, form, brandedMrp),
        const SizedBox(height: 16),
        _buildJanAushadhiCard(ja, saltName, govPrice, brandedMrp, savingsPct, savingsInr, pmbjpCode),
        const SizedBox(height: 18),
        if (cheapestPharmacy != null) ...[
          _buildBrandedSpotlight(cheapestPharmacy),
          const SizedBox(height: 18),
        ],
        _buildPharmaciesList(pharmacies),
        const SizedBox(height: 20),
        if (guide['clinical_action'] != null) ...[
          _buildClinicalGuide(guide),
          const SizedBox(height: 20),
        ],
        _buildDisclaimer(disclaimer),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildDetectedMedicineHeader(String brandName, String saltName, String category, String form, double brandedMrp) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF141416),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF00FFCC).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.medication_outlined, color: Color(0xFF00FFCC), size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      brandName,
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      saltName,
                      style: const TextStyle(color: Color(0xFF00FFCC), fontSize: 13, fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        "$category • $form",
                        style: const TextStyle(color: Colors.white70, fontSize: 11),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(color: Colors.white10),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Standard Branded MRP:", style: TextStyle(color: Colors.white54, fontSize: 12)),
              Text("₹${brandedMrp.toStringAsFixed(0)}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildJanAushadhiCard(
    Map<String, dynamic> ja,
    String saltName,
    double govPrice,
    double brandedMrp,
    double savingsPct,
    double savingsInr,
    String pmbjpCode,
  ) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF131A15),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF10B981).withOpacity(0.5), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withOpacity(0.12),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(17)),
            ),
            child: Row(
              children: [
                const Icon(Icons.savings_outlined, color: Color(0xFF10B981), size: 16),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    "CHEAPEST OPTION: JAN AUSHADHI (PMBJP)",
                    style: TextStyle(color: Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.5),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    pmbjpCode,
                    style: const TextStyle(color: Color(0xFF34D399), fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ja['item_name'] ?? "$saltName Generic Formulation",
                  style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                const Text(
                  "WHO-GMP Certified • Subsidized Bio-Equivalent Salt",
                  style: TextStyle(color: Colors.white54, fontSize: 11),
                ),
                const SizedBox(height: 14),
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.end,
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("Jan Aushadhi Price", style: TextStyle(color: Colors.white54, fontSize: 11)),
                            const SizedBox(height: 2),
                            Text(
                              "₹${govPrice.toStringAsFixed(0)}",
                              style: const TextStyle(
                                color: Color(0xFF00FFCC),
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("Branded MRP", style: TextStyle(color: Colors.white38, fontSize: 11)),
                            const SizedBox(height: 2),
                            Text(
                              "₹${brandedMrp.toStringAsFixed(0)}",
                              style: const TextStyle(
                                color: Colors.white38,
                                fontSize: 16,
                                decoration: TextDecoration.lineThrough,
                                decorationColor: Colors.redAccent,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF10B981).withOpacity(0.4)),
                      ),
                      child: Text(
                        "Save ${savingsPct.toStringAsFixed(0)}% (₹${savingsInr.toStringAsFixed(0)})",
                        style: const TextStyle(color: Color(0xFF34D399), fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _showLocatorDialog,
                    icon: const Icon(Icons.location_on_outlined, size: 16),
                    label: const Text("Locate Nearest Jan Aushadhi Kendra"),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF00FFCC),
                      side: BorderSide(color: const Color(0xFF00FFCC).withOpacity(0.4)),
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBrandedSpotlight(Map<String, dynamic> cheapestPharmacy) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF181613),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.4)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B).withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.local_shipping_outlined, color: Color(0xFFF59E0B), size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Flexible(
                      child: Text(
                        "Lowest Online Branded Rate",
                        style: TextStyle(color: Color(0xFFF59E0B), fontSize: 11, fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      "₹${cheapestPharmacy['price'] ?? 0}",
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  "${cheapestPharmacy['name']} (${cheapestPharmacy['discount'] ?? ''}) • ${cheapestPharmacy['delivery'] ?? ''}",
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                const Text(
                  "Prefer branded or out of stock at Kendra? Available here.",
                  style: TextStyle(color: Colors.white38, fontSize: 10),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPharmaciesList(List<Map<String, dynamic>> pharmacies) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: const [
            Flexible(
              child: Text(
                "All Online Pharmacy Rates",
                style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              "Sorted by lowest price",
              style: TextStyle(color: Colors.white38, fontSize: 11),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: pharmacies.length,
          separatorBuilder: (ctx, i) => const SizedBox(height: 8),
          itemBuilder: (context, idx) {
            final p = pharmacies[idx];
            final isCheapest = idx == 0;
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: isCheapest ? const Color(0xFF181A1B) : const Color(0xFF141416),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isCheapest ? const Color(0xFF00FFCC).withOpacity(0.3) : Colors.white.withOpacity(0.06),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                p['name'] ?? '',
                                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isCheapest) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF00FFCC).withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  "LOWEST ONLINE",
                                  style: TextStyle(color: Color(0xFF00FFCC), fontSize: 9, fontWeight: FontWeight.w800),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          "${p['delivery'] ?? 'Standard delivery'} • ${p['discount'] ?? 'Best offer'}",
                          style: const TextStyle(color: Colors.white54, fontSize: 11),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    "₹${p['price'] ?? 0}",
                    style: TextStyle(
                      color: isCheapest ? const Color(0xFF00FFCC) : Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildClinicalGuide(Map<String, dynamic> guide) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF141416),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.science_outlined, color: Color(0xFF00FFCC), size: 18),
              SizedBox(width: 8),
              Flexible(
                child: Text(
                  "Active Salt Mechanism & Clinical Action",
                  style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            guide['clinical_action'] ?? '',
            style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
          ),
          if (guide['usage_guide'] != null) ...[
            const SizedBox(height: 12),
            const Divider(color: Colors.white10),
            const SizedBox(height: 8),
            Row(
              children: const [
                Icon(Icons.check_circle_outline_rounded, color: Color(0xFF10B981), size: 16),
                SizedBox(width: 6),
                Text("Recommended Usage:", style: TextStyle(color: Color(0xFF10B981), fontSize: 12, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              guide['usage_guide'] ?? '',
              style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDisclaimer(String disclaimer) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1414),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.redAccent.withOpacity(0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded, color: Colors.redAccent, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Prescription & Regulatory Notice",
                  style: TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  disclaimer.isNotEmpty
                      ? disclaimer
                      : "Prescription required for Schedule H medications. Always verify generic salt equivalency with your registered physician or pharmacist.",
                  style: const TextStyle(color: Colors.white70, fontSize: 11, height: 1.3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIntroView() {
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    if (isLandscape) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 5,
                child: _buildIntroBanner(),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 5,
                child: _buildHowItWorks(),
              ),
            ],
          ),
          const SizedBox(height: 28),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildIntroBanner(),
        const SizedBox(height: 20),
        _buildHowItWorks(),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildIntroBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF141416),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.savings_outlined, color: Color(0xFF00FFCC), size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  "Transparent Dermatology Medicine Pricing",
                  style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            "Compare costs across Government Jan Aushadhi (PMBJP) centers and verified e-pharmacies. Find the cheapest generic or branded option for your exact prescribed salt.",
            style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _buildComparisonStat("Supatret 0.04%", "Branded: ₹380", "Jan Aushadhi: ₹45", "Save 88%"),
              const SizedBox(width: 8),
              _buildComparisonStat("Clindac-A Gel", "Branded: ₹260", "Jan Aushadhi: ₹35", "Save 86%"),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHowItWorks() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "How Med Scanner Works",
          style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        _buildStepTile(
          icon: Icons.document_scanner_outlined,
          color: const Color(0xFF00FFCC),
          step: "1",
          title: "Scan Prescription or Tube",
          subtitle: "Optical recognition extracts the medicine brand or active chemical salt.",
        ),
        const SizedBox(height: 10),
        _buildStepTile(
          icon: Icons.biotech_outlined,
          color: const Color(0xFF38BDF8),
          step: "2",
          title: "Match Active Formulation",
          subtitle: "Isolates the therapeutic molecule (e.g., Tretinoin, Clindamycin, Adapalene).",
        ),
        const SizedBox(height: 10),
        _buildStepTile(
          icon: Icons.price_check_outlined,
          color: const Color(0xFF10B981),
          step: "3",
          title: "Discover the Lowest Rate",
          subtitle: "Displays the subsidized Jan Aushadhi generic and lowest available online pharmacy price.",
        ),
      ],
    );
  }

  Widget _buildComparisonStat(String title, String before, String after, String badge) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFF18181A),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.06)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(before, style: const TextStyle(color: Colors.white38, fontSize: 9, decoration: TextDecoration.lineThrough)),
            Text(after, style: const TextStyle(color: Color(0xFF00FFCC), fontSize: 11, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withOpacity(0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(badge, style: const TextStyle(color: Color(0xFF34D399), fontSize: 8, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepTile({
    required IconData icon,
    required Color color,
    required String step,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF141416),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(color: Colors.white54, fontSize: 11, height: 1.3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
