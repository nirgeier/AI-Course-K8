Logo
MCP: from Zero to Production
Overview
Invite details
Raise hand
Show messages

Progress

Hide Instructions
1h, 30m
Refresh tab

View notes
Build an MCP Server
Begin by creating a simple MCP service with a single, simple "echo" tool.

Configure a two-panel layout for the terminal:

shell

copy

run
zellij --layout ~/data/steps/mcp-server/two-pane-layout.kdl
Create a project directory and navigate to it:

bash

copy

run
mkdir echo-mcp-server && cd echo-mcp-server
Initialize a python project:

bash

copy

run
uv init
We will use the fastmcp framework, so add the dependency:

bash

copy

run
uv add fastmcp
Review the following simple application that exposes a single "echo" tool:

shell

copy

run
bat ~/data/steps/mcp-server/main.py
Notes:

The function produces a string that repeats the given message a given number of times.
The MCP service is launched using the http transport on port 8000
Copy the above main.py script to your project, replacing the stub main.py previously produced by uv init:

bash

copy

run
cp ~/data/steps/mcp-server/main.py .
Test it
Launch the application:

shell

copy

run
uv run main.py
You should see the FastMCP banner come up.

Open the MCP Inspector tab.

In the Inspector's browser page, on the left hand side, specify:

Transport Type: Streamable HTTP
URL: http://localhost:8000/mcp
Click Connect.

The inspector will switch to the Connected state.

Select the tools tab from the header.
Click List Tools - the echo tool will display.
Select the echo tool.
Enter a message.
Click Run tool.
Validate the results.

The MCP inspector also provides a CLI as an alternative to the GUI.

Select the bottom panel and run the following command to list tools:

shell

copy

run
mcp-inspector --cli http://localhost:8000/mcp --transport http --method tools/list
Here is an example that calls the echo tool:

shell

copy

run
mcp-inspector --cli http://localhost:8000/mcp --method tools/call --tool-name echo --tool-arg message=hello
Once you are satisfied that the tool is functioning properly:

Disconnect the inspector once you are satisfied that the tool is functioning properly, and
Terminate the running MCP server (press Ctrl+C in the terminal).
Summary
We now have a basic MCP server. In the next step, we turn our attention to MCP authorization.


Skip

Next


Linux
Azure
K8s
Cyber Security (Pr)
Docker
giuthub