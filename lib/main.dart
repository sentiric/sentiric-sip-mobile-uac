import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
// [KRİTİK DÜZELTME]: Import yolu 'pubspec.yaml' ile eşleşecek şekilde güncellendi.
import 'package:sentiric_sip_mobile_uac/src/rust/api/simple.dart';
import 'package:sentiric_sip_mobile_uac/src/rust/frb_generated.dart';

import 'dart:io';
import 'dart:ffi';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    if (Platform.isAndroid) {
      try {
        DynamicLibrary.open('libc++_shared.so');
        print("✅ libc++_shared.so loaded manually.");
      } catch (e) {
        print("⚠️ libc++ load warning: $e");
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
      title: 'UAC', // Başlık kısaltıldı
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0F0F0F),
        primaryColor: Colors.greenAccent,
        colorScheme: const ColorScheme.dark(primary: Colors.greenAccent),
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
  // Kontrolcüler
  final TextEditingController _ipController = TextEditingController(text: "34.122.40.122");
  final TextEditingController _portController = TextEditingController(text: "5060");
  final TextEditingController _toController = TextEditingController(text: "9999");
  final TextEditingController _fromController = TextEditingController(text: "mobile-tester");

  final List<String> _logs = [];
  bool _isCalling = false;
  final ScrollController _scrollController = ScrollController();

  void _addLog(String msg) {
    if (!mounted) return;
    setState(() {
      _logs.add(msg);
    });
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
    var status = await Permission.microphone.status;
    if (!status.isGranted) {
      _addLog("🔐 Requesting Microphone permission...");
      status = await Permission.microphone.request();
    }

    if (!status.isGranted) {
      _addLog("❌ Error: Microphone permission denied.");
      if (status.isPermanentlyDenied) openAppSettings();
      return;
    }

    if (_ipController.text.isEmpty) {
      _addLog("❌ Error: Target IP is required!");
      return;
    }

    setState(() {
      _logs.clear();
      _isCalling = true;
    });

    try {
      final int targetPort = int.parse(_portController.text);
      _addLog("🚀 Starting Hardware-Linked SIP Call...");

      final stream = startSipCall(
        targetIp: _ipController.text,
        targetPort: targetPort,
        toUser: _toController.text,
        fromUser: _fromController.text,
      );

      stream.listen(
        (event) {
          _addLog(event);
          if (event.contains("Terminated") || event.contains("ERROR")) {
            setState(() => _isCalling = false);
          }
        },
        onError: (e) {
          _addLog("🔥 Stream Error: $e");
          setState(() => _isCalling = false);
        },
        onDone: () => setState(() => _isCalling = false),
      );
    } catch (e) {
      _addLog("🔥 Critical failure: $e");
      setState(() => _isCalling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('📡 SENTIRIC FIELD MONITOR'),
        backgroundColor: Colors.black,
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _ipController,
                    enabled: !_isCalling,
                    decoration: const InputDecoration(labelText: 'Edge IP', border: OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 1,
                  child: TextField(
                    controller: _portController,
                    enabled: !_isCalling,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Port', border: OutlineInputBorder()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _toController,
                    enabled: !_isCalling,
                    decoration: const InputDecoration(labelText: 'To', border: OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _fromController,
                    enabled: !_isCalling,
                    decoration: const InputDecoration(labelText: 'From', border: OutlineInputBorder()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton.icon(
                onPressed: _isCalling ? null : _handleCall,
                icon: Icon(_isCalling ? Icons.settings_bluetooth : Icons.call),
                label: Text(_isCalling ? "COMMUNICATION ACTIVE" : "START FULL-DUPLEX CALL"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isCalling ? Colors.grey : Colors.green.shade700,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text("REAL-TIME TELECOM EVENTS", style: TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.greenAccent.withOpacity(0.1)),
                ),
                child: ListView.builder(
                  controller: _scrollController,
                  itemCount: _logs.length,
                  itemBuilder: (context, index) {
                    final log = _logs[index];
                    Color textColor = Colors.greenAccent.shade100;
                    if (log.contains("ERROR") || log.contains("Critical")) textColor = Colors.redAccent;
                    if (log.contains("STATUS")) textColor = Colors.white;

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 1),
                      child: Text(
                        log,
                        style: TextStyle(fontFamily: 'monospace', fontSize: 11, color: textColor),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}