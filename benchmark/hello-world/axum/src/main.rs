use axum::{routing::get, Router};

#[tokio::main]
async fn main() {
    let app = Router::new().route("/", get(|| async { "Hello, World!" }));

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

    axum::Server::bind(&"127.0.0.1:3000".parse().unwrap())
        .serve(app.into_make_service())
        .await
        .unwrap();
}
