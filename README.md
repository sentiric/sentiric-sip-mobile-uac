# 📱 Sentiric SIP Mobile UAC

[![Status](https://img.shields.io/badge/status-active-success.svg)]()
[![Language](https://img.shields.io/badge/language-Flutter%20%7C%20Rust-blue.svg)]()

**Sentiric SIP Mobile UAC**, Sentiric telekomünikasyon altyapısını saha koşullarında (4G/5G) test etmek için geliştirilmiş, Flutter ve Rust tabanlı bir mobil istemcidir.

## 🏗️ Mimari

Uygulama, "Akıllı Motor, Sade Arayüz" prensibini benimser:

*   **Motor (Core):** Tüm SIP ve RTP mantığı, `sentiric-telecom-client-sdk` (Rust) tarafından yönetilir.
*   **Arayüz (UI):** Kullanıcı etkileşimi ve olayların gösterimi Flutter (Dart) ile yapılır.
*   **Köprü (Bridge):** İki dünya arasındaki iletişim `flutter_rust_bridge` ile sağlanır.

## 🚀 Hızlı Başlangıç

Tüm süreçler `Makefile` üzerinden otomatize edilmiştir:

```bash
# Gerekli araçları kur ve köprü kodunu üret
make generate

# Uygulamayı Android cihazda derle ve çalıştır
make run-android
```

© 2026 Sentiric Team | GNU AGPL-3.0 License