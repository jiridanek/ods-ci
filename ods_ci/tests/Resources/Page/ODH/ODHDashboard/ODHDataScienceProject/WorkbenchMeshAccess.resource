*** Settings ***
Library    OperatingSystem
Library    String

*** Keywords ***
Provision Workbench Mesh Access
    [Documentation]    In-kind spike: routes the workbench path on the dashboard host through an
    ...    auth-injecting shim so the browser can open the workbench (see docs/odh-3x-handoff.md).
    [Arguments]    ${project_title}    ${username}
    ${rc}    ${nb_name}=    Run And Return Rc And Output    kubectl get notebooks -n ${project_title} -o jsonpath={.items[0].metadata.name}
    IF    ${rc} != 0
        Fail    msg=No notebook found in ${project_title}: ${nb_name}
    END
    Log    notebook=${nb_name} in ${project_title}
    ${token}=    Fetch Workbench User Token    username=${username}
    ${shim_cmd}=    Catenate    env    PROJ_NS=${project_title}    NB_NAME=${nb_name}    TOKEN=${token}    python3    /tmp/kf3x/apply_shim_param.py
    ${rc2}    ${shim_out}=    Run And Return Rc And Output    ${shim_cmd}
    IF    ${rc2} != 0
        Fail    msg=shim provisioning failed: ${shim_out}
    END
    Wait Until Keyword Succeeds    300s    10s    Workbench Mesh Access Should Be Ready    project_title=${project_title}    nb_name=${nb_name}

Workbench Mesh Access Should Be Ready
    [Arguments]    ${project_title}    ${nb_name}
    ${rc3}    ${out3}=    Run And Return Rc And Output    python3 /tmp/kf3x/shim_ready.py ${project_title} ${nb_name}
    Run Keyword If    ${rc3} != 0    Fail    msg=shim not ready: ${out3}

Harden Workbench Probes
    [Documentation]    In-kind: QEMU makes the workbench liveness probe flaky (transient
    ...    connection-refused -> kubelet kills jupyter). Loosens the probes on the Notebook CR
    ...    and recycles the pod.
    [Arguments]    ${project_title}
    ${rc}    ${out}=    Run And Return Rc And Output    python3 /tmp/kf3x/harden_probes.py ${project_title}
    Log    ${out}
    IF    ${rc} != 0
        Fail    msg=probe hardening failed: ${out}
    END

Stop Workbench Via K8s
    [Documentation]    In-kind: deletes the Notebook CR so the workbench pod goes away and
    ...    QEMU resources are freed for the pipeline steps. The dashboard shows it as Stopped.
    [Arguments]    ${project_title}
    ${rc}    ${out}=    Run And Return Rc And Output    python3 /tmp/kf3x/workbench_stop.py ${project_title}
    Log    ${out}
    IF    ${rc} != 0
        Log    workbench may still be terminating: ${out}
    END

Workbench Pod Should Be Ready
    [Documentation]    In-kind: k8s-level wait for the (recycled) workbench pod
    [Arguments]    ${project_title}
    ${rc}    ${out}=    Run And Return Rc And Output    python3 /tmp/kf3x/workbench_ready.py ${project_title}
    IF    ${rc} != 0
        Fail    msg=workbench pod not ready: ${out}
    END

Workbench Should Respond
    [Documentation]    In-kind: host-side warmup - polls the workbench URL through the gateway
    ...    until the (QEMU-emulated) jupyter server actually answers, so the browser does not
    ...    race the server cold start.
    [Arguments]    ${project_title}    ${nb_name}
    ${wrc}    ${out}=    Run And Return Rc And Output    python3 /tmp/kf3x/wb_poll.py ${project_title} '${nb_name}'
    Log    ${out}
    IF    ${wrc} != 0
        Fail    msg=workbench not responsive yet: ${out}
    END

Fetch Workbench User Token
    [Arguments]    ${username}
    ${tok_cmd}=    Catenate    env    USERNAME=${username}    python3    /tmp/kf3x/fetch_token.py
    ${rc}    ${out}=    Run And Return Rc And Output    ${tok_cmd}
    IF    ${rc} != 0
        Fail    msg=token fetch failed for ${username}: ${out}
    END
    RETURN    ${out.strip()}
