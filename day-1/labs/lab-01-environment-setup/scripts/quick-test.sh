#!/bin/bash

# quick-test.sh - Quick test of basic cluster functionality

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Quick Cluster Test ===${NC}"
echo ""

# Test 1: Create a test pod
echo -e "${YELLOW}Test 1: Creating test pod...${NC}"
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: test-pod
  namespace: default
spec:
  serviceAccountName: mcp-server
  containers:
  - name: nginx
    image: nginx:alpine
    ports:
    - containerPort: 80
EOF

echo -e "${GREEN}✓ Test pod created${NC}"
echo ""

# Wait for pod to be ready
echo -e "${YELLOW}Test 2: Waiting for pod to be ready...${NC}"
kubectl wait --for=condition=ready pod/test-pod --timeout=60s
echo -e "${GREEN}✓ Test pod is ready${NC}"
echo ""

# Test 3: Check pod with ServiceAccount
echo -e "${YELLOW}Test 3: Verifying pod is using mcp-server ServiceAccount...${NC}"
SA=$(kubectl get pod test-pod -o jsonpath='{.spec.serviceAccountName}')
if [ "$SA" == "mcp-server" ]; then
    echo -e "${GREEN}✓ Pod is using correct ServiceAccount: $SA${NC}"
else
    echo -e "${RED}✗ Pod is NOT using mcp-server ServiceAccount (using: $SA)${NC}"
fi
echo ""

# Test 4: Test network connectivity
echo -e "${YELLOW}Test 4: Testing network connectivity...${NC}"
kubectl exec test-pod -- wget -O- -q http://kubernetes.default.svc.cluster.local/healthz &> /dev/null
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Network connectivity working${NC}"
else
    echo -e "${YELLOW}⚠ Network connectivity test failed (this might be normal)${NC}"
fi
echo ""

# Test 5: Check monitoring endpoints
echo -e "${YELLOW}Test 5: Checking monitoring endpoints...${NC}"

# Check if Prometheus service exists
if kubectl get svc -n monitoring prometheus-kube-prometheus-prometheus &> /dev/null; then
    echo -e "${GREEN}✓ Prometheus service exists${NC}"
else
    echo -e "${YELLOW}⚠ Prometheus service not found${NC}"
fi

# Check if Grafana service exists
if kubectl get svc -n monitoring prometheus-grafana &> /dev/null; then
    echo -e "${GREEN}✓ Grafana service exists${NC}"
else
    echo -e "${YELLOW}⚠ Grafana service not found${NC}"
fi
echo ""

# Test 6: Create a test service
echo -e "${YELLOW}Test 6: Creating test service...${NC}"
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: test-service
  namespace: default
spec:
  selector:
    app: test-pod
  ports:
  - port: 80
    targetPort: 80
  type: ClusterIP
EOF

echo -e "${GREEN}✓ Test service created${NC}"
echo ""

# Display test resources
echo -e "${BLUE}Test resources created:${NC}"
kubectl get pod test-pod
kubectl get svc test-service
echo ""

# Cleanup
echo -e "${YELLOW}Cleaning up test resources...${NC}"
kubectl delete pod test-pod --grace-period=0 --force &> /dev/null || true
kubectl delete svc test-service &> /dev/null || true
echo -e "${GREEN}✓ Test resources cleaned up${NC}"
echo ""

echo -e "${GREEN}=== All quick tests completed! ===${NC}"
