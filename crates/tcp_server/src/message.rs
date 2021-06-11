use std::collections::HashMap;

use aes_gcm::aead::{Aead, NewAead};
use aes_gcm::{Aes256Gcm, Key, Nonce};
use serde::{Deserialize, Serialize};
use serde_json::{json, Value};

#[derive(Serialize, Deserialize, Debug)]
pub struct Message {
    id: String,

    #[serde(rename = "type")]
    pub message_type: Type,

    server_id: Option<String>,
    data: HashMap<String, Value>,
    metadata: HashMap<String, Value>,
    errors: Vec<String>,
}

#[derive(Serialize, Deserialize, Debug)]
#[serde(rename_all = "snake_case")]
pub enum Type {
    OnConnect,
    UpdateKeys,
}

impl Message {
    pub fn new(message_type: Type, server_id: Option<String>) -> Self {
        Message {
            id: "".into(),
            message_type,
            server_id,
            data: HashMap::new(),
            metadata: HashMap::new(),
            errors: Vec::new(),
        }
    }

    pub fn from_bytes<F>(data: Vec<u8>, server_key_getter: F) -> Result<Message, String>
    where
        F: Fn(&String) -> Option<Vec<u8>>,
    {
        Ok(extract_data(data, server_key_getter)?)
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

    println!("Id: {:?}", &server_id);

    // Find the server key so the message can be decrypted
    let server_key = match (server_key_getter)(&server_id) {
        Some(key) => key,
        None => return Err(format!("Failed to retrieve server_key for {}", server_id))
    };

    // println!("Key: {:?}", &server_key);

    // Now to decrypt
    let nonce_offset = 1 + id_length;
    let nonce_size = bytes[nonce_offset] as usize;

    let nonce_offset = 1 + nonce_offset;
    let nonce = bytes[nonce_offset..(nonce_offset + nonce_size)].to_vec();

    println!("Nonce: {:?}", &nonce);

    let nonce = Nonce::from_slice(&nonce);

    let enc_offset = nonce_offset + nonce_size;
    let encrypted_bytes = bytes[enc_offset..].to_vec();

    println!("Enc Bytes: {:?}", &encrypted_bytes);

    let server_key = &server_key[0..32];

    println!("Key: {:?}", &server_key);

    let key = Key::from_slice(server_key); // server_key has to be exactly 32 bytes
    let cipher = Aes256Gcm::new(key);

    let message = match cipher.decrypt(nonce, encrypted_bytes.as_ref()) {
        Ok(message) => message,
        Err(_e) => {
            return Err("#extract_data - Failed to decrypt".into());
        }
    };


    match bincode::deserialize::<Message>(&message) {
        Ok(message) => Ok(message),
        Err(_e) => Err(format!("#extract_data - Failed to deserialize. Message: {:?}", &message)),
    }
}

#[derive(Serialize, Deserialize, Debug, Clone)]
enum Data {
    Empty,
}

impl Data {
    pub fn to_hash_map(&self) -> HashMap<String, Value> {
        match self {
            Data::Empty => HashMap::new(),
        }
    }
}

#[derive(Serialize, Deserialize, Debug, Clone)]
enum Metadata {
    Empty,
}

impl Metadata {
    pub fn to_hash_map(&self) -> HashMap<String, Value> {
        match self {
            Metadata::Empty => HashMap::new(),
        }
    }
}

#[derive(Serialize, Deserialize, Debug, Clone)]
enum Empty {}
