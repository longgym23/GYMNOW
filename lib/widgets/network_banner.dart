import 'dart:async';
import 'package:flutter/material.dart';
import 'package:gym_now/services/network_service.dart';

class NetworkBanner extends StatefulWidget {
  final Widget child;

  const NetworkBanner({Key? key, required this.child}) : super(key: key);

  @override
  State<NetworkBanner> createState() => _NetworkBannerState();
}

class _NetworkBannerState extends State<NetworkBanner> {
  final NetworkService _networkService = NetworkService();
  bool _isConnected = true;

  StreamSubscription<bool>? _subscription;

  @override
  void initState() {
    super.initState();
    _networkService.initialize();
    _subscription = _networkService.connectionStatus.listen((isConnected) {
      if (mounted) {
        setState(() {
          _isConnected = isConnected;
        });
      }
    });

    // Kiểm tra trạng thái ban đầu
    _checkInitialStatus();
  }

  Future<void> _checkInitialStatus() async {
    final isConnected = await _networkService.checkInternetConnection();
    if (mounted) {
      setState(() {
        _isConnected = isConnected;
      });
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (!_isConnected)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.red.shade600,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.wifi_off, color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Không có mạng, vui lòng kết nối internet',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        decoration: TextDecoration.none, // Loại bỏ gạch chân
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
