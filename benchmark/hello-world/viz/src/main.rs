#![deny(warnings)]

use std::net::SocketAddr;
use viz::{get, Request, Result, Router, Server, ServiceMaker, Error};

async fn index(_: Request) -> Result<&'static str> {
    Ok("Hello, World!")
}

#[tokio::main]
async fn main() -> Result<()> {
    let addr = SocketAddr::from(([127, 0, 0, 1], 3000));
    let app = Router::new().route("/", get(index));

    #[cfg(feature = "metrics")]
    {
        let handle = tokio::runtime::Handle::current();
        let runtime_monitor = tokio_metrics::RuntimeMonitor::new(&handle);

        // print runtime metrics every second
        let frequency = std::time::Duration::from_millis(1000);
        tokio::spawn(async move {
            for metrics in runtime_monitor.intervals() {
                println!("Metrics = {:?}", metrics);
                tokio::time::sleep(frequency).await;
            }
        });
    }

    Server::bind(&addr)
        .tcp_nodelay(true)
        .serve(ServiceMaker::from(app))
        .await
        .map_err(Error::normal)
}
