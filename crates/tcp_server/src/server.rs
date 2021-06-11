use crate::{connection::ConnectionManager, message::Message, message::Type};
use log::*;
use message_io::{network::{Endpoint, ResourceId}, node::{self, NodeHandler}};
use message_io::{
    network::{NetEvent, Transport},
    node::NodeListener,
};
use serde_json::json;
use tokio::sync::RwLock;
use redis::{AsyncCommands, Client, Commands, Connection, RedisError, aio::MultiplexedConnection};
use std::{collections::HashMap, env};
use std::{sync::Arc};
use tokio::sync::mpsc::{self, UnboundedReceiver, UnboundedSender};
use parking_lot::{RwLock as SyncRwLock};

#[derive(Clone)]
pub struct Server {
    handler: NodeHandler<()>,
    connection_manager: Arc<SyncRwLock<ConnectionManager>>,
    redis_client: Client,
    redis: Arc<SyncRwLock<Connection>>,
    outbound_sender: UnboundedSender<Message>,
    outbound_receiver:  Arc<RwLock<UnboundedReceiver<Message>>>,
    address: String,
}

impl Server {
    pub fn new(handler: NodeHandler<()>) -> Self {
        let address = match env::var("TCP_SERVER_PORT") {
            Ok(port) => {
                format!("0.0.0.0:{}", port)
            }
            Err(_e) => panic!("TCP_SERVER_PORT is not set!")
        };

        let redis_client = match redis::Client::open("redis://127.0.0.1/") {
            Ok(client) => client,
            Err(e) => panic!(format!("Failed to connect to redis. Reason: {}", e))
        };

        let redis = match redis_client.get_connection() {
            Ok(con) => con,
            Err(e) => panic!(format!("Failed to get sync connection. Reason: {}", e))
        };

        let (sender, receiver) = mpsc::unbounded_channel();

        Server {
            handler,
            connection_manager: Arc::new(SyncRwLock::new(ConnectionManager::new())),
            outbound_sender: sender,
            outbound_receiver: Arc::new(RwLock::new(receiver)),
            redis_client: redis_client,
            redis: Arc::new(SyncRwLock::new(redis)),
            address,
        }
    }

    async fn get_redis_connection(&self) -> Result<MultiplexedConnection, RedisError> {
        self.redis_client.get_multiplexed_tokio_connection().await
    }

    /// Send a Message to the bot.
    fn send_to_bot(&self, message: Message) {
        match self.outbound_sender.send(message) {
            Ok(()) => {},
            Err(e) => {
                error!("#send_message - {}", e);
            }
        }
    }

