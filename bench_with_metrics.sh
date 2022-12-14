#!/usr/bin/env bash

# Simple script to evaluate BWoS vs. the original tokio queue and additionally the effects
# of different stealing strategies.
# Attention: This script will use `cargo install`` to install / modify rewrk.
# Please modify the `numactl` command based on your system to bind to an appropriate range of
# cpus for the webframework / rewrk. For rewrk also configure a reasonable amount of threads.


SCRIPT_DIR=$(dirname $(readlink -f $0))

NUM_CONNECTIONS="${1:-500}"

mkdir -p "${SCRIPT_DIR}/result/${NUM_CONNECTIONS}_c/with_metrics"
TEST_RESULT_DIR="${SCRIPT_DIR}/result/${NUM_CONNECTIONS}_c/with_metrics"

write_cargo_config() {
    branch_name="$1"
    echo '[patch.crates-io]' > "${SCRIPT_DIR}/.cargo/config.toml"
    echo "tokio = { git  = \"https://github.com/jschwe/tokio_bench\", branch = \"${branch_name}\" }" >> "${SCRIPT_DIR}/.cargo/config.toml"
}

bench_frameworks() {
    branch_name="$1"
    bench_comment="$2"

    write_cargo_config "${branch_name}"
    echo "Switching benchmarks to ${branch_name}"
    cd "${SCRIPT_DIR}/benchmark"
    cargo tree -i tokio --depth 0 > /dev/null
    cargo update -p tokio
    cargo tree -i tokio --depth 0

    RUSTFLAGS="--cfg tokio_unstable" cargo build --release --features metrics

    # Note: benchmarking rocket might be broken. Sometimes rocket still requires a rebuild
    # when running `cargo run` below, even though the flags are exactly the same so the
    # rewrk measurement will start (and perhaps finish) before the build has finished.
    # If you experience this run rocket seperatly and add a sufficiently long sleep time
    # after `cargo run`.
    for framework in axum hyper poem rocket salvo viz warp
    do
        mkdir -p "${TEST_RESULT_DIR}/${framework}"
        cd "${SCRIPT_DIR}/benchmark/hello-world/${framework}"
        for iter in 1 2 3
        do
        RUSTFLAGS="--cfg tokio_unstable" numactl --cpunodebind=0  \
            cargo run --release --features metrics \
                > "${TEST_RESULT_DIR}/${framework}/${bench_comment}_with_rewrk_bwos_${iter}.log" &
        echo "Starting rewrk"
        pid=$!
        numactl --cpunodebind=1 \
            rewrk -c ${NUM_CONNECTIONS} --host http://127.0.0.1:3000 --duration 30s -t 44 \
                >  "${TEST_RESULT_DIR}/${framework}/${bench_comment}_with_rewrk_bwos_${iter}.rewrk.log"
        kill "${pid}"
        done
    done
}

set -e

# install rewrk patched to use bwos to increase rewrk performance.
cd "${SCRIPT_DIR}/rewrk"
write_cargo_config "bwos_steal_block"
cargo tree -i tokio --depth 0 > /dev/null
cargo update -p tokio
cargo tree -i tokio --depth 0
cargo install --path "."


# The actual benchmark. Add branches you want to test here.

bench_frameworks "steal_half" "original_steal_half"
bench_frameworks "bwos_steal_block" "bwos_steal_block"
#bench_frameworks "bwos_steal_1" "bwos_steal_1"
#bench_frameworks "bwos_steal_4" "bwos_steal_4"
#bench_frameworks "bwos_steal_16" "bwos_steal_16"



