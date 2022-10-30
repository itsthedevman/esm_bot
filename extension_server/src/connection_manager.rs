use std::collections::HashMap;

use message_io::network::Endpoint;
use redis::Commands;

use crate::{client::Client, server::Handler, *};

pub struct ConnectionManager {
    redis_client: redis::Client,
    lobby: Vec<Client>,
    connections: HashMap<Vec<u8>, Client>,
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

    pub fn send(&mut self, handler: &Handler, server_id: &[u8], message: Message) -> ESMResult {
        match self.connections.get(server_id) {
            Some(client) => client.send(handler, message),
            None => Err(format!("[server::ConnectionManager::send] Message with id:{} cannot be sent to \"{}\" - Unable to find client", message.id, String::from_utf8_lossy(server_id))),
        }
    }

    pub fn add(&mut self, endpoint: Endpoint) {
        self.lobby.push(Client::new(endpoint));
    }

    pub fn authorize(
        &mut self,
        server_id: &[u8],
        server_key: &[u8],
        endpoint: Endpoint,
    ) -> Option<()> {
        let index = self.lobby.iter().position(|c| c.endpoint == endpoint)?;
        let mut client = self.lobby.remove(index);

        client.associate(server_id, server_key);

        self.connections.insert(server_id.to_vec(), client);

        Some(())
    }

    pub fn disconnect(&mut self, handler: &Handler, server_id: &[u8]) {
        if let Some(client) = self.connections.remove(server_id) {
            client.disconnect(handler);
        }
    }

    pub fn disconnect_endpoint(&mut self, handler: &Handler, endpoint: Endpoint) {
        if let Some(index) = self.lobby.iter().position(|c| c.endpoint == endpoint) {
            self.lobby.remove(index);
        }

        self.connections.retain(|_, c| c.endpoint != endpoint);

        handler.network().remove(endpoint.resource_id());
    }

    pub fn disconnect_all(&mut self, handler: &Handler) {
        for client in self.lobby.iter() {
            client.disconnect(handler);
        }

        self.lobby.clear();

        for client in self.connections.values() {
            client.disconnect(handler);
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
