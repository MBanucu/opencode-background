# OpenCode Background Processes Plugin (fork from zenobi-us/opencode-background)

The original npm package [`@zenobius/opencode-background`](https://www.npmjs.com/package/@zenobius/opencode-background) from https://github.com/zenobi-us/opencode-background isn't being maintained or updated, so I've stepped in with a maintained fork/version.

Until (or if) the original gets attention, use the [`@mbanucu`](https://www.npmjs.com/package/@mbanucu/opencode-background) version instead.

### Demo: How to use @mbanucu/opencode-background

[![How to use @mbanucu/opencode-background](./demo/Running%20background%20processes/python%20server/correct-usage-demo.gif)](https://asciinema.org/a/765970)

Here is the code for the `echo_server.py`:

```py
import http.server
import socketserver
from datetime import datetime
import json

class EchoHandler(http.server.BaseHTTPRequestHandler):
    def do_POST(self):
        content_length = int(self.headers['Content-Length'])
        post_data = self.rfile.read(content_length)
        msg = post_data.decode('utf-8')
        print(msg, flush=True)
        now = datetime.now().astimezone().isoformat(timespec='seconds')
        try:
            server_ip, server_port = self.connection.getsockname()[:2]
            server_info = f'{server_ip}:{server_port}'
        except Exception:
            server_info = 'unknown'
        log_object = {
            'timestamp': now,
            'message': msg,
            'client_ip': self.client_address[0],
            'server': server_info
        }
        log_line = json.dumps(log_object, indent=2)
        with open('echo_server.log', 'a') as f:
            f.write(log_line + '\n')
        self.send_response(200)
        self.send_header('Content-Type', 'application/json')
        self.end_headers()
        self.wfile.write(log_line.encode('utf-8'))

if __name__ == '__main__':
    with socketserver.TCPServer(("", 0), EchoHandler) as httpd:
        port = httpd.server_address[1]
        print(f"Server running on port {port}", flush=True)
        httpd.serve_forever()
```

### Links

- Fork/Maintained repo: https://github.com/MBanucu/opencode-background
- Original repo: https://github.com/zenobi-us/opencode-background
- npm package (recommended): https://www.npmjs.com/package/@mbanucu/opencode-background
- Original npm package: https://www.npmjs.com/package/@zenobius/opencode-background
- How to install plugins from npm in OpenCode: https://opencode.ai/docs/plugins/#from-npm

# OpenCode Background Processes Plugin

A flexible background process management plugin for OpenCode, offering robust process tracking and lifecycle management.

## Installation

### Basics

For basic information on installing and using plugins in OpenCode, see [the official documentation](https://opencode.ai/docs/plugins/#use-a-plugin).
You don't have to read it, but it is helpful if you want to keep your system clean.

### From npm

Create or edit your OpenCode configuration file (typically `~/.config/opencode/opencode.json`):

```json
{
  "plugins": ["@mbanucu/opencode-background"]
}
```

This installs the plugin from npm. See [the documentation](https://opencode.ai/docs/plugins/#from-npm) for more details on npm installations.

### via Nix

If you have Nix installed, you can install the plugin directly using:

```bash
nix run github:MBanucu/opencode-background#install
```

This will automatically install the plugin to the correct location (`~/.config/opencode/plugin/`).

This installs the plugin as a local file. See [the documentation](https://opencode.ai/docs/plugins/#from-local-files) for more details on local file installations.

To uninstall:

```bash
nix run github:MBanucu/opencode-background#uninstall
```

This will remove the plugin files from `~/.config/opencode/plugin/`.

## Usage

[![asciicast](https://asciinema.org/a/FhwMJK48sUyKzoBe366YuhqS7.svg)](https://asciinema.org/a/FhwMJK48sUyKzoBe366YuhqS7)

### Example 1: Build Pipeline Management

```
I need to run and monitor multiple background processes for a build pipeline:

1. Start a long-running build process tagged as ["build", "critical"] that runs: `bun build ./src/index.ts --outdir dist --target bun`
2. Start a test runner tagged as ["test", "validation"] that runs: `bun test --watch`
3. Start a global process tagged as ["lint"] for linting: `mise run lint` (should persist across sessions)
4. List all current processes and show me their statuses
5. List only the processes tagged with "critical" or "validation"
6. Kill the test runner process, then list remaining processes
7. Show all currently running processes one more time to verify

Walk me through each step so I can see how the plugin handles concurrent processes, filtering, and termination.
```

**Demonstrates:**

- Creating multiple background processes
- Using tags for categorization
- Global vs session-specific processes
- Listing and filtering by tags
- Process termination
- Real-time status tracking

### Example 2: Web Server and Concurrent Testing

```
Let's test running a web server in the background using json-server:
- Start a json-server instance with: bunx json-server --watch db.json
- Tag it as ["server", "json-api"] for easy management
- Test that it's still running
- Execute a sync cmd (without background) to curl results from the server
- Test that it's still running
- Run a subagent that runs cmds to test the server too
- Confirm the subagent's results
```

**Demonstrates:**

- Long-running background services (JSON API server)
- Interleaving background processes with foreground commands
- Process monitoring across concurrent operations
- Subagent coordination with background processes
- Data persistence through process lifecycle
- Full CRUD operations validation while service runs continuously
- Real-time process status verification

### Example 3: Do not use the npm version of [@zenobius/opencode-background](https://www.npmjs.com/package/@zenobius/opencode-background)

[![Do not use @zenobius/opencode-background](./demo/Running%20background%20processes/python%20server/incorrect-usage-demo.gif)](https://asciinema.org/a/765983)

## Features

- 🚀 Create background processes with real-time output tracking
- 🏷️ Tag and categorize processes
- 🔍 Advanced process filtering
- 🔪 Selective process termination
- 🌐 Global and session-specific process support
- :recycle: Automatic cleanup on session end and application close

## Usage in OpenCode

### Creating a Background Process

```
⚙ createBackgroundProcess
  command=/tmp/long-process.sh
  name="Long Running Process"
  tags=["long-process", "processing"]
  global=false  # Optional: default is false
```

### Process Types

- **Session-Specific Processes** (default):
  - Automatically terminated when the session ends
  - Useful for temporary, session-bound operations
  - Tracked in-memory for the current session

- **Global Processes**:
  - Persist across sessions
  - Continues running until explicitly stopped
  - Useful for long-running services or background operations

### Listing Processes

```
# List processes in current session
⚙ listBackgroundProcesses
  sessionId=current_session_id

# List processes with specific tags
⚙ listBackgroundProcesses
  tags=["processing"]
```

### Killing Processes

```
# Kill a specific process
⚙ killProcesses
  processId=specific-process-id

# Kill all processes in a session
⚙ killProcesses
  sessionId=current_session_id
```

## Plugin Methods

### `createBackgroundProcess`

- `command`: Shell command to execute
- `name` (optional): Descriptive name for the process
- `tags` (optional): List of tags to categorize the process
- `global` (optional):
  - `false` (default): Session-specific process
  - `true`: Process persists across sessions

### `listBackgroundProcesses`

- `sessionId` (optional): Filter processes by session
- `status` (optional): Filter processes by status
- `tags` (optional): Filter processes by tags

### `killProcesses`

- `processId` (optional): Kill a specific process
- `sessionId` (optional): Kill processes in a specific session
- `status` (optional): Kill processes with a specific status
- `tags` (optional): Kill processes with specific tags

## Considerations

- Processes are tracked in-memory using a singleton `BackgroundProcessManager`
- Output stream captures up to the last 100 lines of process output
- Processes can be in states: `pending`, `running`, `completed`, `failed`, `cancelled`
- Processes include detailed metadata: start/completion times, error tracking
- ALL processes are killed when OpenCode closes
- Processes generate unique IDs automatically if not specified

## Contributing

Contributions are welcome! Please file issues or submit pull requests on the GitHub repository.

## License

MIT License. See the [LICENSE](LICENSE) file for details.
