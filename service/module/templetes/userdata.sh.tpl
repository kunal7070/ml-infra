#!/bin/bash
set -uo pipefail

exec > >(tee /var/log/servicenow-eks-discovery-host-userdata.log | logger -t user-data -s 2>/dev/console) 2>&1

mkdir -p /opt/servicenow
chmod 755 /opt/servicenow

# Create ssm-user
if ! id ssm-user >/dev/null 2>&1; then
  useradd -m ssm-user
fi

mkdir -p /home/ssm-user/.kube
chmod 700 /home/ssm-user/.kube
chown -R ssm-user:ssm-user /home/ssm-user

# Create extra Linux users
${ join("\n", [ for name in split(",", extra_linux_users_csv) : <<-EOC
if [ -n "${name}" ]; then
  if ! id -u "${name}" >/dev/null 2>&1; then
    useradd -m -s /bin/bash "${name}"
    printf '%s\n' "Created user: ${name}"
  else
    printf '%s\n' "User already exists, skipping: ${name}"
  fi
fi
EOC
]) }

%{ if add_extra_sudo_users ~}
${ join("\n", [ for name in split(",", extra_linux_users_csv) : <<-EOC
if [ -n "${name}" ]; then
  printf '%s\n' "${name} ALL=(ALL) NOPASSWD:ALL" > "/etc/sudoers.d/90-${name}"
  chmod 0440 "/etc/sudoers.d/90-${name}"
  printf '%s\n' "Granted passwordless sudo to: ${name}"
fi
EOC
]) }
%{ endif ~}

cat > /opt/servicenow/eks-clusters.txt <<'EOF'
${replace(cluster_names_csv, ",", "\n")}
EOF

chmod 600 /opt/servicenow/eks-clusters.txt
chown ssm-user:ssm-user /opt/servicenow/eks-clusters.txt

install_pkgs() {
  printf '%s\n' "Installing required packages..."
  yum install -y unzip jq curl || return 1
}

install_awscli_v2() {
  local aws_major_version
  aws_major_version=$(aws --version 2>&1 | grep -oP 'aws-cli/\K[0-9]+' || echo "0")

  if [ "$aws_major_version" != "2" ]; then
    printf '%s\n' "Installing AWS CLI v2..."

    local karch arch
    arch="$(uname -m)"
    if [ "$arch" = "x86_64" ]; then
      karch="x86_64"
    elif [ "$arch" = "aarch64" ]; then
      karch="aarch64"
    else
      karch="x86_64"
    fi

    cd /tmp || return 1
    curl -sSLo awscliv2.zip "https://awscli.amazonaws.com/awscli-exe-linux-${karch}.zip" || return 1
    unzip -oq awscliv2.zip || return 1
    ./aws/install --update || return 1
    rm -rf awscliv2.zip aws/
    printf '%s\n' "AWS CLI v2 installed successfully."
  else
    printf '%s\n' "AWS CLI v2 already installed, skipping."
  fi
}

install_kubectl() {
  local detected_karch installed_version arch
  arch="$(uname -m)"

  if [ "$arch" = "x86_64" ]; then
    detected_karch="amd64"
  elif [ "$arch" = "aarch64" ]; then
    detected_karch="arm64"
  else
    detected_karch="amd64"
  fi

  installed_version=$(kubectl version --client --output=yaml 2>/dev/null \
    | grep -oP 'gitVersion:\s*\K[^ ]+' || echo "none")

  if [ "$installed_version" != "${install_kubectl_version}" ]; then
    printf '%s\n' "Installing kubectl ${install_kubectl_version}..."
    curl -sSLo /usr/local/bin/kubectl \
      "https://dl.k8s.io/release/${install_kubectl_version}/bin/linux/${detected_karch}/kubectl" || return 1
    chmod +x /usr/local/bin/kubectl || return 1
    printf '%s\n' "kubectl ${install_kubectl_version} installed successfully."
  else
    printf '%s\n' "kubectl ${install_kubectl_version} already installed, skipping."
  fi
}

ensure_ssm_agent() {
  if systemctl list-unit-files | grep -q amazon-ssm-agent; then
    systemctl enable amazon-ssm-agent || true
    systemctl restart amazon-ssm-agent || true
  fi
}

install_pkgs      || printf '%s\n' "WARNING: install_pkgs failed, continuing..."
install_awscli_v2 || printf '%s\n' "WARNING: install_awscli_v2 failed, continuing..."
install_kubectl   || printf '%s\n' "WARNING: install_kubectl failed, continuing..."
ensure_ssm_agent  || printf '%s\n' "WARNING: ensure_ssm_agent failed, continuing..."

printf '%s\n' "user_data setup complete."