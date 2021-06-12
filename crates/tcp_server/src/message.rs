use std::collections::HashMap;

use aes_gcm::aead::{Aead, NewAead};
use aes_gcm::{Aes256Gcm, Key, Nonce};
use message_io::network::ResourceId;
use serde::{Deserialize, Serialize};
use serde_json::{json, Value};

#[derive(Serialize, Deserialize, Debug)]
pub struct Message {
    id: String,

    #[serde(rename = "type")]
    pub message_type: Type,

    resource_id: Option<i64>,
    server_id: Option<String>,
    data: HashMap<String, Value>,
    metadata: HashMap<String, Value>,
    errors: Vec<String>,
}

#[derive(Serialize, Deserialize, Debug)]
#[serde(rename_all = "snake_case")]
pub enum Type {
    Connect,
    Disconnect,
    UpdateKeys,
    Ping,
    Pong
}

impl Message {
    pub fn new(message_type: Type) -> Self {
        Message {
            id: "".into(),
            message_type,
            resource_id: None,
            server_id: None,
            data: HashMap::new(),
            metadata: HashMap::new(),
            errors: Vec::new(),
        }
    }

    pub fn from_bytes<F>(data: Vec<u8>, resource_id: ResourceId, server_key_getter: F) -> Result<Message, String>
    where
        F: Fn(&String) -> Option<Vec<u8>>,
    {
        let mut message = extract_data(data, server_key_getter)?;
        message.resource_id = Some(resource_id.adapter_id() as i64);

        Ok(message)
    }

    /*
        {
            // Controls the context of this scope's data attribute.
            type: Symbol,

            // Where did this event originate from?
            resource_id: Symbol or Nil,

            // The payload that is context sensitive to the type
            data: Hash<Symbol, AnyObject> {},

            // Any extra data that needs to be sent along
            metadata: Hash<Symbol, AnyObject> {}
        }
    */

    pub fn set_resource<'a>(&'a mut self, resource_id: ResourceId) -> &'a mut Message {
        self.resource_id = Some(resource_id.adapter_id() as i64);
        self
    }

    pub fn add_data<'a>(&'a mut self, name: &'static str, value: Value) -> &'a mut Message {
        self.data.insert(name.to_string(), value);
        self
    }

    pub fn add_metadata<'a>(&'a mut self, name: &'static str, value: Value) -> &'a mut Message {
        self.metadata.insert(name.to_string(), value);
        self
    }
}

fn extract_data<F>(bytes: Vec<u8>, server_key_getter: F) -> Result<Message, String>
where
    F: Fn(&String) -> Option<Vec<u8>>,
{
    // The first byte is the length of the server_id so we know how many bytes to extract
    let id_length = bytes[0] as usize;

    // Extract the server ID and convert to a String
    let server_id = bytes[1..=id_length].to_vec();
    let server_id = String::from_utf8(server_id);
    let server_id = match server_id {
        Ok(server_id) => server_id,
        Err(_e) => return Err("Failed to extract server ID".into()),
    };

    // Find the server key so the message can be decrypted
    let server_key = match (server_key_getter)(&server_id) {
        Some(key) => key,
        None => return Err(format!("Failed to retrieve server_key for {}", server_id))
    };

    // Now to decrypt. First step, extract the nonce
    let nonce_offset = 1 + id_length;
    let nonce_size = bytes[nonce_offset] as usize;
    let nonce_offset = 1 + nonce_offset;
    let nonce = bytes[nonce_offset..(nonce_offset + nonce_size)].to_vec();
    let nonce = Nonce::from_slice(&nonce);

    // Next, extract the encrypted bytes
    let enc_offset = nonce_offset + nonce_size;
    let encrypted_bytes = bytes[enc_offset..].to_vec();

    // Build the cipher
    let server_key = &server_key[0..32];
    let key = Key::from_slice(server_key); // server_key has to be exactly 32 bytes
    let cipher = Aes256Gcm::new(key);

    // Decrypt!
    let message = match cipher.decrypt(nonce, encrypted_bytes.as_ref()) {
        Ok(message) => message,
        Err(_e) => {
            return Err("#extract_data - Failed to decrypt".into());
        }
    };

    // And deserialize into a struct
    match bincode::deserialize::<Message>(&message) {
        Ok(message) => Ok(message),
        Err(_e) => Err(format!("#extract_data - Failed to deserialize. Message: {:?}", &message)),
    }
}

#[derive(Serialize, Deserialize, Debug, Clone)]
enum Data {
    Empty,
}

#[derive(Serialize, Deserialize, Debug, Clone)]
enum Metadata {
    Empty,
}

#[derive(Serialize, Deserialize, Debug, Clone)]
enum Empty {}
