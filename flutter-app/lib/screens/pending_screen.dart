import 'package:flutter/material.dart';
import 'dart:async';
import '../device_manager.dart';

class PendingScreen extends StatefulWidget {
  final String message;
  final VoidCallback onCheckStatus;
  final DeviceManager deviceManager;

  const PendingScreen({
    super.key,
    required this.message,
    required this.onCheckStatus,
    required this.deviceManager,
  });

  @override
  State<PendingScreen> createState() => _PendingScreenState();
}

class _PendingScreenState extends State<PendingScreen>
    with TickerProviderStateMixin {
  Timer? _autoCheckTimer;
  bool _isChecking = false;
  String _lastChecked = 'Just now';
  String _deviceId = 'Loading...';
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimation();
    _loadDeviceId();
    _startAutoCheck();
  }

  void _setupAnimation() {
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(
      begin: 0.8,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    _pulseController.repeat(reverse: true);
  }

  Future<void> _loadDeviceId() async {
    try {
      final deviceId = await widget.deviceManager.getDeviceDisplayId();
      if (mounted) {
        setState(() {
          _deviceId = deviceId;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _deviceId = 'Error loading ID';
        });
      }
    }
  }

  @override
  void dispose() {
    _autoCheckTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  void _startAutoCheck() {
    // Check every 30 seconds automatically
    _autoCheckTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted && !_isChecking) {
        _checkStatus();
      }
    });
  }

  void _checkStatus() async {
    if (_isChecking) return;
    
    setState(() {
      _isChecking = true;
    });
    
    try {
      widget.onCheckStatus();
      if (mounted) {
        setState(() {
          _lastChecked = _formatCurrentTime();
        });
      }
    } catch (e) {
      // Handle error silently, let parent handle status updates
    } finally {
      if (mounted) {
        setState(() {
          _isChecking = false;
        });
      }
    }
  }

  String _formatCurrentTime() {
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFBBF24), Color(0xFFF59E0B)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Card(
                elevation: 12,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                color: Colors.white.withOpacity(0.95),
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Animated hourglass icon
                      AnimatedBuilder(
                        animation: _pulseAnimation,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: _pulseAnimation.value,
                            child: const Icon(
                              Icons.hourglass_empty,
                              size: 64,
                              color: Color(0xFFF59E0B),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      
                      // Title
                      const Text(
                        'Waiting for Approval',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFF59E0B),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 32),
                      
                      // Spinning progress indicator
                      const CircularProgressIndicator(
                        color: Color(0xFFF59E0B),
                        strokeWidth: 3,
                      ),
                      const SizedBox(height: 24),
                      
                      // Status message
                      const Text(
                        'Device Registration Pending',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF374151),
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Device info
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF9FAFB).withOpacity(0.8),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildInfoRow('Device ID:', _deviceId),
                            _buildInfoRow('Status:', 'Pending Approval'),
                            _buildInfoRow('Last Checked:', _lastChecked),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                      
                      // Check status button
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: _isChecking ? null : _checkStatus,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xFFF59E0B),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            elevation: 4,
                          ),
                          child: _isChecking
                              ? const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        color: Color(0xFFF59E0B),
                                        strokeWidth: 2,
                                      ),
                                    ),
                                    SizedBox(width: 12),
                                    Text(
                                      'Checking...',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                )
                              : const Text(
                                  'Check Status',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      
                      // Information message
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF3B82F6).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border(
                            left: BorderSide(
                              color: const Color(0xFF3B82F6),
                              width: 4,
                            ),
                          ),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.info,
                                  color: Color(0xFF1E40AF),
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                const Expanded(
                                  child: Text(
                                    'Administrator Action Required',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF1E40AF),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Please contact your administrator to approve this device. This screen will automatically update when approved.',
                              style: TextStyle(
                                color: Color(0xFF1E40AF),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Auto-refresh notice
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.refresh,
                              size: 16,
                              color: Colors.grey.shade600,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Auto-checking every 30 seconds',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Color(0xFF374151),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Color(0xFF6B7280),
              ),
            ),
          ),
        ],
      ),
    );
  }
}