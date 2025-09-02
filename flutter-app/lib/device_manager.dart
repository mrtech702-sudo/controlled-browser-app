import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class DeviceManager {
  // Configuration
  static const String wixApiBase = 'https://mrtech702.wixsite.com/my-site-1/_functions';
  static const String initialUrl = 'https://web.corani177.com';
  static const String targetUrl = 'https://mitchell-prodemand.corani177.com/Main/Index#|||||||||||||||||/Home';
  static const Duration heartbeatInterval = Duration(minutes: 15);
  static const Duration redirectDelay = Duration(seconds: 3);
  
  // Storage keys
  static const String _deviceDataKey = 'device_data';
  
  Timer? _heartbeatTimer;
  Map<String, dynamic>? _deviceData;

  // Get stored device data
  Future<Map<String, dynamic>?> getDeviceData() async {
    if (_deviceData != null) return _deviceData;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final deviceJson = prefs.getString(_deviceDataKey);
      
      if (deviceJson != null) {
        _deviceData = jsonDecode(deviceJson);
        return _deviceData;
      }
    } catch (e) {
      print('Error loading device data: $e');
    }
    
    return null;
  }

  // Save device data
  Future<bool> _saveDeviceData(Map<String, dynamic> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _deviceData = data;
      await prefs.setString(_deviceDataKey, jsonEncode(data));
      return true;
    } catch (e) {
      print('Error saving device data: $e');
      return false;
    }
  }

  // Register new device
  Future<bool> registerDevice() async {
    try {
      final uuid = const Uuid().v4();
      final registration = {
        'uuid': uuid,
        'platform': Platform.isAndroid ? 'android' : 'mobile',
        'app_version': '1.0.0',
        'registered_at': DateTime.now().toIso8601String(),
      };

      final response = await http.post(
        Uri.parse('$wixApiBase/device-register'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(registration),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (responseData['success'] == true) {
          final deviceData = {
            ...registration,
            'device_id': responseData['device_id'],
            'status': 'pending',
          };
          
          await _saveDeviceData(deviceData);
          return true;
        }
      }
      
      print('Registration failed: ${response.body}');
      return false;
    } catch (e) {
      print('Registration error: $e');
      return false;
    }
  }

  // Check device configuration and status
  Future<Map<String, dynamic>?> checkDeviceConfig() async {
    try {
      final deviceData = await getDeviceData();
      if (deviceData == null || deviceData['device_id'] == null) {
        return null;
      }

      final response = await http.get(
        Uri.parse('$wixApiBase/device-config?device_id=${deviceData['device_id']}'),
        headers: {
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      
      print('Config check failed: ${response.body}');
      return null;
    } catch (e) {
      print('Config check error: $e');
      return null;
    }
  }

  // Send heartbeat
  Future<void> sendHeartbeat() async {
    try {
      final deviceData = await getDeviceData();
      if (deviceData == null || deviceData['device_id'] == null) return;

      await http.post(
        Uri.parse('$wixApiBase/device-heartbeat'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'device_id': deviceData['device_id'],
          'timestamp': DateTime.now().toIso8601String(),
        }),
      );
    } catch (e) {
      print('Heartbeat failed: $e');
    }
  }

  // Start heartbeat timer
  void startHeartbeat() {
    stopHeartbeat(); // Clear any existing timer
    
    _heartbeatTimer = Timer.periodic(heartbeatInterval, (timer) {
      sendHeartbeat();
    });
    
    // Send initial heartbeat
    sendHeartbeat();
  }

  // Stop heartbeat timer
  void stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  // Get device display ID (short version for UI)
  Future<String> getDeviceDisplayId() async {
    final deviceData = await getDeviceData();
    final deviceId = deviceData?['device_id'] ?? 'Not registered';
    
    if (deviceId == 'Not registered') return deviceId;
    
    // Return first 8 characters as display ID
    return deviceId.toString().substring(0, 8).toUpperCase();
  }

  // Clean up resources
  void dispose() {
    stopHeartbeat();
  }
}