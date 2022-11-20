use std::collections::HashMap;

use chrono::{Duration, Utc};
use message_io::network::Endpoint;
use redis::Commands;

use crate::{client::Client, server::Handler, *};

pub struct ConnectionManager {
    redis_client: redis::Client,
    lobby: Vec<Client>,
    connections: HashMap<Vec<u8>, Client>,
}

impl ConnectionManager {
    const LOBBY_DISCONNECT_AFTER: i64 = 2;
    const CONNECTION_DISCONNECT_AFTER: i64 = 5;

    pub fn new() -> Self {
        let redis_client = match redis::Client::open(crate::ARGS.lock().redis_uri.to_string()) {
            Ok(c) => c,
            Err(e) => panic!("[new] Failed to connect to redis. {}", e),
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
            None => Err(format!(
                "[send] Message with id:{} cannot be sent to \"{}\" - Unable to find client",
                message.id,
                String::from_utf8_lossy(server_id)
            )),
        }
    }

    pub fn add(&mut self, endpoint: Endpoint) {
        self.lobby.push(Client::new(endpoint));
    }

    pub fn remove(&mut self, endpoint: Endpoint) -> Option<Client> {
        if let Some(index) = self.lobby.iter().position(|c| c.endpoint == endpoint) {
            self.lobby.remove(index);
            return None;
        }

        let server_id = self.connections.iter().find_map(|(server_id, client)| {
            if client.endpoint != endpoint {
                Some(server_id.clone())
            } else {
                None
            }
        })?;

        self.connections.remove(&server_id)
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
        self.remove(endpoint);
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
                error!("[server_key] Failed to convert server_id to string. {e}");
                return None;
            }
        };

        match self.redis_client.hget("server_keys", server_id) {
            Ok(key) => key,
            Err(e) => {
                error!("[server_key] Experienced an error while calling HGET on server_keys. {e}");
                None
            }
        }
    }

    pub fn alive_check(&mut self, handler: &Handler) {
        self.lobby.retain(|client| {
            debug!(
                "[alive_check] lobby - {} - Last checked: {} - Needs disconnected: {}",
                client.server_id(),
                client.last_checked_at,
                (client.last_checked_at + Duration::seconds(Self::LOBBY_DISCONNECT_AFTER))
                    < Utc::now()
            );

            // Clients can only sit in the lobby for 2 seconds before being disconnected
            if (client.last_checked_at + Duration::seconds(Self::LOBBY_DISCONNECT_AFTER))
                < Utc::now()
            {
                trace!(
                    "[alive_check] lobby - {} - Disconnecting",
                    client.server_id()
                );

                client.disconnect(handler);
                return false;
            }

            true
        });

        self.connections.retain(|_, client| {
            trace!(
                "[alive_check] connections - {} - Last checked: {} - Needs disconnected: {}",
                client.server_id(),
                client.last_checked_at,
                (client.last_checked_at + Duration::seconds(Self::CONNECTION_DISCONNECT_AFTER))
                    < Utc::now()
            );

            // Disconnect the client if it's been more than 5 seconds
            if (client.last_checked_at + Duration::seconds(Self::CONNECTION_DISCONNECT_AFTER + 5))
                < Utc::now()
            {
                trace!(
                    "[alive_check] connections - {} - Disconnecting",
                    client.server_id()
                );

                client.disconnect(handler);
                return false;
            }

            // Ping every second
            if client.pong_received
                && (client.last_checked_at + Duration::seconds(Self::CONNECTION_DISCONNECT_AFTER))
                    < Utc::now()
            {
                trace!(
                    "[alive_check] connections - {} - Sending ping",
                    client.server_id()
                );

                if let Err(e) = client.ping(handler) {
                    error!("[alive_check] connections - {e}");
                }
            }

            true
        });
    }

    pub fn on_pong(&mut self, server_id: &[u8]) -> Option<()> {
        let client = self.connections.get_mut(server_id)?;
        client.pong();

        trace!("[on_pong] {}", client.server_id());
        Some(())
    }

    pub fn on_disconnect(&mut self, endpoint: Endpoint) -> Option<Client> {
        let client = self.remove(endpoint)?;
        Some(client)
    }
}
