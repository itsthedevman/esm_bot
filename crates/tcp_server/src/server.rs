use parking_lot::{RwLock, RwLockReadGuard, RwLockWriteGuard};
use std::{sync::{Arc}, thread};
use std::{collections::HashMap, time::Duration};
use log::*;
use message_io::network::{NetEvent, Transport};
use message_io::{
    network::{Endpoint, ResourceId},
    node::{self, NodeHandler, NodeTask},
  };
use rutie::{Array, Hash, Integer, Module, NilClass, Object, RString, Symbol, Thread, VM};
use crate::client_message::{ClientMessage, ToHash};

#[derive(Debug)]
pub enum Event {
    OnMessage(Endpoint, Vec<u8>),
    OnConnected(Endpoint, ResourceId),
    OnDisconnect(Endpoint),
    Stop
}

#[derive(Clone)]
pub struct Server {
    rb_receiver: Arc<RwLock<Array>>,
    rb_sender: Arc<RwLock<Array>>,
    handler: Arc<RwLock<NodeHandler<()>>>,
    endpoints: Arc<RwLock<HashMap<usize, Endpoint>>>,
    task: Arc<RwLock<Option<NodeTask>>>,
}


impl Server {
    pub fn new(rb_receiver: Array, rb_sender: Array) -> Self {
        let (handler, _) = node::split::<()>();
        Server {
            rb_receiver: Arc::new(RwLock::new(rb_receiver)),
            rb_sender: Arc::new(RwLock::new(rb_sender)),
            endpoints: Arc::new(RwLock::new(HashMap::new())),
            handler: Arc::new(RwLock::new(handler)),
            task: Arc::new(RwLock::new(None)),
        }
    }

    // This is called from a ruby thread and it is blocking.
    pub fn listen(&mut self, port: String) {
        let (handler, listener) = node::split::<()>();
        let address = format!("0.0.0.0:{}", port);

        // Start listening
        match handler.network().listen(Transport::FramedTcp, &address) {
            Ok((_resource_id, _real_addr)) => {
                debug!("[#listen] Listening on port {}", port);
            }
            Err(_) => {
                return VM::raise(
                    Module::from_existing("ESM")
                        .get_nested_module("Exception")
                        .get_nested_class("AddressInUse"),
                    &address,
                )
            }
        }

        // Store the handler so it can be referenced later
        self.handler = Arc::new(RwLock::new(handler));

        // Process the events
        let task = listener.for_each_async(move |event| match event.network() {
            NetEvent::Connected(endpoint, resource_id) => {
                match crate::SENDER
                    .read()
                    .unwrap()
                    .send(Event::OnConnected(endpoint, resource_id))
                {
                    Ok(_) => {}
                    Err(error) => {
                        error!(
                            "[#listen] {} Failed to send OnConnected event. Error: {:?}",
                            resource_id, error
                        );
                    }
                }
            }
            NetEvent::Message(endpoint, data) => {
                match crate::SENDER
                    .read()
                    .unwrap()
                    .send(Event::OnMessage(endpoint, data.to_vec()))
                {
                    Ok(_) => {}
                    Err(error) => {
                        error!(
                            "[#listen] {} Failed to send OnConnected event. Error: {:?}",
                            endpoint.resource_id(),
                            error
                        );
                    }
                }
            }
            NetEvent::Disconnected(endpoint) => {
                match crate::SENDER.read().unwrap().send(Event::OnDisconnect(endpoint)) {
                    Ok(_) => {}
                    Err(error) => {
                        error!(
                            "[#listen] {} Failed to send OnDisconnected event. Error: {:?}",
                            endpoint.resource_id(),
                            error
                        );
                    }
                }
            }
        });

        self.task = Arc::new(RwLock::new(Some(task)));
    }

