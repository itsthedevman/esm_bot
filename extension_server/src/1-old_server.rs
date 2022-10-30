use crate::connection::ConnectionManager;
use esm_message::{Data, ErrorType, Message, Type};
use log::*;
use message_io::{
    network::{Endpoint, ResourceId},
    node::NodeHandler,
};
use message_io::{
    network::{NetEvent, Transport},
    node::NodeListener,
};
use parking_lot::RwLock as SyncRwLock;
use redis::{aio::MultiplexedConnection, AsyncCommands, Client, Commands, Connection, RedisError};
use std::sync::Arc;
use std::{
    env,
    sync::atomic::{AtomicBool, Ordering},
    time::Duration,
};
use tokio::sync::mpsc::{self, UnboundedReceiver, UnboundedSender};
use tokio::{sync::RwLock, time::sleep};

#[derive(Clone)]
pub struct Server {
    handler: NodeHandler<()>,
    connection_manager: Arc<SyncRwLock<ConnectionManager>>,
    redis_client: Client,
    pub redis: Arc<SyncRwLock<Connection>>,
    outbound_sender: UnboundedSender<Message>,
    outbound_receiver: Arc<RwLock<UnboundedReceiver<Message>>>,
    address: String,

    // The master flag
    bot_alive: Arc<AtomicBool>,

    // Used for tracking if there was a pong received. Use `bot_alive` for checking if the bot is still online
    bot_pong_received: Arc<AtomicBool>,
    allow_connections: Arc<AtomicBool>,
}

impl Server {
    pub fn new(handler: NodeHandler<()>) -> Self {
        let address = match env::var("TCP_SERVER_PORT") {
            Ok(port) => {
                format!("0.0.0.0:{}", port)
            }
            Err(_e) => panic!("TCP_SERVER_PORT is not set!"),
        };

        let redis_client = match redis::Client::open("redis://127.0.0.1/") {
            Ok(client) => client,
            Err(e) => panic!("Failed to connect to redis. Reason: {}", e),
        };

        let mut redis = match redis_client.get_connection() {
            Ok(con) => con,
            Err(e) => panic!("Failed to get sync connection. Reason: {}", e),
        };

        match redis::cmd("DEL")
            .arg("tcp_server_outbound")
            .arg("tcp_server_inbound")
            .query(&mut redis)
        {
            Ok(r) => r,
            Err(e) => error!("#delegate_outbound_messages - {}", e),
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
            allow_connections: Arc::new(AtomicBool::new(true)),
            redis: Arc::new(SyncRwLock::new(redis)),
        }
    }

    async fn get_redis_connection(&self) -> Result<MultiplexedConnection, RedisError> {
        self.redis_client.get_multiplexed_tokio_connection().await
    }

    /// Send a Message to the bot.
    fn send_to_bot(&self, message: Message) {
        match self.outbound_sender.send(message) {
            Ok(()) => {}
            Err(e) => {
                error!("#send_to_bot - {}", e);
            }
        }
    }

    fn send_to_client(&self, message: Message) -> Result<(), Message> {
        let server_id = match message.server_id.clone() {
            Some(id) => id,
            None => {
                return Err(message.add_error(
                    ErrorType::Message,
                    "Cannot send message - Missing server_id",
                ));
            }
        };

        let connection_manager = self.connection_manager.read();
        let endpoint = match connection_manager.find_by_server_id(&server_id) {
            Some(endpoint) => endpoint,
            None => {
                return Err(message.add_error(ErrorType::Code, "client_not_connected"));
            }
        };

        let server_key = match self.server_key(&server_id) {
            Some(key) => key,
            None => {
                error!(
                    "#send_to_client - Failed to find server key for message. \n{:?} ",
                    message
                );

                return Err(message.add_error(
                    ErrorType::Message,
                    "Cannot send message - Missing server key",
                ));
            }
        };

        match message.as_bytes(&server_key) {
            Ok(bytes) => {
                info!("#send_to_client - {}", message.id);

                self.handler.network().send(endpoint.to_owned(), &bytes);
                Ok(())
            }
            Err(error) => {
                error!("#send_to_client - {}", error);
                Err(message.add_error(ErrorType::Code, "client_not_connected"))
            }
        }
    }

