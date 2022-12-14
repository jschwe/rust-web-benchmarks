use hyper::{
    service::{make_service_fn, service_fn},
    Body, Request, Response, Server,
};
use std::{convert::Infallible, net::SocketAddr};

#[tokio::main]
async fn main() {
    let addr = SocketAddr::from(([127, 0, 0, 1], 3000));

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

    let make_svc = make_service_fn(|_conn| async { Ok::<_, Infallible>(service_fn(hello_world)) });

    Server::bind(&addr).serve(make_svc).await.unwrap();
}

async fn hello_world(_req: Request<Body>) -> Result<Response<Body>, Infallible> {
    Ok(Response::new("Hello, World!".into()))
}
