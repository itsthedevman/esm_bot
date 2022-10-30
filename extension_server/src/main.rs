mod bot;
mod router;
mod server;

use router::Router;

use std::sync::{atomic::AtomicBool, Arc};

use clap::Parser;
use lazy_static::lazy_static;
use parking_lot::Mutex;
use tokio::runtime::Runtime;

pub use esm_message::Message;
pub use log::{debug, error, info, trace, warn};

pub type ESMResult = Result<(), String>;

lazy_static! {
    /// Is the bot ready to receive messages?
    pub static ref BOT_CONNECTED: AtomicBool = AtomicBool::new(false);

    /// Is the server ready to receive messages?
    pub static ref SERVER_READY: AtomicBool = AtomicBool::new(false);

    /// The runtime for the asynchronous code
    pub static ref TOKIO_RUNTIME: Arc<Runtime> = Arc::new(tokio::runtime::Builder::new_multi_thread().enable_all().build().unwrap());

    /// Handles sending messages to the Bot and the A3 server
    pub static ref ROUTER: Arc<Router> = Arc::new(Router::new());

    /// This executables arguments
    pub static ref ARGS: Arc<Mutex<Args>> = Arc::new(Mutex::new(Args { port: "".into(), redis_uri: "".into() }));
}

#[derive(Parser, Debug)]
pub struct Args {
    /// The port that the server will use
    #[arg(short, long, default_value_t = String::from("3003"))]
    port: String,

    /// The URI to the redis server the bot is connected to
    #[arg(short, long, default_value_t = String::from("redis://127.0.0.1/"))]
    redis_uri: String,
}

fn main() {
    env_logger::init();
    info!("[main] Initializing...");

    // Must be the first thing to happen
    *ARGS.lock() = Args::parse();

    lazy_static::initialize(&ROUTER);
    info!("[main] Router Started");

    // heartbeat_thread is forever blocking
    crate::TOKIO_RUNTIME.block_on(async {
        bot::heartbeat_thread().await;
    });
}
