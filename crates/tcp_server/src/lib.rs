#[macro_use]
extern crate rutie;
#[macro_use]
extern crate lazy_static;

mod client_message;

use crossbeam::channel::{self, Receiver, Sender, bounded, unbounded};
use log::*;
use message_io::network::{NetEvent, Transport};
use message_io::{
    network::{Endpoint, ResourceId},
    node::{self, NodeHandler, NodeListener, NodeTask},
};
use rutie::{AnyException, AnyObject, Integer, Module, NilClass, Object, RString, Thread, VM};
use std::{sync::{RwLock, RwLockReadGuard, RwLockWriteGuard}, thread};
use std::{
    collections::HashMap,
    sync::{Arc, Mutex},
    time::Duration,
};
use client_message::ClientMessage;

use crate::client_message::ToHash;

lazy_static!(
    static ref RECEIVER: RwLock<Receiver<Event>> = {
        let (_s, receiver) = bounded(0);
        RwLock::new(receiver)
    };

    static ref SENDER: RwLock<Sender<Event>> = {
        let (sender, _r) = bounded(0);
        RwLock::new(sender)
    };
);

#[derive(Debug)]
enum Event {
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
    fn new(instance: AnyObject) -> Self {
        let (handler, _) = node::split::<()>();
        Server {
            instance: RwLock::new(instance),
            endpoints: RwLock::new(HashMap::new()),
            handler: RwLock::new(handler),
            task: Mutex::new(None)
        }
    }

