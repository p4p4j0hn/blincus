#!/usr/bin/env bash

# Display server detection and setup functions

detect_display_server() {
    # Check for Wayland first
    if [[ -n "$WAYLAND_DISPLAY" ]] && [[ -S "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY" ]]; then
        echo "wayland"
        return 0
    fi
    
    # Check for X11
    if [[ -n "$DISPLAY" ]] && [[ -S "/tmp/.X11-unix/X${DISPLAY#*:}" ]]; then
        echo "x11"
        return 0
    fi
    
    # Neither detected
    echo "unknown"
    return 1
}

detect_audio_server() {
    # Check for PipeWire first
    if [[ -S "$XDG_RUNTIME_DIR/pipewire-0" ]]; then
        echo "pipewire"
        return 0
    fi
    
    # Check for PulseAudio (not running under PipeWire)
    if [[ -S "$XDG_RUNTIME_DIR/pulse/native" ]] && ! pgrep -x pipewire > /dev/null; then
        echo "pulseaudio"
        return 0
    fi
    
    # Neither detected
    echo "unknown"
    return 1
}

detect_wayland_compositor() {
    if pgrep -x "sway" > /dev/null; then
        echo "sway"
        export WAYLAND_SOCKET_PATH="$XDG_RUNTIME_DIR/sway-wayland.sock"
    elif pgrep -x "gnome-shell" > /dev/null; then
        echo "gnome"
        export WAYLAND_SOCKET_PATH="$XDG_RUNTIME_DIR/wayland-0"
    elif pgrep -x "kwin_wayland" > /dev/null; then
        echo "kde"
        export WAYLAND_SOCKET_PATH="$XDG_RUNTIME_DIR/wayland-0"
    elif pgrep -x "weston" > /dev/null; then
        echo "weston"
        export WAYLAND_SOCKET_PATH="$XDG_RUNTIME_DIR/wayland-0"
    elif pgrep -x "hikari" > /dev/null; then
        echo "hikari"
        export WAYLAND_SOCKET_PATH="$XDG_RUNTIME_DIR/wayland-0"
    elif pgrep -x "river" > /dev/null; then
        echo "river"
        export WAYLAND_SOCKET_PATH="$XDG_RUNTIME_DIR/wayland-0"
    else
        echo "generic"
        export WAYLAND_SOCKET_PATH="$XDG_RUNTIME_DIR/${WAYLAND_DISPLAY:-wayland-0}"
    fi
}

setup_wayland_environment() {
    local wayland_display="${WAYLAND_DISPLAY:-wayland-0}"
    local xdg_runtime_dir="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
    
    # Set environment variables for container
    export CONTAINER_WAYLAND_DISPLAY="$wayland_display"
    export CONTAINER_XDG_RUNTIME_DIR="$xdg_runtime_dir"
    
    # Detect compositor and set socket path
    detect_wayland_compositor
}

setup_pipewire_environment() {
    local xdg_runtime_dir="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
    
    # Set PipeWire environment variables for container
    export CONTAINER_PIPEWIRE_RUNTIME_DIR="$xdg_runtime_dir"
    export CONTAINER_PULSE_RUNTIME_PATH="$xdg_runtime_dir/pulse"
    
    # Check for PipeWire socket availability
    if [[ ! -S "$xdg_runtime_dir/pipewire-0" ]]; then
        echo "Warning: PipeWire socket not found at $xdg_runtime_dir/pipewire-0"
        echo "Falling back to PulseAudio compatibility mode"
    fi
}

setup_display_forwarding() {
    local display_type=$(detect_display_server)
    case "$display_type" in
        "wayland")
            setup_wayland_forwarding
            ;;
        "x11")
            setup_x11_forwarding
            ;;
        *)
            echo "Error: No supported display server detected"
            return 1
            ;;
    esac
}

