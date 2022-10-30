use message_io::network::{Endpoint, ResourceId, SendStatus};

use crate::server::Handler;
use crate::*;

#[derive(Debug)]
pub struct Client {
    pub endpoint: Endpoint,
    pub resource_id: ResourceId,
    server_id: Vec<u8>,
    server_key: Vec<u8>,
}

impl Client {
    pub fn new(endpoint: Endpoint) -> Self {
        Client {
            endpoint,
            resource_id: endpoint.resource_id(),
            server_id: vec![],
            server_key: vec![],
        }
    }

    pub fn associate(&mut self, server_id: &[u8], server_key: &[u8]) {
        self.server_id = server_id.to_vec();
        self.server_key = server_key.to_vec();
    }

    pub fn send(&self, handler: &Handler, message: Message) -> ESMResult {
        let message_bytes = match message.as_bytes(&self.server_key) {
            Ok(bytes) => bytes,
            Err(error) => return Err(error),
        };

        match handler.network().send(self.endpoint, &message_bytes) {
            SendStatus::Sent => {
                info!(
                    "[server::ConnectionManager::send] Message with id:{} sent to \"{}\"",
                    message.id,
                    String::from_utf8_lossy(&self.server_id)
                );

                Ok(())
            }
            SendStatus::MaxPacketSizeExceeded => Err(format!(
                "[server::ConnectionManager::send] Cannot send to \"{}\" - Message is too large. Size: {} bytes. Message: {message:?}", String::from_utf8_lossy(&self.server_id), message_bytes.len()
            )),
            s => Err(format!("[server::ConnectionManager::send] Cannot send to \"{}\" - {s:?}. Message: {message:?}", String::from_utf8_lossy(&self.server_id)))
        }
    }
    pub fn disconnect(&self, handler: &Handler) {
        handler.network().remove(self.resource_id);
    }
}
