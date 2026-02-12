.PHONY: setup generate build-android run-android install-release

# 1. İlk kurulum
setup:
	flutter pub get
	cargo install flutter_rust_bridge_codegen
	cargo install cargo-ndk

# 2. Köprü Kodlarını Üret (Config dosyasını otomatik okur)
generate:
	flutter_rust_bridge_codegen generate
	
# 3. Android için Rust Kütüphanesini Derle (Hem ARM64 hem ARMv7)
build-android:
	# 1. Rust kütüphanesini derle (Statik linkleme parametresini kaldırdık)
	cd rust && cargo ndk -t arm64-v8a -t armeabi-v7a -o ../android/app/src/main/jniLibs build --release
	
	# 2. libc++_shared.so dosyasını bul ve manuel olarak kopyala (Kritik Adım)
	@echo "🔍 C++ Shared Library aranıyor ve kopyalanıyor..."
	
	@# ARM64 için kopyalama
	@mkdir -p android/app/src/main/jniLibs/arm64-v8a
	@find $(ANDROID_HOME)/ndk -name "libc++_shared.so" | grep "aarch64" | head -n 1 | xargs -I {} cp {} android/app/src/main/jniLibs/arm64-v8a/
	@echo "✅ ARM64 libc++_shared.so kopyalandı."

	@# ARMv7 için kopyalama
	@mkdir -p android/app/src/main/jniLibs/armeabi-v7a
	@find $(ANDROID_HOME)/ndk -name "libc++_shared.so" | grep "arm-linux-androideabi" | head -n 1 | xargs -I {} cp {} android/app/src/main/jniLibs/armeabi-v7a/
	@echo "✅ ARMv7 libc++_shared.so kopyalandı."

# 4. Cihaza OTOMATİK YÜKLE VE ÇALIŞTIR (Debug Modu - Hot Reload destekler)
run-android: generate build-android
	flutter run --debug

# 5. Cihaza FİNAL SÜRÜMÜ YÜKLE (Performance Mode)
# Cihaz bağlıyken bunu çalıştırırsan direkt telefona kurar ve açar.
deploy-device: generate build-android
	flutter run --release