#[macro_use] extern crate rutie;
#[macro_use] extern crate lazy_static;

use std::sync::{Arc, Mutex};
use rutie::{AnyObject, Class, Object, Boolean, RString, NilClass};
use message_io::node::{self, NodeHandler, NodeListener};
use message_io::network::{NetEvent, Transport};
use std::thread;

lazy_static! {
    static ref THING: Mutex<i32> = Mutex::new(0);
}

pub struct Server {
    process: AnyObject,
    handler: Arc<NodeHandler<()>>,
}

impl Server {
    fn new(process: AnyObject) -> Self {
        let (handler, listener) = node::split::<()>();
        handler.network().listen(Transport::FramedTcp, "0.0.0.0:3003").unwrap();

        let server = Server { process, handler: Arc::new(handler) };

        server.listen(listener);

        server
    }

    fn process(&self) -> &AnyObject {
        &self.process
    }

    fn listen(&self, listener: NodeListener<()>) {
        let handler = self.handler.clone();

        thread::spawn(move || {
            // Read incoming network events.
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

    fn ruby_new(process: AnyObject) -> AnyObject {
        let server = Server::new(process.unwrap());

        Class::from_existing("ETCPServer").wrap_data(server, &*SERVER_WRAPPER)
    }

    fn ruby_send_message(message: RString) -> NilClass {
        let process = rtself.get_data(&*SERVER_WRAPPER).process();

        let result = unsafe { process.send("callback", &[]) };
        match result.try_convert_to::<Boolean>() {
            Ok(success) => success,
            Err(_) => Boolean::new(false),
        };

        NilClass::new()
    }
);

#[allow(non_snake_case)]
#[no_mangle]
pub extern "C" fn tcp_server() {
    let data_class = Class::from_existing("Object");

    Class::new("ETCPServer", Some(&data_class)).define(|klass| {
        klass.def_self("new", ruby_new);
        klass.def("send_message", ruby_send_message);
    });
}
