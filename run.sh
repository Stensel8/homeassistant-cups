#!/bin/bash
set -e

# Default configuration
ACTION="${1:-run}"
CONTAINER_NAME="${CONTAINER_NAME:-homeassistant-cups}"
IMAGE_NAME="${IMAGE_NAME:-homeassistant-cups:latest}"
HTTP_PORT="${HTTP_PORT:-631}"
USERNAME="${USERNAME:-admin}"
PASSWORD="${PASSWORD:-admin}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

function log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

function log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

function log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

function show_usage() {
    echo "Usage: $0 [build|run|stop|restart|logs|clean]"
    echo ""
    echo "Environment variables:"
    echo "  CONTAINER_NAME - Container name (default: homeassistant-cups)"
    echo "  IMAGE_NAME     - Podman image name (default: homeassistant-cups:latest)"
    echo "  HTTP_PORT      - HTTP port mapping (default: 631)"
    echo "  USERNAME       - CUPS username (default: admin)"
    echo "  PASSWORD       - CUPS password (default: admin)"
    echo ""
    echo "Examples:"
    echo "  $0 build                    # Build the Podman image"
    echo "  $0 run                      # Build (if needed) and run container"
    echo "  HTTP_PORT=8631 $0 run       # Run on different port"
    echo "  $0 logs                     # Show container logs"
    echo "  $0 stop                     # Stop the container"
    echo "  $0 clean                    # Stop and remove container + cleanup"
}

function build_image() {
    log_info "Building Podman image: $IMAGE_NAME"
    if podman build -t "$IMAGE_NAME" .; then
        log_info "Build completed successfully"
    else
        log_error "Build failed"
        exit 1
    fi
}

function stop_container() {
    log_info "Stopping container: $CONTAINER_NAME"
    if podman ps -q --filter "name=$CONTAINER_NAME" | grep -q .; then
        if podman stop "$CONTAINER_NAME" >/dev/null; then
            log_info "Container stopped"
        else
            log_warning "Could not stop container"
        fi
    else
        log_warning "Container $CONTAINER_NAME is not running"
    fi
}

function remove_container() {
    log_info "Removing container: $CONTAINER_NAME"
    if podman ps -aq --filter "name=$CONTAINER_NAME" | grep -q .; then
        if podman rm "$CONTAINER_NAME" >/dev/null; then
            log_info "Container removed"
        else
            log_warning "Could not remove container"
        fi
    else
        log_warning "Container $CONTAINER_NAME does not exist"
    fi
}

function start_container() {
    log_info "Starting container: $CONTAINER_NAME"
    log_info "Port mapping: ${HTTP_PORT}:631"
    log_info "Credentials: $USERNAME / $PASSWORD"
    
    # Stop and remove existing container
    stop_container
    remove_container
    
    # Start new container
    container_id=$(podman run -d \
        --name "$CONTAINER_NAME" \
        -p "${HTTP_PORT}:631" \
        -e CUPS_USERNAME="$USERNAME" \
        -e CUPS_PASSWORD="$PASSWORD" \
        -e SERVER_NAME="CUPS Print Server" \
        -e SSL_ENABLED=true \
        --restart unless-stopped \
        "$IMAGE_NAME")
        
    if [ -n "$container_id" ]; then
        log_info "Container started successfully"
        log_info "Container ID: $container_id"
        log_info "CUPS Web Interface: https://localhost:$HTTP_PORT"
        log_info "Login with: $USERNAME / $PASSWORD"
        
        # Wait a moment and check if container is still running
        sleep 5
        if podman ps -q --filter "name=$CONTAINER_NAME" | grep -q .; then
            log_info "Container is running healthy"
            log_info "Checking CUPS service status..."
            
            # Quick health check
            if podman exec "$CONTAINER_NAME" ps aux | grep -q cupsd; then
                log_info "CUPS service is running inside container"
            else
                log_warning "CUPS service may not be fully started yet"
            fi
        else
            log_error "Container stopped unexpectedly, checking logs..."
            podman logs "$CONTAINER_NAME"
            exit 1
        fi
    else
        log_error "Failed to start container"
        exit 1
    fi
}

function show_logs() {
    log_info "Showing logs for container: $CONTAINER_NAME"
    if podman ps -q --filter "name=$CONTAINER_NAME" | grep -q . || podman ps -aq --filter "name=$CONTAINER_NAME" | grep -q .; then
        podman logs -f "$CONTAINER_NAME"
    else
        log_error "Container $CONTAINER_NAME does not exist"
        exit 1
    fi
}

function cleanup_all() {
    log_info "Cleaning up Podman resources"
    stop_container
    remove_container
    
    # Remove dangling images
    dangling_images=$(podman images -f "dangling=true" -q)
    if [ -n "$dangling_images" ]; then
        log_info "Removing dangling images"
        echo "$dangling_images" | xargs podman rmi
    fi
    
    log_info "Cleanup completed"
}

function show_status() {
    log_info "Podman containers:"
    podman ps -a --filter "name=$CONTAINER_NAME"
    
    log_info "Podman images:"
    podman images | grep "$(echo "$IMAGE_NAME" | cut -d':' -f1)" || true
}

# Main script logic
log_info "HomeAssistant CUPS Podman Manager"
log_info "Action: $ACTION"

case "$ACTION" in
    "build")
        build_image
        ;;
    "run")
        # Check if image exists, build if not
        if ! podman images -q "$IMAGE_NAME" | grep -q .; then
            log_warning "Image $IMAGE_NAME not found, building first..."
            build_image
        fi
        start_container
        ;;
    "stop")
        stop_container
        ;;
    "restart")
        log_info "Restarting container..."
        stop_container
        sleep 2
        start_container
        ;;
    "logs")
        show_logs
        ;;
    "clean")
        cleanup_all
        ;;
    "status")
        show_status
        ;;
    "help"|"-h"|"--help")
        show_usage
        ;;
    *)
        log_error "Unknown action: $ACTION"
        show_usage
        exit 1
        ;;
esac

log_info "Done!"
