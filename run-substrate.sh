#!/bin/bash
# -----------------------------
# Change to project directory
# -----------------------------
cd "$(dirname "$0")" || exit

# -----------------------------
# Ensure Docker daemon is running
# -----------------------------
if ! docker info >/dev/null 2>&1; then
    echo "❌ Docker daemon is not running. Please start Docker and try again."
    exit 1
fi

# -----------------------------
# Containers to check
# -----------------------------
CONTAINERS=("rabbitmq" "redis" "consumer-service" "llm-node" "api-server")
ALL_RUNNING=true

for c in "${CONTAINERS[@]}"; do
    status=$(docker inspect -f '{{.State.Running}}' "$c" 2>/dev/null)
    if [ "$status" != "true" ]; then
        ALL_RUNNING=false
        break
    fi
done

if [ "$ALL_RUNNING" = true ]; then
    echo "✅ substrate cli is already running. Exiting without pulling images..."
    exit 0
fi

# -----------------------------
# Global cleanup flag
# -----------------------------
CLEANUP_RUNNING=false

# -----------------------------
# API Container Name
# -----------------------------
API_CONTAINER_NAME="api-server"

# -----------------------------
# Cleanup function
# -----------------------------
cleanup() {
    if [ "$CLEANUP_RUNNING" = true ]; then
        return
    fi
    CLEANUP_RUNNING=true
    
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🛑 Shutdown signal received. Cleaning up..."
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # Stop API server
    if docker ps -q -f "name=$API_CONTAINER_NAME" >/dev/null 2>&1; then
        echo ""
        echo "📦 Stopping API server container ($API_CONTAINER_NAME)..."
        docker stop -t 30 "$API_CONTAINER_NAME" 2>&1 || true
        echo "🗑️  Removing API server container..."
        docker rm -f "$API_CONTAINER_NAME" 2>&1 || true
        echo "✅ API server stopped and removed"
    else
        echo "ℹ️  API server container not running"
    fi
    
    # Stop supporting services
    echo ""
    echo "📦 Stopping all supporting services (rabbitmq, redis, consumer-service, llm-node)..."
    echo "⏳ This may take up to 60 seconds..."
    
    if timeout 60 docker-compose -f docker-compose-public.yml down --remove-orphans 2>&1; then
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "✅ All services stopped and removed successfully"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    else
        echo ""
        echo "⚠️  Timeout stopping services gracefully, forcing cleanup..."
        docker-compose -f docker-compose-public.yml kill 2>&1 || true
        docker-compose -f docker-compose-public.yml rm -f 2>&1 || true
        echo "✅ Forced cleanup completed"
    fi
}

# -----------------------------
# Set up signal handling
# -----------------------------
trap 'cleanup; exit 0' SIGINT SIGTERM

# -----------------------------
# Start supporting services in detached mode
# -----------------------------
echo "Starting supporting services..."
if ! docker-compose -f docker-compose-public.yml pull rabbitmq redis consumer-service llm-node; then
    echo "❌ Failed to pull images. Exiting..."
    exit 1
fi

if ! docker-compose -f docker-compose-public.yml up -d rabbitmq redis consumer-service llm-node; then
    echo "❌ Failed to start supporting services. Exiting..."
    exit 1
fi

# -----------------------------
# Start API server interactively in a new Terminal tab
# -----------------------------
# Remove old API server container if it exists
if docker ps -a -q -f "name=$API_CONTAINER_NAME" >/dev/null 2>&1; then
    echo "Removing old API server container..."
    docker rm -f "$API_CONTAINER_NAME" >/dev/null 2>&1
fi

echo "Opening API server in a new terminal window..."
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

osascript <<EOF
tell application "Terminal"
    do script "cd '$SCRIPT_DIR' && docker-compose -f docker-compose-public.yml run --rm --name $API_CONTAINER_NAME --service-ports api-server; exit"
    activate
end tell
EOF

# -----------------------------
# Keep-alive loop with interruptible wait
# -----------------------------
echo ""
echo "🟢 System is running. Press Ctrl+C to gracefully shutdown all services."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

while true; do
    sleep 60 &
    wait $! 2>/dev/null || { cleanup; exit 0; }
    echo "💓 Services running... ($(date '+%H:%M:%S'))"
done