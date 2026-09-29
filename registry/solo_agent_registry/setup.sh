#!/usr/bin/env bash
# Install, start, and stop open-source agentregistry on local Kubernetes.
# Usage:
#   bash registry/solo_agent_registry/setup.sh install
#   bash registry/solo_agent_registry/setup.sh start
#   bash registry/solo_agent_registry/setup.sh stop
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
RELEASE="agentregistry"
NAMESPACE="solo-agent-registry"
EXPECTED_CONTEXT="rancher-desktop"
CHART="oci://ghcr.io/agentregistry-dev/agentregistry/charts/agentregistry"
# Pin recorded at first install. Override with AGENTREGISTRY_CHART_VERSION.
CHART_VERSION="${AGENTREGISTRY_CHART_VERSION:-0.4.0}"
PID_FILE="${TMPDIR:-/tmp}/solo-agent-registry-port-forward.pid"
LOG_FILE="${TMPDIR:-/tmp}/solo-agent-registry-port-forward.log"
HTTP_PORT=12121
MCP_PORT=31313

usage() {
  cat <<EOF
Usage: bash registry/solo_agent_registry/setup.sh <install|start|stop>

  install  Helm-install the chart into namespace ${NAMESPACE}
  start    Scale the registry up and port-forward ${HTTP_PORT} and ${MCP_PORT}
  stop     Stop the port-forward and scale the registry to zero
EOF
}

require_kubectl() {
  if ! command -v kubectl >/dev/null 2>&1; then
    echo "kubectl is required." >&2
    exit 1
  fi
}

require_helm() {
  if ! command -v helm >/dev/null 2>&1; then
    echo "helm is required." >&2
    exit 1
  fi
}

require_context() {
  local context
  context="$(kubectl config current-context)"
  if [[ "$context" != "$EXPECTED_CONTEXT" ]]; then
    echo "Current kubectl context is '${context}'. Expected '${EXPECTED_CONTEXT}'." >&2
    echo "Switch context, or set the cluster you intend, then re-run." >&2
    exit 1
  fi
}

release_installed() {
  helm status "$RELEASE" -n "$NAMESPACE" >/dev/null 2>&1
}

install_arctl() {
  local installed_to_home_bin=0
  if command -v arctl >/dev/null 2>&1; then
    return 0
  fi

  echo "==> Installing arctl v${CHART_VERSION}"
  local installer
  installer="$(mktemp)"
  # Same upstream installer. raw.githubusercontent.com is often intercepted on
  # corporate networks, so fall back to the tagged copy on jsDelivr.
  if ! curl -fsSL --retry 3 --retry-delay 2 \
      "https://raw.githubusercontent.com/agentregistry-dev/agentregistry/v${CHART_VERSION}/scripts/get-arctl" \
      -o "$installer"; then
    echo "    raw.githubusercontent.com unavailable; using jsDelivr"
    curl -fsSL --retry 3 --retry-delay 2 \
      "https://cdn.jsdelivr.net/gh/agentregistry-dev/agentregistry@v${CHART_VERSION}/scripts/get-arctl" \
      -o "$installer"
  fi
  local arctl_args=(--version "v${CHART_VERSION}")
  if ! sudo -n true >/dev/null 2>&1; then
    arctl_args+=(--no-sudo)
    installed_to_home_bin=1
  fi
  # The installer checks `command -v arctl` after copying into ~/bin.
  export PATH="${HOME}/bin:/usr/local/bin:${PATH}"
  bash "$installer" "${arctl_args[@]}"
  rm -f "$installer"

  if [[ "$installed_to_home_bin" == 1 ]]; then
    echo "arctl is in ${HOME}/bin. Add it to your shell PATH:"
    echo "  export PATH=\"\${HOME}/bin:\${PATH}\""
  fi
}

