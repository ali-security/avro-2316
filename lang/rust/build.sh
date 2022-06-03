#!/bin/bash

# Licensed to the Apache Software Foundation (ASF) under one or more
# contributor license agreements.  See the NOTICE file distributed with
# this work for additional information regarding copyright ownership.
# The ASF licenses this file to You under the Apache License, Version 2.0
# (the "License"); you may not use this file except in compliance with
# the License.  You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -e  # exit on error

build_dir="../../build/rust"
dist_dir="../../dist/rust"


function clean {
  if [ -d $build_dir ]; then
    find $build_dir | xargs chmod 755
    rm -rf $build_dir
  fi
}


function prepare_build {
  clean
  mkdir -p $build_dir
}

cd $(dirname "$0")

for target in "$@"
do
  case "$target" in
    clean)
      cargo clean
      ;;
    lint)
      cargo clippy --all-targets --all-features -- -Dclippy::all
      ;;
    test)
      cargo test
      ;;
    dist)
      cargo build --release --lib --all-features
      cargo package
      mkdir -p  ../../dist/rust
      cp target/package/apache-avro-*.crate $dist_dir
      ;;
    interop-data-generate)
      prepare_build
      export RUST_LOG=apache_avro=debug
      export RUST_BACKTRACE=1
      cargo run  --features snappy,zstandard,bzip,xz --example generate_interop_data
      ;;

    interop-data-test)
      prepare_build
      echo "Running interop data tests"
      cargo run --features snappy,zstandard,bzip,xz --example test_interop_data
      echo -e "\nRunning single object encoding interop data tests"
      cargo run --example test_interop_single_object_encoding
      ;;
    profile-heap)
      echo "Heap memory profiling with https://github.com/KDE/heaptrack"
      EXAMPLE_APP=${2:-"benchmark"}
      RUSTFLAGS=-g cargo build --release --example $EXAMPLE_APP
      rm -f heaptrack.${EXAMPLE_APP}.*
      heaptrack ./target/release/examples/$EXAMPLE_APP
      heaptrack --analyze heaptrack.${EXAMPLE_APP}.*
      exit
      ;;
    profile-cpu)
      echo "CPU profiling with perf and https://github.com/KDAB/hotspot"
      EXAMPLE_APP=${2:-"benchmark"}
      RUSTFLAGS=-g cargo build --release --example $EXAMPLE_APP
      NOW=$(date +%y%m%d%H%M%S)
      DATA_FILE=perf-${EXAMPLE_APP}-${NOW}.data
      # sudo sysctl kernel.perf_event_paranoid=-1
      # sudo sysctl kernel.kptr_restrict=0
      perf record --call-graph=dwarf --output=$DATA_FILE ./target/release/examples/$EXAMPLE_APP
      hotspot $DATA_FILE
      exit
      ;;
    *)
      echo "Usage: $0 {lint|test|dist|clean|interop-data-generate|interop-data-test|profile-heap}" >&2
      exit 1
  esac
done
