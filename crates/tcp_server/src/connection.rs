use std::collections::HashMap;
use message_io::network::{Endpoint, ResourceId};

use crate::server;

#[derive(Debug)]
pub struct ConnectionManager {
    pub lobby: Vec<Endpoint>,
    connections: HashMap<String, Endpoint>,
}

impl ConnectionManager {
    pub fn new() -> Self {
        ConnectionManager {
            lobby: Vec::new(),
            connections: HashMap::new(),
        }
    }

    pub fn add_to_lobby(&mut self, endpoint: Endpoint) {
        self.lobby.push(endpoint);
    }

    pub fn accept(&mut self, server_id: String, endpoint: Endpoint) -> Result<(), String> {
        let endpoint = match self.lobby.iter().find(|e| **e == endpoint) {
            Some(endpoint) => endpoint,
            None => return Err(format!("Failed to find endpoint to link to server ID {}", server_id))
        };

        self.connections.insert(server_id, *endpoint);

        Ok(())
    }

    pub fn find_by_server_id<'a>(&'a self, server_id: String) -> Option<&'a Endpoint> {
        self.connections.get(&server_id)
    }

    pub fn remove(&mut self, endpoint: Endpoint) {
        self.lobby.iter().position(|e| *e == endpoint);
        self.connections.retain(|_, e| *e == endpoint);
    }
}
