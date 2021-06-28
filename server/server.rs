use crate::{connection::ConnectionManager};
use log::*;
use message_io::{network::{Endpoint, ResourceId}, node::{self, NodeHandler}};
use message_io::{
    network::{NetEvent, Transport},
    node::NodeListener,
};
use esm_message::{ErrorType, Message, Type};
use tokio::{sync::{RwLock}, time::sleep};
use redis::{AsyncCommands, Client, Commands, Connection, RedisError, aio::MultiplexedConnection};
use std::{env, sync::atomic::{AtomicBool, Ordering}, time::Duration};
use std::{sync::Arc};
use tokio::sync::mpsc::{self, UnboundedReceiver, UnboundedSender};
use parking_lot::{RwLock as SyncRwLock};

#[derive(Clone)]
pub struct Server {
    handler: NodeHandler<()>,
    connection_manager: Arc<SyncRwLock<ConnectionManager>>,
    redis_client: Client,
    pub redis: Arc<SyncRwLock<Connection>>,
    outbound_sender: UnboundedSender<Message>,
    outbound_receiver:  Arc<RwLock<UnboundedReceiver<Message>>>,
    address: String,

    // The master flag
    bot_alive: Arc<AtomicBool>,

    // Used for tracking if there was a pong received. Use `bot_alive` for checking if the bot is still online
    bot_pong_received: Arc<AtomicBool>
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
            Err(e) => panic!("Failed to connect to redis. Reason: {}", e)
        };

        let redis = match redis_client.get_connection() {
            Ok(con) => con,
            Err(e) => panic!("Failed to get sync connection. Reason: {}", e)
        };

        let (sender, receiver) = mpsc::unbounded_channel();

        Server {
            handler,
            redis_client,
            address,
            connection_manager: Arc::new(SyncRwLock::new(ConnectionManager::new())),
            outbound_sender: sender,
            outbound_receiver: Arc::new(RwLock::new(receiver)),
            bot_alive: Arc::new(AtomicBool::new(false)),
            bot_pong_received: Arc::new(AtomicBool::new(true)),
            redis: Arc::new(SyncRwLock::new(redis)),
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

    fn send_to_client(&self, message: &mut Message) -> bool {
        let server_id = match message.server_id.clone() {
            Some(id) => id,
            None => {
                message.add_error(ErrorType::Message, "Cannot send message - Missing server_id");
                return false;
            }
        };

        let connection_manager = self.connection_manager.read();
        let endpoint = match connection_manager.find_by_server_id(server_id) {
            Some(endpoint) => endpoint,
            None => {
                message.add_error(ErrorType::Code, "client_not_connected");
                return false;
            }
        };

        match message.as_bytes(|server_id| self.server_key(server_id)) {
            Ok(bytes) => {
                info!("#send_to_client - {}", message.id);

                self.handler.network().send(endpoint.to_owned(), &bytes);
                true
            },
            Err(error) => {
                error!("#send_to_client - {}", error);
                false
            }
        }

    }

    pub fn server_key(&self, server_id: &[u8]) -> Option<Vec<u8>> {
        let server_id = match String::from_utf8(server_id.to_owned()) {
            Ok(id) => id,
            Err(e) => {
                error!("#server_key - {}", e);
                return None
            }
        };

        match self.redis.write().hget("server_keys", server_id) {
            Ok(key) => key,
            Err(e) => {
                error!("#server_key - {}", e);
                None
            },
        }
    }

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
        let mut server = self.clone();
        listener.for_each(move |event| match event.network() {
            NetEvent::Connected(_, _) => {},
            NetEvent::Message(endpoint, data) => {
                server.on_message(endpoint, data.to_vec())
            },
            NetEvent::Disconnected(endpoint) => {
                server.on_disconnect(endpoint)
            },
            NetEvent::Accepted(endpoint, resource_id) => {
                server.on_connect(endpoint, resource_id)
            },
        });
    }

    /// Spawn's workers to handle delegating and processing messages to/from the bot
    pub async fn start_workers(&self) {
        // Ping the bot
        let mut server = self.clone();
        let _ = tokio::spawn(async move {
            server.ping_bot().await
        });

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
            let (_, json): (String, String) = match connection.blpop("tcp_server_inbound", 0).await {
                Ok(json) => json,
                Err(e) => {
                    error!("#process_inbound_messages - {:?}", e);
                    continue;
                }
            };

            let mut message: Message = match serde_json::from_str(&json) {
                Ok(message) => message,
                Err(e) => {
                    error!("#process_inbound_messages - {}", e);
                    continue;
                }
            };

            if message.message_type != Type::Pong {
                debug!("#process_inbound_messages - {:#?}", message);
            }

            match message.message_type {
                // Received from the bot after a ping has been sent
                Type::Pong => {
                    // Set the flag to true
                    self.bot_pong_received.store(true, Ordering::Relaxed);
                },
                _ => {
                    let success = self.send_to_client(&mut message);
                    if success { continue; }

                    // The message failed, send it back to the bot
                    self.send_to_bot(message);
                }
            }
        }
    }

    /// Pings the bot and tracks if it replies
    async fn ping_bot(&mut self) {
        loop {
            sleep(Duration::from_millis(500)).await;
            if !self.bot_pong_received.load(Ordering::SeqCst) { continue; }

            // Set the flag back to false before sending the ping
            self.bot_pong_received.store(false, Ordering::SeqCst);

            let message = Message::new(Type::Ping);
            self.send_to_bot(message);

            // Give the bot up to 200ms to reply before considering it "offline"
            let mut currently_alive = false;
            for _ in 0..200 {
                if self.bot_pong_received.load(Ordering::SeqCst) {
                    currently_alive = true;
                    break;
                }

                sleep(Duration::from_millis(1)).await;
            }

            // Only write and log if the status has changed
            let previously_alive = self.bot_alive.load(Ordering::SeqCst);
            if currently_alive == previously_alive { continue; }

            self.bot_alive.store(currently_alive, Ordering::SeqCst);

            if currently_alive {
                info!("#ping_bot - Connected");
            } else {
                warn!("#ping_bot - Disconnected");

                // Disconnect all connections to simulate a disconnect
                self.disconnect_all();
            }
        }
    }

    pub fn disconnect(&self, endpoint: Endpoint) {
        self.connection_manager.write().remove(endpoint);
        self.handler.network().remove(endpoint.resource_id());
    }

    fn disconnect_all(&self) {
        let endpoints = self.connection_manager.write().remove_all();
        for endpoint in endpoints.into_iter() {
            self.handler.network().remove(endpoint.resource_id());
        }
    }

    fn on_connect(&mut self, endpoint: Endpoint, resource_id: ResourceId) {
        debug!(
            "#on_connect - {} Incoming connection with address {}",
            resource_id,
            endpoint.addr()
        );

        let mut connection_manager = self.connection_manager.write();
        connection_manager.add_to_lobby(endpoint);

        trace!("#on_connect - {} Connection added", resource_id);
    }

    fn on_message(&self, endpoint: Endpoint, data: Vec<u8>) {
        if !self.bot_alive.load(Ordering::SeqCst) {
            self.disconnect(endpoint);
            return;
        }

        let resource_id = endpoint.resource_id();
        let message = Message::from_bytes(data, |server_id| self.server_key(server_id));

        let message = match message {
            Ok(mut message) => {
                message.set_resource(resource_id);
                message
            },
            Err(e) => {
                error!("#on_message - {}", e);
                self.disconnect(endpoint);
                return;
            }
        };

        info!("#on_message - {} {:#?}", resource_id, message);

        match message.message_type {
            Type::Connect => {
                let server_id = match message.server_id.clone() {
                    Some(id) => id,
                    None => {
                        error!("#on_message - Message has no server ID");
                        return;
                    }
                };

                let mut connection_manager = self.connection_manager.write();
                match connection_manager.accept(server_id, endpoint) {
                    Ok(_) => {},
                    Err(e) => {
                        error!("#on_message - {}", e);
                        return;
                    }
                }

                // Route it through to the bot
                self.send_to_bot(message);
            },
            // Feed the message through to the bot
            _ => self.send_to_bot(message)
        };
    }

    fn on_disconnect(&self, endpoint: Endpoint) {
        let resource_id = endpoint.resource_id();
        debug!("#on_disconnect - {} has disconnected", resource_id);

        // Remove the resource from the connection_manager
        self.connection_manager.write().remove(endpoint);

        let mut message = Message::new(Type::Disconnect);
        message.set_resource(resource_id);
        // TODO: Set Server ID!

        self.send_to_bot(message);
    }
}
