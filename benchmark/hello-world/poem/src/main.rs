use poem::{
    get, handler, listener::TcpListener, Route, Server,
};

#[handler]
fn hello() -> String {
    format!("Hello, World!")
}

#[tokio::main]
async fn main() -> Result<(), std::io::Error> {

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

    let app = Route::new().at("/", get(hello));
    Server::new(TcpListener::bind("127.0.0.1:3000"))
        .name("hello-world")
        .run(app)
        .await
}
