#!/usr/bin/env just --justfile

CRATE_NAME := 'bifrosty'

# if running in CI, treat warnings as errors by setting RUSTFLAGS and RUSTDOCFLAGS to '-D warnings' unless they are already set
# Use `CI=true just ci-test` to run the same tests as in GitHub CI.
# Use `just env-info` to see the current values of RUSTFLAGS and RUSTDOCFLAGS
export RUSTFLAGS := env('RUSTFLAGS', if env('CI', '') == 'true' {'-D warnings'} else {''})
export RUSTDOCFLAGS := env('RUSTDOCFLAGS', if env('CI', '') == 'true' {'-D warnings'} else {''})

@_default:
    just --list

# Clean all build artifacts
clean:
    cargo clean

# Update all dependencies, including breaking changes. Requires nightly toolchain (install with `rustup install nightly`)
update:
    cargo +nightly -Z unstable-options update --breaking
    cargo update

# Find unused dependencies. Install it with `cargo install cargo-udeps`
udeps:  (cargo-install 'cargo-udeps')
    cargo +nightly udeps --all-targets --workspace --all-features

# Check semver compatibility with prior published version. Install it with `cargo install cargo-semver-checks`
semver *args:  (cargo-install 'cargo-semver-checks')
    cargo semver-checks {{args}}

# Find the minimum supported Rust version (MSRV) using cargo-msrv extension, and update Cargo.toml
msrv:  (cargo-install 'cargo-msrv')
    cargo msrv find --write-msrv --ignore-lockfile --all-features

# Get the minimum supported Rust version (MSRV) for the crate
get-msrv:  (get-crate-field 'rust_version')

# Get any package's field from the metadata
get-crate-field field package=CRATE_NAME:
    cargo metadata --format-version 1 | jq -r '.packages | map(select(.name == "{{package}}")) | first | .{{field}}'

# Build the project
build:
    cargo build --workspace --all-targets

# Run cargo clippy to lint the code
clippy:
    cargo clippy --workspace --all-targets

# Reformat all code `cargo fmt`. If nightly is available, use it for better results
fmt:
    #!/usr/bin/env bash
    set -euo pipefail
    if rustup component list --toolchain nightly | grep rustfmt &> /dev/null; then
        echo 'Reformatting Rust code using nightly Rust fmt to sort imports'
        cargo +nightly fmt --all -- --config imports_granularity=Module,group_imports=StdExternalCrate
    else
        echo 'Reformatting Rust with the stable cargo fmt.  Install nightly with `rustup install nightly` for better results'
        cargo fmt --all
    fi

# Build and open code documentation
docs:
    cargo doc --no-deps --open

# Quick compile without building a binary
check:
    cargo check --workspace --all-targets

# Generate code coverage report. Will install `cargo llvm-cov` if missing.
coverage *args='--no-clean --open':  (cargo-install 'cargo-llvm-cov')
    cargo llvm-cov --workspace --all-targets --all-features --include-build-script {{args}}

# Generate code coverage report to upload to codecov.io
ci-coverage: && \
            (coverage '--codecov --output-path target/llvm-cov/codecov.info')
    # ATTENTION: the full file path above is used in the CI workflow
    mkdir -p target/llvm-cov

# Run all unit and integration tests
test:
    cargo test --workspace --all-targets --all-features

# Test code formatting
test-fmt:
    cargo fmt --all -- --check

# Test documentation
test-doc:
    ## uncomment if crate becomes a lib:   cargo test --doc --workspace --all-features
    cargo doc --workspace --all-features --no-deps

# Print environment info
env-info:
    @echo "Running on {{os()}} / {{arch()}}"
    {{just_executable()}} --version
    rustc --version
    cargo --version
    rustup --version
    @echo "RUSTFLAGS='$RUSTFLAGS'"
    @echo "RUSTDOCFLAGS='$RUSTDOCFLAGS'"

# Run all tests as expected by CI
ci-test: env-info test-fmt clippy check test test-doc

# Run minimal subset of tests to ensure compatibility with MSRV
ci-test-msrv: env-info check test

# Check if a certain Cargo command is installed, and install it if needed
[private]
cargo-install $COMMAND $INSTALL_CMD='' *args='':
    #!/usr/bin/env bash
    set -euo pipefail
    if ! command -v $COMMAND > /dev/null; then
        if ! command -v cargo-binstall > /dev/null; then
            echo "$COMMAND could not be found. Installing it with    cargo install ${INSTALL_CMD:-$COMMAND} --locked {{args}}"
            cargo install ${INSTALL_CMD:-$COMMAND} --locked {{args}}
        else
            echo "$COMMAND could not be found. Installing it with    cargo binstall ${INSTALL_CMD:-$COMMAND} --locked {{args}}"
            cargo binstall ${INSTALL_CMD:-$COMMAND} --locked {{args}}
        fi
    fi

# Verify that the current version of the crate is not the same as the one published on crates.io
check-if-published:
    #!/usr/bin/env bash
    set -euo pipefail
    LOCAL_VERSION="$({{just_executable()}} get-crate-field version)"
    echo "Detected crate version: '$LOCAL_VERSION'"
    CRATE_NAME="$({{just_executable()}} get-crate-field name)"
    echo "Detected crate name:    '$CRATE_NAME'"
    PUBLISHED_VERSION="$(cargo search ${CRATE_NAME} | grep "^${CRATE_NAME} =" | sed -E 's/.* = "(.*)".*/\1/')"
    echo "Published crate version: '$PUBLISHED_VERSION'"
    if [ "$LOCAL_VERSION" = "$PUBLISHED_VERSION" ]; then
        echo "ERROR: The current crate version has already been published."
        exit 1
    else
        echo "The current crate version has not yet been published."
    fi
