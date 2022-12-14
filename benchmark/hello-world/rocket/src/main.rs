use rocket::{get, launch, routes};

#[get("/")]
fn hello() -> &'static str {
    "Hello, world!"
}

#[launch]
fn rocket() -> _ {

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

    rocket::build().mount("/", routes![hello])
}
