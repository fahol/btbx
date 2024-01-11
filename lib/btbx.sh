#!/bin/bash

#
# Globals
#

# Get the relative home of this file
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
	export BTBX_HOME=$(realpath $(dirname $0))
else
	export BTBX_HOME=$(realpath $(dirname ${BASH_SOURCE}))
fi

OS_ARCH=$(uname -o | tr -d '/')-$(uname -m)

# File destination can be configured from the caller
BTBX_BASE=${BTBX_BASE:-${BTBX_HOME}/.${OS_ARCH}}
BTBX_BIN=${BTBX_BIN:-${BTBX_BASE}/bin}
BTBX_MAMBA=${BTBX_MAMBA:-${BTBX_BASE}/opt/mamba}

# K8s CLI
OCP_VER=${OCP_VER:-4.12.9}
OC=${BTBX_BIN}/oc
KC=${BTBX_BIN}/kubectl

# Mamba
MBA=${BTBX_BIN}/micromamba

# VSCode
VSCODE=${BTBX_BIN}/code

#K9s
K9S_VER=${K9S_VER:-v0.30.5}
K9S=${BTBX_BIN}/k9s

# Python3
PYTHON3_VER=${PYTHON3_VER:-3.11.7}

# DVC
DVC_VER=${DVC_VER:-3.37.0}
DVC=${BTBX_BIN}/dvc

# mlflow
MLFLOW_VER=${MLFLOW_VER:-2.9.2}
MLFLOW=${BTBX_BIN}/mlflow

# cookiecutter
COOKIECUTTER_VER=${COOKIECUTTER_VER:-2.5.0}
COOKIECUTTER=${BTBX_BIN}/cookiecutter

# supervisord
SUPERVISORD_VER=${SUPERVISORD_VER:-4.2.5}
SUPERVISORD=${BTBX_BIN}/supervisord
SUPERVISORCTL=${BTBX_BIN}/supervisorctl

# yq
YQ_VER=${YQ_VER:-v4.40.5}
YQ=${BTBX_BIN}/yq

# gitlab-runner
GITLAB_RUNNER_VER=${GITLAB_RUNNER_VER:-v16.7.0}
GITLAB_RUNNER=${BTBX_BIN}/gitlab-runner

#
# Helper functions
#

function with_timeout { 
    timeout="$1"
    shift
    ( 
        eval "$@" &
        child=$!
        trap -- "" SIGTERM 
        (       
                sleep $timeout
                kill $child 2> /dev/null 
        ) &     
        wait $child
    )
}

#
# Openshift Auth
#

k8s_auth_check_context() {
  # Test whether we're authenticated
  if with_timeout 1 ${OC} whoami &> /dev/null; then
    echo "Current context ($(oc config current-context)) is authenticated"
    return 0
  fi
  echo "Current context ($(oc config current-context)) is NOT authenticated"
  return 1
}

k8s_auth_ensure() {
  URL=$1
  NS=$2
  # Test whether we're authenticated
  if with_timeout 3 ${OC} -s ${URL} whoami &> /dev/null; then
    echo "Already authenticated to ${URL} ($(oc config current-context))"
    return 0
  fi

  echo "Authenticating to ${URL}"
  read -p "Enter your username : " USERNAME
  read -s -p "Password : " PASSWORD
  echo

  # Authenticate using the provided username and password
  ${OC} login -u "$USERNAME" -p "$PASSWORD" ${URL} &> /dev/null
  if with_timeout 2 ${OC} -s ${URL} whoami &> /dev/null; then
    if [[ ! -z ${NS} ]]; then
      ${OC} -s ${URL} project ${NS} &> ${NS}
    fi
    echo "Authentication successful to ${URL} ($(oc config current-context))"
    return 0
  fi

  echo "Authentication failed."
  return 1
}

#
# Downloaders for external binaries
#

