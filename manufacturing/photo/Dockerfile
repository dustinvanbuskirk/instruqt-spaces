# Build stage
FROM golang:1.21-alpine AS builder

# Set build arguments
ARG VERSION=dev
ARG TEXT_COLOR=#FFFFFF
ARG BG_COLOR=#2C3E50

WORKDIR /build

# Copy all source files
COPY . .

# Download dependencies (if any)
RUN go mod download

# Build the application
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo \
    -ldflags "-s -w" \
    -o server ./cmd/server/main.go

# Final stage
FROM alpine:latest

# Install ca-certificates for HTTPS
RUN apk --no-cache add ca-certificates

WORKDIR /app

# Copy binary from builder
COPY --from=builder /build/server .

# Set environment variables from build args
ARG VERSION=dev
ARG IMAGE=unknown
ARG TEXT_COLOR=#FFFFFF
ARG BG_COLOR=#2C3E50

ENV APP_VERSION=${VERSION} \
    APP_IMAGE=${IMAGE} \
    TEXT_COLOR=${TEXT_COLOR} \
    BG_COLOR=${BG_COLOR} \
    PORT=8080

# Expose port
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:8080/health || exit 1

# Run as non-root user
RUN addgroup -g 1000 appuser && \
    adduser -D -u 1000 -G appuser appuser && \
    chown -R appuser:appuser /app

USER appuser

CMD ["./server"]