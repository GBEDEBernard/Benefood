import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/theme/app_colors.dart';

class DeliveryQrScannerScreen extends StatefulWidget {
  const DeliveryQrScannerScreen({super.key});

  @override
  State<DeliveryQrScannerScreen> createState() =>
      _DeliveryQrScannerScreenState();
}

class _DeliveryQrScannerScreenState extends State<DeliveryQrScannerScreen> {
  late final MobileScannerController _controller;
  bool _completed = false;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      formats: const [BarcodeFormat.qrCode],
      detectionSpeed: DetectionSpeed.noDuplicates,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_completed) {
      return;
    }
    final value = capture.barcodes
        .map((barcode) => barcode.rawValue)
        .whereType<String>()
        .firstOrNull;
    if (value == null) {
      return;
    }
    _completed = true;
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Scanner le QR du client'),
        foregroundColor: Colors.white,
        backgroundColor: Colors.black,
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (context, error) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Caméra indisponible. Autorisez l’accès à la caméra ou saisissez le PIN du client.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            ),
          ),
          IgnorePointer(
            child: Center(
              child: Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.orangeVivid, width: 4),
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
            ),
          ),
          Positioned(
            left: 24,
            right: 24,
            bottom: 36,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Text(
                'Placez le QR de la commande dans le cadre. Le PIN reste disponible en alternative.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, height: 1.4),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
