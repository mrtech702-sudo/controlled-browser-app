import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'dart:convert';
import '../device_manager.dart';

class WebViewScreen extends StatefulWidget {
  final Map<String, dynamic> config;
  final DeviceManager deviceManager;
  final Function(String) onLockDevice;

  const WebViewScreen({
    super.key,
    required this.config,
    required this.deviceManager,
    required this.onLockDevice,
  });

  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  bool _hasRedirected = false;

  @override
  void initState() {
    super.initState();
    _initializeWebView();
    widget.deviceManager.startHeartbeat();
    
    // Periodic status checks
    _startPeriodicStatusCheck();
  }

  void _initializeWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            if (progress == 100) {
              setState(() => _isLoading = false);
            }
          },
          onPageStarted: (String url) {
            setState(() => _isLoading = true);
          },
          onPageFinished: (String url) {
            setState(() => _isLoading = false);
            _applyDOMRules(url);
          },
          onNavigationRequest: (NavigationRequest request) {
            // Control navigation - only allow our domains
            final uri = Uri.parse(request.url);
            final allowedHosts = ['web.corani177.com', 'mitchell-prodemand.corani177.com'];
            
            if (!allowedHosts.contains(uri.host)) {
              print('Blocked navigation to: ${request.url}');
              return NavigationDecision.prevent;
            }
            
            return NavigationDecision.navigate;
          },
        ),
      );

    _loadInitialPage();
  }

  Future<void> _loadInitialPage() async {
    // Inject cookies first
    await _injectCookies();
    
    // Load web.corani177.com first
    await _controller.loadRequest(Uri.parse(DeviceManager.initialUrl));
    
    // Set up redirect after delay
    Future.delayed(DeviceManager.redirectDelay, () {
      if (mounted && !_hasRedirected) {
        _hasRedirected = true;
        _controller.loadRequest(Uri.parse(DeviceManager.targetUrl));
      }
    });
  }

  Future<void> _injectCookies() async {
    final cookies = widget.config['session_bundle']?['cookies'] as List?;
    if (cookies == null) return;

    for (final cookie in cookies) {
      try {
        final cookieString = '${cookie['name']}=${cookie['value']}; '
            'Domain=${cookie['domain'] ?? '.corani177.com'}; '
            'Path=${cookie['path'] ?? '/'}; '
            '${cookie['secure'] == true ? 'Secure; ' : ''}'
            '${cookie['httpOnly'] == true ? 'HttpOnly; ' : ''}';

        await _controller.runJavaScript('''
          document.cookie = "$cookieString";
        ''');
      } catch (e) {
        print('Failed to inject cookie: ${cookie['name']} - $e');
      }
    }
  }

  Future<void> _applyDOMRules(String currentUrl) async {
    final rules = widget.config['rules'] as Map<String, dynamic>?;
    if (rules == null) return;

    // Determine which rules to apply based on current URL
    Map<String, dynamic> activeRules = rules;
    
    if (currentUrl.contains('web.corani177.com') && rules['initial_page_rules'] != null) {
      activeRules = rules['initial_page_rules'];
    } else if (currentUrl.contains('mitchell-prodemand.corani177.com') && rules['target_page_rules'] != null) {
      activeRules = rules['target_page_rules'];
    }

    final script = '''
      (function() {
        const rules = ${jsonEncode(activeRules)};
        const currentDomain = window.location.hostname;
        
        console.log('Applying DOM rules for domain:', currentDomain);
        
        // Show only specific sections (hide everything else first)
        if (rules.showOnlySelectors && rules.showOnlySelectors.length > 0) {
          document.body.style.visibility = 'hidden';
          
          setTimeout(() => {
            // Hide all direct children of body
            Array.from(document.body.children).forEach(child => {
              child.style.display = 'none';
            });
            
            // Show only allowed sections and their parents
            rules.showOnlySelectors.forEach(selector => {
              const elements = document.querySelectorAll(selector);
              elements.forEach(el => {
                el.style.display = '';
                el.style.visibility = 'visible';
                
                // Show parent elements
                let current = el.parentElement;
                while (current && current !== document.body) {
                  current.style.display = '';
                  current.style.visibility = 'visible';
                  current = current.parentElement;
                }
              });
            });
            
            document.body.style.visibility = 'visible';
          }, 500);
        }
        
        // Hide elements
        if (rules.hideSelectors) {
          rules.hideSelectors.forEach(selector => {
            document.querySelectorAll(selector).forEach(el => {
              el.style.visibility = 'hidden';
            });
          });
        }
        
        // Remove elements
        if (rules.removeSelectors) {
          rules.removeSelectors.forEach(selector => {
            document.querySelectorAll(selector).forEach(el => {
              el.style.display = 'none';
            });
          });
        }
        
        // Blur elements
        if (rules.blurSelectors) {
          rules.blurSelectors.forEach(selector => {
            document.querySelectorAll(selector).forEach(el => {
              el.style.filter = 'blur(5px)';
              el.style.pointerEvents = 'none';
            });
          });
        }
        
        // Disable elements
        if (rules.disableSelectors) {
          rules.disableSelectors.forEach(selector => {
            document.querySelectorAll(selector).forEach(el => {
              el.disabled = true;
              el.style.pointerEvents = 'none';
              el.style.opacity = '0.5';
            });
          });
        }
        
        console.log('DOM rules applied:', rules);
      })();
    ''';

    try {
      await _controller.runJavaScript(script);
    } catch (e) {
      print('Failed to apply DOM rules: $e');
    }
  }

  void _startPeriodicStatusCheck() {
    Timer.periodic(const Duration(minutes: 5), (timer) async {
      try {
        final config = await widget.deviceManager.checkDeviceConfig();
        if (config != null && config['status'] != 'approved') {
          timer.cancel();
          widget.onLockDevice('Access status changed');
        }
      } catch (e) {
        print('Periodic status check failed: $e');
      }
    });
  }

  @override
  void dispose() {
    widget.deviceManager.stopHeartbeat();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF667EEA),
        foregroundColor: Colors.white,
        title: const Text('Controlled Browser'),
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _controller.reload();
            },
          ),
          IconButton(
            icon: const Icon(Icons.lock),
            onPressed: () {
              _showLockConfirmation();
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            Container(
              color: Colors.white,
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      color: Color(0xFF667EEA),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Loading secure browser...',
                      style: TextStyle(
                        fontSize: 16,
                        color: Color(0xFF374151),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showLockConfirmation() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Lock Application'),
          content: const Text('Are you sure you want to lock the application?'),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text('Lock'),
              onPressed: () {
                Navigator.of(context).pop();
                widget.onLockDevice('Manually locked by user');
              },
            ),
          ],
        );
      },
    );
  }
}