import 'package:flutter/material.dart';
import 'package:sentiric_mobile_sip_uac/src/rust/api/simple.dart';
import 'package:sentiric_mobile_sip_uac/src/rust/frb_generated.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await RustLib.init();
  await initLogger();
  runApp(const SentiricApp());
}

class SentiricApp extends StatelessWidget {
  const SentiricApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0F0F0F),
        primaryColor: Colors.greenAccent,
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
          labelStyle: TextStyle(color: Colors.greenAccent),
          focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.greenAccent)),
        ),
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
    Future.delayed(const Duration(milliseconds: 50), () {
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
    // Basit Validasyon
    if (_ipController.text.isEmpty || _portController.text.isEmpty) {
      _addLog("ERROR: IP and Port are required!");
      return;
    }

    setState(() {
      _logs.clear();
      _isCalling = true;
    });

    try {
      final int targetPort = int.parse(_portController.text);
      
      _addLog("🚀 Initializing Call Flow...");
      
      // Rust Çekirdek Çağrısı
      final stream = startSipCall(
        targetIp: _ipController.text,
        targetPort: targetPort,
        toUser: _toController.text,
        fromUser: _fromController.text,
      );

      stream.listen(
        (event) {
          _addLog(event);
          if (event == "FINISH") {
            setState(() => _isCalling = false);
            _addLog("🏁 Session Closed.");
          }
        },
        onError: (e) {
          _addLog("❌ Stream Error: $e");
          setState(() => _isCalling = false);
        },
        onDone: () => setState(() => _isCalling = false),
      );
    } catch (e) {
      _addLog("🔥 Critical Exception: $e");
      setState(() => _isCalling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('📡 SENTIRIC FIELD TESTER'),
        centerTitle: true,
        backgroundColor: Colors.black,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Column(
          children: [
            const SizedBox(height: 10),
            // Input Grid
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _ipController,
                    enabled: !_isCalling,
                    decoration: const InputDecoration(labelText: 'Target IP / Host'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 1,
                  child: TextField(
                    controller: _portController,
                    enabled: !_isCalling,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Port'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _toController,
                    enabled: !_isCalling,
                    decoration: const InputDecoration(labelText: 'Dial (To)'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _fromController,
                    enabled: !_isCalling,
                    decoration: const InputDecoration(labelText: 'Identity (From)'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 15),
            // Action Button
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton.icon(
                onPressed: _isCalling ? null : _handleCall,
                icon: Icon(_isCalling ? Icons.hourglass_empty : Icons.call),
                label: Text(_isCalling ? "COMMUNICATING..." : "INITIATE SIP CALL", 
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.greenAccent.shade700,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey.shade900,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Monitor Title
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("LIVE TELECOM MONITOR", style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
                if (_isCalling)
                  const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.greenAccent)),
              ],
            ),
            const SizedBox(height: 8),
            // Log Console
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(color: Colors.greenAccent.withOpacity(0.2)),
                ),
                child: ListView.builder(
                  controller: _scrollController,
                  itemCount: _logs.length,
                  itemBuilder: (context, index) {
                    final isError = _logs[index].contains("ERROR") || _logs[index].contains("CRITICAL");
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text(
                        _logs[index],
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                          color: isError ? Colors.redAccent : Colors.greenAccent.withOpacity(0.9),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}