Enterprise Single sign-on (SSO)

MCP servers need to function in the context of enterprise single sign-on, where employees present a JWT token bearing their claims.

In this lab, you will revise the gateway's configuration to verify enterprise-issued JWT tokens.

Validate enterprise issued JWT tokens
In enterprises, employees log in to multiple workplace applications with a single set of credentials.

Employees will already bear a JWT token in the requests they make.

For our MCP server to work in that context, we can revise the gateway's configuration to verify the enterprise-issued JWT token.

agentgateway supports JWT Authentication, which resembles our previous configuration, in that token verification still involves an issuer, an audience, and a jwks URL.

Let us demonstrate how this works.

JWT Authentication
Use the step CLI to generate a key pair:

bash

copy

run
step crypto jwk create pub-key priv-key --no-password --insecure
Press enter when prompted for a password to protect the key.

Next, generate the JSON Web Key:

bash

copy

run
cat pub-key | step crypto jwk keyset add jwks-keyset
Generate and sign a JWT token, with a specified issuer and audience:

bash

copy

run
step crypto jwt sign --key priv-key \
  --iss "acme@example.com" --aud="mcp.example.com" \
  --sub "jsmith" --exp $(date -d "10 years" +"%s") > jsmith.token
Capture the token in the environment variable JWT:

shell

copy

run
export JWT=$(cat jsmith.token)
Review the following agentgateway configuration, which requires a valid JWT token to access the MCP server:

shell

copy

run
bat ~/data/steps/jwt-and-authz/ag-jwtauth-config.yaml

```
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
        jwtAuth:
          mode: strict
          issuer: "acme@example.com"
          audiences: [mcp.example.com]
          jwks:
            file: ./jwks-keyset
      backends:
      - mcp:
          targets:
          - name: mcp
            mcp:
              host: http://localhost:8000/mcp
```


Copy the above ag-jwtauth-config.yaml script to your project:

bash

copy

run
cp ~/data/steps/jwt-and-authz/ag-jwtauth-config.yaml .
Test it
Configure a three-panel layout for the terminal:

shell

copy

run
zellij --layout ~/data/steps/agentgateway/three-pane-layout.kdl
In the top panel, run the basic MCP server:

shell

copy

run
uv run main.py
In the middle panel, start the agentgateway:

shell

copy

run
./agentgateway -f ag-jwtauth-config.yaml
From the bottom panel, attempt to list tools:

shell

copy

run
mcp-inspector --cli http://localhost:9000/mcp --transport http --method tools/list
The request will fail.

A line in the agentgateway logs confirms that the request was denied due to the absence of a bearer token:

shell

copy
2025-10-17T18:00:57.855104Z     info    request gateway=bind/9000 listener=listener0 \
  route_rule=route0/default route=route0 src.addr=[::1]:63358 http.method=POST \
  http.host=localhost http.path=/mcp http.version=HTTP/1.1 \
  http.status=403 protocol=http error="authentication failure: no bearer token found" duration=0ms
Try again, this time including the JWT token in the request headers:

shell

copy

run
mcp-inspector --cli http://localhost:9000/mcp --transport http --method tools/list --header "Authorization: Bearer $JWT"
Terminate agentgateway (middle pane, Ctrl+C).

MCP Authorization
agentgateway supports configuring authorization policy for MCP requests and gives us access to MCP-specific metadata, such as the tool name being invoked. We also get information from the JWT token, such as claims.

The following gateway configuration adds an MCP authorization policy which requires the user to have administrative privileges (role claim contains "admin") in order to access the echo tool:

shell

copy

run
bat ~/data/steps/jwt-and-authz/ag-mcp-authorization.yaml

```
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
        jwtAuth:
          mode: strict
          issuer: "acme@example.com"
          audiences: [mcp.example.com]
          jwks:
            file: ./jwks-keyset
        mcpAuthorization:
          rules:
          - 'mcp.tool.name == "echo" && "admin" in jwt.roles'
      backends:
      - mcp:
          targets:
          - name: mcp
            mcp:
              host: http://localhost:8000/mcp
```

Copy the above ag-mcp-authorization.yaml script to your project:

bash

copy

run
cp ~/data/steps/jwt-and-authz/ag-mcp-authorization.yaml .

root@server:~# cat ~/data/steps/jwt-and-authz/ag-mcp-authorization.yaml
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
        jwtAuth:
          mode: strict
          issuer: "acme@example.com"
          audiences: [mcp.example.com]
          jwks:
            file: ./jwks-keyset
        mcpAuthorization:
          rules:
          - 'mcp.tool.name == "echo" && "admin" in jwt.roles'
      backends:
      - mcp:
          targets:
          - name: mcp
            mcp:
              host: http://localhost:8000/mcp

              
Restart the agentgateway with the authorization configuration:

shell

copy

run
./agentgateway -f ag-mcp-authorization.yaml
Attempt to list tools again:

shell

copy

run
mcp-inspector --cli http://localhost:9000/mcp --transport http --method tools/list --header "Authorization: Bearer $JWT"
The connection is permitted, but the list of tools is empty.

Generate a second JWT, this time for an admin user:

bash

copy

run
echo '{ "roles": ["admin"] }' | \
  step crypto jwt sign --key priv-key \
    --iss "acme@example.com" --aud="mcp.example.com" \
    --sub "pointy-haired-boss" --exp $(date -d "10 years" +"%s") > boss.token
Capture the token in the environment variable ADMIN_JWT:

shell

copy

run
export ADMIN_JWT=$(cat boss.token)
Attempt to list tools using the admin token:

shell

copy

run
mcp-inspector --cli http://localhost:9000/mcp --transport http --method tools/list --header "Authorization: Bearer $ADMIN_JWT"
The echo tool will be present this time since this user is allowed to call it.


Skip