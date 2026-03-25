#!/bin/bash
set -euo pipefail

exec > >(tee /var/log/servicenow-eks-discovery-host-userdata.log | logger -t user-data -s 2>/dev/console) 2>&1

# CHANGED: create both /opt/servicenow and /home/ssm-user/.kube
mkdir -p /opt/servicenow
chmod 755 /opt/servicenow

# CHANGED: explicitly create ssm-user because SSM scripts use /home/ssm-user
if ! id ssm-user >/dev/null 2>&1; then
  useradd -m ssm-user
fi

# CHANGED: create kube dir where SSM scripts expect it
mkdir -p /home/ssm-user/.kube
chmod 700 /home/ssm-user/.kube
chown -R ssm-user:ssm-user /home/ssm-user

cat > /opt/servicenow/eks-clusters.txt <<'EOF'
${replace(cluster_names_csv, ",", "\n")}
EOF

chmod 600 /opt/servicenow/eks-clusters.txt

# CHANGED: safer to let ssm-user read the cluster file too
chown ssm-user:ssm-user /opt/servicenow/eks-clusters.txt

install_pkgs() {
  printf '%s\n' "Installing required packages..."

  # Keep yum because this looks like your intended AMI family
  yum install -y unzip jq curl
}

install_awscli_v2() {
  local aws_major_version
  aws_major_version=$(aws --version 2>&1 | grep -oP 'aws-cli/\K[0-9]+' || echo "0")

  if [ "$aws_major_version" != "2" ]; then
    printf '%s\n' "Installing AWS CLI v2..."

    local karch
    arch="$(uname -m)"
    if [ "$arch" = "x86_64" ]; then
      karch="x86_64"
    elif [ "$arch" = "aarch64" ]; then
      karch="aarch64"
    else
      karch="x86_64"
    fi

    cd /tmp
    curl -sSLo awscliv2.zip "https://awscli.amazonaws.com/awscli-exe-linux-${karch}.zip"
    unzip -oq awscliv2.zip
    ./aws/install --update
    rm -rf awscliv2.zip aws/
    printf '%s\n' "AWS CLI v2 installed successfully."
  else
    printf '%s\n' "AWS CLI v2 already installed, skipping."
  fi
}

install_kubectl() {
  local karch installed_version

  arch="$(uname -m)"
  if [ "$arch" = "x86_64" ]; then
    karch="amd64"
  elif [ "$arch" = "aarch64" ]; then
    karch="arm64"
  else
    karch="amd64"
  fi

  # --short removed in newer versions, use yaml output
  installed_version=$(kubectl version --client --output=yaml 2>/dev/null \
    | grep -oP 'gitVersion:\s*\K[^ ]+' || echo "none")

  if [ "$installed_version" != "${install_kubectl_version}" ]; then
    printf '%s\n' "Installing kubectl ${install_kubectl_version}..."
    curl -sSLo /usr/local/bin/kubectl \
      "https://dl.k8s.io/release/${install_kubectl_version}/bin/linux/${karch}/kubectl"
    chmod +x /usr/local/bin/kubectl
    printf '%s\n' "kubectl ${install_kubectl_version} installed successfully."
  else
    printf '%s\n' "kubectl ${install_kubectl_version} already installed, skipping."
  fi
}

create_extra_users() {
  EXTRA_USERS_CSV='${extra_linux_users_csv}'

  if [ -n "$EXTRA_USERS_CSV" ]; then
    IFS=',' read -r -a EXTRA_USERS <<< "$EXTRA_USERS_CSV"

    for user in "${EXTRA_USERS[@]}"; do
      if [ -n "$user" ]; then
        if ! id "$user" >/dev/null 2>&1; then
          useradd -m "$user"
          printf '%s\n' "Created user: $user"
        else
          printf '%s\n' "User already exists, skipping create: $user"
        fi

%{ if extra_users_passwordless_sudo_flag ~}
        printf '%s\n' "$user ALL=(ALL) NOPASSWD:ALL" > "/etc/sudoers.d/$user"
        chmod 440 "/etc/sudoers.d/$user"
        printf '%s\n' "Granted passwordless sudo to: $user"
%{ endif ~}
      fi
    done
  fi
}

# CHANGED: ensure SSM agent is enabled/running if present in the AMI
ensure_ssm_agent() {
  if systemctl list-unit-files | grep -q amazon-ssm-agent; then
    systemctl enable amazon-ssm-agent || true
    systemctl restart amazon-ssm-agent || true
  fi
}

install_pkgs
install_awscli_v2
install_kubectl
create_extra_users
ensure_ssm_agent

printf '%s\n' "user_data setup complete."