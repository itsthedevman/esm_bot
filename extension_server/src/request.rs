use esm_message::Message;
use message_io::network::Endpoint;
use serde::{Deserialize, Serialize};

use crate::ESMResult;

#[derive(Serialize, Deserialize, Debug)]
#[serde(tag = "type", content = "content", rename_all = "snake_case")]
pub enum BotRequest {
    // {"type":"server_request","content":{"type":"connect"}}
    ServerRequest(ServerRequest),
    Ping,
    Pong,
    RouteToClient {
        server_id: Vec<u8>,
        message: Box<Message>,
    },
    Message(Box<Message>),

    // Stores a server_id
    Disconnected(Vec<u8>),
}

impl BotRequest {
    pub fn server_request(request: ServerRequest) -> ESMResult {
        crate::ROUTER.route_to_bot(Self::ServerRequest(request))
    }

    pub fn ping() -> ESMResult {
        crate::ROUTER.route_to_bot(Self::Ping)
    }

    pub fn pong() -> ESMResult {
        crate::ROUTER.route_to_bot(Self::Pong)
    }

    pub fn route_to_client(server_id: &[u8], message: Message) -> ESMResult {
        crate::ROUTER.route_to_bot(Self::RouteToClient {
            server_id: server_id.into(),
            message: Box::new(message),
        })
    }

    pub fn message(message: Message) -> ESMResult {
        crate::ROUTER.route_to_bot(Self::Message(Box::new(message)))
    }

    pub fn disconnected(server_id: &[u8]) -> ESMResult {
        crate::ROUTER.route_to_bot(Self::Disconnected(server_id.into()))
    }
}

///////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////

#[derive(Serialize, Deserialize, Debug)]
#[serde(tag = "type", content = "content", rename_all = "snake_case")]
pub enum ServerRequest {
    Disconnect(Option<String>),
    Resume,
    Pause,
    Send {
        server_id: Vec<u8>,
        message: Box<Message>,
    },

    #[serde(skip)]
    AliveCheck,

    #[serde(skip)]
    DisconnectEndpoint(Endpoint),

    #[serde(skip)]
    OnConnect(Endpoint),

    #[serde(skip)]
    OnMessage {
        endpoint: Endpoint,
        message_bytes: Vec<u8>,
    },

    #[serde(skip)]
    OnDisconnect(Endpoint),
}

impl ServerRequest {
    pub fn disconnect(server_id: Option<String>) -> ESMResult {
        crate::ROUTER.route_to_server(Self::Disconnect(server_id))
    }

    pub fn resume() -> ESMResult {
        crate::ROUTER.route_to_server(Self::Resume)
    }

    pub fn pause() -> ESMResult {
        crate::ROUTER.route_to_server(Self::Pause)
    }

    pub fn send(server_id: &[u8], message: Message) -> ESMResult {
        crate::ROUTER.route_to_server(Self::Send {
            server_id: server_id.into(),
            message: Box::new(message),
        })
    }

    pub fn alive_check() -> ESMResult {
        crate::ROUTER.route_to_server(Self::AliveCheck)
    }

    pub fn disconnect_endpoint(endpoint: Endpoint) -> ESMResult {
        crate::ROUTER.route_to_server(Self::DisconnectEndpoint(endpoint))
    }

    pub fn on_connect(endpoint: Endpoint) -> ESMResult {
        crate::ROUTER.route_to_server(Self::OnConnect(endpoint))
    }

    pub fn on_message(endpoint: Endpoint, bytes: &[u8]) -> ESMResult {
        crate::ROUTER.route_to_server(Self::OnMessage {
            endpoint,
            message_bytes: bytes.into(),
        })
    }

    pub fn on_disconnect(endpoint: Endpoint) -> ESMResult {
        crate::ROUTER.route_to_server(Self::OnDisconnect(endpoint))
    }
}
