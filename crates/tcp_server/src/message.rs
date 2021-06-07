use std::{collections::HashMap};

use aes_gcm::aead::{Aead, NewAead};
use aes_gcm::{Aes256Gcm, Key, Nonce};
use serde::{Deserialize, Serialize};
use serde_json::{Value, json};

#[derive(Serialize, Deserialize, Debug)]
pub struct Message {
    #[serde(rename = "type")]
    pub message_type: Type,
    server_id: Option<String>,
    data: HashMap<String, Value>,
    metadata: HashMap<String, Value>,
}

#[derive(Serialize, Deserialize, Debug)]
#[serde(rename_all = "snake_case")]
pub enum Type {
    OnConnect
}

impl Message {
    pub fn new(message_type: Type, server_id: Option<String>) -> Self {
        Message {
            message_type,
            server_id,
            data: HashMap::new(),
            metadata: HashMap::new(),
        }
    }

    pub fn from_bytes(
        data: Vec<u8>,
        message_type: Type,
        server_id: Option<String>,
    ) -> Result<Message, &'static str> {
        let packet = extract_data(data)?;

        Ok(Message {
            message_type: message_type,
            server_id,
            data: packet.data.to_hash_map(),
            metadata: packet.metadata.to_hash_map(),
        })
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
    pub fn add_data<'a>(
        &'a mut self,
        name: &'static str,
        value: Value,
    ) -> &'a mut Message {
        self.data.insert(name.to_string(), value);
        self
    }

    pub fn add_metadata<'a>(
        &'a mut self,
        name: &'static str,
        value: Value,
    ) -> &'a mut Message {
        self.metadata.insert(name.to_string(), value);
        self
    }
}

fn extract_data(bytes: Vec<u8>) -> Result<Packet, &'static str> {
    // The first byte is the length of the server_id so we know how many bytes to extract
    let id_length = bytes[0] as usize;

    // Extract the server ID and convert to a String
    let server_id = bytes[1..=id_length].to_vec();
    let server_id = String::from_utf8(server_id);
    let server_id = match server_id {
        Ok(server_id) => server_id,
        Err(_e) => return Err("Failed to extract server ID"),
    };

    // Find the server key so the message can be decrypted
    // let server_key = crate::SERVER.read().server_key(&server_id[..])?;
    let server_key = "esm".as_bytes();

    // Now to decrypt
    let nonce_offset = 1 + id_length;
    let nonce_size = bytes[nonce_offset] as usize;

    let nonce_offset = 1 + nonce_offset;
    let nonce = bytes[nonce_offset..(nonce_offset + nonce_size)].to_vec();

    let nonce = Nonce::from_slice(&nonce);

    let enc_offset = nonce_offset + nonce_size;
    let encrypted_bytes = bytes[enc_offset..].to_vec();

    let key = Key::from_slice(&server_key); // server_key has to be exactly 32 bytes
    let cipher = Aes256Gcm::new(key);

    let message = match cipher.decrypt(nonce, encrypted_bytes.as_ref()) {
        Ok(message) => message,
        Err(_e) => {
            return Err("#extract_data - Failed to decrypt");
        }
    };

    match bincode::deserialize::<Packet>(&message) {
        Ok(packet) => {
            Ok(packet)
        },
        Err(_e) => {
            Err("#extract_data - Failed to deserialize")
        }
    }
}

#[derive(Serialize, Deserialize, Debug)]
pub struct Packet {
    id: String,
    data_type: String,
    data: Data,
    metadata: Metadata,
}

impl Packet {
    pub fn to_hash_map(&self) -> HashMap<String, Value> {
        let mut hash: HashMap<String, Value> = HashMap::new();
        hash.insert("id".into(), json!(self.id));
        hash.insert("type".into(), json!(self.data_type));
        hash.insert("data".into(), json!(self.data));
        hash.insert("metadata".into(), json!(self.metadata));

        hash
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
            Metadata::Empty => HashMap::new()
        }
    }
}

#[derive(Serialize, Deserialize, Debug, Clone)]
enum Empty {}

/*
{
  type: Symbol,
  resource_id: Symbol,
  data: Hash<Symbol, AnyObject> {
    id: String,
    type: String
    data: Hash<Symbol, AnyObject> {
      errors: Array<String> - This is always defined. If it's empty, there were no errors. If it has contents, something went wrong
    }
    metadata: Hash {}
  },
  metadata: Hash<Symbol, AnyObject> {}
}

ESM::Connection::Server Inbound types:
  connection_event:
    - on_connect, on_disconnect, on_ping, on_pong
  client_message:
    - A message that originates from the Arma Server
    - This is a "request" from the Arma Server to be processed by ESM::Connection::Server
  server_message:
    - A message that originated from ESM::Connection::Server.
    - This is the arma server's "response" to a previous "request" from ESM::Connection::Server

ESM::Connection::Server Outbound types:
  client_message:
    - A message that originated from the Arma Server
    - This is ESM::Connection::Server's "response" to a previous "request" from the Arma Server
  server_message:
    - A message that originates from ESM::Connection::Server.
    - This is a "request" to be sent to the Arma Server.


    240 with string
*/
