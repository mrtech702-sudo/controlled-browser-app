import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'device_manager.dart';
import 'screens/registration_screen.dart';
import 'screens/pending_screen.dart';
import 'screens/locked_screen.dart';
import 'screens/web_view_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Lock orientation to portrait
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);
  
  runApp(const ControlledBrowserApp());
}

class ControlledBrowserApp extends StatelessWidget {
  const ControlledBrowserApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Controlled Browser',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const AppScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class AppScreen extends StatefulWidget {
  const AppScreen({super.key});

  @override
  State<AppScreen> createState() => _AppScreenState();
}

class _AppScreenState extends State<AppScreen> with WidgetsBindingObserver {
  final DeviceManager _deviceManager = DeviceManager();
  AppState _currentState = AppState.loading;
  String _message = 'Loading...';
  Map<String, dynamic>? _config;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeApp();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _deviceManager.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkStatus();
    }
  }

  Future<void> _initializeApp() async {
    try {
      // Check if device is already registered
      final deviceData = await _deviceManager.getDeviceData();
      
      if (deviceData == null) {
        // First run - show registration
        setState(() {
          _currentState = AppState.registration;
          _message = 'Device registration required';
        });
        return;
      }
      
      // Device exists, check status
      await _checkStatus();
      
    } catch (e) {
      setState(() {
        _currentState = AppState.locked;
        _message = 'Initialization failed: ${e.toString()}';
      });
    }
  }

  Future<void> _checkStatus() async {
    try {
      final config = await _deviceManager.checkDeviceConfig();
      
      if (config == null) {
        setState(() {
          _currentState = AppState.locked;
          _message = 'Unable to verify device status';
        });
        return;
      }

      _config = config;
      
      switch (config['status']) {
        case 'approved':
          final license = config['license'];
          if (license != null && license['status'] == 'active') {
            final expiresAt = DateTime.parse(license['expires_at']);
            if (expiresAt.isAfter(DateTime.now())) {
              setState(() {
                _currentState = AppState.main;
                _message = 'Access granted';
              });
            } else {
              setState(() {
                _currentState = AppState.locked;
                _message = 'License expired';
              });
            }
          } else {
            setState(() {
              _currentState = AppState.locked;
              _message = 'License inactive';
            });
          }
          break;
        case 'pending':
          setState(() {
            _currentState = AppState.pending;
            _message = 'Waiting for approval';
          });
          break;
        case 'blocked':
        case 'revoked':
          setState(() {
            _currentState = AppState.locked;
            _message = 'Access revoked';
          });
          break;
        default:
          setState(() {
            _currentState = AppState.locked;
            _message = 'Unknown status';
          });
      }
    } catch (e) {
      setState(() {
        _currentState = AppState.locked;
        _message = 'Status check failed: ${e.toString()}';
      });
    }
  }

  Future<void> _registerDevice() async {
    try {
      setState(() {
        _currentState = AppState.loading;
        _message = 'Registering device...';
      });
      
      final success = await _deviceManager.registerDevice();
      
      if (success) {
        setState(() {
          _currentState = AppState.pending;
          _message = 'Registration successful - waiting for approval';
        });
      } else {
        setState(() {
          _currentState = AppState.registration;
          _message = 'Registration failed - please try again';
        });
      }
    } catch (e) {
      setState(() {
        _currentState = AppState.registration;
        _message = 'Registration error: ${e.toString()}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    switch (_currentState) {
      case AppState.loading:
        return _buildLoadingScreen();
      case AppState.registration:
        return RegistrationScreen(
          message: _message,
          onRegister: _registerDevice,
        );
      case AppState.pending:
        return PendingScreen(
          message: _message,
          onCheckStatus: _checkStatus,
          deviceManager: _deviceManager,
        );
      case AppState.locked:
        return LockedScreen(
          message: _message,
          onRetry: _checkStatus,
        );
      case AppState.main:
        return WebViewScreen(
          config: _config!,
          deviceManager: _deviceManager,
          onLockDevice: (reason) {
            setState(() {
              _currentState = AppState.locked;
              _message = reason;
            });
          },
        );
    }
  }

  Widget _buildLoadingScreen() {
    return Scaffold(
      backgroundColor: Colors.deepPurple.shade50,
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(
              'Loading...',
              style: TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}

enum AppState {
  loading,
  registration,
  pending,
  locked,
  main,
}