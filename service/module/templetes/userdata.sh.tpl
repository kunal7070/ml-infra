#!/bin/bash
set -euo pipefail

exec > >(tee /var/log/servicenow-eks-discovery-host-userdata.log | logger -t user-data -s 2>/dev/console) 2>&1

mkdir -p /opt/servicenow
mkdir -p /home/ssm-user/.kube || true

if ! id ssm-user >/dev/null 2>&1; then
  useradd -m ssm-user || true
fi

chown -R ssm-user:ssm-user /home/ssm-user || true
chmod 700 /home/ssm-user/.kube || true

cat >/opt/servicenow/eks-clusters.txt <<'EOF'
${replace(cluster_names_csv, ",", "\n")}
EOF

chmod 600 /opt/servicenow/eks-clusters.txt
chown ssm-user:ssm-user /opt/servicenow/eks-clusters.txt || true

create_extra_users() {
  EXTRA_USERS_CSV='${extra_linux_users_csv}'
  if [ -n "$EXTRA_USERS_CSV" ]; then
    IFS=',' read -r -a EXTRA_USERS <<< "$EXTRA_USERS_CSV"
    for user in "${EXTRA_USERS[@]}"; do
      if [ -n "$user" ] && ! id "$user" >/dev/null 2>&1; then
        useradd -m "$user"
      fi

%{ if extra_users_passwordless_sudo_flag ~}
      echo "$user ALL=(ALL) NOPASSWD:ALL" > "/etc/sudoers.d/$user"
      chmod 440 "/etc/sudoers.d/$user"
%{ endif ~}
    done
  fi
}

install_pkgs() {
  if command -v dnf >/dev/null 2>&1; then
    dnf install -y unzip curl tar gzip jq
  elif command -v yum >/dev/null 2>&1; then
    yum install -y unzip curl tar gzip jq
  elif command -v apt-get >/dev/null 2>&1; then
    apt-get update -y
    apt-get install -y unzip curl tar gzip jq
  fi
}

install_awscli_v2() {
  if ! command -v aws >/dev/null 2>&1; then
    cd /tmp
    ARCH="$(uname -m)"
    if [ "$ARCH" = "x86_64" ]; then
      AWSCLI_ZIP_URL="https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip"
    elif [ "$ARCH" = "aarch64" ]; then
      AWSCLI_ZIP_URL="https://awscli.amazonaws.com/awscli-exe-linux-aarch64.zip"
    else
      AWSCLI_ZIP_URL="https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip"
    fi
    curl -sSLo awscliv2.zip "$AWSCLI_ZIP_URL"
    unzip -oq awscliv2.zip
    ./aws/install --update
  fi
}

install_kubectl() {
  if ! command -v kubectl >/dev/null 2>&1; then
    ARCH="$(uname -m)"
    if [ "$ARCH" = "x86_64" ]; then
      KARCH="amd64"
    elif [ "$ARCH" = "aarch64" ]; then
      KARCH="arm64"
    else
      KARCH="amd64"
    fi

    curl -sSLo /usr/local/bin/kubectl "https://dl.k8s.io/release/${install_kubectl_version}/bin/linux/${KARCH}/kubectl"
    chmod +x /usr/local/bin/kubectl
  fi
}

ensure_ssm_agent() {
  if systemctl list-unit-files | grep -q amazon-ssm-agent; then
    systemctl enable amazon-ssm-agent || true
    systemctl restart amazon-ssm-agent || true
  fi
}

create_extra_users
install_pkgs
install_awscli_v2
install_kubectl
ensure_ssm_agent

echo "bootstrap complete"