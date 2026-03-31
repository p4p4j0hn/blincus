# Blincus Wayland Migration Specification

## Executive Summary

This specification outlines the migration of Blincus from X11 socket forwarding to Wayland socket forwarding for container display sharing. **Important clarification**: Blincus does not currently implement traditional RDP/VNC protocols. Instead, it uses direct X11 socket forwarding to share the host's display server with containers. The migration to Wayland will maintain this socket forwarding approach while adapting to Wayland's compositor architecture.

## Current Architecture Analysis

### Current X11 Implementation
- **Display Sharing Method**: Direct X11 socket forwarding (`/tmp/.X11-unix/X0`)
- **Access Control**: `xhost +` for permissive X11 connections
- **Container Integration**: Incus profiles mount host X11 socket into containers
- **GPU Access**: Direct GPU passthrough via Incus device sharing
- **Audio**: PulseAudio socket forwarding (`/run/user/1000/pulse/native`)
- **User Mapping**: 1:1 UID/GID mapping between host and container

### Key Components Requiring Migration
1. **X11 Socket Forwarding** → Wayland Socket Forwarding
2. **xhost Access Control** → Wayland Compositor Permissions
3. **Display Environment Variables** → Wayland Environment Setup
4. **PulseAudio Socket Forwarding** → PipeWire Socket Forwarding
5. **Container Profiles** → Updated for Wayland and PipeWire sockets
6. **Template Configurations** → Wayland and PipeWire-aware cloud-init

## Wayland and PipeWire Architecture Overview

### Wayland Socket Location
- **Primary Socket**: `$XDG_RUNTIME_DIR/wayland-0` (typically `/run/user/1000/wayland-0`)
- **Compositor-Specific**: Some compositors use named sockets (e.g., `$XDG_RUNTIME_DIR/sway-wayland.sock`)
- **Environment Variables**: `WAYLAND_DISPLAY`, `XDG_RUNTIME_DIR`

