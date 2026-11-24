FROM golang:1.22-alpine AS builder

WORKDIR /app
COPY go.mod ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -o /gateway ./cmd/server

FROM alpine:3.20
WORKDIR /app
COPY --from=builder /gateway /app/gateway
COPY migrations /app/migrations

EXPOSE 8000
ENTRYPOINT ["/app/gateway"]
