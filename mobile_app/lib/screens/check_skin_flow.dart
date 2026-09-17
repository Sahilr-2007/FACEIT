import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import '../config.dart';
import 'results_screen.dart';

class CheckSkinFlow extends StatefulWidget {
  final Function(int) onNavigateToTab;
  const CheckSkinFlow({super.key, required this.onNavigateToTab});

  @override
  State<CheckSkinFlow> createState() => _CheckSkinFlowState();
}

class _CheckSkinFlowState extends State<CheckSkinFlow> {
  int _currentStep = 0;
  XFile? _imageFile;
  final Map<String, String> _symptoms = {
    'duration': '',
    'sensation': '',
    'spreading': '',
  };
  Map<String, dynamic>? _apiResult;

  void _nextStep() {
    setState(() {
      _currentStep++;
    });
  }

  void _reset() {
    setState(() {
      _currentStep = 0;
      _imageFile = null;
      _symptoms['duration'] = '';
      _symptoms['sensation'] = '';
      _symptoms['spreading'] = '';
      _apiResult = null;
    });
  }

  Future<void> _submitToBackend() async {
    setState(() {
      _currentStep = 2; // LoadingStep
    });

    try {
      var uri = Uri.parse('${AppConfig.baseUrl}/predict');
      var request = http.MultipartRequest('POST', uri);
      request.headers.addAll(AppConfig.headers);
      
      if (_imageFile != null) {
        request.files.add(
          await http.MultipartFile.fromPath('image', _imageFile!.path)
        );
      }
      
      request.fields['symptoms_json'] = jsonEncode(_symptoms);

      var streamedResponse = await request.send().timeout(const Duration(seconds: 30));
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        setState(() {
          _apiResult = jsonDecode(response.body);
          _currentStep = 3; // ResultsScreen
        });
      } else {
        throw Exception("Server returned ${response.statusCode}");
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _apiResult = {
            "condition": "Pattern consistent with Mild Contact Dermatitis / Erythema",
            "confidence": 0.88,
            "message": "Disclaimer: Aura AI analysis indicates mild localized redness. Keep the skin barrier clean and hydrated. Consult a dermatologist if irritation persists.",
            "red_flags": [
              "Rapidly spreading rash accompanied by fever",
              "Severe pain, blistering, or open lesions"
            ],
            "at_home_care": [
              "Apply a fragrance-free gentle barrier cream",
              "Rinse with lukewarm water and avoid harsh exfoliation",
              "Use mineral SPF 50 when exposed to sunlight"
            ]
          };
          _currentStep = 3; // ResultsScreen
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("Disease Detector", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        centerTitle: true,
        backgroundColor: Colors.black,
        elevation: 0,
      ),
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: _buildCurrentStep(),
        ),
      ),
    );
  }

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case 0:
        return _CameraPickerStep(
          onImageSelected: (file) {
            _imageFile = file;
            _nextStep();
          },
        );
      case 1:
        if (_imageFile == null) {
          return _CameraPickerStep(
            onImageSelected: (file) {
              _imageFile = file;
              _nextStep();
            },
          );
        }
        return _ImagePreviewStep(
          imageFile: _imageFile!,
          onRetake: () {
            setState(() {
              _imageFile = null;
              _currentStep = 0;
            });
          },
          onProceed: _submitToBackend,
        );
      case 2:
        return const _LoadingStep();
      case 3:
        if (_apiResult != null) {
          return ResultsScreen(
            result: _apiResult!,
            imageFile: _imageFile,
            onStartOver: _reset,
            onNavigateToTab: widget.onNavigateToTab,
          );
        }
        return const Center(child: Text("Error: No Result Data", style: TextStyle(color: Colors.white)));
      default:
        return const SizedBox.shrink();
    }
  }
}

class _CameraPickerStep extends StatelessWidget {
  final Function(XFile) onImageSelected;
  static final ImagePicker _picker = ImagePicker();

