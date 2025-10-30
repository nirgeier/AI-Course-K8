Proxy the MCP Server
In this lab, you will move security policy configuration and enforcement out of the application and into a proxy: agentgateway.



Configure MCP authentication in a proxy
In the previous section you configured an authenticated MCP server by using FastMCP's built-in authentication support.

In a production setting, we are much better off separating the concern of implementing the MCP server's functionality from that of configuring authorization (or any other cross-cutting concern beyond security, such as observability, for example).

In this exercise, security policy configuration and enforcement is moved out of the application and into a proxy.

agentgateway
agentgateway is a modern proxy that supports modern AI protocols including MCP and A2A.

Install agentgateway
Install the agentgateway binary to your project directory:

shell

copy

```
export AGENTGATEWAY_INSTALL_DIR=. && curl https://raw.githubusercontent.com/agentgateway/agentgateway/refs/heads/main/common/scripts/get-agentgateway | bash
```
## Proxy the MCP server
The documentation provides an example for configuring and running the gateway to route requests to an MCP backend.

Let's give it a try to understand how this works.

Configure a three-panel layout for the terminal:

```shell
zellij --layout ~/data/steps/agentgateway/three-pane-layout.kdl
In the top panel, run the basic MCP server:
uv run main.py
```
Select the middle panel.

Review the following agentgateway configuration file:

shell

copy

run
bat ~/data/steps/agentgateway/ag-config.yaml
Above, we configure agentgateway to listen on port 9000, and to route all requests (with a liberal CORS policy) to our MCP backend listening on port 8000.

Copy the above ag-config.yaml script to your project:

  1 binds:
  2 - port: 9000
  3   listeners:
  4   - routes:
  5     - policies:
  6         cors:
  7           allowOrigins:
  8           - "*"
  9           allowHeaders:
 10           - "*"
 11       backends:
 12       - mcp:
 13           targets:
 14           - name: mcp
 15             mcp:
 16               host: http://localhost:8000/mcp

run
cp ~/data/steps/agentgateway/ag-config.yaml .


```
binds:                                                                                                                                                   
  2 - port: 9000
  3   listeners:
  4   - routes:
  5     - policies:
  6         cors:
  7           allowOrigins:
  8           - "*"
  9           allowHeaders:
 10           - "*"
 11         mcpAuthentication:
 12           issuer: https://server.${_SANDBOX_ID}.instruqt.io:8443/realms/my-realm
 13           jwksUrl: https://server.${_SANDBOX_ID}.instruqt.io:8443/realms/my-realm/protocol/openid-connect/certs
 14           audience: echo-mcp-server
 15           resourceMetadata:
 16             resource: https://server.${_SANDBOX_ID}.instruqt.io:9001/mcp
 17             scopesSupported:
 18             - openid
 19             bearerMethodsSupported:
 20             - header
 21       backends:
 22       - mcp:
 23           targets:
 24           - name: mcp
 25             mcp:
 26               host: http://localhost:8000/mcp
```

Test it
Start the agentgateway:

shell

copy

run
./agentgateway -f ag-config.yaml
Select the bottom panel and list tools, noting that we're targeting the proxy on port 9000:

shell

copy

run
mcp-inspector --cli http://localhost:9000/mcp --transport http --method tools/list
Inspect the agentgateway console logs for evidence that requests are indeed routed via the proxy.

Call the echo tool:

shell

copy

run
mcp-inspector --cli http://localhost:9000/mcp --method tools/call --tool-name echo --tool-arg message=hello
Alternatively:

Visit the MCP inspector tab.
Point the URL field to the agentgateway proxy running on port 9000: http://localhost:9000/mcp
Click Connect and confirm that everything works, as if we were communicating directly with the MCP server.
Terminate the agentgateway (press Ctrl+C).

Configure authentication
The project documentation provides an example for configuring MCP authentication directly on the proxy.

Review the updated agentgateway configuration file:

shell

copy

run
bat ~/data/steps/agentgateway/ag-oauth-config.yaml

binds:
- port: 9000
  listeners:
  - routes:
    - policies:
        cors:
          allowOrigins:
          - "*"
          allowHeaders:
          - "*"
        mcpAuthentication:
          issuer: https://server.${_SANDBOX_ID}.instruqt.io:8443/realms/my-realm
          jwksUrl: https://server.${_SANDBOX_ID}.instruqt.io:8443/realms/my-realm/protocol/openid-connect/certs
          audience: echo-mcp-server
          resourceMetadata:
            resource: https://server.${_SANDBOX_ID}.instruqt.io:9001/mcp
            scopesSupported:
            - openid
            bearerMethodsSupported:
            - header
      backends:
      - mcp:
          targets:
          - name: mcp
            mcp:
              host: http://localhost:8000/mcp


Above, note that the configuration utilizes the same issuer, jwksUrl, and audience field values for the authorization server.

Copy the above ag-oauth-config.yaml script to your project:

bash

copy

run
envsubst < ~/data/steps/agentgateway/ag-oauth-config.yaml > ./ag-oauth-config.yaml
Test it
The same caveats for the OAuth flow apply here:

The MCP inspector cannot proxy OAuth flows like it does unauthenticated requests. Therefore, the MCP server URL can no longer be entered as http://localhost:9000; one must use the fully qualified URL http://server.9c7r8lg0pha6.instruqt.io:9000/mcp

To support a secure OAuth flow, the MCP server running on port 9000 is proxied over HTTPS on port 9001. The fully qualified URL therefore becomes: https://server.9c7r8lg0pha6.instruqt.io:9001/mcp

If it's not already running (top panel), start the basic, unprotected MCP server:

shell

copy

run
uv run main.py


In the middle panel, start the agentgateway:

shell

copy

run
./agentgateway -f ag-oauth-config.yaml
Finally, visit the MCP Inspector.

This MCP server should be protected.

Start by walking through the Guided OAuth flow:

Point the URL field to the agentgateway proxy running on port 9000: https://server.9c7r8lg0pha6.instruqt.io:9001/mcp
Expand Authentication.
Set the Client ID to mcp-client.
Then:

Click Open Auth Settings in the center of the page.
Click Guided OAuth Flow.
Like before, go through all steps from Metadata Discovery through to Token request.
When instructed to follow the authorization URL, log in with the user credentials eitan/test.
Copy and paste the authorization code into the corresponding field.
When the authentication completes, we have been issued a token.

Proceed to click Connect on the left hand panel, and to confirm that interaction with the MCP server continues to function as before: Tools -> List Tools -> Echo -> Run Tool.

Once satisfied, Disconnect from the MCP server.

Summary
Congratulations! You now have a flexible configuration: an MCP server fronted by an intelligent proxy where MCP authentication is configured.

