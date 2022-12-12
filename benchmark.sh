#!/usr/bin/env bash

MODE=wasm
WAVM=thirdparty/wavm/build/bin/wavm
export WAVM_OBJECT_CACHE_DIR=benchmark/wavm/cache
TIMEFORMAT=%4R
COUNT=1 # TODO: change back to 5

NAME=(
    nop
    # cat-sync
    # nbody-c
    # nbody-cpp
    # fannkuch-redux-c
    # mandelbrot-c
    # mandelbrot-simd-c
    # binary-trees-c
    # fasta-c
    # hello_world
)
ARGS=(
    0
    # 0
    # 50000000
    # 50000000
    # 12
    # 15000
    # 15000
    # 21
    # 25000000
)


function prepare() {
    mkdir -p benchmark/native
    mkdir -p benchmark/wavm
    mkdir -p benchmark/wasmer_1
    mkdir -p $WAVM_OBJECT_CACHE_DIR
    dd if=/dev/urandom of=benchmark/random bs=4k count=4k
}

function compile() {
    rm -f benchmark/wavm/compile.time benchmark/wasmer-*/compile.time
    for ((i=0; i<"${#NAME[@]}"; ++i)); do
        echo ""
        # (time "$WAVM" compile --enable simd --format=precompiled-wasm build/"$MODE"/"${NAME[i]}".wasm benchmark/wavm/"${NAME[i]}".wasm 2>&1) 2>> benchmark/wavm/compile.time || true
        cp -n build/"$MODE"/"${NAME[i]}".wasm benchmark/wasmer_1/"${NAME[i]}".wasm
    done
}

function benchmark_native() {
    echo benchmark_native
    for ((i=0; i<"${#NAME[@]}"; ++i)); do
        LOG="benchmark/native/"${NAME[i]}".log"
        rm -f "$LOG"
        touch "$LOG"
        for ((j=0; j<$COUNT; ++j)); do
            time "build/native/${NAME[i]}" "${ARGS[i]}" <benchmark/random >&/dev/null
        done 2> "$LOG"
        /usr/bin/time -o "benchmark/native/"${NAME[i]}".time" --verbose "build/native/${NAME[i]}" "${ARGS[i]}" <benchmark/random >&/dev/null
    done
}


function benchmark_wavm() {
    echo benchmark_wavm
    for ((i=0; i<"${#NAME[@]}"; ++i)); do
        LOG="benchmark/wavm/"${NAME[i]}".log"
        rm -f "$LOG"
        touch "$LOG"
        for ((j=0; j<$COUNT; ++j)); do
            time "$WAVM" run --enable simd --precompiled --abi=wasi benchmark/wavm/"${NAME[i]}".wasm "${ARGS[i]}" <benchmark/random >&/dev/null
        done 2> "$LOG"
        /usr/bin/time -o "benchmark/wavm/"${NAME[i]}".time" --verbose "$WAVM" run --precompiled --abi=wasi benchmark/wavm/"${NAME[i]}".wasm "${ARGS[i]}" <benchmark/random >&/dev/null
    done
}


function benchmark/wasmer_1() {
    echo benchmark/wasmer_1
    for ((i=0; i<"${#NAME[@]}"; ++i)); do
        LOG="benchmark/wasmer_1/"${NAME[i]}".log"
        rm -f "$LOG"
        touch "$LOG"
        for ((j=0; j<$COUNT; ++j)); do 
            echo "executing benchmark/wasm-1/${NAME[i]}.wasm ${ARGS[i]}" 
            # time /home/unixuser/.wasmer/bin/wasmer run benchmark/wasmer_1/"${NAME[i]}".wasm "${ARGS[i]}" <benchmark/random
            wasmer run benchmark/wasmer_1/"program1".wasm
            # time /home/unixuser/.wasmer/bin/wasmer run --backend singlepass --loader kernel benchmark/wasmer_1/${NAME[i]}.wasm ${ARGS[i]} <benchmark/random
            # sudo /home/unixuser/.wasmer/bin/wasmer run --backend singlepass --loader kernel benchmark/wasmer_1/${NAME[i]}.wasm
            # wasmer run --backend singlepass --loader kernel benchmark/wasmer_1/${NAME[i]}.wasm
            # time sudo -E bash -c "/home/unixuser/.wasmer/bin/wasmer run --backend singlepass --loader kernel benchmark/wasmer_1/${NAME[i]}.wasm ${ARGS[i]} <benchmark/random"
        done 
        /usr/bin/time -o "benchmark/wasmer_1/"${NAME[i]}".time" --verbose wasmer run benchmark/wasm/"${NAME[i]}".wasm "${ARGS[i]}" <benchmark/random >&/dev/null
    done
}

function print_result() {
    echo " "
    echo
    for type in native wavm wasmer_1; do
        echo -n "$type" 
        for name in "${NAME[@]}"; do
            echo -n ,"$(awk 'function abs(x){return ((x < 0.0) ? -x : x)} {sum+=$0; sumsq+=($0)^2} END {mean = sum / NR; error = sqrt(abs(sumsq / NR - mean^2)); printf("%.3f(%.3f)", mean, error)}' benchmark/"$type"/"$name".log)"
        done
        echo
    done | tee result.csv
}

prepare
compile
# benchmark_wavm
benchmark/wasmer_1
# benchmark_native
# print_result
