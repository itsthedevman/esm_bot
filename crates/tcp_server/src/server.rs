use crate::message::Message;
use log::*;
use message_io::{
    network::{Endpoint, ResourceId},
    node::{self, NodeHandler, NodeTask},
};
use message_io::{
    network::{NetEvent, Transport},
    node::NodeListener,
};
use parking_lot::{RwLock, RwLockReadGuard, RwLockWriteGuard};
use redis::{aio::MultiplexedConnection, RedisResult};
use std::{collections::HashMap, env, time::Duration};
use std::{sync::Arc, thread};

#[derive(Clone)]
pub struct Server {
    handler: Arc<NodeHandler<()>>,
    endpoints: Arc<HashMap<usize, Endpoint>>,
    redis_connection: Arc<Option<MultiplexedConnection>>,
    address: String,
}

impl Server {
    pub fn new(handler: NodeHandler<()>) -> Self {
        let address = match env::var("TCP_SERVER_PORT") {
            Ok(port) => {
                format!("0.0.0.0:{}", port)
            }
            Err(_e) => {
                panic!("TCP_SERVER_PORT is not set!");
            }
        };

        Server {
            endpoints: Arc::new(HashMap::new()),
            handler: Arc::new(handler),
            redis_connection: Arc::new(None),
            address,
        }
    }

    pub async fn connect_to_redis(&mut self) -> RedisResult<isize> {
        let client = redis::Client::open("redis://127.0.0.1/")?;
        let connection = client.get_multiplexed_tokio_connection().await?;
        self.redis_connection = Arc::new(Some(connection));

        Ok(0)
    }

    // pub fn server_key<'a>(&self, server_id: &'a str) -> Result<Vec<u8>, &'static str> {
    //     let server_id = Symbol::new(server_id);

    //     let server_keys: RwLockReadGuard<Hash> = self.rb_server_keys.read();

    //     let server_key = server_keys.at(&server_id);
    //     let server_key = match server_key.try_convert_to::<RString>() {
    //         Ok(server_key) => server_key.to_string().as_bytes().to_vec(),
    //         Err(_e) => return Err("#server_key - Failed to convert to RString"),
    //     };

    //     Ok(server_key)
    // }

    pub async fn listen(&self, listener: NodeListener<()>) {
        // Start listening
        match self
            .handler
            .network()
            .listen(Transport::FramedTcp, &self.address)
        {
            Ok((_resource_id, real_addr)) => {
                info!("#listen - Listening on port {}", real_addr);
            }
            Err(e) => {
                error!("#listen - Failed to start listening. Error: #{}", e);
                return;
            }
        }

        // Process the events
        listener.for_each(move |event| match event.network() {
            NetEvent::Connected(_, _) => {}
            NetEvent::Message(endpoint, data) => {
                // match crate::SENDER
                //     .read()
                //     .send(Event::OnMessage(endpoint, data.to_vec()))
                // {
                //     Ok(_) => {}
                //     Err(error) => {
                //         error!(
                //             "#listen - {} Failed to send OnConnected event. Error: {:?}",
                //             endpoint.resource_id(),
                //             error
                //         );
                //     }
                // }
            }
            NetEvent::Disconnected(endpoint) => {
                // match crate::SENDER.read().send(Event::OnDisconnect(endpoint)) {
                //     Ok(_) => {}
                //     Err(error) => {
                //         error!(
                //             "#listen - {} Failed to send OnDisconnected event. Error: {:?}",
                //             endpoint.resource_id(),
                //             error
                //         );
                //     }
                // }
            }
            NetEvent::Accepted(endpoint, resource_id) => {}
        });
    }

    pub async fn handle_process_queue(&self) -> redis::RedisResult<isize> {
        let mut connection = match *self.redis_connection {
            Some(ref con) => con.clone(),
            None => panic!("#handle_process_queue - Failed to retrieve a redis connection"),
        };

        loop {
            debug!("#handle_process_queue - Waiting for message");

            let _: () = match redis::cmd("BLMOVE")
                .arg("connection_server_outbound")
                .arg("tcp_server_inbound")
                .arg("LEFT")
                .arg("RIGHT")
                .arg(0)
                .query_async(&mut connection)
                .await
            {
                Ok(r) => r,
                Err(e) => error!("#handle_process_queue - {}", e)
            };

            thread::sleep(Duration::from_millis(500));
        }
    }

