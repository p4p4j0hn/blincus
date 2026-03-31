# Blincus Agent Usage Guidelines

## Agent Roles

### Researcher Agent
- **Purpose**: Web searches and documentation lookup
- **Usage**: Always use for `web_search` tasks
- **Responsibilities**:
  - Fetch latest documentation for languages, packages, and tools used in Blincus
  - Research best practices and current standards
  - Verify outdated or uncertain information
  - Gather external knowledge when local documentation is insufficient

### Debugger Agent
- **Purpose**: Testing, debugging, and bug fixes
- **Usage**: Always use when code doesn't run or tests fail
- **Responsibilities**:
  - Diagnose and fix runtime errors
  - Debug failing tests
  - Investigate unexpected behavior
  - Verify fixes work correctly
  - Handle all testing-related tasks

### Coder Agent (Primary)
- **Purpose**: Code implementation and modification
- **Usage**: Default agent for coding tasks
- **Responsibilities**:
  - Write new code
  - Modify existing code
  - Implement features
  - Perform code reviews
  - Delegate to subagents when appropriate

## Workflow Rules

1. **Documentation First**: Always use researcher for web searches before implementing
2. **Debugging Protocol**: All testing failures and bugs go to debugger agent
3. **Tool Specialization**: Use the right agent for the job to maintain quality
4. **Current Information**: Researcher ensures we always use latest documentation
5. **Testing Discipline**: Debugger handles all test verification and bug resolution