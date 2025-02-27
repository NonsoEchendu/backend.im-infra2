# Build stage
FROM golang:1.22-alpine AS builder
WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -o /backendim-brain ./cmd/server

# Runtime stage
FROM alpine:3.19
WORKDIR /app

# Install core dependencies
RUN apk add --no-cache \
  ca-certificates \
  curl \
  python3 \
  py3-pip \
  git \
  bash \
  jq \
  libc6-compat

# Install security tools
RUN apk add --no-cache --virtual .security-deps \
  openssl \
  libcrypto3

# Install kubectl
COPY scripts/install-kubectl.sh /tmp/
RUN /tmp/install-kubectl.sh && \
  rm -f /tmp/install-kubectl.sh && \
  rm -rf /var/cache/apk/*

# Application setup
COPY --from=builder /backendim-brain .
COPY scripts/ ./scripts/
COPY deployments/ ./deployments/

# Security hardening
RUN find ./scripts/ -type f \( -name '*.sh' -o -name '*.py' \) -exec chmod 0755 {} + && \
  adduser -D -u 1001 backenduser && \
  mkdir -p /home/backenduser/.kube && \
  chown -R backenduser:backenduser /app /home/backenduser && \
  chmod 0700 /home/backenduser/.kube

# Environment variables for K3s
ENV KUBECONFIG=/home/backenduser/.kube/config \
  PATH="/app/scripts:${PATH}" \
  GIT_SSL_NO_VERIFY="false"

USER backenduser

HEALTHCHECK --interval=30s --timeout=3s CMD scripts/healthcheck.sh
ENTRYPOINT ["/app/scripts/kube-init.sh", "--"]
CMD ["./backendim-brain"]
