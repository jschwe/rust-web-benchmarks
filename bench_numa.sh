#!/usr/bin/env bash

SCRIPT_DIR=$(dirname $(readlink -f $0))

NUM_CONNECTIONS="${1:-500}"

mkdir -p foo "${SCRIPT_DIR}/result/${NUM_CONNECTIONS}_c/seperated_numa"
TEST_RESULT_DIR="${SCRIPT_DIR}/result/${NUM_CONNECTIONS}_c/seperated_numa"

set -e

# First benchmark baseline

rm -rf "${SCRIPT_DIR}/.cargo/config.toml"
cd "${SCRIPT_DIR}/benchmark/"
cargo update -p tokio --precise "1.22.0"

# Install original version of rewrk
cd "${SCRIPT_DIR}/rewrk"
cargo tree -i tokio --depth 0 > /dev/null
cargo update -p tokio --precise "1.22.0"
cargo tree -i tokio
cargo install --path "."

cd "${SCRIPT_DIR}/benchmark/"

cargo build --release

for iter in 1 2 3
do
for framework in axum hyper poem rocket salvo viz warp
do
pushd hello-world/${framework}
numactl --cpunodebind=0  cargo run --release -q &
pid=$!
numactl --cpunodebind=1 rewrk -c ${NUM_CONNECTIONS} --host http://127.0.0.1:3000 --duration 30s -t 44 >  "${TEST_RESULT_DIR}/original_${framework}_${iter}.log"
kill "${pid}"
popd
done
done

# Use BWoS tokio for web frameworks (but do not update rewrk)

echo '[patch.crates-io]' > "${SCRIPT_DIR}/.cargo/config.toml"
echo 'tokio = { path = "../tokio/tokio" }' >> "${SCRIPT_DIR}/.cargo/config.toml"

echo "Switching benchmarks to use our tokio"
cd "${SCRIPT_DIR}/benchmark"
cargo tree -i tokio --depth 0 > /dev/null
cargo update -p tokio
cargo tree -i tokio --depth 0

for iter in 1 2 3
do
for framework in axum hyper poem rocket salvo viz warp
do
pushd hello-world/${framework}
numactl --cpunodebind=0  cargo run --release -q &
pid=$!
numactl --cpunodebind=1 rewrk -c ${NUM_CONNECTIONS} --host http://127.0.0.1:3000 --duration 30s -t 44 >  "${TEST_RESULT_DIR}/bwos_${framework}_${iter}.log"
kill "${pid}"
popd
done
done

cd "${SCRIPT_DIR}/rewrk"
cargo tree -i tokio --depth 0 > /dev/null
cargo update -p tokio
cargo tree -i tokio --depth 0
# Install patched version of rewrk with our tokio (.config toml should apply)
cargo install --path "."
cd "${SCRIPT_DIR}/benchmark"

for iter in 1 2 3
do
for framework in  axum hyper poem rocket salvo viz warp
do
pushd hello-world/${framework}
numactl --cpunodebind=0  cargo run --release -q &
pid=$!
numactl --cpunodebind=1 rewrk -c ${NUM_CONNECTIONS} --host http://127.0.0.1:3000 --duration 30s -t 44 >  "${TEST_RESULT_DIR}/bwos_${framework}_with_bwos_rewrk_${iter}.log"
kill "${pid}"
popd
done
done


rm -rf "${SCRIPT_DIR}/.cargo/config.toml"

echo "Switching benchmarks to use original tokio (but keep rewrk with out tokio)"
cd "${SCRIPT_DIR}/benchmark"
cargo tree -i tokio --depth 0 > /dev/null
cargo update -p tokio --precise "1.22.0"
cargo tree -i tokio --depth 0

for iter in 1 2 3
do
for framework in  axum hyper poem rocket salvo viz warp
do
pushd hello-world/${framework}
numactl --cpunodebind=0  cargo run --release -q &
pid=$!
numactl --cpunodebind=1 rewrk -c ${NUM_CONNECTIONS} --host http://127.0.0.1:3000 --duration 30s -t 44 >  "${TEST_RESULT_DIR}/original_${framework}_with_bwos_rewrk_${iter}.log"
kill "${pid}"
popd
done
done
