use std::collections::HashMap;
use message_io::network::{Endpoint, ResourceId};

#[derive(Debug)]
pub struct ConnectionManager {
    pub lobby: HashMap<ResourceId, Connection>,
    connections: HashMap<String, Connection>,
}

impl ConnectionManager {
    pub fn new() -> Self {
        ConnectionManager {
            lobby: HashMap::new(),
            connections: HashMap::new(),
        }
    }

    pub fn add_to_lobby(&mut self, resource_id: ResourceId, endpoint: Endpoint) {
        let connection = Connection::new(resource_id, endpoint);
        self.lobby.insert(resource_id, connection);
    }

    pub fn remove_by_resource_id(&mut self, resource_id: ResourceId) {
        self.lobby.remove(&resource_id);
        self.connections.retain(|_, connection| connection.resource_id != resource_id );
    }

    // Removes a connection via it's resource Id.
    // A connection will no longer be in the lobby if it has a server Id.
    pub fn remove_by_server_id(&mut self, server_id: String) {
        self.connections.remove(&server_id);
    }
}
#[derive(Debug)]
pub struct Connection {
    endpoint: Endpoint,
    resource_id: ResourceId,
}

impl Connection {
    pub fn new(resource_id: ResourceId, endpoint: Endpoint) -> Self {
        Connection { endpoint, resource_id }
    }
}