setup_audio_forwarding() {
    local audio_type=$(detect_audio_server)
    case "$audio_type" in
        "pipewire")
            setup_pipewire_forwarding
            ;;
        "pulseaudio")
            setup_pulseaudio_forwarding
            ;;
        *)
            echo "Warning: No supported audio server detected"
            ;;
    esac
}

setup_wayland_forwarding() {
    local wayland_socket="${WAYLAND_SOCKET_PATH:-$XDG_RUNTIME_DIR/${WAYLAND_DISPLAY:-wayland-0}}"
    
    if [[ ! -S "$wayland_socket" ]]; then
        echo "Error: Wayland socket not found at $wayland_socket"
        return 1
    fi
    
    # Set up Wayland environment variables
    setup_wayland_environment
    
    # Set up environment variables for container launch
    export CONTAINER_WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-0}"
    export CONTAINER_XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
    
    echo "Wayland forwarding configured for socket: $wayland_socket"
}

setup_pipewire_forwarding() {
    local xdg_runtime_dir="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
    
    # Check for PipeWire daemon socket
    if [[ -S "$xdg_runtime_dir/pipewire-0" ]]; then
        export PIPEWIRE_SOCKET="$xdg_runtime_dir/pipewire-0"
    else
        echo "Error: PipeWire socket not found"
        return 1
    fi
    
    # Check for WirePlumber session manager
    if [[ -S "$xdg_runtime_dir/wireplumber-0" ]]; then
        export WIREPLUMBER_SOCKET="$xdg_runtime_dir/wireplumber-0"
    fi
    
    # Verify PulseAudio compatibility socket
    if [[ -S "$xdg_runtime_dir/pulse/native" ]]; then
        export PIPEWIRE_PULSE_SOCKET="$xdg_runtime_dir/pulse/native"
    else
        echo "Warning: PipeWire PulseAudio compatibility not available"
    fi
    
    # Set up PipeWire environment
    setup_pipewire_environment
    
    # Set up environment variables for container launch
    export CONTAINER_PIPEWIRE_RUNTIME_DIR="$xdg_runtime_dir"
    export CONTAINER_PULSE_RUNTIME_PATH="$xdg_runtime_dir/pulse"
    
    echo "PipeWire forwarding configured"
}

setup_x11_forwarding() {
    # Existing X11 forwarding logic
    if [[ -n "$DISPLAY" ]]; then
        echo "Allowing X sharing:"
        xhost +
    fi
    
    # Set up XWayland compatibility for Wayland sessions
    setup_xwayland_support
}

setup_xwayland_support() {
    # Check if XWayland is available
    if command -v Xwayland > /dev/null; then
        # XWayland socket will be created automatically by compositor
        # Ensure X11 environment variables are set for legacy apps
        export DISPLAY=":0"
        
        # Mount X11 socket if XWayland is running
        if [[ -S "/tmp/.X11-unix/X0" ]]; then
            echo "XWayland support configured"
        fi
    fi
}

setup_pulseaudio_forwarding() {
    # Existing PulseAudio forwarding logic
    echo "PulseAudio forwarding configured"
    
    # Set up PipeWire compatibility for PulseAudio sessions
    setup_pulseaudio_compatibility
}

setup_pulseaudio_compatibility() {
    local audio_type=$(detect_audio_server)
    
    if [[ "$audio_type" == "pipewire" ]]; then
        # PipeWire provides PulseAudio compatibility
        # Ensure PulseAudio environment variables point to PipeWire sockets
        export PULSE_RUNTIME_PATH="$XDG_RUNTIME_DIR/pulse"
        
        # Verify PulseAudio compatibility socket exists
        if [[ ! -S "$XDG_RUNTIME_DIR/pulse/native" ]]; then
            echo "Warning: PipeWire PulseAudio compatibility socket not found"
            echo "Ensure pipewire-pulseaudio is installed and running"
        fi
    elif [[ "$audio_type" == "pulseaudio" ]]; then
        # Native PulseAudio - use existing implementation
        echo "Native PulseAudio forwarding configured"
    fi
}