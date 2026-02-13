// sentiric-mobile-sip-uac/rust/src/api/simple.rs

// [KRİTİK]: Doğru SDK'dan, doğru yapıları import et.
use sentiric_telecom_client_sdk::{TelecomClient, UacEvent}; 
use crate::frb_generated::StreamSink;
use log::{info, LevelFilter};
use android_logger::Config;
use tokio::sync::mpsc;

/// Uygulama ilk açıldığında Rust loglarını Android sistemine bağlar.
pub fn init_logger() {
    // Bu fonksiyonun içeriği aynı kalabilir
    android_logger::init_once(
        Config::default()
            .with_max_level(LevelFilter::Info)
            .with_tag("SENTIRIC-RUST"),
    );
    info!("✅ Rust Logger initialized for Android (Telecom SDK v2).");
}

/// SIP çağrısını başlatır ve olayları anlık olarak stream eder.
pub async fn start_sip_call(
    target_ip: String,
    target_port: u16,
    to_user: String,
    from_user: String,
    sink: StreamSink<String>, 
) -> anyhow::Result<()> {
    // Bu fonksiyonun içeriği de bir öncekiyle aynı, sadece importlar önemli.
    let (tx, mut rx) = mpsc::channel::<UacEvent>(100);
    
    let client = TelecomClient::new(tx);

    tokio::spawn(async move {
        while let Some(event) = rx.recv().await {
            let msg = match event {
                UacEvent::Log(m) => format!("[LOG] {}", m),
                UacEvent::CallStateChanged(state) => format!("STATUS: {:?}", state), 
                UacEvent::Error(e) => format!("ERROR: {}", e),
            };
            
            info!("{}", msg); 
            
            if sink.add(msg).is_err() {
                break;
            }
        }
    });

    client.start_call(target_ip, target_port, to_user, from_user).await?;
    
    Ok(())
}