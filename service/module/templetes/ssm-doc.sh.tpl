#!/bin/bash
#set -x
set -euo pipefail

printf '%s\n' "Starting SSM document execution..."

# CHANGED: safer cd with explicit failure handling
cd /home/ssm-user || exit 1

# helper to check command exit status
_check_exit() {
  local rc="$1"
  local cmd="$2"
  if [ "$rc" -ne 0 ]; then
    printf '%s\n' "Error: command failed: $cmd (exit code $rc)" >&2
    exit "$rc"
  fi
}

TOKEN=$(curl -sf -X PUT "http://169.254.169.254/latest/api/token" \
  -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
_check_exit $? "curl -X PUT http://169.254.169.254/latest/api/token"

if [ -z "$TOKEN" ]; then
  printf '%s\n' "ERROR: Failed to retrieve IMDSv2 token." >&2
  exit 1
fi

REGION=$(curl -sf -H "X-aws-ec2-metadata-token: $TOKEN" \
  "http://169.254.169.254/latest/meta-data/placement/region")
_check_exit $? "curl http://169.254.169.254/latest/meta-data/placement/region"

if [ -z "$REGION" ]; then
  printf '%s\n' "ERROR: Failed to retrieve region from instance metadata." >&2
  exit 1
fi

printf '%s\n' "Region: $REGION"

function getClusters() {
  printf '%s\n' "Fetching EKS clusters from $REGION ..."
  # Use AWS CLI and parse cluster names — same logic as reference script
  local tmp_output
  tmp_output=$(aws eks list-clusters --region "$REGION" --query 'clusters[]' --output text)
  _check_exit $? "aws eks list-clusters --region $REGION"

  # Split tab/newline separated output into array
  IFS=$'\t\n' read -d '' -r -a clusters <<< "$tmp_output" || true
}

function getContexts() {
  # capture kubectl output and check exit code before processing
  local kubectl_out
  kubectl_out=$(kubectl config get-contexts --no-headers 2>/dev/null)
  local rc_kubectl=$?
  _check_exit $rc_kubectl "kubectl config get-contexts --no-headers"

  # Extract context names (column 2) — same as reference script
  local names
  names=$(printf '%s\n' "$kubectl_out" | tr -s ' ' | cut -d ' ' -f 2)
  IFS=$'\n' read -d '' -r -a k8names <<< "$names" || true
}

getClusters

if [ ${#clusters[@]} -eq 0 ]; then
  printf '%s\n' "No EKS clusters found to process."
  exit 1
fi

printf '%s\n' "Found ${#clusters[@]} cluster(s): ${clusters[*]}"

export KUBECONFIG=/home/ssm-user/.kube/config

for cluster in "${clusters[@]}"; do
  printf '%s\n' "$cluster" | sed 's/^/#EKS-NAME#/'
  printf '%s\n' "Updating kubeconfig for cluster: $cluster"
  aws eks update-kubeconfig --name "$cluster" --region "$REGION"
  _check_exit $? "aws eks update-kubeconfig --name $cluster --region $REGION"
done

getContexts

if [ ${#k8names[@]} -eq 0 ]; then
  printf '%s\n' "ERROR: No kubectl contexts found after updating kubeconfig." >&2
  exit 1
fi

printf '%s\n' "Outputting ${#k8names[@]} cluster ARN(s) for ServiceNow..."

for ctx in "${k8names[@]}"; do
  printf '%s\n' "$ctx" | sed 's/^/#EKS-ARN#/'
done

printf '%s\n' "Done."
kubectl config view
rc_kubectl=${PIPESTATUS[0]:-$?}
_check_exit $rc_kubectl "kubectl config view"

printf '%s\n' "SSM document execution completed successfully."