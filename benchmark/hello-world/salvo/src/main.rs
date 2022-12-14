use salvo::prelude::*;

#[handler]
fn hello() -> &'static str {
    "Hello, World!"
}

#[tokio::main]
async fn main() {
    let router = Router::new().get(hello);
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
    Server::new(TcpListener::bind("127.0.0.1:3000"))
        .serve(router)
        .await
}
