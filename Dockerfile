# Build stage
FROM golang:1.24-alpine AS builder

# Install build dependencies
RUN apk add --no-cache git make

# Set working directory
WORKDIR /workspace

# Copy go mod files
COPY go.mod go.sum ./

# Download dependencies
RUN go mod download

# Copy source code
COPY . .

# Build the binary
RUN make build

# Runtime stage
FROM alpine:latest

RUN apk --no-cache add ca-certificates

WORKDIR /root/

# Copy the binary from builder
COPY --from=builder /workspace/bin/kubectl-migrate /usr/local/bin/kubectl-migrate

# Create symlink for kubectl plugin usage
RUN ln -s /usr/local/bin/kubectl-migrate /usr/local/bin/kubectl-kubectl_migrate

ENTRYPOINT ["kubectl-migrate"]
CMD ["--help"]
