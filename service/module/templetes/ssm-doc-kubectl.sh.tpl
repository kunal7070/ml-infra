#!/bin/bash
set -euo pipefail

export KUBECONFIG=/home/ssm-user/.kube/config

_check_exit() {
  local rc="$1"
  local cmd="$2"
  if [ "$rc" -ne 0 ]; then
    printf '%s\n' "Error: command failed: $cmd (exit code $rc)" >&2
    exit "$rc"
  fi
}

get_namespaces() {
  mapfile -t k8namespaces < <(kubectl get namespace --no-headers | awk '{print $1}')
  _check_exit $? "kubectl get namespace --no-headers"
}

exec_kubectl_namespace_commands() {
  local resource="$1"
  local namespace="$2"
  local output_format="$3"
  local prefix="$4"

  local safe_prefix
  safe_prefix=$(printf '%s' "$prefix" | sed -e 's/[\/&]/\\&/g')

  kubectl get "$resource" -n "$namespace" -o "$output_format" | sed 's/^/###/' | sed "s/###/###${safe_prefix}###/"
  local rc_kubectl=${PIPESTATUS[0]:-$?}
  _check_exit "$rc_kubectl" "kubectl get $resource -n $namespace -o $output_format"
}

exec_kubectl_cluster_command() {
  local resource="$1"
  local output_format="$2"
  local prefix="$3"

  local safe_prefix
  safe_prefix=$(printf '%s' "$prefix" | sed -e 's/[\/&]/\\&/g')

  kubectl get "$resource" -o "$output_format" | sed "s/^/###${safe_prefix}### /"
  local rc_kubectl=${PIPESTATUS[0]:-$?}
  _check_exit "$rc_kubectl" "kubectl get $resource -o $output_format"
}

execute_for_context() {
  local context="$1"

  kubectl config use-context "$context"
  _check_exit $? "kubectl config use-context $context"

  get_namespaces

  for ns in "${k8namespaces[@]}"; do
    printf '%s\n' "$ns" | sed 's/^/#NAMESPACES#/'
  done

  exec_kubectl_cluster_command namespace json NAMESPACES-JSON

  for ns in "${k8namespaces[@]}"; do
    exec_kubectl_namespace_commands pods "$ns" json PODS-JSON
    exec_kubectl_namespace_commands deployments "$ns" json DEPLOYMENTS-JSON
    exec_kubectl_namespace_commands services "$ns" json SERVICES-JSON
    exec_kubectl_namespace_commands replicasets "$ns" json REPLICASETS-JSON
    exec_kubectl_namespace_commands daemonsets "$ns" json DAEMONSET-JSON
  done

  kubectl get nodes -o json | sed 's/^/#NODES-JSON#/'
  local rc_kubectl=${PIPESTATUS[0]:-$?}
  _check_exit "$rc_kubectl" "kubectl get nodes -o json"
}

get_region() {
  TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
  REGION=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/placement/region)
  printf '%s' "$REGION"
}

get_cluster_names() {
  local configured_file="/opt/servicenow/eks-clusters.txt"
  local region="$1"

  if [ -f "$configured_file" ] && [ -s "$configured_file" ]; then
    mapfile -t all_clusters < <(grep -v '^[[:space:]]*$' "$configured_file")
  else
    mapfile -t all_clusters < <(aws eks list-clusters --region "$region" --query 'clusters[]' --output text | tr '\t' '\n')
  fi
}

process_all_clusters() {
  local region="$1"

  printf '%s\n' "Discovering EKS clusters..."
  get_cluster_names "$region"

  if [ ${#all_clusters[@]} -eq 0 ]; then
    printf '%s\n' "No EKS clusters found to process"
    exit 1
  fi

  printf '%s\n' "Found ${#all_clusters[@]} EKS cluster(s)"

  for cluster_name in "${all_clusters[@]}"; do
    printf '%s\n' "Processing cluster: $cluster_name"
    aws eks update-kubeconfig --name "$cluster_name" --region "$region"
    _check_exit $? "aws eks update-kubeconfig --name $cluster_name --region $region"

    account_id=$(aws sts get-caller-identity --query Account --output text)
    context_arn="arn:aws:eks:${region}:${account_id}:cluster/${cluster_name}"

    execute_for_context "$context_arn"

    printf '%s\n' ""
    printf '%s\n' "Completed processing cluster: $cluster_name"
    printf '%s\n' ""
  done

  printf '%s\n' "All clusters processed successfully"
}

REGION=$(get_region)
process_all_clusters "$REGION"