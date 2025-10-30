MCP authorization
In this lab, you will provision and familiarize yourself with Keycloak, an open-source project for identity and access management, that will act as your authorization server and identity provider (IdP).



Provision and configure the authorization server
We wish to control access to (or otherwise protect) our MCP server.

OAuth2 is an established authorization framework designed for this purpose. The main actors in OAuth2 flows are the authorization server, the resource server, the client, and the resource owner (a user).

In the context of this workshop, the MCP server you just built becomes the resource server, whose responsibility it becomes to validate access tokens presented by clients requesting access to resources. When you tested your MCP server in the last section, the MCP inspector played the part of the client.

In this section, you will provision and familiarize yourself with Keycloak, an open-source project for identity and access management, that will act as your authorization server and identity provider (IdP).

Provision Keycloak
In the spirit of doing this simplest thing that will work, run Keycloak with Docker, as follows:

bash

copy

run
docker run -d --name keycloak -p 8080:8080 -p 8443:8443 \
  -e KC_BOOTSTRAP_ADMIN_USERNAME=admin \
  -e KC_BOOTSTRAP_ADMIN_PASSWORD=admin \
  -v ~/data/steps/auth-server/keycloak/ssl:/opt/keycloak/ssl:ro \
  -v ~/data/steps/auth-server/keycloak-seed:/opt/keycloak/data/import:ro \
  quay.io/keycloak/keycloak:26.4.1 start-dev --import-realm \
    --hostname "server.${_SANDBOX_ID}.instruqt.io" --https-certificate-file=/opt/keycloak/ssl/server.cert --https-certificate-key-file=/opt/keycloak/ssl/server.key
Explanation:

We name the container keycloak, for easy reference.
Set the admin username and password to admin/admin.
start-dev starts Keycloak in development mode (suitable for sandbox environments and learning).
The folder keycloak-seed is mounted to the Keycloak data import conventional location for importing configuration.
The --import-realm flag ensures that a configuration file is imported on start.
We configure the Keycloak server with a TLS certificate so that it runs securely.
Keycloak has the concept of a realm -- a logical grouping of users, applications, and identity-related configurations.

The configuration you just imported consists of:

A realm named my-realm.
A pre-configured user: eitan/test.
A client named mcp-client.
A client scope named mcp:tools that configures the token's audience to echo-mcp-server.
Optional scopes can be additionally configured to support different levels of authorization, though none are defined by default.

Review the Keycloak configuration
Tail the Keycloak logs and make sure that the service has started:

shell

copy

```bash
docker logs keycloak --follow
```
With Keycloak up and running, visit the Keycloak tab to view its web user interface.

Log in as administrator using the above cited "admin" credentials.
Click "Manage realms" and select the realm named my-realm to render it the "current" realm.
Select "Users" and verify that a user named "eitan" is predefined.
Select "Clients" and note that the client mcp-client is predefined.
Select "Client scopes", and the scope named mcp:tools, note under "Mappers" the mapper named echo-mcp-server which configures the audience for the token.
Summary
Great! That should be all we need to implement the authorization server.

We now have the following pieces of information, which will be used in the next step to configure the resource server to validate tokens presented by clients:

audience: echo-mcp-server
issuer: https://server.9c7r8lg0pha6.instruqt.io:8443/realms/my-realm
jwks URI: https://server.9c7r8lg0pha6.instruqt.io:8443/realms/my-realm/protocol/openid-connect/certs
The audience represents the intended audience for the token, and to disambiguate these tokens from ones relevant in the context of other applications and resources.

The token issuer is the URL of the realm my-realm in Keycloak.

The jwks URI is where the resource server goes to fetch a copy of the public key needed to verify the validity of token signatures.