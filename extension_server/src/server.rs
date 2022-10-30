use std::collections::HashMap;

use crate::*;
use message_io::{
    network::{Endpoint, NetEvent, SendStatus},
    node::{self, NodeHandler, NodeListener},
};
use redis::Commands;
use serde::{Deserialize, Serialize};
use tokio::sync::mpsc::UnboundedReceiver;

lazy_static! {
    static ref CONNECTION_MANAGER: Arc<Mutex<ConnectionManager>> =
        Arc::new(Mutex::new(ConnectionManager::new()));
}

type Handler = NodeHandler<()>;

#[derive(Serialize, Deserialize, Debug)]
#[serde(tag = "type", content = "content", rename_all = "snake_case")]
pub enum ServerRequest {
    Connect,
    Disconnect(Option<String>),
    Resume,
    Pause,
    Send(Box<Message>),
}

pub async fn initialize(receiver: UnboundedReceiver<ServerRequest>) {
    let (handler, listener) = node::split::<()>();
    command_thread(handler, receiver).await;
    server_thread(listener).await;

    info!("[server::initialize] Done");
}

async fn command_thread(handler: Handler, mut receiver: UnboundedReceiver<ServerRequest>) {
    tokio::spawn(async move {
        while let Some(request) = receiver.recv().await {
            match request {
                ServerRequest::Connect => todo!(), // I'm not sure if this is needed yet
                ServerRequest::Disconnect(server_id) => todo!(), // If there is a server_id, drop that one client. Otherwise, drop all clients
                ServerRequest::Resume => todo!(),                // Set flag
                ServerRequest::Pause => todo!(), // Set flag and disconnect all clients
                ServerRequest::Send(_) => todo!(), // Send message to client
            }
        }
    });
}

async fn server_thread(listener: NodeListener<()>) {
    tokio::spawn(async move {
        listener.for_each(move |event| match event.network() {
            NetEvent::Connected(_, _) => {} // Unused
            NetEvent::Message(endpoint, data) => {
                // Check if the client is still connected
                // Trigger on_message
            }
            NetEvent::Disconnected(endpoint) => (), // On disconnect
            NetEvent::Accepted(endpoint, resource_id) => {
                // Check if the client is still connected
                // Trigger on_connect
            }
        });
    });
}

async fn heartbeat_thread() {}

struct ConnectionManager {
    redis_client: redis::Client,
    lobby: Vec<Endpoint>,

    // TODO: Convert to storing Client (which stores the endpoint)
    connections: HashMap<Vec<u8>, Endpoint>,
}

impl ConnectionManager {
    pub fn new() -> Self {
        let redis_client = match redis::Client::open(crate::ARGS.lock().redis_uri.to_string()) {
            Ok(c) => c,
            Err(e) => panic!(
                "[server::ConnectionManager::new] Failed to connect to redis. {}",
                e
            ),
        };

        ConnectionManager {
            redis_client,
            lobby: Vec::new(),
            connections: HashMap::new(),
        }
    }

    pub fn send(&mut self, handler: Handler, message: Message) -> ESMResult {
        let server_id = match &message.server_id {
            Some(id) => id,
            None => return Err(format!("[server::ConnectionManager::send] Message with id:{} cannot be sent - server_id was not provided", message.id)),
        };

        let endpoint = match self.connections.get(server_id) {
            Some(endpoint) => endpoint.to_owned(),
            None => return Err(format!("[server::ConnectionManager::send] Message with id:{} cannot be sent - Unable to find endpoint", message.id)),
        };

        let server_key = match self.server_key(server_id) {
            Some(key) => key,
            None => return Err(format!("[server::ConnectionManager::send] Message with id:{} cannot be sent - Unable to find server key", message.id)),
        };

        match message.as_bytes(&server_key) {
            Ok(bytes) => match handler.network().send(endpoint, &bytes) {
                SendStatus::Sent => {
                    info!(
                        "[server::ConnectionManager::send] Message with id:{} sent to \"{}\"",
                        message.id,
                        String::from_utf8_lossy(server_id)
                    );

                    Ok(())
                }
                SendStatus::MaxPacketSizeExceeded => Err(format!(
                    "[server::ConnectionManager::send] Cannot send to \"{}\" - Message is too large. Size: {}. Message: {message:?}", String::from_utf8_lossy(server_id), bytes.len()
                )),
                s => Err(format!("[server::ConnectionManager::send] Cannot send to \"{}\" - {s:?}. Message: {message:?}", String::from_utf8_lossy(server_id)))
            },
            Err(error) => Err(error),
        }
    }

    pub fn connect(&mut self, endpoint: Endpoint) {
        self.lobby.push(endpoint);
    }

    pub fn accept(&mut self, server_id: &[u8], endpoint: Endpoint) -> Option<()> {
        let endpoint = self.lobby.iter().find(|e| **e == endpoint)?;
        self.connections.insert(server_id.to_vec(), *endpoint);
        Some(())
    }

    pub fn disconnect(&mut self, server_id: &[u8]) {
        self.connections.remove(server_id);
    }

    pub fn disconnect_endpoint(&mut self, handler: Handler, endpoint: Endpoint) {
        if let Some(index) = self.lobby.iter().position(|e| *e == endpoint) {
            self.lobby.remove(index);
        }

        self.connections.retain(|_, e| *e != endpoint);

        handler.network().remove(endpoint.resource_id());
    }

    pub fn disconnect_all(&mut self, handler: Handler) {
        for endpoint in self.lobby.iter() {
            handler.network().remove(endpoint.resource_id());
        }

        self.lobby.clear();

        for endpoint in self.connections.values() {
            handler.network().remove(endpoint.resource_id());
        }

        self.connections.clear();
    }

    pub fn server_key(&mut self, server_id: &[u8]) -> Option<Vec<u8>> {
        let server_id = match String::from_utf8(server_id.to_owned()) {
            Ok(id) => id,
            Err(e) => {
                error!("[server::ConnectionManager::server_key] Failed to convert server_id to string. {e}");
                return None;
            }
        };

        match self.redis_client.hget("server_keys", server_id) {
            Ok(key) => key,
            Err(e) => {
                error!("[server::ConnectionManager::server_key] Experienced an error while calling HGET on server_keys. {e}");
                None
            }
        }
    }
}
