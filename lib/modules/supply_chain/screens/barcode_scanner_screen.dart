import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../bloc/inventory_bloc.dart';
import 'add_product_from_image_screen.dart';
import 'product_info_screen.dart';

class BarcodeScannerScreen extends StatefulWidget {
  final bool returnCode;
  const BarcodeScannerScreen({super.key, this.returnCode = false});

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen>
    with SingleTickerProviderStateMixin {
  final MobileScannerController _controller = MobileScannerController();
  late AnimationController _animationController;
  bool _isProcessing = false;
  bool _isTorchOn = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _animationController.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) async {
    if (_isProcessing) return;

    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final String? code = barcodes.first.rawValue;
    if (code == null || code.isEmpty) return;

    setState(() {
      _isProcessing = true;
    });

    // Pause scanner
    await _controller.stop();

    if (!mounted) return;
    _handleScannedCode(code);
  }

  Future<void> _handleScannedCode(String code) async {
    if (widget.returnCode) {
      Navigator.of(context).pop(code);
      return;
    }
    try {
      final product = await InventoryRepository().getProductByBarcode(code);

      if (!mounted) return;

      if (product != null) {
        // Convert Drift Product to Map that is expected by edit screen
        final productMap = {
          'id': product.id,
          'name': product.name,
          'price': product.price,
          'stock': await InventoryRepository().checkStock(product.name),
          'barcode': product.barcode,
          'custom_fields': product.customFields,
        };

        _showProductBottomSheet(
          code: code,
          exists: true,
          title: 'Đã tìm thấy sản phẩm',
          name: product.name,
          price: product.price,
          onAction: () async {
            Navigator.of(context).pop(); // Close bottom sheet
            final result = await Navigator.of(context).push<bool>(
              MaterialPageRoute(
                builder: (_) => ProductInfoScreen(product: productMap),
              ),
            );
            if (result == true && mounted) {
              Navigator.of(context).pop(true); // Pop scanner with refresh
            } else {
              _resumeScanner();
            }
          },
        );
      } else {
        _showProductBottomSheet(
          code: code,
          exists: false,
          title: 'Sản phẩm mới',
          name: 'Mã: $code',
          price: 0,
          onAction: () async {
            Navigator.of(context).pop(); // Close bottom sheet
            final result = await Navigator.of(context).push<bool>(
              MaterialPageRoute(
                builder: (_) => AddProductFromImageScreen(initialBarcode: code),
              ),
            );
            if (result == true && mounted) {
              Navigator.of(context).pop(true); // Pop scanner with refresh
            } else {
              _resumeScanner();
            }
          },
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi khi tra cứu: $e'),
            backgroundColor: const Color(0xFFF43F5E),
          ),
        );
        _resumeScanner();
      }
    }
  }

  void _resumeScanner() async {
    setState(() {
      _isProcessing = false;
    });
    await _controller.start();
  }

  void _showProductBottomSheet({
    required String code,
    required bool exists,
    required String title,
    required String name,
    required double price,
    required VoidCallback onAction,
  }) {
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 16,
                spreadRadius: 4,
              )
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: exists
                          ? const Color(0xFF10B981).withOpacity(0.1)
                          : const Color(0xFF6366F1).withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      exists
                          ? Icons.check_circle_outline
                          : Icons.add_circle_outline,
                      color: exists
                          ? const Color(0xFF10B981)
                          : const Color(0xFF6366F1),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                name,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Mã Barcode: $code',
                style: TextStyle(
                  color: Colors.grey[500],
                  fontFamily: 'monospace',
                  fontSize: 14,
                ),
              ),
              if (exists) ...[
                const SizedBox(height: 8),
                Text(
                  'Đơn giá: ${_formatPrice(price)} VNĐ',
                  style: const TextStyle(
                    fontSize: 16,
                    color: Color(0xFF10B981),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
              const SizedBox(height: 28),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: () {
                        Navigator.of(context).pop();
                        _resumeScanner();
                      },
                      child: const Text('Quét lại'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: exists
                              ? [
                                  const Color(0xFF10B981),
                                  const Color(0xFF06B6D4)
                                ]
                              : [
                                  const Color(0xFF6366F1),
                                  const Color(0xFF06B6D4)
                                ],
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: onAction,
                        child: Text(exists ? 'Chỉnh sửa' : 'Thêm sản phẩm'),
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
  }

  String _formatPrice(dynamic price) {
    if (price is double) {
      return price.toStringAsFixed(0);
    }
    return price.toString();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final scanArea = size.width * 0.7;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Quét mã vạch / QR',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _isTorchOn ? Icons.flash_on : Icons.flash_off,
              color: _isTorchOn ? Colors.amber : Colors.white70,
            ),
            onPressed: () async {
              await _controller.toggleTorch();
              setState(() {
                _isTorchOn = !_isTorchOn;
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.flip_camera_ios, color: Colors.white70),
            onPressed: () => _controller.switchCamera(),
          ),
        ],
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // 1. Scanner Camera View
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
          ),

          // 2. Dark Overlay with cutout hole
          ColorFiltered(
            colorFilter: ColorFilter.mode(
              Colors.black.withOpacity(0.6),
              BlendMode.srcOut,
            ),
            child: Stack(
              children: [
                Container(
                  color: Colors.transparent,
                ),
                Align(
                  alignment: Alignment.center,
                  child: Container(
                    width: scanArea,
                    height: scanArea,
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 3. Viewfinder Frame & Scan Line Animation
          Align(
            alignment: Alignment.center,
            child: SizedBox(
              width: scanArea,
              height: scanArea,
              child: Stack(
                children: [
                  // Corner borders
                  _buildCorners(),

                  // Red Scanning Line
                  AnimatedBuilder(
                    animation: _animationController,
                    builder: (context, child) {
                      return Positioned(
                        top: _animationController.value * (scanArea - 4),
                        left: 12,
                        right: 12,
                        child: Container(
                          height: 3,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                Colors.transparent,
                                Colors.red,
                                Colors.transparent
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.red.withOpacity(0.5),
                                blurRadius: 4,
                                spreadRadius: 1,
                              )
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

          // 4. Instructional prompt
          Positioned(
            bottom: 48,
            left: 24,
            right: 24,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white10),
              ),
              child: const Text(
                'Đặt mã vạch hoặc mã QR vào giữa khung hình để quét tự động',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCorners() {
    const double length = 24.0;
    const double thickness = 4.0;
    const color = Color(0xFF10B981);

    return Stack(
      children: [
        // Top Left
        Positioned(
          top: 0,
          left: 0,
          child: Container(
            width: length,
            height: thickness,
            color: color,
          ),
        ),
        Positioned(
          top: 0,
          left: 0,
          child: Container(
            width: thickness,
            height: length,
            color: color,
          ),
        ),

        // Top Right
        Positioned(
          top: 0,
          right: 0,
          child: Container(
            width: length,
            height: thickness,
            color: color,
          ),
        ),
        Positioned(
          top: 0,
          right: 0,
          child: Container(
            width: thickness,
            height: length,
            color: color,
          ),
        ),

        // Bottom Left
        Positioned(
          bottom: 0,
          left: 0,
          child: Container(
            width: length,
            height: thickness,
            color: color,
          ),
        ),
        Positioned(
          bottom: 0,
          left: 0,
          child: Container(
            width: thickness,
            height: length,
            color: color,
          ),
        ),

        // Bottom Right
        Positioned(
          bottom: 0,
          right: 0,
          child: Container(
            width: length,
            height: thickness,
            color: color,
          ),
        ),
        Positioned(
          bottom: 0,
          right: 0,
          child: Container(
            width: thickness,
            height: length,
            color: color,
          ),
        ),
      ],
    );
  }
}