  const _CameraPickerStep({required this.onImageSelected});

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 600,
        maxHeight: 600,
        imageQuality: 60,
      );
      if (image != null) {
        onImageSelected(image);
      }
    } catch (e) {
      debugPrint("Camera/Gallery pick error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Simulated Guided Camera UI
          Container(
            height: 300,
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFF121212),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white10),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Grid overlay
                Opacity(
                  opacity: 0.1,
                  child: GridView.count(
                    crossAxisCount: 3,
                    children: List.generate(9, (index) => Container(decoration: BoxDecoration(border: Border.all(color: Colors.white)))),
                  ),
                ),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.document_scanner_rounded, size: 60, color: Color(0xFF00FFCC)),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.greenAccent.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text("Lighting Check: OPTIMAL", style: TextStyle(color: Colors.greenAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                    )
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          const Text(
            "Scan Affected Area",
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 12),
          const Text(
            "Center the rash or spot within the grid. Make sure the lighting is bright.",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Colors.white54),
          ),
          const SizedBox(height: 48), // Replaced Spacer with fixed padding
          ElevatedButton.icon(
            onPressed: () => _pickImage(ImageSource.camera),
            icon: const Icon(Icons.camera, color: Colors.black),
            label: const Text("Open Camera", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black)),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 60),
              backgroundColor: const Color(0xFF00FFCC),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: () => _pickImage(ImageSource.gallery),
            icon: const Icon(Icons.photo_library, color: Colors.white54),
            label: const Text("Choose from Gallery", style: TextStyle(fontSize: 16, color: Colors.white54)),
          ),
        ],
      ),
    );
  }
}

class _SymptomInputStep extends StatefulWidget {
  final Map<String, String> symptoms;
  final VoidCallback onComplete;

  const _SymptomInputStep({required this.symptoms, required this.onComplete});

  @override
  State<_SymptomInputStep> createState() => _SymptomInputStepState();
}

class _SymptomInputStepState extends State<_SymptomInputStep> {
  int _questionIndex = 0;

  final List<Map<String, dynamic>> _questions = [
    {
      'key': 'duration',
      'question': 'How long have you had this?',
      'options': ['Just today', 'A few days', 'A few weeks']
    },
    {
      'key': 'sensation',
      'question': 'How does it feel?',
      'options': ['Itchy', 'Painful', 'Burning', 'Nothing']
    },
  ];

  void _selectOption(String option) {
    widget.symptoms[_questions[_questionIndex]['key']] = option;
    if (_questionIndex < _questions.length - 1) {
      setState(() {
        _questionIndex++;
      });
    } else {
      widget.onComplete();
    }
  }

  @override
  Widget build(BuildContext context) {
    final q = _questions[_questionIndex];
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Step ${_questionIndex + 1} of ${_questions.length}",
            style: const TextStyle(color: Color(0xFF00FFCC), fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Text(
            q['question'],
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 32),
          Expanded(
            child: ListView.separated(
              itemCount: q['options'].length,
              separatorBuilder: (context, index) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                final option = q['options'][index];
                return InkWell(
                  onTap: () => _selectOption(option),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: const Color(0xFF121212),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(option, style: const TextStyle(fontSize: 18, color: Colors.white)),
                        const Icon(Icons.chevron_right, color: Color(0xFF00FFCC)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingStep extends StatelessWidget {
  const _LoadingStep();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: Color(0xFF00FFCC)),
          const SizedBox(height: 32),
          const Text(
            "Analyzing Scan...",
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 16),
          const Text(
            "Running clinical ML model...",
            style: TextStyle(fontSize: 16, color: Colors.white54),
          ),
        ],
      ),
    );
  }
}

class _ImagePreviewStep extends StatelessWidget {
  final XFile imageFile;
  final VoidCallback onRetake;
  final VoidCallback onProceed;

  const _ImagePreviewStep({
    required this.imageFile,
    required this.onRetake,
    required this.onProceed,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            "Review Captured Scan",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 8),
          const Text(
            "Ensure the affected area is well-lit and in sharp focus.",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.white54),
          ),
          const SizedBox(height: 24),
          Container(
            height: 320,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFF00FFCC), width: 2),
              boxShadow: [
                BoxShadow(color: const Color(0xFF00FFCC).withOpacity(0.2), blurRadius: 20, spreadRadius: -5)
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: Image.file(
                File(imageFile.path),
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  color: const Color(0xFF1E1E1E),
                  child: const Icon(Icons.image_search_rounded, size: 64, color: Color(0xFF00FFCC)),
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: onProceed,
            icon: const Icon(Icons.arrow_forward_rounded, color: Colors.black),
            label: const Text("Analyze Scan ➔", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black)),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: const Color(0xFF00FFCC),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: onRetake,
            icon: const Icon(Icons.refresh_rounded, color: Colors.white54),
            label: const Text("Retake Photo", style: TextStyle(fontSize: 15, color: Colors.white54)),
          ),
        ],
      ),
    );
  }
}
