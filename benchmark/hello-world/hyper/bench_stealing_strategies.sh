#!/usr/bin/env bash

# This is simple script to help evaluate effects of different stealing strategies on the
# performance of a hyper hello world application.
# It runs rewrk (assumed to be installed) and tests the application built with tokio stealing
# different amount of items per steal, both with BWoS and the original tokio queue.
# Some assumptions are hardcoded for an 88 core machine with 2 numa nodes, so be sure to
# adapt the benchmark code in the for loop to your specific system.

SCRIPT_DIR=$(dirname $(readlink -f $0))

NUM_CONNECTIONS="${1:-500}"

mkdir -p foo "${SCRIPT_DIR}/result/${NUM_CONNECTIONS}_c/test"
TEST_RESULT_DIR="${SCRIPT_DIR}/result/${NUM_CONNECTIONS}_c/test"

bench_hyper() {
    branch_name="$1"
    echo '[patch.crates-io]' > "${SCRIPT_DIR}/.cargo/config.toml"
    echo "tokio = { git  = \"https://github.com/jschwe/tokio_bench\", branch = \"${branch_name}\" }" >> "${SCRIPT_DIR}/.cargo/config.toml"

    echo "Switching benchmarks to ${branch_name}"
    # cargo tree before cargo update is needed, since otherwise cargo update sometimes fails
    # with an error complaining that there is no package `tokio` to update.
    cargo tree -i tokio --depth 0 > /dev/null
    cargo update -p tokio
    # Use cargo tree again to get some output which shows that we really updated the
    # dependency as expected
    cargo tree -i tokio --depth 0

    # prebuild, so that cargo run doesn't have to build anything in `cargo run`.
    RUSTFLAGS="--cfg tokio_unstable" cargo build --release --features metrics

    for iter in 1 2 3
    do
    RUSTFLAGS="--cfg tokio_unstable" numactl --cpunodebind=0  cargo run --release --features metrics > "${TEST_RESULT_DIR}/hyper_${branch_name}_${iter}.log" &
    sleep 1
    pid=$!
    numactl --cpunodebind=1 rewrk -c ${NUM_CONNECTIONS} --host http://127.0.0.1:3000 --duration 30s -t 44 >  "${TEST_RESULT_DIR}/hyper_${branch_name}_${iter}.rewrk.log"
    kill "${pid}"
    done
}

set -e

# Steal one

# Steal half of the queue, but at most X
bench_hyper "steal_1"
bench_hyper "steal_2"
bench_hyper "steal_4"
bench_hyper "steal_8"
bench_hyper "steal_32"
bench_hyper "steal_64"

# Steal at most X (BWoS)
bench_hyper "bwos_steal_1"
bench_hyper "bwos_steal_4"
bench_hyper "bwos_steal_16"
bench_hyper "bwos_steal_block"
bench_hyper "bwos_steal_2block"


# # steal Y of the queue (eight, quarter, half)
bench_hyper "steal_eighth"
bench_hyper "steal_quarter"
bench_hyper "steal_half"
bench_hyper "bwos_steal_half"
bench_hyper "bwos_steal_quarter"
