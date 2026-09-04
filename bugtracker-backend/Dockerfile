FROM golang:1.21-alpine

WORKDIR /app

# Create mount point for persisted DB (mounted at /app/data in compose)
RUN mkdir -p /app/data && chmod 777 /app/data

# Install wget for healthcheck
RUN apk add --no-cache wget

# Copy go mod files
COPY go.mod go.sum ./

# Download dependencies
RUN go mod download

# Copy source code
COPY . .

# Build the application
RUN go build -o main cmd/bugtracker/main.go

# Expose port 8080
EXPOSE 8080

# Run the binary
CMD ["./main"] 