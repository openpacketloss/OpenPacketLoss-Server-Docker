# syntax=docker/dockerfile:1.3

# ==========================================
# 1. Build Stage for Rust WebRTC Server (Native Cross-Compilation)
# ==========================================
FROM --platform=$BUILDPLATFORM rust:bookworm AS builder

# TARGETPLATFORM is provided by Docker Buildx
ARG TARGETPLATFORM

WORKDIR /usr/src/app

# Install cross-compilation linkers and tools
RUN apt-get update && apt-get install -y \
    git \
    build-essential \
    pkg-config \
    gcc-x86-64-linux-gnu \
    gcc-i686-linux-gnu \
    gcc-aarch64-linux-gnu \
    gcc-arm-linux-gnueabihf \
    && rm -rf /var/lib/apt/lists/*

# Clone the backend repository
RUN git clone --depth 1 https://github.com/openpacketloss/OpenPacketLoss-Server.git .

# Map Docker platform strings to Rust target triples and linkers
RUN case "$TARGETPLATFORM" in \
    "linux/amd64") \
        echo "x86_64-unknown-linux-gnu" > /rust_target.txt && \
        echo "x86_64-linux-gnu-gcc" > /rust_linker.txt ;; \
    "linux/arm64") \
        echo "aarch64-unknown-linux-gnu" > /rust_target.txt && \
        echo "aarch64-linux-gnu-gcc" > /rust_linker.txt ;; \
    "linux/arm/v7") \
        echo "armv7-unknown-linux-gnueabihf" > /rust_target.txt && \
        echo "arm-linux-gnueabihf-gcc" > /rust_linker.txt ;; \
    "linux/386") \
        echo "i686-unknown-linux-gnu" > /rust_target.txt && \
        echo "i686-linux-gnu-gcc" > /rust_linker.txt ;; \
    *) exit 1 ;; \
    esac

# Pre-fetch and add the target toolchain
RUN RUST_TARGET=$(cat /rust_target.txt) && rustup target add "$RUST_TARGET"

# Configure cargo for the specific cross-linker (persists across RUN steps)
RUN RUST_TARGET=$(cat /rust_target.txt) && \
    RUST_LINKER=$(cat /rust_linker.txt) && \
    mkdir -p .cargo && \
    printf '[target.%s]\nlinker = "%s"\n' "$RUST_TARGET" "$RUST_LINKER" > .cargo/config.toml

# Build the actual binary for the target architecture
# Note: Renaming binary to webrtc-udp-test-server to match march entrypoint
RUN RUST_TARGET=$(cat /rust_target.txt) && \
    cargo build --release --target "$RUST_TARGET" && \
    cp target/"$RUST_TARGET"/release/openpacketloss-server /usr/local/bin/webrtc-udp-test-server

# ==========================================
# 2. Downloader Stage for Frontend
# ==========================================
FROM alpine/git AS frontend-downloader
WORKDIR /app
RUN git clone --depth 1 https://github.com/openpacketloss/PacketLossTest.git .
RUN find . -name "*.gif" -type f -delete && rm -rf .git

# ==========================================
# 3. Final Runner Stage (Zero-RUN for Multi-Arch Compatibility)
# ==========================================
FROM nginx:bookworm

# Use /app as the working directory for the server
WORKDIR /app

# Copy binary from native builder with build-time chmod
COPY --chmod=0755 --from=builder /usr/local/bin/webrtc-udp-test-server /usr/local/bin/

# Copy configurations (local from this repo, matching march structure)
COPY nginx.conf /etc/nginx/nginx.conf
COPY entrypoint.sh /usr/local/bin/entrypoint.sh

# Copy web assets from downloader (matching march's placement)
COPY --from=frontend-downloader /app/ /usr/share/nginx/html/

EXPOSE 80 3478/udp

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
