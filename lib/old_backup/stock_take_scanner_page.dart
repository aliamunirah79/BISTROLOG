import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class StockTakeScannerPage extends StatefulWidget {
  const StockTakeScannerPage({super.key});

  @override
  State<StockTakeScannerPage> createState() => _StockTakeScannerPageState();
}

class _StockTakeScannerPageState extends State<StockTakeScannerPage> {
  late final MobileScannerController controller;

  bool detected = false;
  bool flashOn = false;

  static const Color mulberry = Color(0xFF6D2B50);
  static const Color cream = Color(0xFFF5ECD7);

  @override
  void initState() {
    super.initState();

    controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      facing: CameraFacing.back,
      torchEnabled: false,
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void _returnCode(String code) {
    if (detected || code.isEmpty) return;

    detected = true;

    if (!mounted) return;

    Navigator.pop(context, code);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: mulberry,
        foregroundColor: cream,
        title: const Text('Scan Barcode'),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: () async {
              setState(() {
                flashOn = !flashOn;
              });

              await controller.toggleTorch();
            },
            icon: Icon(
              flashOn ? Icons.flash_on : Icons.flash_off,
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: controller,
            onDetect: (capture) {
              if (detected) return;

              final barcodes = capture.barcodes;
              if (barcodes.isEmpty) return;

              final code = barcodes.first.rawValue;
              if (code == null || code.isEmpty) return;

              _returnCode(code);
            },
          ),
          Center(
            child: Container(
              width: 260,
              height: 160,
              decoration: BoxDecoration(
                border: Border.all(color: cream, width: 3),
                borderRadius: BorderRadius.circular(18),
              ),
            ),
          ),
          Positioned(
            bottom: 40,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.65),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Text(
                'Point the camera at the barcode',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: cream,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}