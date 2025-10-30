Configure the resource server
In this lab, you begin implementing authorization policy enforcement by coding it directly in the application. This includes the endpoints for MCP authentication discovery.

Authorization server discovery and token verification
The gist of the OAuth flow is that an authorization server issues tokens that give clients access to protected resources for a limited time.

The resource server has the responsibility of enforcing the authorization policy, by:

Checking that requests are accompanied by a JWT token.
Verifying the token's authenticity (by checking the signature of the token).
Verifying the token's expiration timestamp.
Verifying the token's audience scope matches the intended audience (echo-mcp-server).
In this section we begin implementing this enforcement by coding it directly in the application.

Instructions
Review the following updated application:

shell

copy

run
bat ~/data/steps/resource-server/main-with-auth.py


File: /root/data/steps/resource-server/main-with-auth.py
───────┼───────────────────────────────────────────────────────────────────────────────────────
   1 from typing import Annotated                                                                                                                             
  2 from fastmcp import FastMCP
  3 from fastmcp.server.auth import RemoteAuthProvider
  4 from fastmcp.server.auth.providers.jwt import JWTVerifier
  5 from pydantic import AnyHttpUrl, Field
  6 auth_provider = RemoteAuthProvider(
  7     token_verifier=JWTVerifier(
  8         jwks_uri="https://server.${_SANDBOX_ID}.instruqt.io:8443/realms/my-realm/protocol/openid-connect/certs",
  9         issuer="https://server.${_SANDBOX_ID}.instruqt.io:8443/realms/my-realm",
 10         audience="echo-mcp-server"
 11     ),
 12     authorization_servers=[AnyHttpUrl("https://server.${_SANDBOX_ID}.instruqt.io:8443/realms/my-realm")],
 13     base_url="https://server.${_SANDBOX_ID}.instruqt.io:8001"
 14 )
 15 mcp = FastMCP("MCP Echo Server", auth=auth_provider)
 16 @mcp.tool
 17 def echo(
 18         message: Annotated[str, "Message to echo"],
 19         repeat_count: Annotated[int, Field(description="Number of times to repeat the message", ge=1, le=10)] = 3
 20     ) -> str:
 21         """Echo a message a specified number of times."""
 22         return message * repeat_count
 23 if __name__ == "__main__":
 24     mcp.run(transport="http", host="0.0.0.0", port=8000)

  

The main difference from main.py is the construction of the FastMCP object with the auth provider auth_provider. Note how the jwks_uri, issuer, and audience match those of the authorization server provisioned in the previous section.

Copy the above main-with-auth.py script to your project:

bash

copy

run
envsubst < ~/data/steps/resource-server/main-with-auth.py > ./main-with-auth.py
Test it
Configure a two-panel layout for the terminal:

shell

copy

run
zellij --layout ~/data/steps/mcp-server/two-pane-layout.kdl
In the top panel, start the MCP server:

shell

copy

run
uv run main-with-auth.py
In the bottom panel, attempt to make an HTTP POST request to the /mcp endpoint:

shell

copy

run
curl -s -v -X POST http://localhost:8000/mcp
Here are the salient parts of the captured response:

shell

copy
* Host localhost:8000 was resolved.
* ...
* Established connection to localhost (127.0.0.1 port 8000) from 127.0.0.1 port 65521
* using HTTP/1.x
> POST /mcp HTTP/1.1
> Host: localhost:8000
> User-Agent: curl/8.16.0
> Accept: ..
>
* Request completely sent off
< HTTP/1.1 401 Unauthorized
< date: Wed, 15 Oct 2025 18:09:13 GMT
< server: uvicorn
< content-type: application/json
< content-length: 74
< www-authenticate: Bearer error="invalid_token", \
    error_description="Authentication required", \
    resource_metadata="https://server.9c7r8lg0pha6.instruqt.io:8001/.well-known/oauth-protected-resource"
<
* Connection #0 to host localhost:8000 left intact
{"error": "invalid_token", "error_description": "Authentication required"}
Above, note that we were not granted access to the resource, due to the absence of a valid access token in the request.

We get a 401 "Unauthorized" response. The interesting part is the presence of the response header www-authenticate, whose value includes the resource_metadata attribute which tells the client where to find the authorization server.

If we query that URL:

shell

copy

run
curl -s http://localhost:8000/.well-known/oauth-protected-resource/mcp | jq
We are indeed told where to find the authorization server:

json

copy
{
  "resource": "https://server.9c7r8lg0pha6.instruqt.io:8001/mcp",
  "authorization_servers": [
    "https://server.9c7r8lg0pha6.instruqt.io:8443/realms/my-realm"
  ],
  "scopes_supported": [],
  "bearer_methods_supported": [
    "header"
  ]
}
Note: Above, the field scopes_supported is empty because we didn't configure a list of valid scopes for the application.

Test the full OAuth flow
Caveats:

The MCP inspector cannot proxy OAuth flows like it does unauthenticated requests. Therefore, the MCP server URL can no longer be entered as http://localhost:8000; one must use the fully qualified URL http://server.9c7r8lg0pha6.instruqt.io:8000/mcp

To support a secure OAuth flow, the MCP server running on port 8000 is proxied over HTTPS on port 8001. The fully qualified URL therefore becomes: https://server.9c7r8lg0pha6.instruqt.io:8001/mcp

Visit MCP inspector.

In the form panel on the left:

Set the URL to https://server.9c7r8lg0pha6.instruqt.io:8001/mcp
Expand Authentication.
Set the Client ID to mcp-client.
Click Open Auth Settings (in the middle of the page).
The Authentication Settings page in the inspector provides a guided OAuth flow.

Metadata Discovery: click the Continue button. Expand the OAuth Metadata Sources. The inspector fetched the discovery endpoint and used it to introspect Keycloak's metadata to discover the endpoints for registration, authorization, and the token endpoint.
Client registration: since we're using a registered client mcp-client, no registration takes place. Click Continue
Preparing Authorization: This is where the client constructs the authorization URL. Follow the instructions: click the link to authorize in your browser. Log in to Keycloak using the realm user eitan (password test). An authorization code is presented. Copy it and paste it into the Authorization Code field. Click Continue
Token Request: Click Continue. The inspector will call the token endpoint with the supplied authorization code.
Authentication Complete: Expand Access Tokens to revel the access token obtained from the token endpoint. Feel free to use sites such as jwt.io to decode the access token and confirm that the audience scope is present in the token.
The full flow functions: Click Connect and confirm that you can still list tools and call the echo tool as before.

Disconnect from the MCP Server and terminate the application.

Summary
Congrats! Basic OAuth authorization is functioning.

But the solution is not ideal, in that the authorization enforcement concern is coupled to the application logic.

A better solution would be to separate those two responsibilities, which can be implemented with the aid of a proxy -- the subject of the next section.