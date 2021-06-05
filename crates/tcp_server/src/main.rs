mod server;
mod message;

use message_io::node;
use server::Server;

#[tokio::main]
async fn main() {
    env_logger::init();

    let (handler, listener) = node::split::<()>();
    let mut server = Server::new(handler);

    // Connect to redis
    match server.connect_to_redis().await {
        Ok(_) => (),
        Err(e) => {
            panic!(format!("#main - Failed to connect to redis: {}", e));
        }
    };

    // Clone the server so it can be moved into the spawn
    let server_clone = server.clone();
    let _ = tokio::spawn(async move {
        server_clone.delegate_inbound_messages().await
    });

    // Clone the server so it can be moved into the spawn
    let server_clone = server.clone();
    let _ = tokio::spawn(async move {
        server_clone.process_inbound_messages().await
    });

    server.listen(listener).await;
}