    pub async fn process_requests(&self) -> redis::RedisResult<isize> {
        // THIS NEEDS TO BE A SEPARATE CONNECTION, JUST LIKE THE BOT
        let mut connection = match *self.redis_connection {
            Some(ref con) => con.clone(),
            None => panic!("#process_requests - Failed to retrieve a redis connection"),
        };

        loop {
            debug!("#process_requests - Waiting for message");
            let json: Option<String> = match redis::cmd("BLPOP")
                .arg("tcp_server_inbound")
                .arg(0)
                .query_async(&mut connection)
                .await
            {
                Ok(json) => json,
                Err(e) => {
                    error!("#process_requests - {:?}", e);
                    continue;
                }
            };

            let json: String = match json {
                Some(json) => json,
                None => continue
            };

            debug!("#process_requests - Received message. Deserializing...");

            let message: Message = match serde_json::from_str(&json) {
                Ok(message) => message,
                Err(e) => {
                    error!("#process_requests - {}", e);
                    continue;
                }
            };

            info!("#process_requests - Incoming message: {:?}", message);

            match message.message_type {
                _ => {}
            }
        }
    }

    // pub fn rb_sender_mut(&self) -> Option<RwLockWriteGuard<Array>> {
    //     let mut attempt_counter = 0;
    //     let sender = loop {
    //         match self.rb_sender.try_write() {
    //             Some(sender) => break sender,
    //             None => {
    //                 if attempt_counter <= 15 {
    //                     attempt_counter += 1;
    //                     thread::sleep(Duration::from_secs(1));
    //                     continue;
    //                 }

    //                 error!("#rb_sender_mut - Failed to gain lock.");
    //                 return None;
    //             }
    //         }
    //     };

    //     Some(sender)
    // }

    // pub fn endpoints(&self) -> Option<RwLockReadGuard<HashMap<usize, Endpoint>>> {
    //     let mut attempt_counter = 0;
    //     let endpoints = loop {
    //         match self.endpoints.try_read() {
    //             Some(endpoints) => break endpoints,
    //             None => {
    //                 if attempt_counter <= 15 {
    //                     attempt_counter += 1;
    //                     thread::sleep(Duration::from_secs(1));
    //                     continue;
    //                 }

    //                 return None;
    //             }
    //         }
    //     };

    //     Some(endpoints)
    // }

    // pub fn endpoints_mut(&self) -> Option<RwLockWriteGuard<HashMap<usize, Endpoint>>> {
    //     let mut attempt_counter = 0;
    //     let endpoints = loop {
    //         match self.endpoints.try_write() {
    //             Some(endpoints) => break endpoints,
    //             None => {
    //                 if attempt_counter <= 15 {
    //                     attempt_counter += 1;
    //                     thread::sleep(Duration::from_secs(1));
    //                     continue;
    //                 }

    //                 return None;
    //             }
    //         }
    //     };

    //     Some(endpoints)
    // }

    // pub fn remove_endpoint(&self, adapter_id: usize) -> Option<Endpoint> {
    //     let mut endpoints = match self.endpoints_mut() {
    //         Some(endpoints) => endpoints,
    //         None => {
    //             error!("#remove_endpoint - Failed to gain write lock");
    //             return None;
    //         }
    //     };

    //     endpoints.remove(&adapter_id)
    // }

    // fn handler(&self) -> Option<RwLockReadGuard<NodeHandler<()>>> {
    //     let mut attempt_counter = 0;
    //     let handler = loop {
    //         match self.handler.try_read() {
    //             Some(handler) => break handler,
    //             None => {
    //                 if attempt_counter <= 15 {
    //                     attempt_counter += 1;
    //                     thread::sleep(Duration::from_secs(1));
    //                     continue;
    //                 }

    //                 error!("#handler - Failed to gain lock");
    //                 return None;
    //             }
    //         }
    //     };

    //     Some(handler)
    // }

    // pub fn send_message(&self, resource_id: i64, message: crate::ServerMessage) {
    //     let endpoints = match self.endpoints() {
    //         Some(endpoints) => endpoints,
    //         None => {
    //             error!("#endpoint - Failed to gain read lock.");
    //             return;
    //         },
    //     };

    //     let endpoint = match endpoints.get(&(resource_id as usize)) {
    //         Some(endpoint) => endpoint,
    //         None => {
    //             // Raise an exception in ruby
    //             return VM::raise(
    //                 Module::from_existing("ESM")
    //                     .get_nested_module("Exception")
    //                     .get_nested_class("ClientNotConnected"),
    //                 &format!("{}", resource_id),
    //             );
    //         }
    //     };

