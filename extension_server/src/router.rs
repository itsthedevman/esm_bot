use crate::{bot::BotRequest, server::ServerRequest, *};

use tokio::sync::mpsc::{unbounded_channel, UnboundedSender};

pub struct Router {
    server_channel: Mutex<UnboundedSender<ServerRequest>>,
    bot_channel: Mutex<UnboundedSender<BotRequest>>,
}

impl Router {
    #[allow(clippy::new_without_default)]
    pub fn new() -> Self {
        let (server_channel, server_receiver) = unbounded_channel::<ServerRequest>();
        let (bot_channel, bot_receiver) = unbounded_channel::<BotRequest>();

        crate::TOKIO_RUNTIME.block_on(async move {
            crate::bot::initialize(bot_receiver).await;
            crate::server::initialize(server_receiver).await;
        });

        info!("[new] ✅");

        Router {
            server_channel: Mutex::new(server_channel),
            bot_channel: Mutex::new(bot_channel),
        }
    }

    pub fn route_to_server(&self, request: ServerRequest) -> ESMResult {
        debug!("routing request {request:?} to server");
        match lock!(self.server_channel).send(request) {
            Ok(_) => Ok(()),
            Err(e) => Err(format!("Failed to route. Reason: {}", e)),
        }
    }

    pub fn route_to_bot(&self, request: BotRequest) -> ESMResult {
        match lock!(self.bot_channel).send(request) {
            Ok(_) => Ok(()),
            Err(e) => Err(format!("Failed to route. Reason: {}", e)),
        }
    }
}
