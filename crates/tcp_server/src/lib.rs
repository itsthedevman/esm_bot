#[macro_use] extern crate rutie;
#[macro_use] extern crate lazy_static;

use std::sync::{Arc, Mutex};
use rutie::{AnyObject, VM, Object, Boolean, RString, NilClass, Module, Class};
use message_io::node::{self, NodeHandler, NodeListener};
use message_io::network::{NetEvent, Transport};
use std::thread;

lazy_static! {
    static ref THING: Mutex<i32> = Mutex::new(0);
}

pub struct Server {
    // An instance of ESM::Connection::Server
    instance: AnyObject,
    handler: Arc<NodeHandler<()>>,
}

impl Server {
    fn new(instance: AnyObject, port: RString) -> Self {
        let (handler, listener) = node::split::<()>();
        let server = Server { instance, handler: Arc::new(handler) };

        server.listen(listener, port);
        server
    }

    fn instance(&self) -> &AnyObject {
        &self.instance
    }

    fn listen(&self, listener: NodeListener<()>, port: RString) {
        let address = format!("0.0.0.0:{}", port.to_str());
        let handler = self.handler.clone();

        // Start listening
        match handler.network().listen(Transport::FramedTcp, &address) {
            Ok((_resource_id, _real_addr)) => (),
            Err(_) => {
                return VM::raise(
                    Module::from_existing("ESM").get_nested_module("Exception").get_nested_class("AddressInUse"),
                    &address
                )
            }
        }

        // And wait for the events
        thread::spawn(|| {
            listener.for_each(move |event| match event.network() {
                NetEvent::Connected(_endpoint, _) => println!("Client connected"), // Tcp or Ws
                NetEvent::Message(endpoint, data) => {
                    println!("Received: {}", String::from_utf8_lossy(data));
                    handler.network().send(endpoint, data);
                },
                NetEvent::Disconnected(_endpoint) => println!("Client disconnected"), //Tcp or Ws
            });
        });
    }
}

wrappable_struct!(Server, ServerWrapper, SERVER_WRAPPER);

class!(TCPServer);

methods!(
    TCPServer,
    rtself,

    fn ruby_new(instance: AnyObject, port: RString) -> AnyObject {
        if let Err(ref error) = instance {
            VM::raise(error.class(), "Argument `instance` is invalid");
        }

        if let Err(ref error) = port {
            VM::raise(error.class(), "Argument `port` is invalid");
        }

        let server = Server::new(instance.unwrap(), port.unwrap());
        Module::from_existing("ESM").get_nested_class("TCPServer").wrap_data(server, &*SERVER_WRAPPER)
    }

    fn ruby_send_message(message: RString) -> NilClass {
        let instance = rtself.get_data(&*SERVER_WRAPPER).instance();

        let result = unsafe { instance.send("callback", &[]) };
        match result.try_convert_to::<Boolean>() {
            Ok(success) => success,
            Err(_) => Boolean::new(false),
        };

        NilClass::new()
    }
);

#[allow(non_snake_case)]
#[no_mangle]
pub extern "C" fn esm_tcp_server() {
    Module::from_existing("ESM").define(|module| {
        module.define_nested_class("TCPServer", None).define(|klass| {
            klass.def_self("new", ruby_new);
            klass.def("send_message", ruby_send_message);
        });
    });
}
