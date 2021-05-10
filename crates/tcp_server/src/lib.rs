#[macro_use]
extern crate rutie;
#[macro_use]
extern crate lazy_static;

mod client_message;
mod server;

use std::sync::RwLock;

use server::{Server, Event};
use crossbeam::channel::{bounded, unbounded, Receiver, Sender};


use rutie::{AnyObject, Boolean, Integer, Module, NilClass, Object, RString, VM};


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
}

wrappable_struct!(Server, ServerWrapper, SERVER_WRAPPER);

class!(TCPServer);

methods!(
    TCPServer,
    rtself,
    fn rb_new(instance: AnyObject) -> AnyObject {
        let instance = match instance {
            Ok(instance) => instance,
            Err(error) => {
                VM::raise(error.class(), "Argument `instance` is invalid");
                return NilClass::new().to_any_object();
            }
        };

        let server = Server::new(instance);
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
    },
    fn rb_send_message(resource_id: Integer, message: RString) -> NilClass {
        let resource_id = match resource_id {
            Ok(id) => id.to_i64(),
            Err(error) => {
                VM::raise(error.class(), "Argument `resource_id` is invalid");
                return NilClass::new();
            }
        };

        let message = match message {
            Ok(message) => message.to_string(),
            Err(error) => {
                VM::raise(error.class(), "Argument `message` is invalid");
                return NilClass::new();
            }
        };

        let server = rtself.get_data(&*SERVER_WRAPPER);
        server.send_message(resource_id, message);

        NilClass::new()
    },
    fn rb_disconnect(resource_id: Integer) -> Boolean {
        let resource_id = match resource_id {
            Ok(id) => id.to_i64(),
            Err(error) => {
                VM::raise(error.class(), "Argument `resource_id` is invalid");
                return Boolean::new(false);
            }
        };

        let server = rtself.get_data(&*SERVER_WRAPPER);

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
                klass.def("disconnect", rb_disconnect);
            });
    });
}
