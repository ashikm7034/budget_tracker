import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/auth_state.dart';
import '../../core/api_service.dart';
import '../../core/widgets/apple_widgets.dart';

enum QRScanStep {
  scanning,
  enteringAmount,
  assistant,
  processing,
  success,
}

class QRScannerScreen extends StatefulWidget {
  const QRScannerScreen({super.key});

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  final AuthState _authState = AuthState();
  final ApiService _apiService = ApiService();
  NumberFormat get _currencyFormat =>
      NumberFormat.currency(locale: 'en_IN', symbol: _authState.currency, decimalDigits: 0);

  final MobileScannerController _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
    autoStart: false,
  );

  late AnimationController _animController;
  bool _isLoading = true;
  bool _hasScanned = false;
  Map<String, dynamic> _dashboardData = {};

  final List<Map<String, dynamic>> _mockQrs = [
    {'title': '🍔 Burger at Cafeteria', 'amount': 120.0, 'category': 'Food', 'classification': 'Want', 'vpa': 'cafeteria@upi'},
    {'title': '☕ Hot Tea & Samosa', 'amount': 45.0, 'category': 'Tea', 'classification': 'Want', 'vpa': 'teavendor@upi'},
    {'title': '🚌 Travel Monthly Pass', 'amount': 850.0, 'category': 'Travel', 'classification': 'Need', 'vpa': 'transit@upi'},
    {'title': '🤖 EMO Robot Purchase', 'amount': 25000.0, 'category': 'Shopping', 'classification': 'Want', 'vpa': 'robotics@upi'},
  ];

  final List<String> _categories = [
    'Food',
    'Tea',
    'Snacks',
    'Travel',
    'College',
    'Recharge',
    'Shopping',
    'Subscription',
    'Other'
  ];

  QRScanStep _currentStep = QRScanStep.scanning;
  String _payeeName = 'UPI Merchant';
  String _payeeVpa = '';
  String _note = '';
  String _amountStr = '';
  String _category = 'Other';
  String _classification = 'Want';
  bool _isAmountFocused = true;
  final TextEditingController _customCategoryController = TextEditingController();
  final FocusNode _customCategoryFocusNode = FocusNode();
  bool _isCustomCategoryFocused = false;
  String _customCategory = '';
  bool _animateAmountUI = false;
  String _selectedPaymentMethod = 'UPI';

  String get _displayCategory {
    return (_category == 'Other' && _customCategory.trim().isNotEmpty)
        ? _customCategory.trim()
        : _category;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadData();
    _startScannerSafe();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _customCategoryFocusNode.addListener(() {
      setState(() {
        _isCustomCategoryFocused = _customCategoryFocusNode.hasFocus;
        if (_customCategoryFocusNode.hasFocus) {
          _isAmountFocused = false;
        } else {
          _isAmountFocused = true;
        }
      });
    });
  }

  Future<void> _startScannerSafe() async {
    try {
      if (!_scannerController.value.isRunning) {
        await _scannerController.start();
      }
    } catch (e) {
      debugPrint('Error starting scanner: $e');
    }
  }

  Future<void> _stopScannerSafe() async {
    try {
      if (_scannerController.value.isRunning) {
        await _scannerController.stop();
      }
    } catch (e) {
      debugPrint('Error stopping scanner: $e');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_currentStep != QRScanStep.scanning) return;

    switch (state) {
      case AppLifecycleState.resumed:
        _startScannerSafe();
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        _stopScannerSafe();
        break;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scannerController.dispose();
    _animController.dispose();
    _customCategoryController.dispose();
    _customCategoryFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final userId = _authState.userId;
      if (userId != null) {
        final data = await _apiService.request('getDashboardData', {'userId': userId});
        setState(() {
          _dashboardData = data;
          _isLoading = false;
        });
      }
    } catch (_) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _determineCategory(String text) {
    final lowerText = text.toLowerCase();
    if (lowerText.contains('tea') || lowerText.contains('coffee') || lowerText.contains('chai')) {
      return 'Tea';
    } else if (lowerText.contains('snack') || lowerText.contains('samosa') || lowerText.contains('biscuit') || lowerText.contains('lays') || lowerText.contains('kurkure')) {
      return 'Snacks';
    } else if (lowerText.contains('food') || lowerText.contains('lunch') || lowerText.contains('dinner') || lowerText.contains('breakfast') || lowerText.contains('hotel') || lowerText.contains('mess') || lowerText.contains('restaurant') || lowerText.contains('cafe')) {
      return 'Food';
    } else if (lowerText.contains('travel') || lowerText.contains('bus') || lowerText.contains('taxi') || lowerText.contains('auto') || lowerText.contains('train') || lowerText.contains('metro') || lowerText.contains('fuel') || lowerText.contains('petrol')) {
      return 'Travel';
    } else if (lowerText.contains('college') || lowerText.contains('fees') || lowerText.contains('book') || lowerText.contains('exam') || lowerText.contains('pen') || lowerText.contains('pencil')) {
      return 'College';
    } else if (lowerText.contains('recharge') || lowerText.contains('phone') || lowerText.contains('internet') || lowerText.contains('wifi') || lowerText.contains('mobile')) {
      return 'Recharge';
    } else if (lowerText.contains('shop') || lowerText.contains('dress') || lowerText.contains('cloth') || lowerText.contains('shoe') || lowerText.contains('pant') || lowerText.contains('shirt')) {
      return 'Shopping';
    } else if (lowerText.contains('sub') || lowerText.contains('netflix') || lowerText.contains('spotify') || lowerText.contains('prime') || lowerText.contains('youtube')) {
      return 'Subscription';
    }
    return 'Other';
  }

  String _determineNeedOrWant(String category, String text) {
    final lowerText = text.toLowerCase();
    if (lowerText.contains('need') || category == 'College' || category == 'Bills' || category == 'Travel') {
      return 'Need';
    }
    return 'Want';
  }

  void _handleRealScan(String rawValue) {
    if (rawValue.trim().isEmpty) {
      setState(() {
        _hasScanned = false;
      });
      return;
    }

    if (rawValue.startsWith('upi://pay')) {
      try {
        final uri = Uri.parse(rawValue);
        final params = uri.queryParameters;
        
        final String payeeName = Uri.decodeComponent(params['pn'] ?? 'UPI Merchant');
        final String payeeVpa = params['pa'] ?? '';
        final String note = Uri.decodeComponent(params['tn'] ?? 'UPI Payment');
        final String? amtStr = params['am'];
        final double amount = amtStr != null ? (double.tryParse(amtStr) ?? 0.0) : 0.0;

        final String category = _determineCategory('$payeeName $note');
        final String classification = _determineNeedOrWant(category, '$payeeName $note');

        _onQRScanned({
          'title': payeeName,
          'vpa': payeeVpa,
          'amount': amount,
          'category': category,
          'classification': classification,
          'note': note,
        });
      } catch (e) {
        _handleTextQRScan(rawValue);
      }
    } else {
      _handleTextQRScan(rawValue);
    }
  }

  void _handleTextQRScan(String text) {
    final numRegex = RegExp(r'\b\d+\b');
    final match = numRegex.firstMatch(text);
    double amount = 0.0;
    if (match != null) {
      amount = double.tryParse(match.group(0)!) ?? 0.0;
    }

    final category = _determineCategory(text);
    final classification = _determineNeedOrWant(category, text);
    
    String cleanNote = text
        .replaceAll(match?.group(0) ?? '', '')
        .replaceAll(RegExp(r'\b(need|want|spent|add|logged|expense|for|on|rs|inr|₹|spent)\b', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    if (cleanNote.isEmpty) {
      cleanNote = category;
    }

    _onQRScanned({
      'title': cleanNote,
      'amount': amount,
      'category': category,
      'classification': classification,
      'note': cleanNote,
    });
  }

  void _onQRScanned(Map<String, dynamic> qr) {
    _scannerController.stop();
    setState(() {
      _payeeName = qr['title'] ?? 'UPI Merchant';
      _payeeVpa = qr['vpa'] ?? '';
      final double amt = qr['amount'] ?? 0.0;
      _amountStr = amt > 0 ? amt.toStringAsFixed(0) : '';
      
      final String scannedCat = qr['category'] ?? 'Other';
      if (_categories.contains(scannedCat)) {
        _category = scannedCat;
        _note = scannedCat;
        _customCategory = '';
        _customCategoryController.text = '';
      } else {
        _category = 'Other';
        _customCategory = scannedCat;
        _customCategoryController.text = scannedCat;
        _note = scannedCat;
      }
      _classification = qr['classification'] ?? 'Want';
      _currentStep = QRScanStep.enteringAmount;
      _isAmountFocused = true;
    });
  }

  void _showMockQRPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C1C1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 5,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2C2C2E),
                      borderRadius: BorderRadius.circular(2.5),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  color: const Color(0xFF0A84FF).withOpacity(0.12),
                  margin: const EdgeInsets.symmetric(vertical: 4.0),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: const Color(0xFF0A84FF).withOpacity(0.3), width: 1),
                  ),
                  child: ListTile(
                    leading: const Icon(Icons.photo_library_rounded, color: Color(0xFF0A84FF)),
                    title: Text(
                      'Choose from Gallery',
                      style: GoogleFonts.outfit(
                        color: const Color(0xFF0A84FF),
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    trailing: const Icon(Icons.chevron_right, color: Color(0xFF0A84FF)),
                    onTap: () {
                      Navigator.of(context).pop();
                      _pickAndScanGalleryImage();
                    },
                  ),
                ),
                const SizedBox(height: 12),
                const Divider(color: Color(0xFF2C2C2E), height: 1),
                const SizedBox(height: 12),
                Text(
                  'SIMULATED UPI QR CODES',
                  style: GoogleFonts.outfit(
                    color: const Color(0xFF8E8E93),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 10),
                ...List.generate(_mockQrs.length, (index) {
                  final qr = _mockQrs[index];
                  return Card(
                    color: const Color(0xFF2C2C2E),
                    margin: const EdgeInsets.symmetric(vertical: 6.0),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: ListTile(
                      leading: const Icon(Icons.qr_code, color: Color(0xFF0A84FF)),
                      title: Text(
                        qr['title'],
                        style: GoogleFonts.outfit(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                      trailing: Text(
                        _currencyFormat.format(qr['amount']),
                        style: GoogleFonts.outfit(color: const Color(0xFF30D158), fontWeight: FontWeight.bold),
                      ),
                      onTap: () {
                        Navigator.of(context).pop();
                        _onQRScanned(qr);
                      },
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickAndScanGalleryImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);
      
      if (image == null) return;
      
      setState(() {
        _isLoading = true;
      });

      final BarcodeCapture? barcode = await _scannerController.analyzeImage(image.path);
      
      setState(() {
        _isLoading = false;
      });

      if (barcode != null && barcode.barcodes.isNotEmpty) {
        final String? code = barcode.barcodes.first.rawValue;
        if (code != null && code.isNotEmpty) {
          _handleRealScan(code);
        } else {
          _showErrorSnackBar('Unable to read QR code data from selected image.');
        }
      } else {
        _showErrorSnackBar('No valid QR code or barcode found in the selected image.');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showErrorSnackBar('Failed to scan image: $e');
    }
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.outfit(color: Colors.white)),
        backgroundColor: const Color(0xFFFF453A),
        duration: const Duration(seconds: 4),
      ),
    );
  }



  Widget _buildStepBody() {
    switch (_currentStep) {
      case QRScanStep.scanning:
        return _buildScanningBody();
      case QRScanStep.enteringAmount:
        return _buildEnteringAmountBody();
      case QRScanStep.assistant:
        return _buildAssistantBody();
      case QRScanStep.processing:
        return _buildProcessingBody();
      case QRScanStep.success:
        return _buildSuccessBody();
    }
  }

  Widget _buildScanningBody() {
    return Stack(
      alignment: Alignment.center,
      children: [
        Positioned.fill(
          child: MobileScanner(
            controller: _scannerController,
            onDetect: (capture) {
              if (_hasScanned) return;
              final List<Barcode> barcodes = capture.barcodes;
              for (final barcode in barcodes) {
                if (barcode.rawValue != null) {
                  setState(() {
                    _hasScanned = true;
                  });
                  _handleRealScan(barcode.rawValue!);
                  break;
                }
              }
            },
            errorBuilder: (context, error, child) {
              if (error.toString().contains('already started')) {
                return child ?? const SizedBox.shrink();
              }
              return Container(
                color: const Color(0xFF1C1C1E),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.videocam_off_rounded, color: Color(0xFF8E8E93), size: 48),
                        const SizedBox(height: 16),
                        Text(
                          'Camera Access Required',
                          style: GoogleFonts.outfit(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Please ensure camera permissions are granted and try again.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.outfit(color: const Color(0xFF8E8E93), fontSize: 13),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00D632),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(100),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            elevation: 0,
                          ),
                          onPressed: _startScannerSafe,
                          icon: const Icon(Icons.refresh_rounded, size: 18),
                          label: Text(
                            'Retry Camera',
                            style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),

        /*
        Positioned.fill(
          child: ColorFiltered(
            colorFilter: ColorFilter.mode(
              Colors.black.withValues(alpha: 0.65),
              BlendMode.srcOut,
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Colors.black,
                      backgroundBlendMode: BlendMode.dstOut,
                    ),
                  ),
                ),
                Center(
                  child: Container(
                    width: 240,
                    height: 240,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        */

        Center(
          child: Container(
            width: 240,
            height: 240,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
            ),
            child: Stack(
              children: [
                _buildCorner(Alignment.topLeft),
                _buildCorner(Alignment.topRight),
                _buildCorner(Alignment.bottomLeft),
                _buildCorner(Alignment.bottomRight),
              ],
            ),
          ),
        ),

        AnimatedBuilder(
          animation: _animController,
          builder: (context, child) {
            return Positioned(
              top: (MediaQuery.of(context).size.height - 240) / 2 + 10 + (_animController.value * 220),
              child: Container(
                width: 220,
                height: 2,
                decoration: BoxDecoration(
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0A84FF).withValues(alpha: 0.8),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                  color: const Color(0xFF0A84FF),
                ),
              ),
            );
          },
        ),

        Positioned(
          top: 40,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'Align any UPI QR inside the frame',
              style: GoogleFonts.outfit(color: const Color(0xFF8E8E93), fontSize: 13),
            ),
          ),
        ),


      ],
    );
  }

  Widget _buildEnteringAmountBody() {
    final double parsedAmt = double.tryParse(_amountStr) ?? 0.0;
    final bool canContinue = parsedAmt > 0.0;

    if (!_animateAmountUI) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _animateAmountUI = true;
          });
        }
      });
    }

    return Column(
      children: [
        // Top Scrollable Area
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
            child: Column(
              children: [
                const SizedBox(height: 12),
                // Cash App Style To: Payee Pill Badge
                AnimatedOpacity(
                  opacity: _animateAmountUI ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 400),
                  child: AnimatedSlide(
                    offset: _animateAmountUI ? Offset.zero : const Offset(0, -0.15),
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeOutCubic,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1C1C1E),
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'To: ',
                              style: GoogleFonts.outfit(
                                color: const Color(0xFF8E8E93),
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              _payeeName,
                              style: GoogleFonts.outfit(
                                color: const Color(0xFF00D632), // Cash App Green
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // Centered Amount display with individual typing animation
                AnimatedOpacity(
                  opacity: _animateAmountUI ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 500),
                  child: GestureDetector(
                    onTap: () {
                      if (_customCategoryFocusNode.hasFocus) {
                        _customCategoryFocusNode.unfocus();
                      }
                      setState(() {
                        _isAmountFocused = true;
                      });
                    },
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 48),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            '₹',
                            style: GoogleFonts.outfit(
                              color: const Color(0xFF00D632), // Cash App Green
                              fontSize: 38,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: (_amountStr.isEmpty ? ['0'] : _amountStr.split(''))
                                .asMap()
                                .entries
                                .map((entry) {
                              final idx = entry.key;
                              final char = entry.value;
                              return AnimatedSwitcher(
                                duration: const Duration(milliseconds: 180),
                                transitionBuilder: (Widget child, Animation<double> animation) {
                                  return FadeTransition(
                                    opacity: animation,
                                    child: ScaleTransition(
                                      scale: Tween<double>(begin: 0.6, end: 1.0).animate(
                                        CurvedAnimation(
                                          parent: animation,
                                          curve: Curves.easeOutBack,
                                        ),
                                      ),
                                      child: child,
                                    ),
                                  );
                                },
                                child: Text(
                                  char,
                                  key: ValueKey<String>('${idx}_$char'),
                                  style: GoogleFonts.outfit(
                                    color: _amountStr.isEmpty
                                        ? const Color(0xFF2C2C2E)
                                        : Colors.white,
                                    fontSize: 72,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(width: 4),
                          if (_isAmountFocused) const _BlinkingCursor(),
                          const SizedBox(width: 12),
                          IconButton(
                            icon: const Icon(Icons.calculate_outlined, color: Color(0xFF8E8E93), size: 28),
                            onPressed: () async {
                              final result = await showModalBottomSheet<String>(
                                context: context,
                                backgroundColor: const Color(0xFF1C1C1E),
                                shape: const RoundedRectangleBorder(
                                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                                ),
                                isScrollControlled: true,
                                builder: (context) => ExpenseCalculatorSheet(
                                  initialValue: _amountStr,
                                ),
                              );
                              if (result != null) {
                                setState(() {
                                  _amountStr = result;
                                });
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Premium Category Chips Selector
                AnimatedOpacity(
                  opacity: _animateAmountUI ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 600),
                  child: AnimatedSlide(
                    offset: _animateAmountUI ? Offset.zero : const Offset(0, 0.15),
                    duration: const Duration(milliseconds: 600),
                    curve: Curves.easeOutCubic,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(left: 4.0),
                          child: Text(
                            'SELECT CATEGORY',
                            style: GoogleFonts.outfit(
                              color: const Color(0xFF8E8E93),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          height: 38,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: _categories.length,
                            itemBuilder: (context, idx) {
                              final cat = _categories[idx];
                              final isSelected = _category == cat;
                              return Padding(
                                padding: const EdgeInsets.only(right: 8.0),
                                child: AppleBounceable(
                                  onTap: () {
                                    setState(() {
                                      _category = cat;
                                      if (cat == 'Other') {
                                        _note = _customCategory;
                                      } else {
                                        _note = cat;
                                        _customCategoryFocusNode.unfocus();
                                      }
                                      _classification = _determineNeedOrWant(_displayCategory, _note);
                                    });
                                  },
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? const Color(0xFF00D632)
                                          : const Color(0xFF1C1C1E),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: isSelected
                                            ? Colors.transparent
                                            : const Color(0xFF2C2C2E),
                                        width: 1,
                                      ),
                                    ),
                                    child: Text(
                                      cat,
                                      style: GoogleFonts.outfit(
                                        color: isSelected ? Colors.black : const Color(0xFF8E8E93),
                                        fontSize: 13,
                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Smooth Animated Custom Category field
                AnimatedSize(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOutCubic,
                  child: Container(
                    child: _category == 'Other'
                        ? Padding(
                            padding: const EdgeInsets.only(top: 16.0),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1C1C1E),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: _isCustomCategoryFocused ? const Color(0xFF00D632) : const Color(0xFF2C2C2E),
                                  width: _isCustomCategoryFocused ? 1.5 : 1,
                                ),
                              ),
                              child: TextField(
                                controller: _customCategoryController,
                                focusNode: _customCategoryFocusNode,
                                onChanged: (val) {
                                  setState(() {
                                    _customCategory = val;
                                    _note = val;
                                    _classification = _determineNeedOrWant(_displayCategory, _note);
                                  });
                                },
                                style: GoogleFonts.outfit(color: Colors.white, fontSize: 14),
                                decoration: InputDecoration(
                                  icon: const Icon(Icons.category_rounded, color: Color(0xFF00D632), size: 20),
                                  hintText: 'Enter custom category (e.g. Medicine, Rent)',
                                  hintStyle: GoogleFonts.outfit(color: const Color(0xFF8E8E93)),
                                  border: InputBorder.none,
                                ),
                              ),
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                ),
                const Divider(color: Color(0xFF2C2C2E), height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'PAYMENT METHOD',
                      style: GoogleFonts.outfit(
                        color: const Color(0xFF8E8E93),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    DropdownButton<String>(
                      value: _selectedPaymentMethod,
                      dropdownColor: const Color(0xFF1C1C1E),
                      iconEnabledColor: const Color(0xFF8E8E93),
                      underline: Container(),
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                      items: <String>['UPI', 'UPI Lite'].map<DropdownMenuItem<String>>((String val) {
                        return DropdownMenuItem<String>(
                          value: val,
                          child: Text(val),
                        );
                      }).toList(),
                      onChanged: (String? newVal) {
                        if (newVal != null) {
                          setState(() {
                            _selectedPaymentMethod = newVal;
                          });
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        // Bottom Keypad & Action Button Container
        Container(
          padding: const EdgeInsets.only(left: 24, right: 24, bottom: 24, top: 8),
          color: Colors.transparent,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Hide custom keypad when system keyboard is active or amount is not focused
              if (!_isCustomCategoryFocused && _isAmountFocused) ...[
                _buildKeypad(),
                const SizedBox(height: 16),
              ],
              SafeArea(
                child: AppleBounceable(
                  onTap: canContinue
                      ? () {
                          setState(() {
                            _currentStep = QRScanStep.assistant;
                          });
                        }
                      : () {},
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    height: 52,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: canContinue ? const Color(0xFF00D632) : const Color(0xFF1C1C1E),
                      borderRadius: BorderRadius.circular(26),
                      boxShadow: canContinue
                          ? [
                              BoxShadow(
                                color: const Color(0xFF00D632).withValues(alpha: 0.25),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              )
                            ]
                          : [],
                    ),
                    child: Text(
                      'Pay',
                      style: GoogleFonts.outfit(
                        color: canContinue ? Colors.black : const Color(0xFF8E8E93),
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildKeypad() {
    final List<String> keys = [
      '1', '2', '3',
      '4', '5', '6',
      '7', '8', '9',
      '.', '0', 'backspace'
    ];

    return Table(
      children: List.generate(4, (rowIdx) {
        return TableRow(
          children: List.generate(3, (colIdx) {
            final keyStr = keys[rowIdx * 3 + colIdx];
            return Padding(
              padding: const EdgeInsets.all(4.0),
              child: _buildKeypadButton(keyStr),
            );
          }),
        );
      }),
    );
  }

  Widget _buildKeypadButton(String keyStr) {
    final isBackspace = keyStr == 'backspace';
    
    return AppleBounceable(
      onTap: () {
        SystemSound.play(SystemSoundType.click);
        HapticFeedback.lightImpact();
        setState(() {
          if (isBackspace) {
            if (_amountStr.isNotEmpty) {
              _amountStr = _amountStr.substring(0, _amountStr.length - 1);
            }
          } else {
            if (_amountStr.length < 8) {
              if (keyStr == '.') {
                if (!_amountStr.contains('.')) {
                  _amountStr += _amountStr.isEmpty ? '0.' : '.';
                }
              } else {
                _amountStr += keyStr;
              }
            }
          }
        });
      },
      child: Container(
        height: 56,
        decoration: const BoxDecoration(
          color: Colors.transparent,
        ),
        alignment: Alignment.center,
        child: isBackspace
            ? const Icon(Icons.backspace_outlined, color: Colors.white, size: 24)
            : Text(
                keyStr,
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w400,
                ),
              ),
      ),
    );
  }

  Widget _buildAssistantBody() {
    if (_isLoading) {
      return Container(
        color: const Color(0xFF000000),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(
                color: Color(0xFF00D632),
                strokeWidth: 3,
              ),
              const SizedBox(height: 24),
              Text(
                'Analyzing budget impact...',
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Reading your dashboard state from Google Sheets',
                style: GoogleFonts.outfit(
                  color: const Color(0xFF8E8E93),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final double amount = double.tryParse(_amountStr) ?? 0.0;
    final summary = _dashboardData['summary'] ?? {};
    final double balance = (summary['currentBalance'] as num?)?.toDouble() ?? 0.0;
    final double remainingDaily = (summary['dailyBudgetRemaining'] as num?)?.toDouble() ?? 0.0;
    final goals = _dashboardData['goals'] as List? ?? [];

    final isOverDaily = amount > remainingDaily;
    final isOverBalance = amount > balance;

    String goalImpactText = "This purchase doesn't conflict with your savings targets.";
    Color impactColor = const Color(0xFF30D158);

    if (goals.isNotEmpty) {
      final primaryGoal = goals.first;
      final goalName = primaryGoal['goalName'] ?? 'Goal';
      final double target = (primaryGoal['targetAmount'] as num?)?.toDouble() ?? 0.0;
      final double current = (primaryGoal['currentAmount'] as num?)?.toDouble() ?? 0.0;
      final double diff = target - current;

      if (diff > 0) {
        final double postPurchaseBalance = balance - amount;
        if (postPurchaseBalance < diff) {
          goalImpactText = "⚠️ Warning: Spending ₹${amount.toStringAsFixed(0)} reduces your cash reserve to ₹${postPurchaseBalance.toStringAsFixed(0)}, falling short of the remaining target for your '$goalName' (₹${diff.toStringAsFixed(0)}).";
          impactColor = const Color(0xFFFF9F0A);
        } else {
          goalImpactText = "🟢 Cool: You will still have ₹${postPurchaseBalance.toStringAsFixed(0)} reserve left, keeping your '$goalName' goal on track.";
        }
      }
    }

    if (isOverBalance) {
      goalImpactText = "🔴 High Alert: You do not have enough balance to cover this transaction.";
      impactColor = const Color(0xFFFF453A);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1C1C1E), Color(0xFF0F0F10)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFF2C2C2E), width: 1),
                    ),
                    child: Column(
                      children: [
                        Text(
                          _payeeName,
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        if (_payeeVpa.isNotEmpty)
                          Text(
                            _payeeVpa,
                            style: GoogleFonts.outfit(
                              color: const Color(0xFF8E8E93),
                              fontSize: 12,
                            ),
                          ),
                        const SizedBox(height: 16),
                        Text(
                          _currencyFormat.format(amount),
                          style: GoogleFonts.outfit(
                            color: const Color(0xFF0A84FF),
                            fontSize: 38,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                  color: const Color(0xFF0A84FF).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: const Color(0xFF0A84FF).withValues(alpha: 0.3), width: 1),
                              ),
                              child: Text(
                                _displayCategory,
                                style: GoogleFonts.outfit(
                                  color: const Color(0xFF0A84FF),
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  Text(
                    'FINANCIAL IMPACT ANALYSIS',
                    style: GoogleFonts.outfit(
                      color: const Color(0xFF8E8E93),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 12),

                  _buildImpactRow(
                    label: "Remaining Daily Limit",
                    value: _currencyFormat.format(remainingDaily),
                    status: isOverDaily ? "Limit Exceeded" : "Safe",
                    statusColor: isOverDaily ? const Color(0xFFFF9F0A) : const Color(0xFF30D158),
                  ),
                  const Divider(color: Color(0xFF2C2C2E), height: 20),

                  _buildImpactRow(
                    label: "Bank / Cash Balance",
                    value: _currencyFormat.format(balance),
                    status: isOverBalance ? "Low Funds" : "Sufficient",
                    statusColor: isOverBalance ? const Color(0xFFFF453A) : const Color(0xFF30D158),
                  ),
                  const Divider(color: Color(0xFF2C2C2E), height: 24),

                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: impactColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: impactColor.withValues(alpha: 0.2), width: 1),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline, color: impactColor, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            goalImpactText,
                            style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          Row(
            children: [
              Expanded(
                child: AppleBounceable(
                  onTap: () {
                    setState(() {
                      _currentStep = QRScanStep.enteringAmount;
                      _isAmountFocused = true;
                    });
                  },
                  child: Container(
                    height: 52,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1C1C1E),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF2C2C2E)),
                    ),
                    child: Text(
                      'Back',
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppleBounceable(
                  onTap: isOverBalance
                      ? () {}
                      : () {
                          _startPaymentProcess();
                        },
                  child: Container(
                    height: 52,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isOverBalance ? const Color(0xFF1C1C1E) : const Color(0xFF00D632),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      'Pay Now',
                      style: GoogleFonts.outfit(
                        color: isOverBalance ? const Color(0xFF8E8E93) : Colors.black,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _startPaymentProcess() async {
    setState(() {
      _currentStep = QRScanStep.processing;
    });

    final double amount = double.tryParse(_amountStr) ?? 0.0;
    
    // 1. Sync data to Google Sheets first
    try {
      final userId = _authState.userId;
      if (userId != null) {
        final expenseId = 'exp_${const Uuid().v4()}';
        final newExpense = {
          'id': expenseId,
          'userId': userId,
          'amount': amount,
          'category': _displayCategory,
          'note': _note.isNotEmpty ? _note : _payeeName,
          'date': DateTime.now().toIso8601String(),
          'paymentMethod': _selectedPaymentMethod,
          'needOrWant': _classification,
        };

        await _apiService.request('syncData', {
          'userId': userId,
          'expenses': [newExpense],
        });
      }
    } catch (_) {}

    // 2. Open the native payment apps via UPI deep link scheme
    if (_payeeVpa.isNotEmpty) {
      final String upiUrl = 'upi://pay?pa=$_payeeVpa'
          '&pn=${Uri.encodeComponent(_payeeName)}'
          '&tn=${Uri.encodeComponent(_note.isNotEmpty ? _note : _payeeName)}'
          '&am=$amount'
          '&cu=INR';
      try {
        final Uri uri = Uri.parse(upiUrl);
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (e) {
        debugPrint('Error launching UPI: $e');
      }
    }

    if (mounted) {
      setState(() {
        _currentStep = QRScanStep.success;
      });
    }
  }

  Widget _buildProcessingBody() {
    return Container(
      color: const Color(0xFF000000),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(
              color: Color(0xFF00D632),
              strokeWidth: 3,
            ),
            const SizedBox(height: 24),
            Text(
              'Redirecting to UPI Pay...',
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Processing secure payment transaction',
              style: GoogleFonts.outfit(
                color: const Color(0xFF8E8E93),
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccessBody() {
    final double amount = double.tryParse(_amountStr) ?? 0.0;
    final summary = _dashboardData['summary'] ?? {};
    final double balance = (summary['currentBalance'] as num?)?.toDouble() ?? 0.0;
    
    return Container(
      color: const Color(0xFF000000),
      child: Column(
        children: [
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TweenAnimationBuilder<double>(
                    duration: const Duration(milliseconds: 600),
                    tween: Tween<double>(begin: 0.0, end: 1.0),
                    curve: Curves.elasticOut,
                    builder: (context, val, child) {
                      return Transform.scale(
                        scale: val,
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: const BoxDecoration(
                            color: Color(0xFF00D632),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.check, color: Colors.black, size: 48),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 28),
                  Text(
                    'Payment Successful!',
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Sent to $_payeeName',
                    style: GoogleFonts.outfit(
                      color: const Color(0xFF8E8E93),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 32),
                  // Premium details card showing entered amount and remaining balance
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 32),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1C1C1E),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFF2C2C2E),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Amount Sent',
                              style: GoogleFonts.outfit(
                                color: const Color(0xFF8E8E93),
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              '₹${amount.toStringAsFixed(0)}',
                              style: GoogleFonts.outfit(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12.0),
                          child: Divider(color: Color(0xFF2C2C2E), height: 1),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Remaining Balance',
                              style: GoogleFonts.outfit(
                                color: const Color(0xFF8E8E93),
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              '₹${(balance - amount).toStringAsFixed(0)}',
                              style: GoogleFonts.outfit(
                                color: const Color(0xFF00D632),
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: AppleBounceable(
                onTap: () {
                  Navigator.of(context).pop(true);
                },
                child: Container(
                  height: 52,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFF00D632),
                    borderRadius: BorderRadius.circular(26),
                  ),
                  child: Text(
                    'Done',
                    style: GoogleFonts.outfit(
                      color: Colors.black,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImpactRow({
    required String label,
    required String value,
    required String status,
    required Color statusColor,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: GoogleFonts.outfit(color: const Color(0xFF8E8E93), fontSize: 13),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: GoogleFonts.outfit(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            status,
            style: GoogleFonts.outfit(
              color: statusColor,
              fontWeight: FontWeight.bold,
              fontSize: 11,
            ),
          ),
        ),
      ],
    );
  }

  void _backToScanning() {
    _startScannerSafe();
    setState(() {
      _currentStep = QRScanStep.scanning;
      _hasScanned = false;
      _animateAmountUI = false;
    });
  }

  Widget _buildCorner(Alignment alignment) {
    final isTop = alignment == Alignment.topLeft || alignment == Alignment.topRight;
    final isLeft = alignment == Alignment.topLeft || alignment == Alignment.bottomLeft;
    
    return Align(
      alignment: alignment,
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          border: Border(
            top: isTop ? const BorderSide(color: Color(0xFF00D632), width: 4) : BorderSide.none,
            bottom: !isTop ? const BorderSide(color: Color(0xFF00D632), width: 4) : BorderSide.none,
            left: isLeft ? const BorderSide(color: Color(0xFF00D632), width: 4) : BorderSide.none,
            right: !isLeft ? const BorderSide(color: Color(0xFF00D632), width: 4) : BorderSide.none,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        
        // If system keyboard is open (focus is on text fields), unfocus/hide it first!
        if (_customCategoryFocusNode.hasFocus) {
          _customCategoryFocusNode.unfocus();
          return;
        }
        
        // If custom numeric keypad is active, dismiss it!
        if (_isAmountFocused) {
          setState(() {
            _isAmountFocused = false;
          });
          return;
        }

        // Handle navigation step rollback
        if (_currentStep == QRScanStep.enteringAmount) {
          _backToScanning();
        } else if (_currentStep == QRScanStep.assistant) {
          setState(() {
            _currentStep = QRScanStep.enteringAmount;
            _isAmountFocused = true;
          });
        } else {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF000000),
        appBar: _currentStep == QRScanStep.processing || _currentStep == QRScanStep.success
            ? null
            : AppBar(
                backgroundColor: const Color(0xFF000000),
                elevation: 0,
                scrolledUnderElevation: 0,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF00D632), size: 20),
                  onPressed: () {
                    if (_currentStep == QRScanStep.enteringAmount) {
                      _backToScanning();
                    } else if (_currentStep == QRScanStep.assistant) {
                      setState(() {
                        _currentStep = QRScanStep.enteringAmount;
                        _isAmountFocused = true;
                      });
                    } else {
                      Navigator.of(context).pop();
                    }
                  },
                ),
                actions: _currentStep == QRScanStep.scanning
                    ? [
                        IconButton(
                          icon: const Icon(Icons.photo_library_rounded, color: Colors.white),
                          onPressed: _showMockQRPicker,
                        ),
                      ]
                    : null,
              ),
        body: _buildStepBody(),
      ),
    );
  }
}

class _BlinkingCursor extends StatefulWidget {
  const _BlinkingCursor({super.key});

  @override
  State<_BlinkingCursor> createState() => _BlinkingCursorState();
}

class _BlinkingCursorState extends State<_BlinkingCursor> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _controller,
      child: Container(
        width: 3,
        height: 48,
        color: const Color(0xFF00D632),
      ),
    );
  }
}
             