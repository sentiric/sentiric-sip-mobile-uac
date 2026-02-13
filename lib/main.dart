import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sentiric_sip_mobile_uac/src/rust/api/simple.dart';
import 'package:sentiric_sip_mobile_uac/src/rust/frb_generated.dart';
import 'package:sentiric_sip_mobile_uac/telecom_telemetry.dart'; // Yeni import

import 'dart:io';
import 'dart:ffi';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
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
      title: 'Sentiric Mobile UAC',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0A0A0A),
        primaryColor: Colors.greenAccent,
      ),
      home: const DialerScreen(),
    );
  }
}

class DialerScreen extends StatefulWidget {
  const DialerScreen({super.key});
  @override
  _DialerScreenState createState() => _DialerScreenState();
}

class _DialerScreenState extends State<DialerScreen> {
  final TextEditingController _ipController = TextEditingController(text: "34.122.40.122");
  final TextEditingController _portController = TextEditingController(text: "5060");
  final TextEditingController _toController = TextEditingController(text: "9999");
  final TextEditingController _fromController = TextEditingController(text: "mobile-tester");

  final List<TelemetryEntry> _telemetryLogs = [];
  bool _isCalling = false;
  final ScrollController _scrollController = ScrollController();

  void _processIncomingEvent(String raw) {
    if (!mounted) return;
    final entry = TelecomTelemetry.parse(raw);
    
    setState(() {
      _telemetryLogs.add(entry);
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _handleCall() async {
    if (await Permission.microphone.request().isGranted) {
      setState(() {
        _telemetryLogs.clear();
        _isCalling = true;
      });

      final stream = startSipCall(
        targetIp: _ipController.text,
        targetPort: int.parse(_portController.text),
        toUser: _toController.text,
        fromUser: _fromController.text,
      );

      stream.listen(
        (event) => _processIncomingEvent(event),
        onDone: () => setState(() => _isCalling = false),
        onError: (e) => _processIncomingEvent("Error(\"Stream: $e\")"),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('📡 FIELD MONITOR v2.0', style: TextStyle(letterSpacing: 2, fontSize: 16)),
        backgroundColor: Colors.black,
        elevation: 0,
      ),
      body: Column(
        children: [
          _buildInputPanel(),
          _buildActionBtn(),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Divider(color: Colors.greenAccent, thickness: 0.2),
          ),
          Expanded(child: _buildLogConsole()),
        ],
      ),
    );
  }

  Widget _buildInputPanel() {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Card(
        color: Colors.white.withOpacity(0.03),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(child: _miniField(_ipController, "Edge IP")),
                  const SizedBox(width: 8),
                  Expanded(child: _miniField(_portController, "Port")),
                ],
              ),
              Row(
                children: [
                  Expanded(child: _miniField(_toController, "To")),
                  const SizedBox(width: 8),
                  Expanded(child: _miniField(_fromController, "From")),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _miniField(TextEditingController ctrl, String hint) {
    return TextField(
      controller: ctrl,
      enabled: !_isCalling,
      style: const TextStyle(fontSize: 12),
      decoration: InputDecoration(labelText: hint, labelStyle: const TextStyle(color: Colors.grey)),
    );
  }

  Widget _buildActionBtn() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SizedBox(
        width: double.infinity,
        height: 50,
        child: ElevatedButton(
          onPressed: _isCalling ? null : _handleCall,
          style: ElevatedButton.styleFrom(
            backgroundColor: _isCalling ? Colors.blueGrey : Colors.green.shade900,
          ),
          child: Text(_isCalling ? "CALL IN PROGRESS..." : "START TELECOM SESSION"),
        ),
      ),
    );
  }

  Widget _buildLogConsole() {
    return Container(
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.white10),
      ),
      child: ListView.builder(
        controller: _scrollController,
        itemCount: _telemetryLogs.length,
        itemBuilder: (context, index) {
          final entry = _telemetryLogs[index];
          return _logLine(entry);
        },
      ),
    );
  }

  Widget _logLine(TelemetryEntry entry) {
    Color color = Colors.greenAccent.withOpacity(0.8);
    FontWeight weight = FontWeight.normal;
    double size = 11;

    if (entry.level == TelemetryLevel.status) {
      color = Colors.white;
      weight = FontWeight.bold;
    } else if (entry.level == TelemetryLevel.error) {
      color = Colors.redAccent;
    } else if (entry.level == TelemetryLevel.sip) {
      color = Colors.cyanAccent.withOpacity(0.9);
      size = 10;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: color, width: 2)),
      ),
      child: Text(
        entry.message,
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: size,
          color: color,
          fontWeight: weight,
        ),
      ),
    );
  }
}