    // This is called from a ruby thread and it is blocking.
    pub fn process_requests(&self) {
        let server = self.clone();

        thread::spawn(move || {
            loop {
                let event = match crate::RECEIVER.read().unwrap().recv() {
                    Ok(event) => event,
                    Err(error) => {
                        error!(
                            "[#process_requests] Failed to receive message. Error: {:?}",
                            error
                        );
                        continue;
                    }
                };

                trace!("[#process_requests] Incoming event: {:?}", event);

                match event {
                    Event::OnConnected(endpoint, resource_id) => server.on_connect(endpoint, resource_id),
                    Event::OnMessage(endpoint, data) => server.on_message(endpoint, data),
                    Event::OnDisconnect(endpoint) => server.on_disconnect(endpoint),
                    Event::Stop => break
                }
            }
        });
    }

    pub fn rb_sender_mut(&self) -> Option<RwLockWriteGuard<Array>> {
        let mut attempt_counter = 0;
        let sender = loop {
            match self.rb_sender.try_write() {
                Some(sender) => break sender,
                None => {
                    if attempt_counter <= 15 {
                        attempt_counter += 1;
                        thread::sleep(Duration::from_secs(1));
                        continue;
                    }

                    error!("[#rb_sender_mut] Failed to gain lock.");
                    return None;
                }
            }
        };

        Some(sender)
    }

    pub fn endpoints(&self) -> Option<RwLockReadGuard<HashMap<usize, Endpoint>>> {
        let mut attempt_counter = 0;
        let endpoints = loop {
            match self.endpoints.try_read() {
                Some(endpoints) => break endpoints,
                None => {
                    if attempt_counter <= 15 {
                        attempt_counter += 1;
                        thread::sleep(Duration::from_secs(1));
                        continue;
                    }

                    return None;
                }
            }
        };

        Some(endpoints)
    }

    pub fn endpoints_mut(&self) -> Option<RwLockWriteGuard<HashMap<usize, Endpoint>>> {
        let mut attempt_counter = 0;
        let endpoints = loop {
            match self.endpoints.try_write() {
                Some(endpoints) => break endpoints,
                None => {
                    if attempt_counter <= 15 {
                        attempt_counter += 1;
                        thread::sleep(Duration::from_secs(1));
                        continue;
                    }

                    return None;
                }
            }
        };

        Some(endpoints)
    }

    pub fn remove_endpoint(&self, resource_id: ResourceId) -> Option<Endpoint> {
        let mut endpoints = match self.endpoints_mut() {
            Some(endpoints) => endpoints,
            None => {
                error!("[#remove_endpoint] Failed to gain write lock");
                return None;
            }
        };

        let adapter_id = resource_id.adapter_id() as usize;
        endpoints.remove(&adapter_id)
    }

    fn handler(&self) -> Option<RwLockReadGuard<NodeHandler<()>>> {
        let mut attempt_counter = 0;
        let handler = loop {
            match self.handler.try_read() {
                Some(handler) => break handler,
                None => {
                    if attempt_counter <= 15 {
                        attempt_counter += 1;
                        thread::sleep(Duration::from_secs(1));
                        continue;
                    }

                    error!("[#handler] Failed to gain lock");
                    return None;
                }
            }
        };

        Some(handler)
    }

    pub fn send_message(&self, resource_id: i64, message: crate::ServerMessage) {
        let endpoints = match self.endpoints() {
            Some(endpoints) => endpoints,
            None => {
                error!("[#endpoint] Failed to gain read lock.");
                return;
            },
        };

        let endpoint = match endpoints.get(&(resource_id as usize)) {
            Some(endpoint) => endpoint,
            None => {
                // Raise an exception in ruby
                return VM::raise(
                    Module::from_existing("ESM")
                        .get_nested_module("Exception")
                        .get_nested_class("ClientNotConnected"),
                    &format!("{}", resource_id),
                );
            }
        };

        // Using the endpoint, send the message via the handler
        let handler = match self.handler() {
            Some(handler) => handler,
            None => return,
        };

        debug!("[#send_message] Sending message: {:?}", message);

        handler.network().send(*endpoint, message.as_bytes());
    }

