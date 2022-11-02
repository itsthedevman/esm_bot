use std::sync::atomic::Ordering;

use crate::{bot::BotRequest, connection_manager::ConnectionManager, *};
use message_io::{
    network::{Endpoint, NetEvent},
    node::{self, NodeHandler, NodeListener},
};
use serde::{Deserialize, Serialize};
use tokio::sync::mpsc::UnboundedReceiver;

pub type Handler = NodeHandler<()>;

#[derive(Serialize, Deserialize, Debug)]
#[serde(tag = "type", content = "content", rename_all = "snake_case")]
pub enum ServerRequest {
    Connect,
    Disconnect(Option<String>),
    Resume,
    Pause,
    Send(Vec<u8>, Box<Message>),

    #[serde(skip)]
    DisconnectEndpoint(Endpoint),

    #[serde(skip)]
    OnConnect(Endpoint),

    #[serde(skip)]
    OnMessage {
        endpoint: Endpoint,
        message_bytes: Vec<u8>,
    },

    #[serde(skip)]
    OnDisconnect(Endpoint),
}

pub async fn initialize(receiver: UnboundedReceiver<ServerRequest>) {
    let (handler, listener) = node::split::<()>();
    routing_thread(handler, receiver).await;
    server_thread(listener).await;
    heartbeat_thread().await;

    info!("[server::initialize] Done");
}

async fn routing_thread(handler: Handler, mut receiver: UnboundedReceiver<ServerRequest>) {
    tokio::spawn(async move {
        let mut connection_manager = ConnectionManager::new();
        while let Some(request) = receiver.recv().await {
            match request {
                ServerRequest::Connect => todo!(), // I'm not sure if this is needed yet

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

                ServerRequest::Send(server_id, message) => {
                    if let Err(e) = connection_manager.send(&handler, &server_id, *message) {
                        error!("{e}")
                    }
                }

                ServerRequest::OnConnect(endpoint) => on_connect(&mut connection_manager, endpoint),

                ServerRequest::OnMessage {
                    endpoint,
                    message_bytes,
                } => on_message(&handler, &mut connection_manager, endpoint, &message_bytes),

                ServerRequest::OnDisconnect(endpoint) => {
                    on_disconnect(&mut connection_manager, endpoint)
                }
            }
        }
    });
}

async fn server_thread(listener: NodeListener<()>) {
    tokio::spawn(async move {
        let not_ready = || {
            !crate::BOT_CONNECTED.load(Ordering::SeqCst)
                || !crate::SERVER_READY.load(Ordering::SeqCst)
        };

        listener.for_each(move |event| match event.network() {
            NetEvent::Connected(_, _) => {} // Unused
            NetEvent::Message(endpoint, message_bytes) => {
                if not_ready() {
                    if let Err(e) = crate::ROUTER.route_to_server(ServerRequest::DisconnectEndpoint(endpoint)) {
                        error!("[server::server_thread] Failed to route disconnect_endpoint to server on Message event. {e}")
                    }
                }

                if let Err(e) =
                    crate::ROUTER.route_to_server(ServerRequest::OnMessage { endpoint, message_bytes: message_bytes.to_vec() })
                {
                    error!("[server::server_thread] Failed to route on_message to server on Message event. {e}")
                }
            }
            NetEvent::Disconnected(endpoint) => {
                if let Err(e) = crate::ROUTER.route_to_server(ServerRequest::OnDisconnect(endpoint)) {
                    error!("[server::server_thread] Failed to route endpoint to server on Accepted event. {e}")
                }
            },
            NetEvent::Accepted(endpoint, _resource_id) => {
                if not_ready() {
                    if let Err(e) = crate::ROUTER.route_to_server(ServerRequest::DisconnectEndpoint(endpoint)) {
                        error!("[server::server_thread] Failed to route disconnect_endpoint to server on Accepted event. {e}")
                    }
                }

                if let Err(e) =
                    crate::ROUTER.route_to_server(ServerRequest::OnConnect(endpoint))
                {
                    error!("[server::server_thread] Failed to route on_connect to server on Accepted event. {e}")
                }
            }
        });
    });
}

async fn heartbeat_thread() {
    todo!("heartbeat_thread and handle lobby");
}

fn on_connect(connection_manager: &mut ConnectionManager, endpoint: Endpoint) {
    debug!(
        "[server::on_connect] Accepting incoming connection with address \"{}\"",
        endpoint.addr()
    );

    connection_manager.add(endpoint)
}

fn on_message(
    handler: &Handler,
    connection_manager: &mut ConnectionManager,
    endpoint: Endpoint,
    message_bytes: &[u8],
) {
    // Extract the server_id from the message
    let server_id = &message_bytes[1..=(message_bytes[0] as usize)];

    // Get the server key to perform the decryption
    let server_key = match connection_manager.server_key(server_id) {
        Some(key) => key,
        None => {
            error!(
                "[server#on_message] Failed to find server key for {}",
                String::from_utf8_lossy(server_id)
            );

            connection_manager.disconnect_endpoint(handler, endpoint);
            return;
        }
    };

    let message = match Message::from_bytes(message_bytes, &server_key) {
        Ok(message) => message,
        Err(e) => {
            error!(
                "[server#on_message] {} - {e}",
                String::from_utf8_lossy(server_id)
            );

            connection_manager.disconnect_endpoint(handler, endpoint);
            return;
        }
    };

    // The client has to encrypt the message with the same server key as the Id
    // Which means that if it fails to decrypt above, the message was invalid and the endpoint is disconnect
    // It's safe to assume this messages is from an authorized source
    if let Type::Init = message.message_type {
        connection_manager.authorize(server_id, &server_key, endpoint);
    }

    info!(
        "[server#on_message] {server_id} - {message_id} - {message_type:?}",
        message_id = message.id,
        server_id = String::from_utf8_lossy(server_id),
        message_type = message.message_type,
    );

    debug!("[server#on_message] \"{}\" - {message:?}", endpoint.addr());

    if let Err(e) = crate::ROUTER.route_to_bot(BotRequest::Send(Box::new(message))) {
        error!("[server#on_message] {e}")
    }
}

fn on_disconnect(connection_manager: &mut ConnectionManager, endpoint: Endpoint) {
    debug!(
        "[server::on_disconnect] \"{}\" - on_disconnect",
        endpoint.addr()
    );

    connection_manager.remove(endpoint);

    if let Err(e) = crate::ROUTER.route_to_bot(BotRequest::Disconnected) {
        error!("[server::on_disconnect] Failed to route disconnected event to bot. {e}")
    }
}
