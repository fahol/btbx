setup_suite() {
    # bats version
    bats_require_minimum_version 1.5.0

    # Diretories from the repository relative to the test filename
    ROOT="$( cd "$( dirname "$BATS_TEST_FILENAME" )/.." >/dev/null 2>&1 && pwd )"
    load ${ROOT}/tests/lib/bats-support/load
    load ${ROOT}/tests/lib/bats-assert/load
    load ${ROOT}/tests/lib/bats-file/load

    # Load the library itself
    export BTBX_BASE=${ROOT}/.tmp
    load ${ROOT}/lib/btbx.sh

    # Ensure the command line utilities
    ensure_cli_openshift ${BTBX_BIN}
    assert_exist ${BTBX_BIN}/oc
    assert_exist ${BTBX_BIN}/kubectl
    assert_exist ${OC}
    assert_exist ${KC}

    # See if we have access to a kubernetes context
    # only if we have ${K8S_TESTS_ENABLED} defined
    if [[ ! -z ${K8S_TESTS_ENABLED} ]]; then
        echo "# > k8s tests enabled - 'unset K8S_TESTS_ENABLED' to disable" >&3
        rm -rf ${ROOT}/.tmp/has_k8s_auth
        if k8s_auth_check_context ; then
            # Set marker
            mkdir -p ${ROOT}/.tmp
            touch ${ROOT}/.tmp/has_k8s_auth
            echo "# > k8s_auth - using current context $(${OC} whoami -c)" >&3
            # Start an adhoc pod that can be used throughout the test suite
            echo "# > adhoc_pod - starting" >&3
            adhoc_pod_start ubuntu:20.04
        else
            echo "# > k8s_auth - current context is NOT authenticated" >&3
            echo "# > k8s_auth - Authenticate into a k8s cluster!" >&3
            exit 1
        fi
    else
        echo "# > k8s tests disabled - 'export K8S_TESTS_ENABLED=1' to enable" >&3
    fi

}

teardown_suite() {
    echo ""
    # Remove the k8s auth marker and the adhoc pod
    # if we had k8s capabilities enabled
    if [[ -e ${ROOT}/.tmp/has_k8s_auth ]]; then
        rm -rf ./.tmp/has_k8s_auth
        echo "# > adhoc_pod stopping" >&3
        adhoc_pod_stop
    fi
}
