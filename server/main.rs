mod connection;
mod server;
use message_io::node;
use server::Server;

#[tokio::main]
async fn main() {
    env_logger::init();

    let (handler, listener) = node::split::<()>();
    let server = Server::new(handler);

    server.start_workers().await;
    server.listen(listener).await;
}
