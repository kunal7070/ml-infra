#!/bin/bash
#set -x
set -euo pipefail

# helper to check command exit status
_check_exit() {
  local rc="$1"
  local cmd="$2"
  if [ "$rc" -ne 0 ]; then
    printf '%s\n' "Error: command failed: $cmd (exit code $rc)" >&2
    exit "$rc"
  fi
}

function getNamespaces() {
  # Build array of namespace names
  IFS=$'\n' k8namespaces=($(kubectl get namespace --no-headers | awk '{print $1}'))
  _check_exit $? "kubectl get namespace --no-headers | awk '{print \$1}'"
}

# Args: $1=resource $2=namespace $3=output-format $4=prefix-label
function execKubectlNamespaceCommands() {
  printf '%s\n' "Executing $1 $2 $3 $4"

  # escape $4 for use in sed replacement
  local safe_4
  safe_4=$(printf '%s' "$4" | sed -e 's/[\/&]/\\&/g')

  # run kubectl — two sed calls to build ###PREFIX### pattern
  kubectl get "$1" -n "$2" -o "$3" 2>&1 | sed 's/^/###/' | sed "s/###/###$safe_4###/"
  local rc_kubectl=${PIPESTATUS[0]:-$?}
  _check_exit $rc_kubectl "kubectl get $1 -n $2 -o $3"
}

# Args: $1=resource $2=output-format $3=prefix-label
function execKubectlGetNamespaces() {
  local safe_3
  safe_3=$(printf '%s' "$3" | sed -e 's/[\/&]/\\&/g')

  kubectl get "$1" -o "$2" 2>&1 | sed "s/^/###$safe_3### /"
  local rc_kubectl=${PIPESTATUS[0]:-$?}
  _check_exit $rc_kubectl "kubectl get $1 -o $2"
}

# Args: $1=cluster_context_ARN
function executeCommands() {
  kubectl config use-context "$1"
  _check_exit $? "kubectl config use-context $1"

  getNamespaces

  # Print each namespace with #NAMESPACES prefix
  for ((n=0; n<${#k8namespaces[@]}; n++)); do
    printf '%s\n' "${k8namespaces[$n]}" | sed 's/^/#NAMESPACES#/'
  done

  # Output namespaces as JSON with prefix
  execKubectlGetNamespaces namespace json NAMESPACES-JSON

  # For each namespace, collect pods/deployments/services/replicasets/daemonsets
  for ((n=0; n<${#k8namespaces[@]}; n++)); do
    execKubectlNamespaceCommands pods        "${k8namespaces[$n]}" json PODS-JSON
    execKubectlNamespaceCommands deployments "${k8namespaces[$n]}" json DEPLOYMENTS-JSON
    execKubectlNamespaceCommands services    "${k8namespaces[$n]}" json SERVICES-JSON
    execKubectlNamespaceCommands replicasets "${k8namespaces[$n]}" json REPLICASETS-JSON
    execKubectlNamespaceCommands daemonsets  "${k8namespaces[$n]}" json DAEMONSET-JSON
  done

  # Collect node data
  kubectl get nodes -o json 2>&1 | sed 's/^/#NODES-JSON#/'
  local rc_kubectl=${PIPESTATUS[0]:-$?}
  _check_exit $rc_kubectl "kubectl get nodes -o json"
}

# Get all EKS cluster ARNs – builds full ARN from region + account + cluster name
function getAllEKSClusters() {
  local account_id
  account_id=$(aws sts get-caller-identity --query Account --output text 2>/dev/null)

  if [ -z "$account_id" ]; then
    printf '%s\n' "Error: Unable to get AWS account ID" >&2
    exit 1
  fi

  local clusters
  clusters=$(aws eks list-clusters --region "$REGION" --query 'clusters[]' --output text 2>/dev/null)

  if [ -z "$clusters" ]; then
    printf '%s\n' "No EKS clusters found in region $REGION"
    return 1
  fi

  # Build full ARN for each cluster — context name matches ARN after update-kubeconfig
  for cluster_name in $clusters; do
    printf '%s\n' "arn:aws:eks:${REGION}:${account_id}:cluster/${cluster_name}"
  done
}

function processAllClusters() {
  printf '%s\n' "Discovering EKS clusters..."

  mapfile -t all_clusters < <(getAllEKSClusters)

  if [ "${#all_clusters[@]}" -eq 0 ]; then
    printf '%s\n' "No EKS clusters found to process"
    exit 1
  fi

  printf '%s\n' "Found ${#all_clusters[@]} EKS cluster(s)"

  export KUBECONFIG=/home/ssm-user/.kube/config

  for cluster_arn in "${all_clusters[@]}"; do
    printf '%s\n' ""
    printf '%s\n' "Processing cluster: $cluster_arn"

    # Extract cluster name from ARN (everything after last /)
    local cluster_name="${cluster_arn##*/}"

    # Use resolved REGION consistently
    aws eks update-kubeconfig --name "$cluster_name" --region "$REGION"
    _check_exit $? "aws eks update-kubeconfig --name $cluster_name --region $REGION"

    # executeCommands uses the full ARN as the kubectl context name
    executeCommands "$cluster_arn"

    printf '%s\n' ""
    printf '%s\n' "Completed processing cluster: $cluster_arn"
    printf '%s\n' ""
  done

  printf '%s\n' "All clusters processed successfully"
}

export KUBECONFIG=/home/ssm-user/.kube/config

# Resolve REGION once globally
REGION=$(aws configure get region 2>/dev/null || true)

# Fallback to IMDSv2 if aws configure region is empty
if [ -z "$REGION" ]; then
  TOKEN=$(curl -sf -X PUT "http://169.254.169.254/latest/api/token" \
    -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
  _check_exit $? "curl IMDSv2 token"

  REGION=$(curl -sf -H "X-aws-ec2-metadata-token: $TOKEN" \
    "http://169.254.169.254/latest/meta-data/placement/region")
  _check_exit $? "curl IMDSv2 region"
fi

processAllClusters