    pub fn disconnect(&self, resource_id: ResourceId) -> bool {
        let handler = match self.handler() {
            Some(handler) => handler,
            None => return false,
        };

        match self.remove_endpoint(resource_id) {
            Some(_) => {
                debug!("Removing");
                handler.network().remove(resource_id)
            },
            None => {
                warn!(
                    "[#disconnect] {} Endpoint already removed",
                    resource_id
                );

                false
            }
        }
    }

    fn on_connect(&self, endpoint: Endpoint, resource_id: ResourceId) {
        debug!(
            "[#on_connect] {} Incoming connection with address {}",
            resource_id,
            endpoint.addr()
        );

        let mut endpoints = match self.endpoints_mut() {
            Some(endpoints) => endpoints,
            None => {
                error!("[#on_connect] Failed to gain write lock");
                return
            },
        };

        let adapter_id = resource_id.adapter_id() as usize;

        // Check if the client has already connected
        match endpoints.get(&adapter_id) {
            Some(_) => {
                // Release the lock this scope owns so the remove can lock it.
                drop(endpoints);

                debug!(
                    "[#on_connect] {} Endpoint already connected",
                    adapter_id
                );

                self.disconnect(resource_id);
                return;
            }
            None => (),
        }

        // Store the connection so it can be retrieved later
        endpoints.insert(adapter_id, endpoint);

        // We no longer need write access, release it so other threads can gain read access
        drop(endpoints);

        trace!("[#on_connect] {} Connection added", resource_id);

        // Inform the bot of a new connection
        match self.rb_sender_mut() {
            Some(mut sender) => {
                let mut message = Hash::new();
                message.store(Symbol::new("type"), Symbol::new("connection_event"));
                message.store(Symbol::new("resource_id"), Integer::new(resource_id.adapter_id() as i64));

                let mut data = Hash::new();
                data.store(Symbol::new("event"), Symbol::new("on_connect"));

                message.store(Symbol::new("data"), data);

                sender.push(message);
            },
            None => return
        };
    }

    fn on_message(&self, endpoint: Endpoint, data: Vec<u8>) {
        let resource_id = endpoint.resource_id();

        let client_message: ClientMessage = match bincode::deserialize(&data) {
            Ok(message) => message,
            Err(_error) => {
                error!(
                    "[#on_message] {} Malformed message: {}",
                    resource_id,
                    String::from_utf8_lossy(&data)
                );
                return;
            }
        };

        debug!(
            "[#on_message] {} Message: {:?}",
            resource_id, client_message
        );

        // Trigger the on_message on the ruby side
        match self.rb_sender_mut() {
            Some(mut sender) => {
                let mut message = Hash::new();
                message.store(Symbol::new("type"), Symbol::new("connection_event"));
                message.store(Symbol::new("resource_id"), Integer::new(resource_id.adapter_id() as i64));

                let mut data = Hash::new();
                data.store(Symbol::new("event"), Symbol::new("on_message"));
                data.store(Symbol::new("key"), RString::new_utf8(client_message.key.as_str()));
                data.store(Symbol::new("data"), client_message.data.to_hash());
                data.store(Symbol::new("metadata"), client_message.metadata.to_hash());

                message.store(Symbol::new("data"), data);

                sender.push(message);
            },
            None => return
        };
    }

    fn on_disconnect(&self, endpoint: Endpoint) {
        let resource_id = endpoint.resource_id();
        debug!("[#on_disconnect] {} has disconnected", resource_id);

        match self.remove_endpoint(resource_id) {
            Some(_) => (),
            None => {
                warn!(
                    "[#on_disconnect] {} Endpoint already removed",
                    resource_id
                );
            }
        };

        // Trigger the on_message on the ruby side
        match self.rb_sender_mut() {
            Some(mut sender) => {
                let mut message = Hash::new();
                message.store(Symbol::new("type"), Symbol::new("connection_event"));
                message.store(Symbol::new("resource_id"), Integer::new(resource_id.adapter_id() as i64));

                let mut data = Hash::new();
                data.store(Symbol::new("event"), Symbol::new("on_disconnect"));

                message.store(Symbol::new("data"), data);

                sender.push(message);
            },
            None => return
        };
    }
}