install_registry() {
  require_kubectl
  require_helm
  require_context

  echo "==> Installing ${RELEASE} ${CHART_VERSION} into namespace ${NAMESPACE}"
  helm upgrade --install "$RELEASE" "$CHART" \
    --version "$CHART_VERSION" \
    --namespace "$NAMESPACE" \
    --create-namespace \
    --values "${ROOT}/values.yaml" \
    --wait \
    --timeout 10m

  echo "==> Waiting for pods"
  kubectl -n "$NAMESPACE" rollout status deploy/agentregistry --timeout=10m
  kubectl -n "$NAMESPACE" rollout status deploy/agentregistry-postgresql --timeout=10m
  kubectl -n "$NAMESPACE" get pods
  install_arctl
}

scale_workloads() {
  local replicas="$1"
  kubectl -n "$NAMESPACE" scale deploy/agentregistry --replicas="$replicas"
  kubectl -n "$NAMESPACE" scale deploy/agentregistry-postgresql --replicas="$replicas"
  if [[ "$replicas" != "0" ]]; then
    kubectl -n "$NAMESPACE" rollout status deploy/agentregistry-postgresql --timeout=10m
    kubectl -n "$NAMESPACE" rollout status deploy/agentregistry --timeout=10m
  fi
}

port_forward_pids() {
  pgrep -f "kubectl -n ${NAMESPACE} port-forward svc/${RELEASE} " || true
}

start_port_forward() {
  local existing
  existing="$(port_forward_pids)"
  if [[ -n "$existing" ]]; then
    echo "Port-forward already running (pid ${existing//$'\n'/, })"
    return 0
  fi

  echo "==> Port-forwarding ${HTTP_PORT} and ${MCP_PORT}"
  nohup kubectl -n "$NAMESPACE" port-forward "svc/${RELEASE}" \
    "${HTTP_PORT}:${HTTP_PORT}" "${MCP_PORT}:${MCP_PORT}" \
    >"$LOG_FILE" 2>&1 &
  echo $! >"$PID_FILE"

  local _
  for _ in $(seq 1 40); do
    if curl -sf -o /dev/null "http://127.0.0.1:${HTTP_PORT}/"; then
      return 0
    fi
    sleep 0.5
  done

  echo "Port-forward did not become ready. See ${LOG_FILE}" >&2
  exit 1
}

stop_port_forward() {
  local pid
  if [[ -f "$PID_FILE" ]]; then
    pid="$(cat "$PID_FILE")"
    if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
      kill "$pid" 2>/dev/null || true
    fi
    rm -f "$PID_FILE"
  fi

  local existing
  existing="$(port_forward_pids)"
  if [[ -n "$existing" ]]; then
    # shellcheck disable=SC2086
    kill $existing 2>/dev/null || true
  fi
}

cmd_install() {
  install_registry
  echo ""
  echo "Registry is installed in namespace ${NAMESPACE}."
  echo "Start it with:"
  echo "  bash registry/solo_agent_registry/setup.sh start"
}

cmd_start() {
  require_kubectl
  require_helm
  require_context

  if ! release_installed; then
    install_registry
  else
    echo "==> Starting ${RELEASE} in namespace ${NAMESPACE}"
    scale_workloads 1
    kubectl -n "$NAMESPACE" get pods
  fi

  start_port_forward
  echo ""
  echo "Registry is up: http://localhost:${HTTP_PORT}"
  echo "MCP port: localhost:${MCP_PORT}"
  echo "Stop it with:"
  echo "  bash registry/solo_agent_registry/setup.sh stop"
}

cmd_stop() {
  require_kubectl
  require_context

  echo "==> Stopping port-forward"
  stop_port_forward

  if kubectl get namespace "$NAMESPACE" >/dev/null 2>&1 && release_installed; then
    echo "==> Scaling ${RELEASE} to zero"
    scale_workloads 0
  fi

  echo "Registry is stopped. The Helm release and Postgres volume are still in ${NAMESPACE}."
  echo "Start it again with:"
  echo "  bash registry/solo_agent_registry/setup.sh start"
}

case "${1:-install}" in
  install) cmd_install ;;
  start) cmd_start ;;
  stop) cmd_stop ;;
  -h|--help|help) usage ;;
  *)
    usage >&2
    exit 1
    ;;
esac
