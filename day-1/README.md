# Day 1: Foundational MCP Development

## Module 1: Understanding MCP and Kagent Fundamentals

**Duration**: Full Day (8 hours)  
**Focus**: 25% Lecture, 75% Hands-On Labs

## Objectives

By the end of Day 1, you will:

- ✅ Understand the MCP protocol and its role in AI agent interaction
- ✅ Master Kagent architecture and core components
- ✅ Set up a complete development environment
- ✅ Build and deploy your first MCP server
- ✅ Implement foundational metrics collection

## Schedule

| Time | Activity | Duration |
|------|----------|----------|
| 09:00-10:30 | **Lecture**: MCP Protocol & Kagent Architecture | 1.5 hours |
| 10:30-10:45 | Break | 15 min |
| 10:45-12:45 | **Lab 1**: Environment Setup | 2 hours |
| 12:45-13:45 | Lunch | 1 hour |
| 13:45-16:45 | **Lab 2**: Building Your First MCP Server | 3 hours |
| 16:45-17:00 | Break | 15 min |
| 17:00-19:30 | **Lab 3**: Foundational Metrics Collection | 2.5 hours |

## Lectures

### 1. MCP Protocol Foundation (45 min)

**Topics Covered**:
- What is the Model Context Protocol (MCP)?
- MCP's role in AI agent interaction
- JSON-RPC 2.0 foundation and transport layers
- Client-server architecture and bidirectional communication
- MCP capabilities: resources, tools, and prompts
- Message types: requests, responses, and notifications

📖 [Lecture Slides](./lectures/01-mcp-protocol-foundation.md)

### 2. Kagent Architecture Deep Dive (45 min)

**Topics Covered**:
- Core architecture of Kagent framework
- Relationship between Tools, Agents, and MCP Framework
- Agent lifecycle management and state persistence
- Tool registration, discovery, and execution patterns
- Security boundaries and permission models
- Scalability considerations for multi-agent environments

📖 [Lecture Slides](./lectures/02-kagent-architecture.md)

### 3. Development vs Production Environments (15 min)

**Topics Covered**:
- kmcp CLI for local development
- Kubernetes Controller for production
- Development workflow patterns and debugging strategies
- Configuration management across environments
- Deployment pipelines and GitOps integration
- Monitoring and observability requirements

📖 Slides provided in-session (refer to instructor deck)

### 4. Cloud-Native Use Cases & Integration (15 min)

**Topics Covered**:
- Practical use cases in cloud-native environments
- Automated operations: scaling, healing, optimization
- Intelligent troubleshooting and root cause analysis
- Cost optimization through AI-driven resource management
- Compliance and security automation
- Integration with CNCF ecosystem tools

📖 Slides provided in-session (refer to instructor deck)

## Labs

### Lab 1: Comprehensive Environment Setup (2 hours)

**Objectives**:
- Install and configure all required development tools
- Set up local Kubernetes cluster
- Configure monitoring stack
- Verify connectivity and permissions

**Prerequisites**:
- macOS, Linux, or Windows with WSL2
- Admin/sudo access
- Internet connectivity

📝 [Lab Instructions](./labs/lab-01-environment-setup/README.md)

**Deliverables**:
- ✅ Working kind cluster
- ✅ kubectl configured and operational
- ✅ kmcp CLI installed and authenticated
- ✅ Prometheus and Grafana running
- ✅ IDE configured with MCP extensions

### Lab 2: Building Your First MCP Server (3 hours)

**Objectives**:
- Initialize a new MCP server project
- Implement a "Hello World" tool
- Add error handling and logging
- Test the server locally
- Package as a container image

**Prerequisites**:
- Completed Lab 1
- Basic Python or Go knowledge

📝 [Lab Instructions](./labs/lab-02-first-mcp-server/README.md)

**Deliverables**:
- ✅ Working MCP server with custom tool
- ✅ Unit tests passing
- ✅ Container image built and tagged
- ✅ Local deployment verified

### Lab 3: Foundational Metrics Collection Implementation (2.5 hours)

**Objectives**:
- Design custom metrics for MCP server performance
- Create Prometheus-compatible endpoints
- Configure metric scraping
- Build Grafana dashboards
- Implement basic alerting

**Prerequisites**:
- Completed Lab 2
- Understanding of Prometheus metrics

📝 [Lab Instructions](./labs/lab-03-metrics-collection/README.md)

**Deliverables**:
- ✅ Prometheus metrics endpoint
- ✅ Metrics being scraped and stored
- ✅ Grafana dashboard showing MCP server metrics
- ✅ Basic alert rules configured

## Resources

### Code Examples

- [Simple MCP Server Template](../resources/templates/simple-mcp-server/README.md)

### Reference Materials

- [Best Practices](../docs/best-practices.md)
- [Troubleshooting Guide](../docs/troubleshooting.md)

### Troubleshooting

- [Course-Wide Troubleshooting](../docs/troubleshooting.md)

## Verification Checklist

Before proceeding to Day 2, ensure you have:

- [ ] Complete working development environment
- [ ] Successfully built and deployed an MCP server
- [ ] Implemented at least one custom tool
- [ ] Metrics being collected and visualized
- [ ] Understanding of MCP protocol basics
- [ ] Familiarity with Kagent architecture

## Next Steps

Once you've completed Day 1:

1. Review your code and ensure all tests pass
2. Explore the additional examples provided
3. Read ahead on [Day 2 topics](../day-2/README.md)
4. Optional: Try implementing an additional custom tool

---

**Need Help?** Check the [troubleshooting guide](./troubleshooting/debug-guide.md) or ask your instructor.

➡️ **Continue to**: [Day 2: Advanced Features & Customization](../day-2/README.md)
