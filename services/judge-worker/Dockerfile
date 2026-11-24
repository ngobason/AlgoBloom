# Stage 1: Build stateless Go Redis Streams worker binary
FROM golang:1.22-alpine AS builder
WORKDIR /src
COPY go.mod ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -o /judge-worker ./cmd/worker

# Stage 2: Extend headless dmoj/judge-small runtime (cptbox + g++ + python3 + dmoj-cli)
# NOTE(W13 - Nam): Verify `SYS_PTRACE` and seccomp settings in docker-compose when running cptbox.
# Example runtime flags:
#   docker run --cap-add=SYS_PTRACE --security-opt seccomp=unconfined \
#     -v problems_data:/data/problems:ro algobloom-judge-worker
FROM dmoj/judge-small:latest

COPY --from=builder /judge-worker /usr/local/bin/judge-worker

ENV WORKER_MODE=judge
ENV PROBLEMS_DIR=/data/problems

ENTRYPOINT ["/usr/local/bin/judge-worker"]
