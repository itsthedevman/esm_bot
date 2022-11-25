use crate::{connection_manager::ConnectionManager, *};

use message_io::{
    network::{Endpoint, NetEvent, Transport},
    node::{self, NodeHandler, NodeListener, NodeTask},
};
use std::{sync::atomic::Ordering, time::Duration};
use tokio::sync::mpsc::UnboundedReceiver;

lazy_static! {
    static ref LISTENER_TASK: Arc<Mutex<Option<NodeTask>>> = Arc::new(Mutex::new(None));
}

pub type Handler = NodeHandler<()>;

const HEARTBEAT_WAIT_MS: u64 = 1500;

pub async fn initialize(receiver: UnboundedReceiver<ServerRequest>) {
    let (handler, listener) = node::split::<()>();

    // Start listening
    match handler.network().listen(
        Transport::FramedTcp,
        format!("0.0.0.0:{}", crate::ARGS.lock().port),
    ) {
        Ok((_resource_id, real_addr)) => {
            info!("[initialize] ✅ Listening on port {real_addr}");
            crate::SERVER_READY.store(true, Ordering::SeqCst)
        }
        Err(e) => panic!("[initialize] Failed to start server. {}", e),
    }

    routing_thread(handler, receiver).await;
    listener_thread(listener).await;
    heartbeat_thread().await;
}

async fn routing_thread(handler: Handler, mut receiver: UnboundedReceiver<ServerRequest>) {
    tokio::spawn(async move {
        info!("[routing_thread] ✅");

        let mut connection_manager = ConnectionManager::new();

        loop {
            let Some(request) = receiver.recv().await else {
                continue;
            };

            trace!("[routing_thread] Processing request: {request:?}");

            match request {
                ServerRequest::Disconnect(server_id) => match server_id {
                    Some(id) => connection_manager.disconnect(&handler, id.as_bytes()),
                    None => connection_manager.disconnect_all(&handler),
                },

                ServerRequest::DisconnectEndpoint(endpoint) => {
                    connection_manager.disconnect_endpoint(&handler, endpoint);
                }

                ServerRequest::Resume => crate::SERVER_READY.store(true, Ordering::SeqCst),

                ServerRequest::Pause => {
                    crate::SERVER_READY.store(false, Ordering::SeqCst);
                    connection_manager.disconnect_all(&handler);
                }

                ServerRequest::Send { server_id, message } => {
                    if let Err(e) = connection_manager.send(&handler, &server_id, *message) {
                        error!("{e}")
                    }
                }

                ServerRequest::AliveCheck => connection_manager.alive_check(&handler),

                ServerRequest::OnConnect(endpoint) => on_connect(endpoint),

                ServerRequest::OnMessage {
                    endpoint,
                    message_bytes,
                } => {
                    if let Err(e) = on_message(&mut connection_manager, endpoint, &message_bytes) {
                        connection_manager.disconnect_endpoint(&handler, endpoint);
                        error!("{e}");
                    }
                }
                ServerRequest::OnDisconnect(endpoint) => {
                    if let Err(e) = on_disconnect(&mut connection_manager, endpoint) {
                        error!("{e}");
                    }
                }
            }
        }
    });
}

async fn listener_thread(listener: NodeListener<()>) {
    tokio::spawn(async move {
        let ready = || {
            crate::BOT_CONNECTED.load(Ordering::SeqCst)
                && crate::SERVER_READY.load(Ordering::SeqCst)
        };

        let task = listener.for_each_async(move |event| match event.network() {
            NetEvent::Accepted(endpoint, _resource_id) => {
                trace!("[listener_thread] {} - accepted - are we ready? {}", endpoint.addr(), ready());

                if !ready() {
                    if let Err(e) = ServerRequest::disconnect_endpoint(endpoint) {
                        error!("[listener_thread] Failed to route disconnect_endpoint to server on Accepted event. {e}")
                    }

                    return
                }

                if let Err(e) = ServerRequest::on_connect(endpoint)
                {
                    error!("[listener_thread] Failed to route on_connect to server on Accepted event. {e}")
                }
            }
            NetEvent::Connected(_, _) => unreachable!(), // Unused
            NetEvent::Disconnected(endpoint) => {
                if let Err(e) = ServerRequest::on_disconnect(endpoint) {
                    error!("[listener_thread] Failed to route endpoint to server on Accepted event. {e}")
                }
            },
            NetEvent::Message(endpoint, message_bytes) => {
                if !ready() {
                    if let Err(e) = ServerRequest::disconnect_endpoint(endpoint) {
                        error!("[listener_thread] Failed to route disconnect_endpoint to server on Message event. {e}")
                    }
                }

                if let Err(e) = ServerRequest::on_message(endpoint, message_bytes)
                {
                    error!("[listener_thread] Failed to route on_message to server on Message event. {e}")
                }
            }
        });

        *lock!(LISTENER_TASK) = Some(task);

        info!("[listener_thread] ✅");
    });
}

async fn heartbeat_thread() {
    tokio::spawn(async {
        info!("[heartbeat_thread] ✅");

        loop {
            tokio::time::sleep(Duration::from_millis(HEARTBEAT_WAIT_MS)).await;

            if let Err(e) = ServerRequest::alive_check() {
                error!("[heartbeat_thread] Failed to route alive_check to server {e}")
            }
        }
    });
}

fn on_connect(endpoint: Endpoint) {
    debug!("[on_connect] \"{}\"", endpoint.addr());

    ServerRequest::send(server_id, message)
}

fn on_message(
    connection_manager: &mut ConnectionManager,
    endpoint: Endpoint,
    message_bytes: &[u8],
) -> ESMResult {
    let server_id = &message_bytes[1..=(message_bytes[0] as usize)];
    let message = connection_manager.authenticate(endpoint, server_id, message_bytes)?;
    trace!("[on_message] \"{}\" - {message:#?}", endpoint.addr());

    // Not all messages are for the bot to ingest
    let Some(message) = message else {
        return Ok(());
    };

    info!(
        "[on_message] \"{address}\" - {server_id} - {message_type:?} - {message_id}",
        address = endpoint.addr(),
        message_id = message.id,
        server_id = String::from_utf8_lossy(server_id),
        message_type = message.message_type,
    );

    BotRequest::message(message)
}

fn on_disconnect(connection_manager: &mut ConnectionManager, endpoint: Endpoint) -> ESMResult {
    debug!("[on_disconnect] \"{}\"", endpoint.addr());

    let Some(server_id) = connection_manager.on_disconnect(endpoint) else {
        return Err(format!("[on_disconnect] {} - Failed to mark disconnected", endpoint.addr()));
    };

    BotRequest::disconnected(&server_id)
}
