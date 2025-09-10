# Copilot Instructions for SM JSON API Plugin

## Repository Overview
This repository contains **SM JSON API**, a SourcePawn plugin for SourceMod that provides a TCP-based JSON API interface for Source engine game servers. The plugin enables external applications to interact with the game server through JSON requests over TCP sockets, supporting function calls, event subscriptions, and real-time data exchange.

## Technical Environment & Build System

### Core Technologies
- **Language**: SourcePawn
- **Platform**: SourceMod 1.11+ (targeting latest stable)
- **Build System**: **SourceKnight** (NOT traditional spcomp) - Version 0.2
- **Dependencies**: Managed via `sourceknight.yaml`

### Key Dependencies
- **AsyncSocket**: TCP socket communication
- **ripext**: HTTP/REST extensions and JSON parsing
- **multicolors**: Enhanced chat color support
- **basic**: Custom methodmap base classes

### Build Process
- **Primary Build Tool**: SourceKnight via GitHub Actions
- **Configuration**: `sourceknight.yaml` defines dependencies, targets, and build settings
- **Output**: Compiled plugins go to `/addons/sourcemod/plugins`
- **CI/CD**: GitHub Actions with `maxime1907/action-sourceknight@v1`

## Project Architecture

### Core Plugin Structure
```
addons/sourcemod/
├── scripting/
│   ├── SMJSONAPI.sp              # Main plugin entry point
│   └── include/
│       ├── API.inc               # Core API functions
│       ├── Request.inc           # JSON request handling
│       ├── Response.inc          # JSON response generation  
│       ├── Subscribe.inc         # Event subscription system
│       ├── Forwards.inc          # Forward declarations
│       └── GameEvents.inc        # Game event definitions
├── configs/
│   ├── Events.csgo.cfg          # CS:GO event definitions
│   └── Events.cstrike.cfg       # CS 1.6 event definitions
└── example.txt                   # API usage examples
```

### Key Components
1. **TCP Server**: Async socket server listening for JSON requests
2. **Request Parser**: Methodmap-based JSON request parsing
3. **Response Builder**: JSON response generation system
4. **Event System**: Subscribe/publish pattern for game events
5. **Dynamic Function Calls**: Execute SourceMod natives via JSON

## Code Style & Standards

### Formatting & Naming
- **Indentation**: 4 spaces (configured as tabs)
- **Variables**: camelCase for local variables and parameters
- **Functions**: PascalCase for function names
- **Globals**: PascalCase with `g_` prefix (e.g., `g_ServerSocket`)
- **Constants**: UPPER_SNAKE_CASE
- **Files**: PascalCase with `.inc` extension for includes

### Required Pragmas
```sourcepawn
#pragma semicolon 1
#pragma newdecls required
#pragma dynamic 65535  // For large JSON handling
```

### Memory Management Rules
- **Always use `delete`** for Handle cleanup - never check for null first
- **Never use `.Clear()`** on StringMap/ArrayList - causes memory leaks
- **Use `delete` and recreate** instead of clearing collections
- **Async patterns required** for all database/network operations

## Plugin-Specific Patterns

### Methodmap Usage
- **Request/Response classes**: Inherit from `Basic` methodmap
- **Constructor pattern**: Always initialize with `new ClassName()`
- **Factory methods**: Use `FromString()` for JSON parsing
- **Proper inheritance**: `methodmap Response < Basic`

### JSON API Design
- **Request structure**: `{"method": "...", "module": "...", "function": "...", "args": [...]}`
- **Response structure**: `{"method": "...", "error": 0, "result": ...}`
- **Event structure**: `{"method": "publish", "module": "gameevents", "event": {...}}`

### Socket Programming
- **Async sockets only**: Use `AsyncSocket` class
- **Connection management**: Track clients in arrays with `MAX_CLIENTS` limit
- **Error handling**: Always handle socket errors and disconnections
- **Data buffering**: Handle partial JSON messages properly

## Development Guidelines

