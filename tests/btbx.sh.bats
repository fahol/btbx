setup() {
    # Diretories from the repository relative to the test filename
    ROOT="$( cd "$( dirname "$BATS_TEST_FILENAME" )/.." >/dev/null 2>&1 && pwd )"
    load ${ROOT}/tests/lib/bats-support/load
    load ${ROOT}/tests/lib/bats-assert/load
    load ${ROOT}/tests/lib/bats-file/load
    load ${ROOT}/tests/lib/bats-detik/lib/utils
    load ${ROOT}/tests/lib/bats-detik/lib/detik

    # Load the library file
    FILE_DST=${ROOT}/.tmp/bin
    load ${ROOT}/lib/btbx.sh

    # Test what we need
    assert_exist ${FILE_DST}/oc
    assert_exist ${FILE_DST}/kubectl
    assert_exist ${OC}
    assert_exist ${KC}

    # TMP_DIR
    TMP_DIR="$(temp_make)"

    # Check k8s auth
    skip_k8s_if_not_auth() {
        if [[ ! -e ${ROOT}/.tmp/has_k8s_auth ]]; then
            skip
        fi
        return 0
    }
}

teardown() {
    echo ""
    temp_del ${TMP_DIR}
}

@test "btbx.sh can be loaded properly" {
    assert_equal ${FILE_HOME} $(realpath ${ROOT}/lib)
    assert_exist ${FILE_HOME}/btbx.sh
}

#
# Downloaders for external binaries
#

@test "ensure_cli - openshift client can be downloaded and run properly" {
    ensure_cli_openshift ${TMP_DIR}
    # Openshift CLI
    assert_exist ${TMP_DIR}/oc
    ${TMP_DIR}/oc
    # Kubectl CLI
    assert_exist ${TMP_DIR}/kubectl
    ${TMP_DIR}/kubectl
}

@test "ensure_cli - vscode can be downloaded an run properly" {
    ensure_cli_vscode ${TMP_DIR}
    assert_exist ${TMP_DIR}/code
    ${TMP_DIR}/code --help
}

@test "ensure_cli - micromamba can be downloaded an run properly" {
    ensure_cli_micromamba ${TMP_DIR}
    assert_exist ${TMP_DIR}/micromamba
    ${TMP_DIR}/micromamba
}

#
# adhoc_pod on k8s
#

@test "adhoc_pod_exec - check basics" {
    skip_k8s_if_not_auth
    adhoc_pod_exec bash -l -c '[[ -e /bin && -e /sbin ]]'
}
