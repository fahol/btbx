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

#
# adhoc_pod on k8s
#

@test "adhoc_pod_exec - check basics" {
    skip_k8s_if_not_auth
    adhoc_pod_exec bash -l -c '[[ -e /bin && -e /sbin ]]'
}
