use std::collections::HashMap;

use aes_gcm::aead::{Aead, NewAead};
use aes_gcm::{Aes256Gcm, Key, Nonce};
use message_io::network::ResourceId;
use rand::random;
use serde::{Deserialize, Serialize};
use serde_json::{json, Value};

#[derive(Serialize, Deserialize, Debug)]
pub struct Message {
    pub id: String,

    #[serde(rename = "type")]
    pub message_type: Type,

    resource_id: Option<i64>,
    pub server_id: Option<String>,
    data: HashMap<String, Value>,
    metadata: HashMap<String, Value>,
    errors: Vec<Error>,
}

#[derive(Serialize, Deserialize, Debug, PartialEq)]
#[serde(rename_all = "snake_case")]
pub enum Type {
    Connect,
    Disconnect,
    Testing,
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
        let mut message = decrypt_message(data, server_key_getter)?;
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

    pub fn add_error<'a>(&'a mut self, error_type: ErrorType, error_message: &'static str) -> &'a mut Message {
        let error = Error::new(error_type, error_message.into());
        self.errors.push(error);
        self
    }

    pub fn as_bytes<F>(&self, server_key_getter: F) -> Result<Vec<u8>, String>
    where
        F: Fn(&String) -> Option<Vec<u8>>,
    {
        let server_id = match self.server_id.clone() {
            Some(id) => id,
            None => return Err(format!("Message does not have a server ID"))
        };

        encrypt_message(self, &server_id, server_key_getter)
    }
}

fn encrypt_message<F>(message: &Message, server_id: &String, server_key_getter: F) -> Result<Vec<u8>, String>
where
    F: Fn(&String) -> Option<Vec<u8>>,
{
    // Find the server key so the message can be encrypted
    let server_key = match (server_key_getter)(server_id) {
        Some(key) => key,
        None => return Err(format!("Failed to retrieve server_key for {}", server_id))
    };

    // Setup everything for encryption
    let encryption_key = Key::from_slice(&server_key[0..32]);
    let encryption_cipher = Aes256Gcm::new(encryption_key);
    let nonce_key: Vec<u8> = (0..12).map(|_| random::<u8>()).collect();
    let encryption_nonce = Nonce::from_slice(&nonce_key);

    // Serialize this message
    let message = match bincode::serialize(message) {
        Ok(bytes) => bytes,
        Err(e) => return Err("Failed to deserialize".into())
    };

    // Encrypt the message
    let encrypted_message = match encryption_cipher.encrypt(encryption_nonce, message.as_ref()) {
        Ok(bytes) => bytes,
        Err(e) => return Err(e.to_string())
    };

    // Start the packet off as the server_id bytes
    let mut packet = server_id.as_bytes().to_vec();

    // Insert the length of the server_id as byte zero
    packet.insert(0, packet.len() as u8);

    // Append the nonce length and itself to the packet
    packet.push(nonce_key.len() as u8);
    packet.extend(&*nonce_key);

    // Now add the encrypted message to the end. This completes the packet
    packet.extend(&*encrypted_message);

    Ok(packet)
}

fn decrypt_message<F>(bytes: Vec<u8>, server_key_getter: F) -> Result<Message, String>
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
struct Error {
    // Controls how the error_message is treated
    #[serde(rename = "type")]
    error_type: ErrorType,

    #[serde(rename = "message")]
    error_message: String,
}

impl Error {
    pub fn new(error_type: ErrorType, error_message: String) -> Self {
        Error { error_type, error_message }
    }
}

#[derive(Serialize, Deserialize, Debug, Clone)]
pub enum ErrorType {
    // Treats the error_message as a locale error code.
    Code,

    // Treats the error_message as a normal string
    Message
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
