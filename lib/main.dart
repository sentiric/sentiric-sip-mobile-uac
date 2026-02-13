// lib/main.dart

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sentiric_sip_mobile_uac/src/rust/api/simple.dart';
import 'package:sentiric_sip_mobile_uac/src/rust/frb_generated.dart';
import 'package:sentiric_sip_mobile_uac/telecom_telemetry.dart';
import 'dart:io';
import 'dart:ffi';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    // Android için C++ kütüphanesini yükle (Gerekli)
    if (Platform.isAndroid) {
      try {
        DynamicLibrary.open('libc++_shared.so');
      } catch (e) {
        debugPrint("⚠️ libc++ load warning: $e");
      }
    }
    await RustLib.init();
    await initLogger(); 
  } catch (e) {
    debugPrint("Rust Init Error: $e");
  }
  runApp(const SentiricApp());
}

class SentiricApp extends StatelessWidget {
  const SentiricApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sentiric Mobile',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0D0D0D),
        primaryColor: const Color(0xFF00FF9D),
        colorScheme: ColorScheme.dark(
          primary: const Color(0xFF00FF9D),
          secondary: Colors.cyanAccent,
          surface: Colors.grey.shade900,
        ),
      ),
      home: const DialerScreen(),
    );
  }
}

class DialerScreen extends StatefulWidget {
  const DialerScreen({super.key});
  @override
  State<DialerScreen> createState() => _DialerScreenState();
}

class _DialerScreenState extends State<DialerScreen> {
  // Varsayılan Değerler (Hardcode değil, Default Value)
  final TextEditingController _ipController = TextEditingController(text: "34.122.40.122");
  final TextEditingController _portController = TextEditingController(text: "5060");
  final TextEditingController _toController = TextEditingController(text: "9999");
  final TextEditingController _fromController = TextEditingController(text: "mobile-tester");

  final List<TelemetryEntry> _telemetryLogs = [];
  bool _isCalling = false;
  final ScrollController _scrollController = ScrollController();

  void _addLog(TelemetryEntry entry) {
    if (!mounted) return;
    setState(() {
      _telemetryLogs.add(entry);
    });
    // Otomatik Scroll
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _handleCall() async {
    // İzin Kontrolü (Mikrofon)
    if (await Permission.microphone.request().isGranted) {
      setState(() {
        _telemetryLogs.clear();
        _isCalling = true;
      });
      
      _addLog(TelemetryEntry(message: "🚀 Initializing SDK...", level: TelemetryLevel.status));

      try {
        final stream = startSipCall(
          targetIp: _ipController.text.trim(),
          targetPort: int.parse(_portController.text.trim()),
          toUser: _toController.text.trim(),
          fromUser: _fromController.text.trim(),
        );

        stream.listen(
          (eventRaw) {
            // Rust'tan gelen string'i parse et ve listeye ekle
            final entry = TelecomTelemetry.parse(eventRaw);
            _addLog(entry);
            
            // Eğer arama sonlandıysa butonu aktif et
            if (eventRaw.contains("Terminated")) {
               setState(() => _isCalling = false);
            }
          },
          onDone: () {
            _addLog(TelemetryEntry(message: "🏁 Stream Closed", level: TelemetryLevel.status));
            setState(() => _isCalling = false);
          },
          onError: (e) {
            _addLog(TelemetryEntry(message: "System Error: $e", level: TelemetryLevel.error));
            setState(() => _isCalling = false);
          },
        );
      } catch (e) {
        _addLog(TelemetryEntry(message: "Exception: $e", level: TelemetryLevel.error));
        setState(() => _isCalling = false);
      }
    } else {
      _addLog(TelemetryEntry(message: "Microphone permission denied!", level: TelemetryLevel.error));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SENTIRIC FIELD MONITOR', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
        backgroundColor: Colors.black,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () => setState(() => _telemetryLogs.clear()),
          )
        ],
      ),
      body: Column(
        children: [
          // Girdi Alanı
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white.withOpacity(0.05),
            child: Column(
              children: [
                Row(children: [
                  Expanded(flex: 3, child: _inputField(_ipController, "Edge IP", Icons.dns)),
                  const SizedBox(width: 10),
                  Expanded(flex: 1, child: _inputField(_portController, "Port", Icons.numbers)),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: _inputField(_toController, "To (Callee)", Icons.call_made)),
                  const SizedBox(width: 10),
                  Expanded(child: _inputField(_fromController, "From (You)", Icons.person)),
                ]),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: _isCalling ? null : _handleCall,
                    icon: Icon(_isCalling ? Icons.timelapse : Icons.call),
                    label: Text(_isCalling ? "CALL IN PROGRESS..." : "START TEST CALL"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00FF9D),
                      foregroundColor: Colors.black,
                      disabledBackgroundColor: Colors.grey.shade800,
                      disabledForegroundColor: Colors.white54,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          const Divider(height: 1, color: Colors.white24),
          
          // Log Konsolu
          Expanded(
            child: Container(
              color: Colors.black,
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(8),
                itemCount: _telemetryLogs.length,
                itemBuilder: (context, index) => _buildLogItem(_telemetryLogs[index]),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _inputField(TextEditingController controller, String label, IconData icon) {
    return TextField(
      controller: controller,
      enabled: !_isCalling,
      style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 16, color: Colors.white54),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
        filled: true,
        fillColor: Colors.black12,
      ),
    );
  }

  Widget _buildLogItem(TelemetryEntry entry) {
    Color textColor = Colors.grey;
    if (entry.level == TelemetryLevel.status) textColor = const Color(0xFF00FF9D);
    if (entry.level == TelemetryLevel.error) textColor = Colors.redAccent;
    if (entry.level == TelemetryLevel.sip) textColor = Colors.cyanAccent;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Text(
        entry.message,
        style: TextStyle(
          color: textColor, 
          fontFamily: 'monospace', 
          fontSize: 11,
          height: 1.2
        ),
      ),
    );
  }
}