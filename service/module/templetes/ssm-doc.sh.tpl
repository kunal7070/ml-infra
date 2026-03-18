#!/bin/bash
set -euo pipefail

printf '%s\n' "starting SSM document execution..."
cd /home/ssm-user || exit 1
export KUBECONFIG=/home/ssm-user/.kube/config

_check_exit() {
  local rc="$1"
  local cmd="$2"
  if [ "$rc" -ne 0 ]; then
    printf '%s\n' "Error: command failed: $cmd (exit code $rc)" >&2
    exit "$rc"
  fi
}

TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
_check_exit $? "get IMDSv2 token"

REGION=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/placement/region)
_check_exit $? "get instance region"

get_clusters() {
  local configured_file="/opt/servicenow/eks-clusters.txt"

  if [ -f "$configured_file" ] && [ -s "$configured_file" ]; then
    mapfile -t clusters < <(grep -v '^[[:space:]]*$' "$configured_file")
  else
    mapfile -t clusters < <(aws eks list-clusters --region "$REGION" --query 'clusters[]' --output text | tr '\t' '\n')
  fi
}

get_contexts() {
  mapfile -t k8names < <(kubectl config get-contexts --no-headers 2>/dev/null | awk '{print $2}')
}

get_clusters

if [ ${#clusters[@]} -eq 0 ]; then
  printf '%s\n' "No EKS clusters found to process."
  exit 1
fi

for cluster in "${clusters[@]}"; do
  printf '%s\n' "$cluster" | sed 's/^/#EKS-NAME#/'
  aws eks update-kubeconfig --name "$cluster" --region "$REGION"
  _check_exit $? "aws eks update-kubeconfig --name $cluster --region $REGION"
done

get_contexts
for ctx in "${k8names[@]}"; do
  printf '%s\n' "$ctx" | sed 's/^/#EKS-ARN#/'
done

printf '%s\n' "Done."
kubectl config view
_check_exit $? "kubectl config view"

printf '%s\n' "SSM document execution completed successfully."