function ensure_cli_openshift() {
  # Openshift client source
  OCP_BASE=https://mirror.openshift.com/pub/openshift-v4/clients/ocp
  if [[ ! -z ${1} ]]; then
    BTBX_BIN=$1
  fi
  if [[ -e ${BTBX_BIN}/oc && -e ${BTBX_BIN}/kubectl ]]; then
    return 0
  fi

  # Identify the text
  case ${OS_ARCH} in
  Darwin-x86_64)
    ostype=mac 
    ;;
  Darwin-arm64)
    ostype=mac-arm64
    ;;
  GNULinux-x86_64)
    ostype=linux
    ;;
  GNULinux-arm64)
    ostype=linux-arm64
    ;;
  esac

  URL=${OCP_BASE}/${OCP_VER}/openshift-client-${ostype}.tar.gz
  echo "Downloading openshift client from ${URL}"
  temp_dir=$(mktemp -d)
  if [[ -d "$temp_dir" ]]; then
    mkdir -p "$temp_dir"
    curl -o "$temp_dir/oc.tar.gz" ${URL} &> /dev/null
    tar xzf "$temp_dir/oc.tar.gz" -C "$temp_dir"
    mkdir -p ${BTBX_BIN}
    mv "$temp_dir/oc" ${BTBX_BIN}/
    mv "$temp_dir/kubectl" ${BTBX_BIN}/
    chmod 700 ${BTBX_BIN}/oc
    chmod 700 ${BTBX_BIN}/kubectl
    rm -rf "$temp_dir"
  fi
  return 0
}

ensure_cli_vscode() {
  if [[ ! -z ${1} ]]; then
    BTBX_BIN=$1
  fi
  if [[ -e ${BTBX_BIN}/code ]]; then
    return 0
  fi

  # Download vscode CLI
  case ${OS_ARCH} in
  Darwin-x86_64)
    URL="https://code.visualstudio.com/sha/download?build=stable&os=cli-darwin-x64"
    ;;
  Darwin-arm64)
    URL="https://code.visualstudio.com/sha/download?build=stable&os=cli-darwin-arm64"
    ;;
  GNULinux-x86_64)
    URL="https://code.visualstudio.com/sha/download?build=stable&os=cli-alpine-x64"
    ;;
  GNULinux-arm64)
    URL="https://code.visualstudio.com/sha/download?build=stable&os=cli-alpine-arm64"
    ;;
  esac

  temp_dir=$(mktemp -d)
  if [[ -d "$temp_dir" ]]; then
    mkdir -p "$temp_dir"
    curl -Lk ${URL} --output ${temp_dir}/vscode_cli.tar.gz &>/dev/null
    tar xzf "$temp_dir/vscode_cli.tar.gz" -C "$temp_dir"
    mkdir -p ${BTBX_BIN}
    mv "$temp_dir/code" ${BTBX_BIN}/
    chmod 700 ${BTBX_BIN}/code
    rm -rf "$temp_dir"
  fi
  return 0
}

ensure_cli_micromamba() {
  if [[ ! -z ${1} ]]; then
    BTBX_BIN=$1
  fi
  if [[ -e ${BTBX_BIN}/micromamba ]]; then
    return 0
  fi

  # Download vscode CLI
  temp_dir=$(mktemp -d)
  mkdir -p ${temp_dir}
  case ${OS_ARCH} in
  Darwin-x86_64)
    curl -Ls https://micro.mamba.pm/api/micromamba/osx-64/latest | tar -xvj -C ${temp_dir} bin/micromamba 
    ;;
  Darwin-arm64)
    curl -Ls https://micro.mamba.pm/api/micromamba/osx-arm64/latest | tar -xvj -C ${temp_dir} bin/micromamba
    ;;
  GNULinux-x86_64)
    curl -Ls https://micro.mamba.pm/api/micromamba/linux-64/latest | tar -xvj -C ${temp_dir} bin/micromamba
    ;;
  GNULinux-arm64)
    curl -Ls https://micro.mamba.pm/api/micromamba/linux-aarch64/latest | tar -xvj -C ${temp_dir} bin/micromamba
    ;;
  esac
  mkdir -p ${BTBX_BIN}
  mv ${temp_dir}/bin/micromamba ${BTBX_BIN}/
  chmod 700 ${BTBX_BIN}/micromamba
  rm -rf ${temp_dir}
  return 0
}

