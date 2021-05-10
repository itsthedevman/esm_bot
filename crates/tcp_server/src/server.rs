use std::{sync::{RwLock, RwLockReadGuard, RwLockWriteGuard}, thread};
use std::{collections::HashMap, sync::Mutex, time::Duration};
use log::*;
use message_io::network::{NetEvent, Transport};
use message_io::{
    network::{Endpoint, ResourceId},
    node::{self, NodeHandler, NodeTask},
  };
use rutie::{Object, AnyObject, Integer, Module, VM};
use crate::client_message::{ClientMessage, ToHash};

#[derive(Debug)]
pub enum Event {
    OnMessage(Endpoint, Vec<u8>),
    OnConnected(Endpoint, ResourceId),
    OnDisconnect(Endpoint),
}

pub struct Server {
    // An instance of ESM::Connection::Server
    instance: RwLock<AnyObject>,
    handler: RwLock<NodeHandler<()>>,
    endpoints: RwLock<HashMap<usize, Endpoint>>,
    task: Mutex<Option<NodeTask>>,
}

impl Server {
    pub fn new(instance: AnyObject) -> Self {
        let (handler, _) = node::split::<()>();
        Server {
            instance: RwLock::new(instance),
            endpoints: RwLock::new(HashMap::new()),
            handler: RwLock::new(handler),
            task: Mutex::new(None),
        }
    }

