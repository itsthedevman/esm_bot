use crate::*;
use message_io::{
    network::NetEvent,
    node::{self, NodeHandler, NodeListener},
};
use serde::{Deserialize, Serialize};
use tokio::sync::mpsc::UnboundedReceiver;

#[derive(Serialize, Deserialize, Debug)]
#[serde(tag = "type", content = "content", rename_all = "snake_case")]
pub enum ServerRequest {
    Connect,
    Disconnect,
    Resume,
    Pause,
    Send(Box<Message>),
}

pub async fn initialize(receiver: UnboundedReceiver<ServerRequest>) {
    let (handler, listener) = node::split::<()>();
    command_thread(handler, receiver).await;
    server_thread(listener).await;

    info!("[server::initialize] Done");
}

async fn command_thread(handler: NodeHandler<()>, mut receiver: UnboundedReceiver<ServerRequest>) {
    tokio::spawn(async move {
        while let Some(request) = receiver.recv().await {
            match request {
                ServerRequest::Connect => todo!(), // I'm not sure if this is needed yet
                ServerRequest::Disconnect => todo!(), // If there is a server_id, drop that one client. Otherwise, drop all clients
                ServerRequest::Resume => todo!(),     // Set flag
                ServerRequest::Pause => todo!(),      // Set flag and disconnect all clients
                ServerRequest::Send(_) => todo!(),    // Send message to client
            }
        }
    });
}

async fn server_thread(listener: NodeListener<()>) {
    tokio::spawn(async move {
        listener.for_each(move |event| match event.network() {
            NetEvent::Connected(_, _) => {} // Unused
            NetEvent::Message(endpoint, data) => {
                // Check if the client is still connected
                // Trigger on_message
            }
            NetEvent::Disconnected(endpoint) => (), // On disconnect
            NetEvent::Accepted(endpoint, resource_id) => {
                // Check if the client is still connected
                // Trigger on_connect
            }
        });
    });
}