    pub fn server_key<'a>(&self, server_id: &String) -> Option<Vec<u8>> {
        match self.redis.write().hget("server_keys", server_id) {
            Ok(key) => key,
            Err(e) => {
                error!("#server_key - {}", e);
                None
            },
        }
    }

    pub async fn listen(&mut self, listener: NodeListener<()>) {
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
                self.on_message(endpoint, data.to_vec())
            }
            NetEvent::Disconnected(endpoint) => {
                self.on_disconnect(endpoint)
            }
            NetEvent::Accepted(endpoint, resource_id) => {
                self.on_connect(endpoint, resource_id)
            }
        });
    }

    /// Spawn's workers to handle delegating and processing messages to/from the bot
    pub async fn start_workers(&self) {
        // Delegate inbound messages
        for _ in 1..=2 {
            let server = self.clone();
            let _ = tokio::spawn(async move {
                server.delegate_inbound_messages().await
            });
        }

        // Process inbound messages
        for _ in 1..=2 {
            let mut server = self.clone();
            let _ = tokio::spawn(async move {
                server.process_inbound_messages().await
            });
        }

        // Delegate outbound messages
        for _ in 1..=2 {
            let server = self.clone();
            let _ = tokio::spawn(async move {
                server.delegate_outbound_messages().await
            });
        }
    }

    /// Moves messages from the connection server outbound queue to the tcp server inbound queue.
    /// Processing of these messages occurs in #process_inbound_messages
    async fn delegate_inbound_messages(&self) -> redis::RedisResult<isize> {
        let mut connection = match self.get_redis_connection().await {
            Ok(connection) => connection,
            Err(e) => panic!("#process_inbound_messages - {}", e)
        };

        loop {
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
                Err(e) => error!("#delegate_inbound_messages - {}", e)
            };
        }
    }

    /// Moves messages from the internal outbound queue into the redis outbound queue so the bot may pick them up
    async fn delegate_outbound_messages(&self) {
        let mut connection = match self.get_redis_connection().await {
            Ok(connection) => connection,
            Err(e) => panic!("#delegate_outbound_messages - {}", e)
        };

        loop {
            let mut receiver = self.outbound_receiver.write().await;

            let message = match receiver.recv().await {
                Some(message) => message,
                None => continue
            };

            let json: String = match serde_json::to_string(&message) {
                Ok(json) => json,
                Err(e) => {
                    error!("#delegate_outbound_messages - {}", e);
                    continue;
                }
            };

            let _: () = match redis::cmd("RPUSH")
                .arg("tcp_server_outbound")
                .arg(json)
                .query_async(&mut connection)
                .await
            {
                Ok(r) => r,
                Err(e) => error!("#delegate_inbound_messages - {}", e)
            };
        }
    }

    /// Processes messages from the redis inbound queue based on their message_type.
    /// These messages are moved into this queue by #delegate_inbound_messages
    async fn process_inbound_messages(&mut self) -> redis::RedisResult<isize> {
        let mut connection = match self.get_redis_connection().await {
            Ok(connection) => connection,
            Err(e) => panic!("#process_inbound_messages - {}", e)
        };

        loop {
            let (_, json): (String, String) = match redis::cmd("BLPOP")
                .arg("tcp_server_inbound")
                .arg(0)
                .query_async(&mut connection)
                .await
            {
                Ok(json) => json,
                Err(e) => {
                    error!("#process_inbound_messages - {:?}", e);
                    continue;
                }
            };

            let message: Message = match serde_json::from_str(&json) {
                Ok(message) => message,
                Err(e) => {
                    error!("#process_inbound_messages - {}", e);
                    continue;
                }
            };

            info!("#process_inbound_messages - Incoming message: {:#?}", message);

            match message.message_type {
                _ => {}
            }
        }
    }

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

    pub fn disconnect(&self, resource_id: ResourceId) {
        self.connection_manager.write().remove_by_resource_id(resource_id);
        self.handler.network().remove(resource_id);
    }

    fn on_connect(&mut self, endpoint: Endpoint, resource_id: ResourceId) {
        debug!(
            "#on_connect - {} Incoming connection with address {}",
            resource_id,
            endpoint.addr()
        );

        self.connection_manager.write().add_to_lobby(resource_id, endpoint);
        trace!("#on_connect - {} Connection added", resource_id);
    }

    fn on_message(&self, endpoint: Endpoint, data: Vec<u8>) {
        let resource_id = endpoint.resource_id();
        let message = Message::from_bytes(data, resource_id, |server_id| self.server_key(server_id));

        let message = match message {
            Ok(message) => message,
            Err(e) => {
                error!("#on_message - {}", e);
                self.disconnect(endpoint.resource_id());
                return;
            }
        };

        debug!("#on_message - {} Message: {:?}", resource_id, message);

        match message.message_type {
            // Feed the message through to the bot
            _ => self.send_to_bot(message)
        };
    }

    fn on_disconnect(&self, endpoint: Endpoint) {
        let resource_id = endpoint.resource_id();
        debug!("#on_disconnect - {} has disconnected", resource_id);

        // Remove the resource from the connection_manager
        self.connection_manager.write().remove_by_resource_id(resource_id);

        let message = Message::new(Type::OnDisconnect, resource_id);
        self.send_to_bot(message);
    }
}