### Adding New API Functions
1. Define in appropriate `.inc` file (usually `API.inc`)
2. Follow existing parameter validation patterns
3. Return appropriate JSON response structures
4. Handle edge cases and invalid inputs
5. Update `example.txt` with usage examples

### Event System Extension
1. Add event definitions to appropriate `.cfg` files
2. Implement subscription logic in `Subscribe.inc`
3. Update `GameEvents.inc` for new event types
4. Test with both subscribe/unsubscribe flows

### Error Handling Patterns
```sourcepawn
// Always validate JSON parsing
JSONObject jsonObject = JSONObject.FromString(data);
if (jsonObject == null)
    return null;

if (!jsonObject.Size)
{
    delete jsonObject;
    return null;
}
```

## Testing & Validation

### Manual Testing
- Use `example.txt` for API endpoint testing
- Test via telnet or custom TCP clients
- Validate JSON request/response cycles
- Test event subscription/publishing flows

### Build Validation
```bash
# Build using SourceKnight
sourceknight build

# Check for compilation errors
# Validate against SourceMod 1.11+ compatibility
```

### Key Test Scenarios
1. **Socket connectivity**: TCP server startup and client connections
2. **JSON parsing**: Valid/invalid JSON request handling  
3. **Function calls**: Dynamic native function execution
4. **Event system**: Subscribe, publish, unsubscribe flows
5. **Error handling**: Network failures, invalid requests
6. **Memory management**: No leaks with repeated operations

## Configuration Management

### ConVars
- `sm_jsonapi_addr`: Listen IP address (default: 127.0.0.1)
- `sm_jsonapi_port`: Listen port (default: 27021)  
- `sm_jsonapi_debug`: Debug logging toggle

### Game-Specific Configs
- **CS:GO**: Use `Events.csgo.cfg` for event definitions
- **CS 1.6**: Use `Events.cstrike.cfg` for event definitions
- **Custom games**: Create appropriate `.cfg` files

## Performance Considerations

### Critical Performance Areas
- **Socket I/O**: Minimize blocking operations
- **JSON parsing**: Cache parsed objects when possible
- **Event callbacks**: Avoid heavy processing in event handlers
- **String operations**: Minimize string concatenations in loops
- **Timer usage**: Prefer event-driven patterns over polling

### Optimization Guidelines
- Use `StringMap` over arrays for key-value lookups
- Batch JSON responses when possible
- Implement connection pooling for high-traffic scenarios
- Profile memory usage with SourceMod's built-in tools

## Debugging & Troubleshooting

### Common Issues
1. **Socket binding failures**: Check port availability and permissions
2. **JSON parsing errors**: Validate request structure and encoding
3. **Memory leaks**: Verify proper `delete` usage for all handles
4. **Event timing**: Ensure proper event hook/unhook sequences

### Debug Techniques
- Enable `sm_jsonapi_debug 1` for verbose logging
- Use `sm_dump_handles` to check for handle leaks
- Monitor server console for error messages
- Test with minimal JSON requests first

## Dependencies & Updates

### Dependency Management
- **Update `sourceknight.yaml`** for version changes
- **Test compatibility** after dependency updates
- **Check breaking changes** in AsyncSocket, ripext APIs
- **Validate build** after any dependency modifications

### Version Control
- Follow semantic versioning (MAJOR.MINOR.PATCH)
- Update plugin version in `SMJSONAPI.sp`
- Tag releases appropriately
- Maintain changelog for API changes

## Integration Notes

### External Applications
- **Protocol**: TCP JSON over socket connection
- **Authentication**: None (rely on network security)
- **Rate limiting**: Implement client-side to avoid overwhelming server
- **Connection handling**: Support graceful disconnections

### SourceMod Integration
- **Native functions**: Accessible via dynamic function calls
- **Game events**: Real-time forwarding to connected clients
- **Admin commands**: Integration with SourceMod's admin system
- **Plugin compatibility**: Designed to work alongside other plugins

This plugin serves as a bridge between external applications and SourceMod, enabling sophisticated server management and monitoring capabilities through a standardized JSON API interface.