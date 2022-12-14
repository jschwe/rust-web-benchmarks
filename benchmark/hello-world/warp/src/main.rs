//#![deny(warnings)]
use warp::Filter;

#[tokio::main]
async fn main() {
    // Match any request and return hello world!
    let routes = warp::any().map(|| "Hello, World!");

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

    warp::serve(routes).run(([127, 0, 0, 1], 3000)).await;
}
