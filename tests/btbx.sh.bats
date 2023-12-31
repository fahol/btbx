setup() {
    # Diretories from the repository relative to the test filename
    ROOT="$( cd "$( dirname "$BATS_TEST_FILENAME" )/.." >/dev/null 2>&1 && pwd )"
    load ${ROOT}/tests/lib/bats-support/load
    load ${ROOT}/tests/lib/bats-assert/load
    load ${ROOT}/tests/lib/bats-file/load
    load ${ROOT}/tests/lib/bats-detik/lib/utils
    load ${ROOT}/tests/lib/bats-detik/lib/detik

    # Load the library file
    BTBX_BASE=${ROOT}/.tmp
    load ${ROOT}/lib/btbx.sh

    # Test what we need
    assert_exist ${BTBX_BIN}/oc
    assert_exist ${BTBX_BIN}/kubectl
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

@test "btbx.sh - can be loaded properly" {
    assert_equal ${BTBX_HOME} $(realpath ${ROOT}/lib)
    assert_exist ${BTBX_HOME}/btbx.sh
}

@test "btbx.sh - environment variable propagation" {
    # Test if btbx.sh can build the environment variables
    # as expected if we have a clean environment

    # Artificially create a safe environment
    unset BTBX_BASE
    unset BTBX_BIN

    # Setup a new base
    BTBX_BASE=${TMP_DIR}
    . ${BTBX_HOME}/btbx.sh

    # Then we should have a series of variables automatically set
    assert_equal ${BTBX_BIN} ${TMP_DIR}/bin
}

#
# Downloaders for external binaries
#

@test "ensure_cli - openshift clients can be downloaded and run properly" {
    ensure_cli_openshift
    # Openshift CLI
    assert_exist ${OC}
    ${OC}
    # Kubectl CLI
    assert_exist ${KC}
    ${KC}
}

@test "ensure_cli - vscode cli can be downloaded an run properly" {
    ensure_cli_vscode
    assert_exist ${VSCODE}
    ${VSCODE} --help
}

@test "ensure_cli - micromamba cli can be downloaded an run properly" {
    ensure_cli_micromamba
    assert_exist ${MBA}
    ${MBA}
}

@test "ensure_cli - k9s cli can be downloaded an run properly" {
    ensure_cli_k9s
    assert_exist ${K9S}
    run ${K9S} --help
    assert_output -p 'K9s'
}

#
# adhoc_pod on k8s
#

@test "adhoc_pod_exec - check basics" {
    skip_k8s_if_not_auth
    adhoc_pod_exec bash -l -c '[[ -e /bin && -e /sbin ]]'
}
