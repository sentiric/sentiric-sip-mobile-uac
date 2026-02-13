    // lib/telecom_telemetry.dart

class TelemetryEntry {
  final String message;
  final TelemetryLevel level;
  final bool isSipPacket;

  TelemetryEntry({
    required this.message,
    this.level = TelemetryLevel.info,
    this.isSipPacket = false,
  });
}

enum TelemetryLevel { info, status, error, sip }

class TelecomTelemetry {
  /// Rust'tan gelen ham string'i işleyip görselleştirilebilir bir nesneye çevirir.
  static TelemetryEntry parse(String raw) {
    // 1. Durum Değişiklikleri: CallStateChanged(Connected)
    if (raw.startsWith("CallStateChanged(")) {
      final state = raw.substring(17, raw.length - 1);
      return TelemetryEntry(
        message: "🔔 STATUS: $state",
        level: TelemetryLevel.status,
      );
    }

    // 2. Hatalar: Error("...")
    if (raw.startsWith("Error(\"")) {
      final err = raw.substring(7, raw.length - 2);
      return TelemetryEntry(
        message: "❌ ERROR: $err",
        level: TelemetryLevel.error,
      );
    }

    // 3. Loglar ve SIP Paketleri: Log("...")
    if (raw.startsWith("Log(\"")) {
      String content = raw.substring(5, raw.length - 2);
      
      // Kaçış karakterlerini temizle (\n, \", \r)
      content = content.replaceAll("\\n", "\n").replaceAll("\\\"", "\"").replaceAll("\\r", "");

      // SIP Paketi mi? (İçinde SIP/2.0 veya metodlar geçiyor mu?)
      bool isSip = content.contains("SIP/2.0") || 
                   content.contains("INVITE") || 
                   content.contains("ACK");

      return TelemetryEntry(
        message: content,
        level: isSip ? TelemetryLevel.sip : TelemetryLevel.info,
        isSipPacket: isSip,
      );
    }

    return TelemetryEntry(message: raw);
  }
}