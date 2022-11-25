use std::collections::HashMap;

use chrono::{Duration, Utc};
use message_io::network::Endpoint;
use redis::Commands;

use crate::{client::Client, server::Handler, *};

pub struct ConnectionManager {
    redis_client: redis::Client,
    connections: HashMap<Vec<u8>, Client>,
}

impl ConnectionManager {
    const DISCONNECT_AFTER: i64 = 10;
    const PING_AFTER: i64 = 5;

    pub fn new() -> Self {
        let redis_client = match redis::Client::open(crate::ARGS.lock().redis_uri.to_string()) {
            Ok(c) => c,
            Err(e) => panic!("[new] Failed to connect to redis. {}", e),
        };

        ConnectionManager {
            redis_client,
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

    pub fn add(&mut self, endpoint: Endpoint, server_id: &[u8], server_key: &[u8]) {
        self.connections.insert(
            server_id.to_vec(),
            Client::new(endpoint, server_id, server_key),
        );
    }

    pub fn remove(&mut self, endpoint: Endpoint) -> Option<Client> {
        let server_id = self.connections.iter().find_map(|(server_id, client)| {
            if client.endpoint != endpoint {
                Some(server_id.clone())
            } else {
                None
            }
        })?;

        self.connections.remove(&server_id)
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
        for client in self.connections.values() {
            client.disconnect(handler);
        }

        self.connections.clear();
    }

    pub fn alive_check(&mut self, handler: &Handler) {
        self.connections.retain(|_, client| {
            if !client.connected {
                return false;
            }

            debug!(
                "[alive_check] connections - {} ({}) - Last checked: {} - Needs disconnected: {}",
                client.network_address(),
                client.server_id(),
                client.last_checked_at,
                (client.last_checked_at + Duration::seconds(Self::DISCONNECT_AFTER)) < Utc::now()
            );

            // Disconnect the client if it's been more than 5 seconds
            if (client.last_checked_at + Duration::seconds(Self::DISCONNECT_AFTER)) < Utc::now() {
                warn!(
                    "[alive_check] connections - {} ({}) - Disconnecting",
                    client.network_address(),
                    client.server_id()
                );

                client.disconnect(handler);
                return false;
            }

            // Ping
            if client.pong_received
                && (client.last_checked_at + Duration::seconds(Self::PING_AFTER)) < Utc::now()
            {
                trace!(
                    "[alive_check] connections - {} ({}) - Sending ping",
                    client.network_address(),
                    client.server_id()
                );

                if let Err(e) = client.ping(handler) {
                    error!(
                        "[alive_check] connections - {} ({}) - {e}",
                        client.network_address(),
                        client.server_id()
                    );
                }
            }

            true
        });
    }

    pub fn on_disconnect(&mut self, endpoint: Endpoint) -> Option<Vec<u8>> {
        let (server_id, client) = self
            .connections
            .iter_mut()
            .find_map(|(server_id, client)| {
                if client.endpoint == endpoint {
                    Some((server_id, client))
                } else {
                    None
                }
            })?;

        client.connected = false;

        Some(server_id.to_owned())
    }

    pub fn authenticate(
        &mut self,
        endpoint: Endpoint,
        server_id: &[u8],
        message_bytes: &[u8],
    ) -> Result<Option<Message>, String> {
        // Get the server key to perform the decryption
        let server_key = match self.server_key(server_id) {
            Some(key) => key,
            None => {
                return Err(format!(
                    "[authenticate] {} - Failed to find server key",
                    String::from_utf8_lossy(server_id)
                ))
            }
        };

        // The client has to encrypt the message with the same server key as the Id
        // Which means that if it fails to decrypt, the message was invalid and the endpoint is disconnected
        // It's safe to assume this endpoint is who they say they are
        let message = match Message::from_bytes(message_bytes, &server_key) {
            Ok(message) => message,
            Err(e) => {
                return Err(format!(
                    "[authenticate] {} - {e}",
                    String::from_utf8_lossy(server_id)
                ));
            }
        };

        match message.message_type {
            Type::Init => self.add(endpoint, server_id, &server_key),
            Type::Pong => {
                if self.on_pong(server_id).is_some() {
                    // Do not pass the message to the bot
                    return Ok(None);
                } else {
                    return Err(format!(
                        "[authenticate] {} - Failed to update on_pong",
                        String::from_utf8_lossy(server_id)
                    ));
                }
            }
            _ => {
                if !self.valid(endpoint, server_id) {
                    return Err(format!(
                        "[authenticate] {} - Failed to validate endpoint",
                        String::from_utf8_lossy(server_id)
                    ));
                }
            }
        };

        Ok(Some(message))
    }

    fn on_pong(&mut self, server_id: &[u8]) -> Option<()> {
        let client = self.connections.get_mut(server_id)?;
        client.pong();

        trace!("[on_pong] {}", client.server_id());
        Some(())
    }

    fn valid(&self, endpoint: Endpoint, server_id: &[u8]) -> bool {
        match self.connections.get(&server_id.to_vec()) {
            Some(client) => client.endpoint == endpoint,
            None => false,
        }
    }

    fn server_key(&mut self, server_id: &[u8]) -> Option<Vec<u8>> {
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
}
