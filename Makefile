.PHONY: setup generate sync-sdk build-android run-android deploy-device clean-android clean-all

# ==============================================================================
# SENTIRIC MOBILE UAC - ORCHESTRATION MAKEFILE (v2.1 - Strict Sync)
# ==============================================================================

# 1. İlk kurulum (SDK'lar ve araçlar için)
setup:
	@echo "--- 🛠️ Gerekli araçlar kuruluyor... ---"
	flutter pub get
	cargo install flutter_rust_bridge_codegen --version 2.11.1
	cargo install cargo-ndk

# 2. SDK Senkronizasyonu (KRİTİK ADIM)
# Cargo.lock dosyasını ezerek SDK'yı en son commite günceller.
sync-sdk:
	@echo "--- 🔄 Telecom SDK Senkronize Ediliyor (Cargo Update)... ---"
	cd rust && cargo update -p sentiric-telecom-client-sdk
	@echo "✅ SDK Güncellendi."

# 3. Köprü Kodlarını Üret
# SDK güncellendikten SONRA çalışmalıdır ki yeni imzalar algılansın.
generate:
	@echo "--- 🌉 Rust/Dart köprü kodları üretiliyor... ---"
	flutter_rust_bridge_codegen generate
	
# 4. Android için Rust Kütüphanesini Derle (C++ bağımlılıkları dahil)
build-android:
	@echo "--- 🦀 Rust çekirdeği Android için derleniyor... ---"
	# ANDROID_HOME environment variable'ının sistemde tanımlı olduğunu varsayıyoruz.
	cd rust && cargo ndk -t arm64-v8a -t armeabi-v7a -o ../android/app/src/main/jniLibs build --release
	
	# libc++_shared.so dosyasını bul ve manuel olarak kopyala (Kritik Adım)
	@echo "🔍 C++ Shared Library aranıyor ve kopyalanıyor..."
	@mkdir -p android/app/src/main/jniLibs/arm64-v8a
	@find $$(echo $$ANDROID_HOME)/ndk -name "libc++_shared.so" | grep "aarch64" | head -n 1 | xargs -I {} cp {} android/app/src/main/jniLibs/arm64-v8a/
	@echo "✅ ARM64 libc++_shared.so kopyalandı."
	@mkdir -p android/app/src/main/jniLibs/armeabi-v7a
	@find $$(echo $$ANDROID_HOME)/ndk -name "libc++_shared.so" | grep "arm-linux-androideabi" | head -n 1 | xargs -I {} cp {} android/app/src/main/jniLibs/armeabi-v7a/
	@echo "✅ ARMv7 libc++_shared.so kopyalandı."

# 5. Temizlik Hedefleri (Ayrıştırıldı)
clean-android:
	@echo "--- 🧹 Flutter & Android artıkları temizleniyor... ---"
	flutter clean
	rm -rf android/app/src/main/jniLibs/*

clean-all: clean-android
	@echo "--- 🧹 Rust derleme önbelleği temizleniyor... ---"
	rm -rf rust/target

# 6. Cihaza OTOMATİK YÜKLE VE ÇALIŞTIR (Debug Modu)
# [AKIŞ]: Temizle -> SDK Güncelle -> Kod Üret -> Derle -> Çalıştır
run-android: clean-android sync-sdk generate build-android
	@echo "--- 🚀 Uygulama cihaza yükleniyor (Debug)... ---"
	flutter run --debug

# 7. Cihaza FİNAL SÜRÜMÜ YÜKLE (Performance Mode)
deploy-device: clean-android sync-sdk generate build-android
	@echo "--- 🚀 Uygulama cihaza yükleniyor (Release)... ---"
	flutter run --release