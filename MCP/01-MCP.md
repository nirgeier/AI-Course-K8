# Build an MCP Server

* Begin by creating a simple MCP service with a single, simple "echo" tool.

## 01. Set up the project

* Ensure you have followed the [MCP Inspector setup instructions](./00-MCP-Inspector.md) to have the MCP Inspector ready.

* 
  ```bash
  # 01. Create a project directory and navigate to it:
  mkdir echo-mcp-server && cd echo-mcp-server
  
  # 02. Create and activate a Python virtual environment:
  python3 -m venv venv
  source venv/bin/activate
  
  # 03. Start Zellij with the provided layout file:
  zellij --layout=zellij-layout.kdl

  # 04. Initialize a new UV project:
  uv init
  
  # 05. Add the fastmcp dependency
  uv add fastmcp


## 04. Implement the MCP server

* Review the following simple application that exposes a single "echo" tool:
* Copy this code to your project as `main.py`. 
  
```python
# main.py
# This is the main entry point for the echo-mcp-server.

# Import necessary modules
from typing import Annotated
from fastmcp import MCPServer, MCPRequest, MCPResponse
from pydantic import Field

# Define the MCP server behavior
mcp = FastMCP("CodeWizard Echo Server Lab", version="1.0.0")

# Define an echo tool
@mcp.tool
def echo(
    message: Annotated[str, "Message to echo"],
    repeat_count: Annotated[int, Field(description="Number of times to repeat the message", ge=1, le=10)] = 3
) -> str:
    """Echo a message a specified number of times."""
    return message * repeat_count

# Main function to run the server
# Run the MCP server
if __name__ == "__main__":
    mcp.run(transport="http", host="0.0.0.0", port=8000)
```

**Notes:**

- The function produces a string that repeats the given message a given number of times.
- The MCP service is launched using the HTTP transport on port 8000.

## 05. Test the MCP server

* Start the MCP server:
  ```bash
  uv run main.py
  ```

You should see the FastMCP banner come up.

### Using the MCP Inspector GUI

1. Open the MCP Inspector tab.
2. In the Inspector's browser page, on the left hand side, specify:
   - **Transport Type:** Streamable HTTP
   - **URL:** `http://localhost:8000/mcp`
3. Click **Connect**.
4. The inspector will switch to the Connected state.
5. Select the **tools** tab from the header.
6. Click **List Tools** - the echo tool will display.
7. Select the echo tool.
8. Enter a message.
9. Click **Run tool**.
10. Validate the results.

### Using the MCP Inspector CLI

The MCP inspector also provides a CLI as an alternative to the GUI.

Select the bottom panel and run the following command to list tools:

```bash
mcp-inspector --cli http://localhost:8000/mcp --transport http --method tools/list
```

Here is an example that calls the echo tool:

```bash
mcp-inspector --cli http://localhost:8000/mcp --method tools/call --tool-name echo --tool-arg message=hello
```

### Cleanup

Once you are satisfied that the tool is functioning properly:

1. Disconnect the inspector.
2. Terminate the running MCP server (press `Ctrl+C` in the terminal).

## Summary

We now have a basic MCP server. In the next step, we turn our attention to MCP authorization.