ensure_cli_k9s() {
  # Ensure k9s

  if [[ ! -z ${1} ]]; then
    BTBX_BIN=$1
  fi
  if [[ -e ${BTBX_BIN}/k9s ]]; then
    return 0
  fi

  # Download vscode CLI
  temp_dir=$(mktemp -d)
  mkdir -p ${temp_dir}

  case ${OS_ARCH} in
  Darwin-x86_64)
    curl -LS https://github.com/derailed/k9s/releases/download/${K9S_VER}/k9s_Darwin_amd64.tar.gz | tar -xvz -C ${temp_dir} k9s
    ;;
  Darwin-arm64)
    curl -Ls https://github.com/derailed/k9s/releases/download/${K9S_VER}/k9s_Darwin_arm64.tar.gz | tar -xvz -C ${temp_dir} k9s
    ;;
  GNULinux-x86_64)
    curl -Ls https://github.com/derailed/k9s/releases/download/${K9S_VER}/k9s_Linux_amd64.tar.gz | tar -xvz -C ${temp_dir} k9s
    ;;
  GNULinux-arm64)
    curl -Ls https://github.com/derailed/k9s/releases/download/${K9S_VER}/k9s_Linux_arm64.tar.gz | tar -xvz -C ${temp_dir} k9s
    ;;
  esac

  mkdir -p ${BTBX_BIN}
  mv ${temp_dir}/k9s ${BTBX_BIN}/
  chmod 700 ${BTBX_BIN}/k9s
  rm -rf ${temp_dir}
  return 0
}

ensure_cli_mambaenv() {
  # Ensure mamba environment with python
  if [[ ! -z ${1} ]]; then
    BTBX_MAMBA=$1
  fi
  if [[ -e ${BTBX_MAMBA} \
    && -e ${BTBX_MAMBA}/bin/python3 \
    && -e ${BTBX_MAMBA}/bin/pip3 \
    && -e ${BTBX_MAMBA}/bin/pipx ]]; then
    return 0
  fi

  # Ensure dependencies
  ensure_cli_micromamba

  # Setup a mamba environment with python and pipx as a base
  mkdir -p $(dirname ${BTBX_MAMBA})
  ${MBA} create -p ${BTBX_MAMBA} -y -c conda-forge \
    python=${PYTHON3_VER} \
    pipx
  return 0
}

ensure_cli_dvc() {
  # Install dvc on mamba
  if [[ -e ${BTBX_BIN}/dvc ]]; then
    return 0
  fi
  ensure_cli_mambaenv $1

  # DVC will be installed using pipx
  export PIPX_HOME=${BTBX_BASE}
  export PIPX_BIN_DIR=${BTBX_BIN}
  local PIPX=${BTBX_MAMBA}/bin/pipx

  ${PIPX} install dvc[all]==${DVC_VER}
  return 0
}

ensure_cli_mlflow() {
  # Install dvc on mamba
  if [[ -e ${BTBX_BIN}/mlflow ]]; then
    return 0
  fi
  ensure_cli_mambaenv $1

  # DVC will be installed using pipx
  export PIPX_HOME=${BTBX_BASE}
  export PIPX_BIN_DIR=${BTBX_BIN}
  local PIPX=${BTBX_MAMBA}/bin/pipx

  ${PIPX} install mlflow==${MLFLOW_VER}
  return 0
}

ensure_cli_cookiecutter() {
  # Install dvc on mamba
  if [[ -e ${BTBX_BIN}/cookiecutter ]]; then
    return 0
  fi
  ensure_cli_mambaenv $1

  # DVC will be installed using pipx
  export PIPX_HOME=${BTBX_BASE}
  export PIPX_BIN_DIR=${BTBX_BIN}
  local PIPX=${BTBX_MAMBA}/bin/pipx

  ${PIPX} install cookiecutter==${COOKIECUTTER_VER}
  return 0
}

ensure_cli_supervisord() {
  # Install dvc on mamba
  if [[ -e ${BTBX_BIN}/supervisord && -e ${BTBX_BIN}/supervisorctl ]]; then
    return 0
  fi
  ensure_cli_mambaenv $1

  # DVC will be installed using pipx
  export PIPX_HOME=${BTBX_BASE}
  export PIPX_BIN_DIR=${BTBX_BIN}
  local PIPX=${BTBX_MAMBA}/bin/pipx

  ${PIPX} install supervisor==${SUPERVISORD_VER}
  return 0
}

