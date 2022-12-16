#!/usr/bin/env bash

# This is simple script to help evaluate effects of different stealing strategies on the
# performance of a hyper hello world application.
# It runs rewrk (assumed to be installed) and tests the application built with tokio stealing
# different amount of items per steal, both with BWoS and the original tokio queue.
# Some assumptions are hardcoded for an 88 core machine with 2 numa nodes, so be sure to
# adapt the benchmark code in the for loop to your specific system.

SCRIPT_DIR=$(dirname $(readlink -f $0))

NUM_CONNECTIONS="${1:-500}"

mkdir -p "${SCRIPT_DIR}/result/${NUM_CONNECTIONS}_c/bench_rewrk"
TEST_RESULT_DIR="${SCRIPT_DIR}/result/${NUM_CONNECTIONS}_c/bench_rewrk"
REWRK_DIR="${SCRIPT_DIR}/../../../rewrk"

# if [[ $(ulimit -n) < $((NUM_CONNECTIONS+100)) ]] ; then
#     echo "Please increase 'ulimit -n' setting to allow more connections"
#     exit
# fi

set -e

install_rewrk() {
    rewrk_branch_name="$1"
    rewrk_tokio_branch_name="$2"
    pushd "${REWRK_DIR}"
    pwd
    echo '[patch.crates-io]' > ".cargo/config.toml"
    echo "tokio = { git  = \"https://github.com/jschwe/tokio_bench\", branch = \"${rewrk_tokio_branch_name}\" }" >> ".cargo/config.toml"

    git checkout "${rewrk_branch_name}"
    echo "Install rewrk branch ${rewrk_branch_name} with tokio policy ${rewrk_tokio_branch_name}"
    cargo install --path .
    popd
}

bench_hyper() {
    hyper_tokio_branch_name="$1"
    rewrk_comment="$2"
    echo '[patch.crates-io]' > "${SCRIPT_DIR}/.cargo/config.toml"
    echo "tokio = { git  = \"https://github.com/jschwe/tokio_bench\", branch = \"${hyper_tokio_branch_name}\" }" >> "${SCRIPT_DIR}/.cargo/config.toml"

    echo "Switching benchmarks to ${hyper_tokio_branch_name}"
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
    RUSTFLAGS="--cfg tokio_unstable" numactl --cpunodebind=0  cargo run --release --features metrics > "${TEST_RESULT_DIR}/hyper_${hyper_tokio_branch_name}_${rewrk_comment}_${iter}.log" &
    sleep 1
    pid=$!
    numactl --cpunodebind=1 rewrk -c ${NUM_CONNECTIONS} --host http://127.0.0.1:3000 --duration 30s -t 44 >  "${TEST_RESULT_DIR}/hyper_${hyper_tokio_branch_name}_${rewrk_comment}_${iter}.rewrk.log"
    kill "${pid}"
    done
}

set -e

# Steal one

# b54aede813655165646a0af577a8fc852d32463c is the baseline on which the single_thread branch is based on

install_rewrk "single-thread" "steal_half"
bench_hyper "bwos_steal_block" "rewrk_single_thread"

install_rewrk "single-thread" "steal_half"
bench_hyper "bwos_steal_half" "rewrk_single_thread"

install_rewrk "single-thread" "steal_half"
bench_hyper "steal_half" "rewrk_single_thread"

install_rewrk "b54aede813655165646a0af577a8fc852d32463c" "steal_half"
bench_hyper "steal_half" "rewrk_base_original"

install_rewrk "b54aede813655165646a0af577a8fc852d32463c" "bwos_steal_block"
bench_hyper "steal_half" "rewrk_base_bwos_steal_block"

install_rewrk "b54aede813655165646a0af577a8fc852d32463c" "bwos_steal_block"
bench_hyper "bwos_steal_block" "rewrk_base_bwos_steal_block"

install_rewrk "b54aede813655165646a0af577a8fc852d32463c" "bwos_steal_1"
bench_hyper "steal_half" "rewrk_base_bwos_steal_1"

install_rewrk "b54aede813655165646a0af577a8fc852d32463c" "bwos_steal_half"
bench_hyper "steal_half" "rewrk_base_bwos_steal_half"


