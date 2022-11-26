mod bot;
mod client;
mod client_manager;
mod macros;
mod request;
mod router;
mod server;

use lazy_static::lazy_static;
use parking_lot::Mutex;
use std::sync::{atomic::AtomicBool, Arc};
use tokio::runtime::Runtime;

pub use esm_message::{Message, Type};
pub use log::{debug, error, info, trace, warn};

pub use request::*;
pub use router::ROUTER;

pub type ESMResult = Result<(), String>;

lazy_static! {
    /// Is the bot ready to receive messages?
    pub static ref BOT_CONNECTED: AtomicBool = AtomicBool::new(false);

    /// Is the server ready to receive messages?
    pub static ref SERVER_READY: AtomicBool = AtomicBool::new(false);

    /// The runtime for the asynchronous code
    pub static ref TOKIO_RUNTIME: Arc<Runtime> = Arc::new(tokio::runtime::Builder::new_multi_thread().enable_all().build().unwrap());
}

const REDIS_URI: &str = "redis://127.0.0.1";
const SERVER_PORT: &str = "3003";

fn main() {
    env_logger::builder().format_timestamp_millis().init();
    info!("[main] Starting...");

    lazy_static::initialize(&ROUTER);

    // heartbeat_thread is forever blocking
    crate::TOKIO_RUNTIME.block_on(async {
        bot::heartbeat().await;
    });
}
