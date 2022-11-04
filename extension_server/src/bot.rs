use std::{sync::atomic::Ordering, time::Duration};

use crate::{server::ServerRequest, *};

use redis::AsyncCommands;
use serde::{Deserialize, Serialize};
use tokio::{sync::mpsc::UnboundedReceiver, time::sleep};

lazy_static! {
    static ref PONG_RECEIVED: AtomicBool = AtomicBool::new(true);
}

#[derive(Serialize, Deserialize, Debug)]
#[serde(tag = "type", content = "content", rename_all = "snake_case")]
pub enum BotRequest {
    // {"type":"server_request","content":{"type":"connect"}}
    ServerRequest(ServerRequest),
    Ping,
    Pong,
    RouteToClient {
        server_id: Vec<u8>,
        message: Box<Message>,
    },
    Message(Box<Message>),

    // Stores a server_id
    Disconnected(Vec<u8>),
}

/// Initializes the various processes needed for the "bot" side of the server to run
pub async fn initialize(receiver: UnboundedReceiver<BotRequest>) {
    routing_thread(receiver).await;

    ipc_thread().await;
    delegation_thread().await;
}

/// Manages a ping based heartbeat with esm_bot to ensure messages can be sent back and forth
/// This function is blocking
pub async fn heartbeat() {
    info!("[heartbeat] ✅");

    loop {
        sleep(Duration::from_millis(500)).await;

        if !PONG_RECEIVED.load(Ordering::SeqCst) {
            continue;
        }

        // Set the flag back to false before sending the ping
        PONG_RECEIVED.store(false, Ordering::SeqCst);

        if let Err(e) = crate::ROUTER.route_to_bot(BotRequest::Ping) {
            error!("[heartbeat] Ping attempt experienced an error. {e}");
            continue;
        }

        // Give the bot up to 200ms to reply before considering it "offline"
        let mut currently_alive = false;
        for _ in 0..200 {
            if PONG_RECEIVED.load(Ordering::SeqCst) {
                currently_alive = true;
                break;
            }

            sleep(Duration::from_millis(1)).await;
        }

        // Only write and log if the status has changed
        let previously_alive = crate::BOT_CONNECTED.load(Ordering::SeqCst);
        if currently_alive == previously_alive {
            continue;
        }

        crate::BOT_CONNECTED.store(currently_alive, Ordering::SeqCst);

        if currently_alive {
            info!("[heartbeat] Connected");
            continue;
        }

        warn!("[heartbeat] Disconnected");

        if let Err(e) = crate::ROUTER.route_to_server(ServerRequest::Disconnect(None)) {
            error!("[heartbeat] Failed to route disconnect all to server. {e}");
        }
    }
}

/// Manages internal requests and routes them to esm_bot
async fn routing_thread(mut receiver: UnboundedReceiver<BotRequest>) {
    tokio::spawn(async move {
        info!("[routing_thread] ✅");

        let redis_client = match redis::Client::open(crate::ARGS.lock().redis_uri.to_string()) {
            Ok(c) => c,
            Err(e) => panic!("[routing_thread] Failed to connect to redis. {}", e),
        };

        while let Some(request) = receiver.recv().await {
            let json: String = match serde_json::to_string(&request) {
                Ok(s) => s,
                Err(e) => {
                    error!("[routing_thread] Failed to convert BotRequest into String. {e}");
                    continue;
                }
            };

            let mut connection = match redis_client.get_multiplexed_tokio_connection().await {
                Ok(connection) => connection,
                Err(e) => {
                    error!("[routing_thread] Failed to retrieve redis connection. {e}");
                    continue;
                }
            };

            trace!("[routing_thread] {json:?}");

            match redis::cmd("RPUSH")
                .arg("server_outbound")
                .arg(json)
                .query_async(&mut connection)
                .await
            {
                Ok(r) => r,
                Err(e) => {
                    error!("[routing_thread] Failed to RPUSH json into server_outbound. {e}");
                }
            };
        }
    });
}

/// Manages messages inbound from esm_bot and routes them to their destination
async fn ipc_thread() {
    let redis_client = match redis::Client::open(crate::ARGS.lock().redis_uri.to_string()) {
        Ok(c) => c,
        Err(e) => panic!("[initialize] Failed to connect to redis. {}", e),
    };

    tokio::spawn(async move {
        info!("[ipc_thread] ✅");

        let mut connection = match redis_client.get_multiplexed_tokio_connection().await {
            Ok(connection) => connection,
            Err(e) => panic!("[ipc_thread] Failed to retrieve redis connection. {}", e),
        };

        loop {
            let (_, json): (String, String) = match connection.blpop("server_inbound", 0).await {
                Ok(json) => json,
                Err(e) => {
                    error!("[ipc_thread] server_inbound blpop encountered an error. {e:?}");
                    continue;
                }
            };

            let command: BotRequest = match serde_json::from_str(&json) {
                Ok(message) => message,
                Err(e) => {
                    error!("[ipc_thread] Conversion from str to BotRequest failed. {e}");
                    error!("[ipc_thread] Input: {json:#?}");
                    continue;
                }
            };

            trace!("[ipc_thread] {command:?}");

            match command {
                BotRequest::ServerRequest(r) => {
                    if let Err(e) = crate::ROUTER.route_to_server(r) {
                        error!("[ipc_thread] Error while sending request to server. {e}");
                    }
                }
                BotRequest::Pong => {
                    PONG_RECEIVED.store(true, Ordering::SeqCst);
                }
                BotRequest::RouteToClient { server_id, message } => {
                    if let Err(e) =
                        crate::ROUTER.route_to_server(ServerRequest::Send { server_id, message })
                    {
                        error!("[ipc_thread] Error while sending message to client. {e}");
                    }
                }
                c => error!("[ipc_thread] Unsupported command \"{c:?}\"."),
            };
        }
    });
}

/// This functions supports the ipc_thread by moving messages from esm_bot's outbound queue into the inbound queue
async fn delegation_thread() {
    let redis_client = match redis::Client::open(crate::ARGS.lock().redis_uri.to_string()) {
        Ok(c) => c,
        Err(e) => panic!("[delegation_thread] Failed to connect to redis. {}", e),
    };

    tokio::spawn(async move {
        info!("[delegation_thread] ✅");

        let mut connection = match redis_client.get_multiplexed_tokio_connection().await {
            Ok(connection) => connection,
            Err(e) => panic!(
                "[delegation_thread] Failed to retrieve redis connection. {}",
                e
            ),
        };

        loop {
            match redis::cmd("BLMOVE")
                .arg("bot_outbound")
                .arg("server_inbound")
                .arg("LEFT")
                .arg("RIGHT")
                .arg(0)
                .query_async(&mut connection)
                .await
            {
                Ok(r) => r,
                Err(e) => error!("[delegation_thread] Failed to BLMOVE server_inbound. {e}"),
            };
        }
    });
}
