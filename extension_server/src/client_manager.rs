use std::{collections::HashMap, net::SocketAddr};

use chrono::{Duration, Utc};
use message_io::network::Endpoint;

use crate::{client::Client, server::Handler, *};

pub struct ClientManager(HashMap<SocketAddr, Client>);

impl ClientManager {
    const DISCONNECT_AFTER: i64 = 10;
    const PING_AFTER: i64 = 5;

    pub fn new() -> Self {
        ClientManager(HashMap::new())
    }

    pub fn add(&mut self, endpoint: Endpoint) -> &mut Client {
        self.0.insert(endpoint.addr(), Client::new(endpoint));
        self.get_mut(endpoint).unwrap()
    }

    pub fn get(&self, endpoint: Endpoint) -> Option<&Client> {
        self.0.iter().find_map(|(_server_id, client)| {
            if client.endpoint == endpoint {
                Some(client)
            } else {
                None
            }
        })
    }

    pub fn get_by_id(&self, server_id: &[u8]) -> Option<&Client> {
        self.0.iter().find_map(|(_addr, client)| {
            if client.server_id == server_id {
                Some(client)
            } else {
                None
            }
        })
    }

    pub fn get_mut(&mut self, endpoint: Endpoint) -> Option<&mut Client> {
        self.0.iter_mut().find_map(|(_server_id, client)| {
            if client.endpoint == endpoint {
                Some(client)
            } else {
                None
            }
        })
    }

    pub fn remove(&mut self, address: SocketAddr) -> Option<Client> {
        self.0.remove(&address)
    }

    pub fn disconnect_all(&mut self, handler: &Handler) {
        for client in self.0.values() {
            client.disconnect(handler);
        }

        self.0.clear();
    }

    pub fn alive_check(&mut self, handler: &Handler) {
        self.0.retain(|_, client| {
            if !client.connected {
                return false;
            }

            trace!(
                "[alive_check] {} - {} - Last checked: {} - Needs disconnected: {}",
                client.host(),
                client.server_id(),
                client.last_checked_at,
                (client.last_checked_at + Duration::seconds(Self::DISCONNECT_AFTER)) < Utc::now()
            );

            // Disconnect the client if it's been more than 5 seconds
            if (client.last_checked_at + Duration::seconds(Self::DISCONNECT_AFTER)) < Utc::now() {
                warn!(
                    "[alive_check] {} - {} - Timed out",
                    client.host(),
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
                    "[alive_check] {} - {} - Sending ping",
                    client.host(),
                    client.server_id()
                );

                if let Err(e) = client.ping(handler) {
                    error!(
                        "[alive_check] {} - {} - {e}",
                        client.host(),
                        client.server_id()
                    );
                }
            }

            true
        });
    }
}
