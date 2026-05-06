# ─────────────────────────────────────────
# Stage 1: Builder
# ─────────────────────────────────────────
FROM golang:1.25-alpine AS builder

# Install git and ca-certs (needed to fetch modules over HTTPS)
RUN apk add --no-cache git ca-certificates tzdata

# Create non-root user for the final image
RUN adduser -D -g '' appuser

WORKDIR /app

# Copy dependency files first — Docker caches this layer
# so 'go mod download' only re-runs when go.mod/go.sum change
COPY go.mod go.sum ./
RUN go mod download

# Copy the rest of the source code
COPY . .

# Install swag CLI and generate swagger docs
RUN go install github.com/swaggo/swag/cmd/swag@latest
RUN swag init -g cmd/api/main.go --output docs

# Build the binary
# CGO_ENABLED=0  → statically linked (no C deps, works in scratch/alpine)
# -ldflags "-s -w" → strip debug info, smaller binary
RUN CGO_ENABLED=0 GOOS=linux go build \
    -ldflags="-s -w" \
    -o /app/server \
    ./cmd/api

# ─────────────────────────────────────────
# Stage 2: Final image
# ─────────────────────────────────────────
FROM alpine:3.19

# Security: don't run as root
RUN apk add --no-cache ca-certificates tzdata curl
RUN adduser -D -g '' appuser

WORKDIR /app

# Copy only the compiled binary from builder
COPY --from=builder /app/server .

# Own the binary
RUN chown appuser:appuser /app/server

USER appuser

EXPOSE 8080

# Health check using the /ping endpoint
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD curl -f http://localhost:8080/ping || exit 1

ENTRYPOINT ["/app/server"]