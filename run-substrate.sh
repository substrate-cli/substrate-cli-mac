#!/bin/bash
# -----------------------------
# Change to project directory
# -----------------------------
cd "$(dirname "$0")" || exit

# -----------------------------
# Global cleanup flag
# -----------------------------
CLEANUP_RUNNING=false

# -----------------------------
# Start supporting services in detached mode
# -----------------------------
echo "Starting supporting services..."
docker-compose -f docker-compose-public.yml pull rabbitmq redis consumer-service llm-node
docker-compose -f docker-compose-public.yml up -d rabbitmq redis consumer-service llm-node

# -----------------------------
# Start API server interactively in a new Terminal tab
# -----------------------------
API_CONTAINER_NAME="api-server"

# Remove old API server container if it exists
if docker ps -a -q -f "name=$API_CONTAINER_NAME" >/dev/null 2>&1; then
    echo "Removing old API server container..."
    docker rm -f "$API_CONTAINER_NAME" >/dev/null 2>&1
fi

echo "Opening API server in a new terminal tab interactively..."
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
osascript <<EOF
tell application "Terminal"
    activate
    do script "cd \"$SCRIPT_DIR\"; docker-compose -f docker-compose-public.yml run --service-ports --name $API_CONTAINER_NAME api-server"
end tell
EOF

# Wait a few seconds for the API server container to start
sleep 5
echo "All supporting services are running."
echo "API server started in a new terminal tab interactively."
echo "Press Ctrl+C here to stop all services."

# -----------------------------
# Enhanced cleanup function
# -----------------------------
cleanup() {
    if [ "$CLEANUP_RUNNING" = true ]; then
        echo ""
        echo "⚠️  Cleanup already in progress! Please wait..."
        return
    fi
    
    CLEANUP_RUNNING=true
    trap '' SIGINT SIGTERM
    
    echo ""
    echo "🛑 Shutdown initiated..."
    
    # Stop interactive API server
    if docker ps -a -q -f "name=$API_CONTAINER_NAME" >/dev/null 2>&1; then
        echo "📦 Stopping API server container..."
        timeout 30 docker stop "$API_CONTAINER_NAME" 2>&1
        timeout 10 docker rm -f "$API_CONTAINER_NAME" 2>&1
    fi
    
    # Stop supporting services
    echo "📦 Stopping all supporting services..."
    if timeout 60 docker-compose -f docker-compose-public.yml down --remove-orphans 2>&1; then
        echo "✅ All services stopped successfully"
    else
        echo "⚠️  Timeout stopping services, forcing cleanup..."
        docker-compose -f docker-compose-public.yml kill 2>/dev/null || true
        docker-compose -f docker-compose-public.yml rm -f 2>/dev/null || true
    fi
    
    exit 0
}

# -----------------------------
# Set up signal handling
# -----------------------------
trap cleanup SIGINT SIGTERM

# -----------------------------
# Keep-alive loop
# -----------------------------
echo ""
echo "🟢 System is running. Press Ctrl+C to gracefully shutdown all services."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

counter=0
while true; do
    sleep 10
    counter=$((counter + 1))
    if [ $((counter % 6)) -eq 0 ]; then
        echo "💓 Services running... ($(date '+%H:%M:%S'))"
    fi
done