    // This is called from a ruby thread and it is blocking.
    pub fn listen(&mut self, port: String) {
        let (handler, listener) = node::split::<()>();
        let address = format!("0.0.0.0:{}", port);

        // Start listening
        match handler.network().listen(Transport::FramedTcp, &address) {
            Ok((_resource_id, _real_addr)) => {
                debug!("[server#listen] Listening on port {}", port);
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
        self.handler = RwLock::new(handler);

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
                            "[server#listen] {} Failed to send OnConnected event. Error: {:?}",
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
                            "[server#listen] {} Failed to send OnConnected event. Error: {:?}",
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
                            "[server#listen] {} Failed to send OnDisconnected event. Error: {:?}",
                            endpoint.resource_id(),
                            error
                        );
                    }
                }
            }
        });

        self.task = Mutex::new(Some(task));
    }

    // This is called from a ruby thread and it is blocking.
    pub fn process_requests(&self) {
        loop {
            let event = match crate::RECEIVER.read().unwrap().recv() {
                Ok(event) => event,
                Err(error) => {
                    error!(
                        "[server#process_requests] Failed to receive message. Error: {:?}",
                        error
                    );
                    continue;
                }
            };

            trace!("[server#process_requests] Incoming event: {:?}", event);

            match event {
                Event::OnConnected(endpoint, resource_id) => self.on_connect(endpoint, resource_id),
                Event::OnMessage(endpoint, data) => self.on_message(endpoint, data),
                Event::OnDisconnect(endpoint) => self.on_disconnect(endpoint),
            }
        }
    }

    pub fn endpoints(&self) -> Option<RwLockReadGuard<HashMap<usize, Endpoint>>> {
        let mut attempt_counter = 0;
        let endpoints = loop {
            match self.endpoints.try_read() {
                Ok(endpoints) => break endpoints,
                Err(e) => {
                    if attempt_counter <= 15 {
                        attempt_counter += 1;
                        thread::sleep(Duration::from_secs(1));
                        continue;
                    }

                    error!(
                        "[server#endpoint] Failed to gain read lock. Reason: {:?}",
                        e
                    );
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
                Ok(endpoints) => break endpoints,
                Err(e) => {
                    if attempt_counter <= 15 {
                        attempt_counter += 1;
                        thread::sleep(Duration::from_secs(1));
                        continue;
                    }

                    error!(
                        "[server#endpoint_mut] Failed to gain write lock. Reason: {:?}",
                        e
                    );
                    return None;
                }
            }
        };

        Some(endpoints)
    }

    pub fn remove_endpoint(&self, resource_id: ResourceId) -> Option<Endpoint> {
        let mut endpoints = match self.endpoints_mut() {
            Some(endpoints) => endpoints,
            None => return None,
        };

        let adapter_id = resource_id.adapter_id() as usize;
        endpoints.remove(&adapter_id)
    }

    fn handler(&self) -> Option<RwLockReadGuard<NodeHandler<()>>> {
        let mut attempt_counter = 0;
        let handler = loop {
            match self.handler.try_read() {
                Ok(handler) => break handler,
                Err(e) => {
                    if attempt_counter <= 15 {
                        attempt_counter += 1;
                        thread::sleep(Duration::from_secs(1));
                        continue;
                    }

                    error!("[server#handler] Failed to gain read lock. Reason: {:?}", e);
                    return None;
                }
            }
        };

        Some(handler)
    }

    pub fn send_message(&self, resource_id: i64, message: String) {
        let endpoints = match self.endpoints() {
            Some(endpoints) => endpoints,
            None => return,
        };

        let endpoint = match endpoints.get(&(resource_id as usize)) {
            Some(endpoint) => endpoint,
            None => {
                // Raise an exception in ruby
                return VM::raise(
                    Module::from_existing("ESM")
                        .get_nested_module("Exception")
                        .get_nested_class("ServerNotConnected"),
                    &format!("{}", resource_id),
                );
            }
        };

        // Using the endpoint, send the message via the handler
        let handler = match self.handler() {
            Some(handler) => handler,
            None => return,
        };

        debug!("[server#send_message] Sending message: {}", message);

        handler.network().send(*endpoint, message.as_bytes());
    }

    pub fn disconnect(&self, resource_id: ResourceId) -> bool {
        let handler = match self.handler() {
            Some(handler) => handler,
            None => return false,
        };

        let removed = handler.network().remove(resource_id);
        match self.remove_endpoint(resource_id) {
            Some(_) => (),
            None => {
                warn!(
                    "[server#disconnect] {} Endpoint already removed",
                    resource_id
                );
            }
        };

        removed
    }

    fn on_connect(&self, endpoint: Endpoint, resource_id: ResourceId) {
        debug!(
            "[server#on_connect] {} Incoming connection with address {}",
            resource_id,
            endpoint.addr()
        );

        let mut endpoints = match self.endpoints_mut() {
            Some(endpoints) => endpoints,
            None => return,
        };

        let adapter_id = resource_id.adapter_id() as usize;

        // Check if the client has already connected
        match endpoints.get(&adapter_id) {
            Some(_) => {
                // Release the lock this scope owns so the remove can lock it.
                drop(endpoints);

                debug!(
                    "[server#on_connect] {} Endpoint already connected",
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

        trace!("[server#on_connect] {} Connection added", resource_id);

        // Inform the bot of a new connection
        let result = match self.instance.read() {
            Ok(instance) => instance.protect_send(
                "on_connect",
                &[Integer::new(resource_id.adapter_id() as i64).to_any_object()],
            ),
            Err(error) => {
                error!(
                    "[server#on_connect] {} Failed to gain read lock on instance. Error: {:?}",
                    resource_id, error
                );
                return;
            }
        };

        match result {
            Ok(_) => {
                debug!("[server#on_connect] {} has connected", resource_id);
            }
            Err(error) => {
                error!(
                    "[server#on_connect] {} Failed to call `on_connect`. Error: {:?}",
                    resource_id, error
                );
            }
        }
    }

    fn on_message(&self, endpoint: Endpoint, data: Vec<u8>) {
        let resource_id = endpoint.resource_id();

        let client_message: ClientMessage = match bincode::deserialize(&data) {
            Ok(message) => message,
            Err(_error) => {
                error!(
                    "[server#on_message] {} Malformed message: {}",
                    resource_id,
                    String::from_utf8_lossy(&data)
                );
                return;
            }
        };

        debug!(
            "[server#on_message] {} Message: {:?}",
            resource_id, client_message
        );

        // Trigger the on_message on the ruby side
        let result = match self.instance.read() {
            Ok(instance) => instance.protect_send(
                "on_message",
                &[
                    Integer::new(resource_id.adapter_id() as i64).to_any_object(),
                    client_message.to_hash().to_any_object(),
                ],
            ),
            Err(error) => {
                error!(
                    "[server#on_message] {} Failed to gain read lock on instance. Error: {:?}",
                    resource_id, error
                );
                return;
            }
        };

        match result {
            Ok(_) => {
                debug!("[server#on_message] {} has connected", resource_id);
            }
            Err(error) => {
                error!(
                    "[server#on_message] {} Failed to call `on_message`. Error: {:?}",
                    resource_id, error
                );
            }
        }
    }

    fn on_disconnect(&self, endpoint: Endpoint) {
        let resource_id = endpoint.resource_id();
        debug!("[server#on_disconnect] {} has disconnected", resource_id);

        match self.remove_endpoint(resource_id) {
            Some(_) => (),
            None => {
                warn!(
                    "[server#on_disconnect] {} Endpoint already removed",
                    resource_id
                );
            }
        };

        // Trigger the on_message on the ruby side
        let result = match self.instance.read() {
            Ok(instance) => instance.protect_send(
                "on_disconnect",
                &[Integer::new(resource_id.adapter_id() as i64).to_any_object()],
            ),
            Err(error) => {
                error!(
                    "[server#on_disconnect] {} Failed to gain read lock on instance. Error: {:?}",
                    resource_id, error
                );
                return;
            }
        };

        match result {
            Ok(_) => {
                debug!("[server#on_disconnect] #on_disconnect called successfully");
            },
            Err(error) => {
                error!(
                    "[server#on_disconnect] {} Failed to call `on_disconnect`. Error: {:?}",
                    resource_id, error
                );
            }
        }
    }
}