    //     // Using the endpoint, send the message via the handler
    //     let handler = match self.handler() {
    //         Some(handler) => handler,
    //         None => return,
    //     };

    //     debug!("#send_message - Sending message: {:?}", message);

    //     handler.network().send(*endpoint, message.as_bytes());
    // }

    // pub fn disconnect(&self, adapter_id: usize) -> bool {
    //     let handler = match self.handler() {
    //         Some(handler) => handler,
    //         None => return false,
    //     };

    //     match self.remove_endpoint(adapter_id) {
    //         Some(endpoint) => handler.network().remove(endpoint.resource_id()),
    //         None => {
    //             warn!("#disconnect - {} Endpoint already removed", adapter_id);

    //             false
    //         }
    //     }
    // }

    // fn on_connect(&self, endpoint: Endpoint, resource_id: ResourceId) {
    //     debug!(
    //         "#on_connect - {} Incoming connection with address {}",
    //         resource_id,
    //         endpoint.addr()
    //     );

    //     let check_connection = || -> Result<(), &'static str> {
    //         let mut endpoints = match self.endpoints_mut() {
    //             Some(endpoints) => endpoints,
    //             None => return Err("Failed to gain write lock"),
    //         };

    //         let adapter_id = resource_id.adapter_id() as usize;

    //         // Check if the client has already connected
    //         match endpoints.get(&adapter_id) {
    //             Some(_) => {
    //                 self.disconnect(adapter_id);
    //                 Err("Endpoint already connected")
    //             }
    //             None => {
    //                 // Store the connection so it can be retrieved later
    //                 endpoints.insert(adapter_id, endpoint);
    //                 Ok(())
    //             }
    //         }
    //     };

    //     // Log and return if something went wrong
    //     if let Err(message) = check_connection() {
    //         error!("#connect - {} {}", resource_id, message);
    //         return;
    //     }

    //     trace!("#on_connect - {} Connection added", resource_id);

    //     let mut message = Message::new("connection_event", Some(resource_id.adapter_id() as i64));
    //     message.add_data("event", Symbol::new("on_connect").to_any_object());

    //     debug!("Message");

    //     let mut writer = self.flag.write();
    //     *writer = Boolean::new(true);
    //     drop(writer);

    //     debug!("Writer");

    //     // Inform the bot of a new connection
    //     match self.rb_sender_mut() {
    //         Some(mut sender) => {
    //             sender.push(message.to_hash());
    //         }
    //         None => return,
    //     };

    //     debug!("Done");
    // }

    // fn on_message(&self, endpoint: Endpoint, data: Vec<u8>) {
    //     let resource_id = endpoint.resource_id();
    //     let message = Message::from_bytes(
    //         data,
    //         "connection_event",
    //         Some(resource_id.adapter_id() as i64),
    //     );

    //     let mut message = match message {
    //         Ok(message) => message,
    //         Err(e) => {
    //             error!("#on_message - {}", e);
    //             self.disconnect(resource_id.adapter_id() as usize);
    //             return;
    //         }
    //     };

    //     message.add_data("event", RString::new_utf8("on_message").into());

    //     debug!("#on_message - {} Message: {:?}", resource_id, message);

    //     // Trigger the on_message on the ruby side
    //     match self.rb_sender_mut() {
    //         Some(mut sender) => {
    //             sender.push(message.to_hash());
    //         }
    //         None => return,
    //     };
    // }

    // fn on_disconnect(&self, endpoint: Endpoint) {
    //     let resource_id = endpoint.resource_id();
    //     debug!("#on_disconnect - {} has disconnected", resource_id);

    //     match self.remove_endpoint(resource_id.adapter_id() as usize) {
    //         Some(_) => (),
    //         None => {
    //             warn!("#on_disconnect - {} Endpoint already removed", resource_id);
    //         }
    //     };

    //     // Trigger the on_message on the ruby side
    //     match self.rb_sender_mut() {
    //         Some(mut sender) => {
    //             let mut message = Hash::new();
    //             message.store(Symbol::new("type"), Symbol::new("connection_event"));
    //             message.store(
    //                 Symbol::new("resource_id"),
    //                 Integer::new(resource_id.adapter_id() as i64),
    //             );

    //             let mut data = Hash::new();
    //             data.store(Symbol::new("event"), Symbol::new("on_disconnect"));

    //             message.store(Symbol::new("data"), data);

    //             sender.push(message);
    //         }
    //         None => return,
    //     };
    // }
}
