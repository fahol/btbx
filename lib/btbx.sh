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
OC=${BTBX_BIN}/oc
KC=${BTBX_BIN}/kubectl
MBA=${BTBX_BIN}/micromamba
VSCODE=${BTBX_BIN}/code
K9S=${BTBX_BIN}/k9s

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
  OCP_VER=4.12.9
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

  K9S_VER=v0.30.5

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
    curl -LS https://github.com/derailed/k9s/releases/download/${K9S_VER}/k9s_Darwin_amd64.tar.gz | tar -xvj -C ${temp_dir} k9s
    ;;
  Darwin-arm64)
    curl -Ls https://github.com/derailed/k9s/releases/download/${K9S_VER}/k9s_Darwin_arm64.tar.gz | tar -xvj -C ${temp_dir} k9s
    ;;
  GNULinux-x86_64)
    curl -Ls https://github.com/derailed/k9s/releases/download/${K9S_VER}/k9s_Linux_amd64.tar.gz | tar -xvj -C ${temp_dir} k9s
    ;;
  GNULinux-arm64)
    curl -Ls https://github.com/derailed/k9s/releases/download/${K9S_VER}/k9s_Linux_arm64.tar.gz | tar -xvj -C ${temp_dir} k9s
    ;;
  esac

  mkdir -p ${BTBX_BIN}
  mv ${temp_dir}/k9s ${BTBX_BIN}/
  chmod 700 ${BTBX_BIN}/k9s
  rm -rf ${temp_dir}
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