    // This is called from a ruby thread and it is blocking.
    fn listen(&mut self, port: String) {
        let (handler, listener) = node::split::<()>();
        let address = format!("0.0.0.0:{}", port);

        // Start listening
        match handler.network().listen(Transport::FramedTcp, &address) {
            Ok((_resource_id, _real_addr)) => {
                debug!("[server#listen] Listening on port {}", port);
            },
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
        let task =
            listener.for_each_async(move |event| match event.network() {
                NetEvent::Connected(endpoint, resource_id) => {
                    match SENDER.read().unwrap().send(Event::OnConnected(endpoint, resource_id)) {
                        Ok(_) => {},
                        Err(error) => {
                            error!("[server#listen] {} Failed to send OnConnected event. Error: {:?}", resource_id, error);
                        }
                    }
                }
                NetEvent::Message(endpoint, data) => {
                    match SENDER.read().unwrap().send(Event::OnMessage(endpoint, data.to_vec())) {
                        Ok(_) => {},
                        Err(error) => {
                            error!("[server#listen] {} Failed to send OnConnected event. Error: {:?}", endpoint.resource_id(), error);
                        }
                    }
                }
                NetEvent::Disconnected(endpoint) => {
                    match SENDER.read().unwrap().send(Event::OnDisconnect(endpoint)) {
                        Ok(_) => {},
                        Err(error) => {
                            error!("[server#listen] {} Failed to send OnDisconnected event. Error: {:?}", endpoint.resource_id(), error);
                        }
                    }
                }
            });

        self.task = Mutex::new(Some(task));
    }

    // This is called from a ruby thread and it is blocking.
    fn process_requests(&self) {
        loop {
            let event = match RECEIVER.read().unwrap().recv() {
                Ok(event) => event,
                Err(error) => {
                    error!("[server#process_requests] Failed to receive message. Error: {:?}", error);
                    continue;
                }
            };

            trace!("[server#process_requests] Incoming event: {:?}", event);

            match event {
                Event::OnConnected(endpoint, resource_id) => self.on_connected(endpoint, resource_id),
                Event::OnMessage(endpoint, data) => self.on_message(endpoint, data),
                Event::OnDisconnect(endpoint) => self.on_disconnect(endpoint),
            }
        };
    }

    fn endpoints(&self) -> Option<RwLockReadGuard<HashMap<usize, Endpoint>>> {
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

                    error!("[server#endpoint] Failed to gain read lock. Reason: {:?}", e);
                    return None;
                }
            }
        };

        Some(endpoints)
    }

    fn endpoints_mut(&self) -> Option<RwLockWriteGuard<HashMap<usize, Endpoint>>> {
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

                    error!("[server#endpoint_mut] Failed to gain write lock. Reason: {:?}", e);
                    return None;
                }
            }
        };

        Some(endpoints)
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

    fn send_message(&self, resource_id: i64, message: String) {
        // Retrieve the connection
        let endpoints = match self.endpoints() {
            Some(endpoints) => endpoints,
            None => return
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
                )
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

    fn remove(&self, resource_id: ResourceId) -> bool {
        let handler = match self.handler() {
            Some(handler) => handler,
            None => return false,
        };

        let removed = handler.network().remove(resource_id);

        let mut endpoints = match self.endpoints_mut() {
            Some(endpoints) => endpoints,
            None => return false
        };

        let adapter_id = resource_id.adapter_id() as usize;
        match endpoints.remove(&adapter_id) {
            Some(_) => (),
            None => {
                warn!("[server#remove] R:{} Endpoint already remove", resource_id);
                return true;
            },
        };

        removed
    }

    fn on_connected(&self, endpoint: Endpoint, resource_id: ResourceId) {
        debug!(
            "[server#on_connected] {} Incoming connection with address {}",
            resource_id,
            endpoint.addr()
        );

        let mut endpoints = match self.endpoints_mut() {
            Some(endpoints) => endpoints,
            None => return
        };

        let adapter_id = resource_id.adapter_id() as usize;
        match endpoints.get(&adapter_id) {
            Some(_) => {
                // Release the lock this scope owns so the remove can lock it.
                drop(endpoints);

                debug!("[server#on_connected] {} Endpoint already connected", adapter_id);
                println!("Suc: {}", self.remove(resource_id));
                return;
            }
            None => (),
        }

        // Store the connection so it can be retrieved later
        endpoints.insert(adapter_id, endpoint);
        trace!("[server#on_connected] {} Connection added", resource_id);

        // We no longer need write access, release it so other threads can gain read access
        drop(endpoints);

        // Inform the bot of a new connection
        let result = match self.instance.read() {
            Ok(instance) => {
                instance.protect_send(
                    "on_connected",
                    &[Integer::new(resource_id.adapter_id() as i64).to_any_object()],
                )
            },
            Err(error) => {
                error!(
                    "[server#on_connected] {} Failed to gain read lock on instance. Error: {:?}",
                    resource_id, error
                );
                return;
            }
        };

        match result {
            Ok(_) => {
                debug!("[server#on_connected] {} has connected", resource_id);
            },
            Err(error) => {
                error!(
                    "[server#on_connected] {} Failed to call `on_open`. Error: {:?}",
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
                error!("[server#on_message] {} Malformed message: {}", resource_id, String::from_utf8_lossy(&data));
                return;
            }
        };

        debug!("[server#on_message] {} Message: {:?}", endpoint.resource_id(), client_message);

        // Trigger the on_message on the ruby side
        let result = match self.instance.read() {
            Ok(instance) => {
                instance.protect_send(
                    "on_message",
                    &[Integer::new(resource_id.adapter_id() as i64).to_any_object(), client_message.to_hash().to_any_object()],
                )
            },
            Err(error) => {
                error!(
                    "[server#on_connected] {} Failed to gain read lock on instance. Error: {:?}",
                    resource_id, error
                );
                return;
            }
        };

        match result {
            Ok(_) => {
                debug!("[server#on_connected] {} has connected", resource_id);
            },
            Err(error) => {
                error!(
                    "[server#on_connected] {} Failed to call `on_open`. Error: {:?}",
                    resource_id, error
                );
            }
        }
    }

    fn on_disconnect(&self, endpoint: Endpoint) {

    }
}

wrappable_struct!(Server, ServerWrapper, SERVER_WRAPPER);

class!(TCPServer);

methods!(
    TCPServer,
    rtself,
    fn rb_new(instance: AnyObject, port: RString) -> AnyObject {
        if let Err(ref error) = instance {
            VM::raise(error.class(), "Argument `instance` is invalid");
        }

        let server = Server::new(instance.unwrap());
        Module::from_existing("ESM")
            .get_nested_class("TCPServer")
            .wrap_data(server, &*SERVER_WRAPPER)
    },

    fn rb_listen(port: RString) -> NilClass {
        let port = match port {
            Ok(port) => port.to_string(),
            Err(error) => {
                VM::raise(error.class(), "Argument `port` is invalid");
                return NilClass::new();
            }
        };

        let server = rtself.get_data_mut(&*SERVER_WRAPPER);
        server.listen(port);

        NilClass::new()
    },

    fn rb_process_requests() -> NilClass {
        let server = rtself.get_data(&*SERVER_WRAPPER);
        server.process_requests();

        NilClass::new()
    }

    fn rb_send_message(resource_id: Integer, message: RString) -> NilClass {
        let server = rtself.get_data(&*SERVER_WRAPPER);
        server.send_message(resource_id.unwrap().to_i64(), message.unwrap().to_string());

        NilClass::new()
    },

    fn rb_stop() -> NilClass {
        let server = rtself.get_data(&*SERVER_WRAPPER);
        // server.stop();

        NilClass::new()
    }
);

#[allow(non_snake_case)]
#[no_mangle]
pub extern "C" fn esm_tcp_server() {
    env_logger::init();
    VM::init();
    lazy_static::initialize(&RECEIVER);

    // Overwrite the globals with a proper channel pair
    let (sender, receiver) = unbounded();
    *SENDER.write().unwrap() = sender;
    *RECEIVER.write().unwrap() = receiver;

    Module::from_existing("ESM").define(|module| {
        module
            .define_nested_class("TCPServer", None)
            .define(|klass| {
                klass.def_self("new", rb_new);
                klass.def("listen", rb_listen);
                klass.def("process_requests", rb_process_requests);
                klass.def("send_message", rb_send_message);
                klass.def("stop", rb_stop);
            });
    });
}
