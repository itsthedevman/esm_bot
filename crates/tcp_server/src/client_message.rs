use rutie::{AnyObject, Hash, Integer, RString};
use serde::Deserialize;

pub trait ToHash {
    fn to_hash(&self) -> Hash;
}

#[derive(Deserialize, Debug)]
pub struct ClientMessage {
    // pub op_code: i64,
    pub key: String,
    pub data: Data,
    pub metadata: Metadata,
}

impl ToHash for ClientMessage {
    fn to_hash(&self) -> Hash {
        let mut hash = Hash::new();
        //   hash.store(RString::from("op_code"), Integer::from(self.op_code));
        hash.store(RString::from("key"), RString::from(self.key.clone()));
        hash.store(RString::from("data"), self.data.to_hash());

        hash
    }
}

#[derive(Deserialize, Debug)]
pub enum Data {
    Empty,
}

impl ToHash for Data {
    fn to_hash(&self) -> Hash {
        match self {
            Data::Empty => Hash::new(),
        }
    }
}

#[derive(Deserialize, Debug)]
pub enum Metadata {
    Empty,
}

impl ToHash for Metadata {
    fn to_hash(&self) -> Hash {
        match self {
            Metadata::Empty => Hash::new(),
        }
    }
}


pub enum Empty {}