    pub fn server_key(&self, server_id: &[u8]) -> Option<Vec<u8>> {
        let server_id = match String::from_utf8(server_id.to_owned()) {
            Ok(id) => id,
            Err(e) => {
                error!("#server_key - {}", e);
                return None;
            }
        };

        match self.redis.write().hget("server_keys", server_id) {
            Ok(key) => key,
            Err(e) => {
                error!("#server_key - {}", e);
                None
            }
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

        let disconnect_if_dead = |server: &Server, endpoint: &Endpoint| -> bool {
            if server.bot_alive.load(Ordering::SeqCst)
                && server.allow_connections.load(Ordering::SeqCst)
            {
                return false;
            }

            server.handler.network().remove(endpoint.resource_id());

            true
        };

        // Process the events
        let mut server = self.clone();
        listener.for_each(move |event| match event.network() {
            NetEvent::Connected(_, _) => {}
            NetEvent::Message(endpoint, data) => {
                if disconnect_if_dead(&server, &endpoint) {
                    return;
                }

                server.on_message(endpoint, data.to_vec())
            }
            NetEvent::Disconnected(endpoint) => server.on_disconnect(endpoint),
            NetEvent::Accepted(endpoint, resource_id) => {
                // if disconnect_if_dead(&server, &endpoenv_logger::init();

                // let (handler, listener) = node::split::<()>();
                // let server = Server::new(handler);

                // server.start_workers().await;
                // server.listen(listener).await;nt) {
                //     return;
                // }

                // server.on_connect(endpoint, resource_id)
            }
        });
    }

    /// Moves messages from the internal outbound queue into the redis outbound queue so the bot may pick them up
    async fn delegate_outbound_messages(&self) {
        let mut connection = match self.get_redis_connection().await {
            Ok(connection) => connection,
            Err(e) => panic!("#delegate_outbound_messages - {}", e),
        };

        loop {
            let mut receiver = self.outbound_receiver.write().await;

            let message = match receiver.recv().await {
                Some(message) => message,
                None => continue,
            };

            let json: String = match serde_json::to_string(&message) {
                Ok(json) => json,
                Err(e) => {
                    error!("#delegate_outbound_messages - {}", e);
                    continue;
                }
            };

            trace!("#delegate_outbound_messages - {}", message);

            match redis::cmd("RPUSH")
                .arg("tcp_server_outbound")
                .arg(json)
                .query_async(&mut connection)
                .await
            {
                Ok(r) => r,
                Err(e) => error!("#delegate_outbound_messages - {}", e),
            };
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

        // Extract the server ID from the message
        let id_length = data[0] as usize;
        let server_id = data[1..=id_length].to_vec();

        let server_key = match self.server_key(&server_id) {
            Some(key) => key,
            None => {
                match std::str::from_utf8(&server_id) {
                    Ok(id) => {
                        error!(
                            "[client#on_message] Disconnecting {:?}. Failed to find server key",
                            id
                        );
                    }
                    Err(_) => {
                        error!(
                            "[client#on_message] Disconnecting {:?}. Failed to find server key",
                            server_id
                        );
                    }
                }

                self.disconnect(endpoint);
                return;
            }
        };

        let resource_id = endpoint.resource_id();
        let message = match Message::from_bytes(data, &server_key) {
            Ok(message) => message.set_resource(resource_id),
            Err(e) => {
                error!("#on_message - {}", e);
                self.disconnect(endpoint);
                return;
            }
        };

        let server_id = match message.server_id.clone() {
            Some(id) => id,
            None => {
                error!("#on_message - Message has no server ID");
                return;
            }
        };

        info!(
            "{} #on_message - {} - {} - {:?}",
            resource_id,
            message.id,
            std::str::from_utf8(&server_id).unwrap_or("INVALID_SERVER_ID"),
            message.message_type,
        );

        debug!("#on_message - {:?}", message);

        match message.message_type {
            Type::Init => {
                match self.connection_manager.write().accept(server_id, endpoint) {
                    Ok(_) => {}
                    Err(e) => {
                        error!("#on_message - {}", e);
                        return;
                    }
                }

                // Route it through to the bot
                self.send_to_bot(message);
            }

            // Disallow system commands
            Type::Connect
            | Type::Disconnect
            | Type::Ping
            | Type::Pong
            | Type::Test
            | Type::Resume
            | Type::Pause => {
                let message =
                    message.add_error(ErrorType::Message, "Error - Invalid message type provided");
                if let Err(message) = self.send_to_client(message) {
                    // The message failed, send it back to the bot
                    self.send_to_bot(message.set_type(Type::Error).set_data(Data::Empty));
                }
            }

            // Feed the message through to the bot
            _ => self.send_to_bot(message),
        };
    }

    fn on_disconnect(&self, endpoint: Endpoint) {
        let resource_id = endpoint.resource_id();
        debug!("#on_disconnect - {} has disconnected", resource_id);

        // Remove the resource from the connection_manager
        self.connection_manager.write().remove(endpoint);

        self.send_to_bot(Message::new(Type::Disconnect).set_resource(resource_id));
    }
}