### PipeWire Socket Location
- **Primary Socket**: `$XDG_RUNTIME_DIR/pipewire-0` (typically `/run/user/1000/pipewire-0`)
- **PulseAudio Compatibility**: `$XDG_RUNTIME_DIR/pulse/native` (PipeWire's PulseAudio emulation)
- **Session Manager**: `$XDG_RUNTIME_DIR/wireplumber-0` (WirePlumber session manager)
- **Environment Variables**: `PIPEWIRE_RUNTIME_DIR`, `XDG_RUNTIME_DIR`

### Security Model
- **Socket Permissions**: File system permissions control access
- **No xhost Equivalent**: Access controlled via socket ownership and permissions
- **Compositor Security**: Some compositors support client security labels
- **Protocol Filtering**: Advanced compositors can block specific Wayland protocols
- **PipeWire Security**: Built-in security contexts and sandboxing via `pw-container`

## Migration Strategy

### Phase 1: Wayland Detection and Compatibility Layer

#### 1.1 Display Server and Audio System Detection
Create detection logic to identify the current display server and audio system:

```bash
detect_display_server() {
    if [[ -n "$WAYLAND_DISPLAY" ]] && [[ -S "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY" ]]; then
        echo "wayland"
    elif [[ -n "$DISPLAY" ]] && [[ -S "/tmp/.X11-unix/X${DISPLAY#*:}" ]]; then
        echo "x11"
    else
        echo "unknown"
    fi
}

detect_audio_server() {
    if [[ -S "$XDG_RUNTIME_DIR/pipewire-0" ]]; then
        echo "pipewire"
    elif [[ -S "$XDG_RUNTIME_DIR/pulse/native" ]] && ! pgrep -x pipewire > /dev/null; then
        echo "pulseaudio"
    else
        echo "unknown"
    fi
}
```

#### 1.2 Unified Socket Forwarding Interface
Implement abstraction layer for both display and audio systems:

```bash
setup_display_forwarding() {
    local display_type=$(detect_display_server)
    case "$display_type" in
        "wayland")
            setup_wayland_forwarding
            ;;
        "x11")
            setup_x11_forwarding  # Existing implementation
            ;;
        *)
            echo "Error: No supported display server detected"
            exit 1
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
            setup_pulseaudio_forwarding  # Existing implementation
            ;;
        *)
            echo "Warning: No supported audio server detected"
            ;;
    esac
}
```

### Phase 2: Wayland and PipeWire Socket Forwarding Implementation

#### 2.1 Wayland and PipeWire Socket Mounting
Update Incus profiles to mount both Wayland and PipeWire sockets:

```yaml
# profiles/waylanddevs.yaml
devices:
  wayland-socket:
    path: /mnt/.container_wayland_socket
    source: /run/user/1000/wayland-0  # Dynamic based on $XDG_RUNTIME_DIR/$WAYLAND_DISPLAY
    type: disk
  pipewire-socket:
    path: /mnt/.container_pipewire_socket
    source: /run/user/1000/pipewire-0
    type: disk
  pipewire-pulse-socket:
    path: /mnt/.container_pipewire_pulse_socket
    source: /run/user/1000/pulse/native  # PipeWire's PulseAudio compatibility socket
    type: disk
  wireplumber-socket:
    path: /mnt/.container_wireplumber_socket
    source: /run/user/1000/wireplumber-0
    type: disk
  xdg-runtime:
    path: /run/user/1000
    source: /run/user/1000
    type: disk
    readonly: false
```

#### 2.2 Container Wayland and PipeWire Setup
Update cloud-init templates for Wayland and PipeWire support:

```yaml
# cloud-init/fedorawayland.yaml
packages:
  - pipewire
  - pipewire-pulseaudio
  - pipewire-alsa
  - wireplumber
  - wayland-protocols
  - libwayland-client
  - libwayland-cursor
  - libwayland-egl

runcmd:
  # Setup XDG_RUNTIME_DIR
  - mkdir -p /run/user/1000
  - chown 1000:1000 /run/user/1000
  - chmod 700 /run/user/1000
  
  # Setup Wayland socket
  - ln -sf /mnt/.container_wayland_socket /run/user/1000/wayland-0
  
  # Setup PipeWire sockets
  - mkdir -p /run/user/1000/pulse
  - ln -sf /mnt/.container_pipewire_socket /run/user/1000/pipewire-0
  - ln -sf /mnt/.container_pipewire_pulse_socket /run/user/1000/pulse/native
  - ln -sf /mnt/.container_wireplumber_socket /run/user/1000/wireplumber-0
  
  # Setup environment variables
  - echo 'export WAYLAND_DISPLAY=wayland-0' >> /home/BLINCUSUSER/.bashrc
  - echo 'export XDG_RUNTIME_DIR=/run/user/1000' >> /home/BLINCUSUSER/.bashrc
  - echo 'export PIPEWIRE_RUNTIME_DIR=/run/user/1000' >> /home/BLINCUSUSER/.bashrc
  - echo 'export PULSE_RUNTIME_PATH=/run/user/1000/pulse' >> /home/BLINCUSUSER/.bashrc
```

#### 2.3 Environment Variable Management
Update launch scripts to set Wayland and PipeWire environment variables:

```bash
setup_wayland_environment() {
    local wayland_display="${WAYLAND_DISPLAY:-wayland-0}"
    local xdg_runtime_dir="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
    
    # Set environment variables for container
    export CONTAINER_WAYLAND_DISPLAY="$wayland_display"
    export CONTAINER_XDG_RUNTIME_DIR="$xdg_runtime_dir"
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
```

### Phase 3: Compositor-Specific Adaptations

#### 3.1 Multi-Compositor Support
Support various Wayland compositors with different socket naming:

```bash
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
    else
        echo "generic"
        export WAYLAND_SOCKET_PATH="$XDG_RUNTIME_DIR/${WAYLAND_DISPLAY:-wayland-0}"
    fi
}
```

#### 3.2 Permission Management
Implement Wayland-appropriate permission handling:

```bash
setup_wayland_permissions() {
    local socket_path="$1"
    local container_user_id="$2"
    
    # Ensure socket is accessible to container user
    if [[ -S "$socket_path" ]]; then
        # Check if user has access to socket
        if ! sudo -u "#$container_user_id" test -r "$socket_path"; then
            echo "Warning: Container user may not have access to Wayland socket"
            echo "Consider adding user to appropriate groups or adjusting socket permissions"
        fi
    fi
}
```

### Phase 4: XWayland and PulseAudio Compatibility

#### 4.1 XWayland Support
Maintain X11 application compatibility through XWayland:

```bash
setup_xwayland_support() {
    # Check if XWayland is available
    if command -v Xwayland > /dev/null; then
        # XWayland socket will be created automatically by compositor
        # Ensure X11 environment variables are set for legacy apps
        export DISPLAY=":0"
        
        # Mount X11 socket if XWayland is running
        if [[ -S "/tmp/.X11-unix/X0" ]]; then
            setup_x11_socket_forwarding
        fi
    fi
}
```

#### 4.2 PulseAudio Compatibility Layer
Maintain PulseAudio application compatibility through PipeWire's PulseAudio emulation:

```bash
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
        setup_pulseaudio_forwarding
    fi
}
```

## Implementation Details

### File Modifications Required

#### 1. Core Scripts
- **`src/launch_command.sh`**: Add Wayland detection and setup logic
- **`src/blincus`**: Update main script with display server detection

#### 2. Profile Updates
- **`profiles/xdevs.yaml`** → **`profiles/waylanddevs.yaml`**: New Wayland and PipeWire device profile
- **`profiles/hybriddevs.yaml`**: New profile supporting both X11/Wayland and PulseAudio/PipeWire
- **`profiles/pipewiredevs.yaml`**: PipeWire-only audio profile for systems with PipeWire but X11

#### 3. Cloud-Init Templates
- **`cloud-init/fedorawayland.yaml`**: Fedora with Wayland and PipeWire support
- **`cloud-init/debianwayland.yaml`**: Debian with Wayland and PipeWire support
- **`cloud-init/ubuntuwayland.yaml`**: Ubuntu with Wayland and PipeWire support
- **`cloud-init/fedorapipewire.yaml`**: Fedora with PipeWire support (X11 display)
- **`cloud-init/debianpipewire.yaml`**: Debian with PipeWire support (X11 display)
- **`cloud-init/ubuntupipewire.yaml`**: Ubuntu with PipeWire support (X11 display)

#### 4. Configuration System
- **Template naming convention**: 
  - Templates ending in 'w' for Wayland + PipeWire (e.g., `fedoraw`, `ubuntuw`)
  - Templates ending in 'p' for PipeWire + X11 (e.g., `fedorap`, `ubuntup`)
  - Templates ending in 'x' continue to work for X11 + PulseAudio (backward compatibility)

### Dependency Updates

#### Nix Flake Dependencies
```nix
# flake.nix additions
waylandDeps = with pkgs; [
  wayland              # Wayland protocol libraries
  wayland-utils        # Wayland utilities (wayland-info, etc.)
  wl-clipboard         # Wayland clipboard utilities
];

pipewireDeps = with pkgs; [
  pipewire             # PipeWire multimedia server
  wireplumber          # PipeWire session manager
  pipewire-pulse       # PipeWire PulseAudio compatibility
  pipewire-alsa        # PipeWire ALSA compatibility
  pipewire-jack        # PipeWire JACK compatibility
];
```

#### Container Dependencies
```yaml
# cloud-init package additions for Wayland + PipeWire
packages:
  # Wayland packages
  - wayland-protocols
  - libwayland-client0
  - libwayland-cursor0
  - libwayland-egl1
  
  # PipeWire packages
  - pipewire
  - pipewire-pulse
  - pipewire-alsa
  - wireplumber
  - libpipewire-0.3-0
  
  # Compatibility packages
  - pulseaudio-utils    # For pactl, pacmd compatibility
  - alsa-utils          # For alsamixer, aplay compatibility
```

### Security Considerations

#### 1. Socket Access Control
- **File Permissions**: Rely on filesystem permissions for socket access
- **User Groups**: Consider adding container users to appropriate groups
- **Socket Ownership**: Ensure proper ownership of mounted sockets

#### 2. Compositor Security
- **Protocol Filtering**: Some compositors support blocking dangerous protocols
- **Client Isolation**: Advanced compositors may provide client sandboxing
- **Privilege Separation**: Maintain principle of least privilege

#### 3. Container Security
- **Read-Only Mounts**: Consider making certain mounts read-only where possible
- **Namespace Isolation**: Leverage container namespaces for additional security
- **Capability Dropping**: Remove unnecessary container capabilities

## Testing Strategy

### Phase 1: Basic Functionality Testing
1. **Socket Detection**: Verify correct detection of Wayland vs X11
2. **Socket Mounting**: Confirm proper socket forwarding to containers
3. **Environment Setup**: Validate environment variables in containers
4. **Basic Applications**: Test simple Wayland applications (e.g., `wayland-info`)

### Phase 2: Compositor Compatibility Testing
1. **GNOME/Mutter**: Test with GNOME Wayland session
2. **KDE/KWin**: Test with KDE Plasma Wayland session
3. **Sway**: Test with Sway compositor
4. **Weston**: Test with reference Weston compositor

### Phase 3: Application Compatibility Testing
1. **Native Wayland Apps**: GTK4, Qt6 applications
2. **XWayland Apps**: Legacy X11 applications
3. **GPU Applications**: OpenGL/Vulkan applications with GPU passthrough
4. **PipeWire Audio Applications**: Native PipeWire applications
5. **PulseAudio Compatibility**: Legacy PulseAudio applications through PipeWire
6. **ALSA Applications**: ALSA applications through PipeWire-ALSA
7. **JACK Applications**: Professional audio applications through PipeWire-JACK
8. **Real-time Audio**: Low-latency audio applications and DAWs

### Phase 4: Performance and Stability Testing
1. **Performance Benchmarks**: Compare X11 vs Wayland performance
2. **Memory Usage**: Monitor memory consumption differences
3. **Stability Testing**: Long-running container sessions
4. **Multi-Container**: Multiple containers with display sharing

## Migration Timeline

### Phase 1: Foundation (Weeks 1-2)
- [ ] Implement display server and audio system detection
- [ ] Create Wayland and PipeWire socket forwarding infrastructure
- [ ] Update core launch scripts
- [ ] Basic Wayland and PipeWire profile creation

### Phase 2: Core Implementation (Weeks 3-4)
- [ ] Implement Wayland and PipeWire socket mounting
- [ ] Update cloud-init templates with PipeWire support
- [ ] Environment variable management for both systems
- [ ] Basic testing with simple Wayland and audio applications

### Phase 3: Compositor and Audio Support (Weeks 5-6)
- [ ] Multi-compositor detection and support
- [ ] PipeWire session manager integration (WirePlumber)
- [ ] Compositor-specific socket handling
- [ ] Audio routing and device management
- [ ] Permission management improvements
- [ ] Extended testing across compositors and audio configurations

### Phase 4: Compatibility Integration (Weeks 7-8)
- [ ] XWayland compatibility layer
- [ ] PulseAudio compatibility through PipeWire
- [ ] Hybrid mode implementation (X11/Wayland + PulseAudio/PipeWire)
- [ ] Legacy application testing
- [ ] Audio application compatibility testing
- [ ] Performance optimization

### Phase 5: Polish and Documentation (Weeks 9-10)
- [ ] Comprehensive testing across all configurations
- [ ] Audio latency and quality testing
- [ ] Documentation updates including audio setup
- [ ] Migration guide creation
- [ ] Backward compatibility verification
- [ ] Performance benchmarking (display and audio)

## Backward Compatibility

### Compatibility Strategy
1. **Dual Support**: Maintain both X11 and Wayland support during transition
2. **Automatic Detection**: Automatically choose appropriate display server
3. **Fallback Mechanism**: Fall back to X11 if Wayland unavailable
4. **Configuration Options**: Allow users to force specific display server

### Migration Path for Users
1. **Transparent Migration**: Most users should see no difference
2. **Template Updates**: New Wayland templates available alongside X11 versions
3. **Configuration Migration**: Existing configurations continue to work
4. **Gradual Adoption**: Users can migrate at their own pace

## Risk Assessment and Mitigation

### High-Risk Areas
1. **Compositor Compatibility**: Different compositors may have varying socket behaviors
   - **Mitigation**: Extensive testing across major compositors
   - **Fallback**: Maintain X11 support as backup

2. **Permission Issues**: Wayland and PipeWire socket permissions may be more restrictive
   - **Mitigation**: Comprehensive permission handling and user guidance
   - **Documentation**: Clear troubleshooting guides

3. **Application Compatibility**: Some applications may not work properly with socket forwarding
   - **Mitigation**: XWayland support for legacy applications and PipeWire compatibility layers
   - **Testing**: Extensive application compatibility testing

4. **Audio Latency and Quality**: PipeWire forwarding may introduce audio latency or quality issues
   - **Mitigation**: Proper PipeWire configuration and buffer management
   - **Testing**: Professional audio application testing and latency measurements

### Medium-Risk Areas
1. **Performance Impact**: Wayland and PipeWire forwarding performance compared to X11/PulseAudio
   - **Mitigation**: Performance benchmarking and optimization
   - **Monitoring**: Continuous performance monitoring

2. **GPU Passthrough**: Wayland GPU integration complexity
   - **Mitigation**: Thorough testing with various GPU configurations
   - **Documentation**: GPU-specific setup guides

3. **PipeWire Session Management**: WirePlumber configuration and session handling
   - **Mitigation**: Proper WirePlumber configuration and fallback mechanisms
   - **Testing**: Multi-device and complex audio routing scenarios

4. **Audio Device Enumeration**: Container access to host audio devices through PipeWire
   - **Mitigation**: Comprehensive device passthrough testing
   - **Documentation**: Audio device configuration guides

### Low-Risk Areas
1. **Container Runtime**: Incus container functionality should be unaffected
2. **File Sharing**: User ID mapping and file sharing unchanged
3. **GPU Passthrough**: Basic GPU functionality should transfer directly
4. **Network Configuration**: Container networking unchanged

## Success Criteria

### Functional Requirements
- [ ] Wayland applications run successfully in containers
- [ ] XWayland applications maintain compatibility
- [ ] GPU acceleration works with Wayland forwarding
- [ ] PipeWire audio forwarding functions correctly
- [ ] PulseAudio compatibility through PipeWire works
- [ ] ALSA and JACK compatibility through PipeWire works
- [ ] Multi-compositor support (GNOME, KDE, Sway, Weston)
- [ ] Audio device enumeration and routing works
- [ ] Real-time audio applications function with acceptable latency

### Performance Requirements
- [ ] Wayland forwarding performance within 5% of X11 forwarding
- [ ] PipeWire audio latency within 10ms of PulseAudio forwarding
- [ ] Container startup time not significantly impacted
- [ ] Memory usage increase less than 15% (accounting for both Wayland and PipeWire)
- [ ] Audio quality maintains bit-perfect reproduction for supported formats

### Compatibility Requirements
- [ ] Existing X11 + PulseAudio configurations continue to work
- [ ] Smooth migration path for existing users
- [ ] Backward compatibility maintained for at least 6 months
- [ ] PulseAudio applications work transparently through PipeWire
- [ ] ALSA and JACK applications maintain compatibility
- [ ] Audio configuration tools (pavucontrol, alsamixer) continue to function

### User Experience Requirements
- [ ] Transparent operation for most users
- [ ] Clear documentation and migration guides
- [ ] Troubleshooting resources available
- [ ] Community feedback incorporated

## Additional PipeWire Implementation Details

### PipeWire Socket Management
```bash
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
}
```

### PipeWire Configuration in Containers
```yaml
# Additional cloud-init configuration for PipeWire
write_files:
  - path: /home/BLINCUSUSER/.config/pipewire/pipewire.conf.d/99-container.conf
    content: |
      context.properties = {
        default.clock.rate = 48000
        default.clock.quantum = 1024
        default.clock.min-quantum = 32
        default.clock.max-quantum = 2048
      }
    owner: BLINCUSUSER:BLINCUSUSER
    permissions: '0644'
  
  - path: /home/BLINCUSUSER/.config/wireplumber/main.lua.d/99-container.lua
    content: |
      -- Container-specific WirePlumber configuration
      alsa_monitor.enabled = false  -- Disable ALSA device discovery in container
      v4l2_monitor.enabled = false  -- Disable V4L2 device discovery in container
    owner: BLINCUSUSER:BLINCUSUSER
    permissions: '0644'
```

### Audio Testing and Validation
```bash
# Container audio validation script
validate_pipewire_setup() {
    echo "Testing PipeWire setup in container..."
    
    # Test PipeWire connection
    if pw-cli info > /dev/null 2>&1; then
        echo "✓ PipeWire connection successful"
    else
        echo "✗ PipeWire connection failed"
        return 1
    fi
    
    # Test PulseAudio compatibility
    if pactl info > /dev/null 2>&1; then
        echo "✓ PulseAudio compatibility working"
    else
        echo "✗ PulseAudio compatibility failed"
    fi
    
    # Test audio playback capability
    if pw-play --list-targets > /dev/null 2>&1; then
        echo "✓ Audio playback targets available"
    else
        echo "✗ No audio playback targets found"
    fi
    
    # Test audio recording capability
    if pw-record --list-targets > /dev/null 2>&1; then
        echo "✓ Audio recording targets available"
    else
        echo "✗ No audio recording targets found"
    fi
}
```

## Conclusion

The migration from X11 + PulseAudio to Wayland + PipeWire socket forwarding in Blincus is a comprehensive but manageable undertaking. The current architecture's use of direct socket forwarding (rather than traditional remote desktop protocols) actually simplifies the migration process for both display and audio systems.

The key advantages of this migration include:
- **Modern Display Protocol**: Wayland provides better security, performance, and features
- **Unified Audio Architecture**: PipeWire handles audio, video, and MIDI in a single framework
- **Better Compatibility**: PipeWire provides transparent compatibility with PulseAudio, ALSA, and JACK
- **Lower Latency**: PipeWire's design enables lower audio latency for professional applications
- **Future-Proofing**: Both Wayland and PipeWire are the future of Linux desktop environments

The phased approach ensures stability while providing a clear path forward to modern Wayland + PipeWire desktop environments. The key to success will be thorough testing across different compositors, audio configurations, and applications, maintaining backward compatibility during the transition, and providing clear documentation for users.

With proper implementation, this migration will position Blincus as a modern, future-ready container development environment that supports the latest Linux desktop technologies while maintaining compatibility with legacy applications.