ensure_cli_yq() {
  # Ensure yq the yaml parser

  if [[ ! -z ${1} ]]; then
    BTBX_BIN=$1
  fi
  if [[ -e ${BTBX_BIN}/yq ]]; then
    return 0
  fi

  temp_dir=$(mktemp -d)
  mkdir -p ${temp_dir}
  mkdir -p ${BTBX_BIN}

  case ${OS_ARCH} in
  Darwin-x86_64)
    curl -LS https://github.com/mikefarah/yq/releases/download/${YQ_VER}/yq_darwin_amd64.tar.gz | tar -xvz -C ${temp_dir} ./yq_darwin_amd64
    cp ${temp_dir}/yq_darwin_amd64 ${BTBX_BIN}/yq
    ;;
  Darwin-arm64)
    curl -LS https://github.com/mikefarah/yq/releases/download/${YQ_VER}/yq_darwin_arm64.tar.gz | tar -xvz -C ${temp_dir} ./yq_darwin_arm64
    cp ${temp_dir}/yq_darwin_arm64 ${BTBX_BIN}/yq
    ;;
  GNULinux-x86_64)
    curl -LS https://github.com/mikefarah/yq/releases/download/${YQ_VER}/yq_linux_amd64.tar.gz | tar -xvz -C ${temp_dir} ./yq_linux_amd64
    cp ${temp_dir}/yq_linux_amd64 ${BTBX_BIN}/yq
    ;;
  GNULinux-arm64)
    curl -LS https://github.com/mikefarah/yq/releases/download/${YQ_VER}/yq_linux_arm64.tar.gz | tar -xvz -C ${temp_dir} ./yq_linux_arm64
    cp ${temp_dir}/yq_linux_arm64 ${BTBX_BIN}/yq
    ;;
  esac
  chmod 700 ${BTBX_BIN}/yq
  rm -rf ${temp_dir}
  return 0
}

ensure_cli_gitlab_runner() {
  # Ensure the gitlab runner binary
  # https://gitlab.com/gitlab-org/gitlab-runner/-/tags
  # 

  if [[ ! -z ${1} ]]; then
    BTBX_BIN=$1
  fi
  if [[ -e ${BTBX_BIN}/gitlab-runner ]]; then
    return 0
  fi

  mkdir -p ${BTBX_BIN}

  case ${OS_ARCH} in
  Darwin-x86_64)
    curl -Lo ${BTBX_BIN}/gitlab-runner "https://gitlab-runner-downloads.s3.amazonaws.com/${GITLAB_RUNNER_VER}/binaries/gitlab-runner-darwin-amd64"
    ;;
  Darwin-arm64)
    curl -Lo ${BTBX_BIN}/gitlab-runner "https://gitlab-runner-downloads.s3.amazonaws.com/${GITLAB_RUNNER_VER}/binaries/gitlab-runner-darwin-arm64"
    ;;
  GNULinux-x86_64)
    curl -Lo ${BTBX_BIN}/gitlab-runner "https://gitlab-runner-downloads.s3.amazonaws.com/${GITLAB_RUNNER_VER}/binaries/gitlab-runner-linux-amd64"
    ;;
  GNULinux-arm64)
    curl -Lo ${BTBX_BIN}/gitlab-runner "https://gitlab-runner-downloads.s3.amazonaws.com/${GITLAB_RUNNER_VER}/binaries/gitlab-runner-linux-arm64"
    ;;
  esac
  chmod 700 ${BTBX_BIN}/gitlab-runner
  return 0
}

#
# adhoc_pod on k8s
#
adhoc_pod_name() {
  echo "adhoc-pod-k8s-$(${OC} whoami)"
}

adhoc_pod_start() {
  local POD_NAME=$(adhoc_pod_name)
  local IMG=$1
  local TIMEOUT=$2
  if [[ -z ${TIMEOUT} ]]; then
    TIMEOUT=300
  fi
  if ${OC} delete --grace-period=1 --timeout=5s po ${POD_NAME}; then echo ""; fi
  ${OC} run --image=${IMG} ${POD_NAME} sleep ${TIMEOUT}
  while [[ $(kubectl get pods ${POD_NAME} -o 'jsonpath={..status.conditions[?(@.type=="Ready")].status}') != "True" ]]; do
    echo "waiting for pod" && sleep 1;
  done
  return 0
}

adhoc_pod_stop() {
  local POD_NAME=$(adhoc_pod_name)
  if ${OC} delete --grace-period=1 --timeout=3s po ${POD_NAME}; then echo ""; fi
  return 0
}

adhoc_pod_exec() {
  local POD_NAME=$(adhoc_pod_name)
  ${OC} exec -it ${POD_NAME} -c ${POD_NAME} -- "$@"
  return $?
}
