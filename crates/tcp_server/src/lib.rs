#[macro_use]
extern crate rutie;
#[macro_use]
extern crate lazy_static;

mod client_message;
mod server_message;
mod server;

use log::*;
use std::sync::RwLock;
use server_message::ServerMessage;
use server::{Server, Event};
use crossbeam::channel::{bounded, unbounded, Receiver, Sender};


use rutie::{AnyObject, Boolean, Class, Hash, Integer, Module, NilClass, Object, RString, VM, Array};


lazy_static! {
    /*
        These references are used to communicate between a Ruby thread and a Rust thread, essentially.
        In order to make calls to Ruby, the current thread must be owned by the Ruby GVL. This requires spawning a new thread and lock it in a continuous loop in Rust. See Server#process_requests.
    */
    static ref RECEIVER: RwLock<Receiver<Event>> = {
        let (_s, receiver) = bounded(0);
        RwLock::new(receiver)
    };
    static ref SENDER: RwLock<Sender<Event>> = {
        let (sender, _r) = bounded(0);
        RwLock::new(sender)
    };
    static ref SERVER: RwLock<Server> = {
        RwLock::new(
            Server::new(
                Array::new(),
                Array::new()
            )
        )
    };
}

class!(TCPServer);

methods!(
    TCPServer,
    _rtself,
    fn rb_stop() -> Boolean {
        match SENDER.read() {
            Ok(sender) => {
                match sender.send(server::Event::Stop) {
                    Ok(_) => Boolean::new(true),
                    Err(_) => Boolean::new(false)
                }
            },
            Err(_error) => {
                VM::raise(Class::from_existing("StandardError"), "Failed to gain read access to sender");
                return Boolean::new(false);
            }
        }
    },
    fn rb_listen(port: RString, inbound_messages: Array, outbound_messages: Array) -> NilClass {
        let inbound_messages = match inbound_messages {
            Ok(inbound_messages) => inbound_messages,
            Err(error) => {
                VM::raise(error.class(), "Argument `inbound_messages` is invalid");
                return NilClass::new();
            }
        };

        let outbound_messages = match outbound_messages {
            Ok(outbound_messages) => outbound_messages,
            Err(error) => {
                VM::raise(error.class(), "Argument `outbound_messages` is invalid");
                return NilClass::new();
            }
        };

        let port = match port {
            Ok(port) => port.to_string(),
            Err(error) => {
                VM::raise(error.class(), "Argument `port` is invalid");
                return NilClass::new();
            }
        };

        // Start listening for connections
        let mut server = Server::new(inbound_messages, outbound_messages);
        server.listen(port);

        // Store the server instance in the global
        match SERVER.write() {
            Ok(mut container) => *container = server,
            Err(_error) => {
                VM::raise(Class::from_existing("StandardError"), "Failed to gain write access to server container");
                return NilClass::new();
            }
        };

        NilClass::new()
    },
    fn rb_process_requests() -> NilClass {
        let server = match SERVER.read() {
            Ok(server) => server,
            Err(_error) => {
                VM::raise(Class::from_existing("StandardError"), "Failed to gain read access to server container");
                return NilClass::new();
            }
        };

        server.process_requests();

        NilClass::new()
    },
    fn rb_send_message(resource_id: Integer, message: Hash) -> NilClass {
        let resource_id = match resource_id {
            Ok(id) => id.to_i64(),
            Err(error) => {
                VM::raise(error.class(), "Argument `resource_id` is invalid");
                return NilClass::new();
            }
        };

        let message = match message {
            Ok(message) => ServerMessage::new(message),
            Err(error) => {
                VM::raise(error.class(), "Argument `message` is invalid");
                return NilClass::new();
            }
        };

        match SERVER.read() {
            Ok(server) => server.send_message(resource_id, message),
            Err(_error) => {
                VM::raise(Class::from_existing("StandardError"), "Failed to gain read access to server container");
                return NilClass::new();
            }
        };

        NilClass::new()
    },
    fn rb_disconnect(resource_id: Integer) -> Boolean {
        debug!("disconnect 1");
        let resource_id = match resource_id {
            Ok(id) => id.to_i64(),
            Err(error) => {
                VM::raise(error.class(), "Argument `resource_id` is invalid");
                return Boolean::new(false);
            }
        };

        debug!("disconnect 2");
        let server = match SERVER.read() {
            Ok(server) => server,
            Err(_error) => {
                VM::raise(Class::from_existing("StandardError"), "Failed to gain read access to server container");
                return Boolean::new(false);
            }
        };

        debug!("Disconnect 3");

        let endpoints = match server.endpoints() {
            Some(endpoints) => endpoints,
            None => return Boolean::new(false),
        };

        match endpoints.get(&(resource_id as usize)) {
            Some(endpoint) => {
                let result = server.disconnect(endpoint.resource_id());
                Boolean::new(result)
            }
            None => Boolean::new(false),
        }
    },
);

#[allow(non_snake_case)]
#[no_mangle]
pub extern "C" fn esm_tcp_server() {
    env_logger::init();
    VM::init();
    lazy_static::initialize(&RECEIVER);
    lazy_static::initialize(&SENDER);
    lazy_static::initialize(&SERVER);

    // Overwrite the globals with a proper channel pair
    let (sender, receiver) = unbounded();
    *SENDER.write().unwrap() = sender;
    *RECEIVER.write().unwrap() = receiver;

    Module::from_existing("ESM").define(|module| {
        module
            .define_nested_class("TCPServer", None)
            .define(|klass| {
                klass.def_self("stop", rb_stop);
                klass.def_self("listen", rb_listen);
                klass.def_self("process_requests", rb_process_requests);
                klass.def_self("send_message", rb_send_message);
                klass.def_self("disconnect", rb_disconnect);
            });
    });
}
