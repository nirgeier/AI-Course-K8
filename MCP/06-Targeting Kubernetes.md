In this final activity, you will learn about kmcp, a tool designed to aid with the end-to-end process of authoring, packaging, and deploying MCP servers to Kubernetes.


Learn to build and deploy an MCP server to Kubernetes
Activities so far have run MCP servers on a local machine. This is useful when developing.

In this final activity, you will learn about kmcp, (a part of the kagent project) a tool designed specifically to aid with the end-to-end process, from scaffolding a new project, to building a Docker image, to deploying the MCP server to Kubernetes.

Install the kmcp CLI

bash

copy

run
curl -fsSL https://raw.githubusercontent.com/kagent-dev/kmcp/refs/heads/main/scripts/get-kmcp.sh | bash
A Kubernetes cluster is running.

Deploy the kmcp CRDs:

bash

copy

run
helm install kmcp-crds oci://ghcr.io/kagent-dev/kmcp/helm/kmcp-crds \
  --namespace kmcp-system \
  --create-namespace
Run kmcp install to deploy the Kubernetes controller:

bash

copy

run
kmcp install
Scaffolding
kmcp supports multiple target frameworks: go, python, java, and typescript.

shell

copy

run
kmcp init --help
Start a new python project:

bash

copy

run
kmcp init python my-mcp-server --description "My first mcp server" --non-interactive \
  && cd my-mcp-server
Inspect the project directory structure:

shell

copy

run
tree .
An example echo tool is present by default. It's easy to add more tools by adding more .py files to the tools/ subdirectory.

The kmcp CLI provides a convenient run command for local testing with the MCP inspector, which is launched automatically.

Build and Package
The kmcp build command simplifies building and packaging the MCP server:

shell

copy

run
kmcp build --help
Building the MCP server produces a Docker image:

bash

copy

run
kmcp build --tag my-mcp-server:latest
Next, we can publish the container image to a registry.

Here let's simply upload the image to the cluster:

bash

copy

run
k3d image import my-mcp-server --cluster my-k8s-cluster
Deploy
Finally, deploy the MCP server to the cluster:

bash

copy

run
kmcp deploy --file kmcp.yaml --image my-mcp-server:latest --no-inspector
Deployment generates and applies an MCPServer resource to the cluster:

shell

copy

run
kubectl get mcpserver my-mcp-server -o yaml | bat -l yaml
The kmcp controller watches for MCPServer resources and creates (and applies) the deployment manifest for us:

shell

copy

run
kubectl get pod
Configure a two-panel layout for the terminal:

shell

copy

run
zellij --layout ~/data/steps/mcp-server/two-pane-layout.kdl
In the top panel, port-forward the my-mcp-server service running on port 3000 in the cluster so that we can connect to it from the inspector.

shell

copy

run
kubectl port-forward svc/my-mcp-server 3000
In the bottom panel, test the tool with the MCP inspector CLI.

List tools:

shell

copy

run
mcp-inspector --cli http://localhost:3000/mcp --transport http --method tools/list
Call the echo tool:

shell

copy

run
mcp-inspector --cli http://localhost:3000/mcp --method tools/call --tool-name echo --tool-arg message=hello
Summary
Congratulations! Your MCP server is now running on Kubernetes.

The story does not end here.

Agentgateway is supported in Kubernetes by the kgateway project, a control plane that can dynamically program agentgateway using cloud-native APIs such as the Kubernetes Gateway API and AI extensions.

With kgateway, we can deploy an agentgateway proxy for our MCP server and configure it to route requests to the MCP server, with MCP authorization and other policies. See Christian Posta and Lin Sun's upcoming ebook AI Agents in Kubernetes for more information.