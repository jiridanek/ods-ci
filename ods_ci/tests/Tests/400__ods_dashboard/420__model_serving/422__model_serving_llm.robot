*** Settings ***
Documentation     Collection of CLI tests to validate the model serving stack for Large Language Models (LLM)
Resource          ../../../Resources/Page/ODH/ODHDashboard/ODHModelServing.resource
Resource          ../../../Resources/OCP.resource
Resource          ../../../Resources/Page/Operators/ISVs.resource
Resource          ../../../Resources/Page/ODH/ODHDashboard/ODHDashboardAPI.resource
Library            OpenShiftLibrary
Suite Setup       Install Model Serving Stack Dependencies
Suite Teardown    RHOSi Teardown
Test Tags         KServe


*** Variables ***
${DEFAULT_OP_NS}=    openshift-operators
${LLM_RESOURCES_DIRPATH}=    ods_ci/tests/Resources/Files/llm
${SERVERLESS_OP_NAME}=     serverless-operator
${SERVERLESS_SUB_NAME}=    serverless-operator
${SERVERLESS_NS}=    openshift-serverless
${SERVERLESS_CR_NS}=    knative-serving
${SERVERLESS_KNATIVECR_FILEPATH}=    ${LLM_RESOURCES_DIRPATH}/knativeserving_istio.yaml
${SERVERLESS_GATEWAYS_FILEPATH}=    ${LLM_RESOURCES_DIRPATH}/gateways.yaml
${WILDCARD_GEN_SCRIPT_FILEPATH}=    ods_ci/utils/scripts/generate-wildcard-certs.sh
${SERVICEMESH_OP_NAME}=     servicemeshoperator
${SERVICEMESH_SUB_NAME}=    servicemeshoperator
${SERVICEMESH_CONTROLPLANE_FILEPATH}=    ${LLM_RESOURCES_DIRPATH}/smcp.yaml
${SERVICEMESH_ROLL_FILEPATH}=    ${LLM_RESOURCES_DIRPATH}/smmr.yaml
${SERVICEMESH_PEERAUTH_FILEPATH}=    ${LLM_RESOURCES_DIRPATH}/peer_auth.yaml
${SERVICEMESH_CR_NS}=    istio-system
${KIALI_OP_NAME}=     kiali-ossm
${KIALI_SUB_NAME}=    kiali-ossm
${JAEGER_OP_NAME}=     jaeger-product
${JAEGER_SUB_NAME}=    jaeger-product
${KSERVE_NS}=    ${APPLICATIONS_NAMESPACE}    # NS is "kserve" for ODH
${CAIKIT_FILEPATH}=    ${LLM_RESOURCES_DIRPATH}/caikit_servingruntime_{{protocol}}.yaml
${TEST_NS}=    singlemodel
${BUCKET_SECRET_FILEPATH}=    ${LLM_RESOURCES_DIRPATH}/bucket_secret.yaml
${BUCKET_SA_FILEPATH}=    ${LLM_RESOURCES_DIRPATH}/bucket_sa.yaml
${USE_BUCKET_HTTPS}=    "1"
${INFERENCESERVICE_FILEPATH}=    ${LLM_RESOURCES_DIRPATH}/caikit_isvc.yaml
${DEFAULT_BUCKET_SECRET_NAME}=    models-bucket-secret
${DEFAULT_BUCKET_SA_NAME}=        models-bucket-sa
${EXP_RESPONSES_FILEPATH}=    ${LLM_RESOURCES_DIRPATH}/model_expected_responses.json
${UWM_ENABLE_FILEPATH}=    ${LLM_RESOURCES_DIRPATH}/uwm_cm_enable.yaml
${UWM_CONFIG_FILEPATH}=    ${LLM_RESOURCES_DIRPATH}/uwm_cm_conf.yaml
${SKIP_PREREQS_INSTALL}=    ${TRUE}
${SCRIPT_BASED_INSTALL}=    ${TRUE}
${MODELS_BUCKET}=    ${S3.BUCKET_3}
${FLAN_MODEL_S3_DIR}=    flan-t5-small/flan-t5-small-caikit
${FLAN_GRAMMAR_MODEL_S3_DIR}=    flan-t5-large-grammar-synthesis-caikit/flan-t5-large-grammar-synthesis-caikit
${FLAN_LARGE_MODEL_S3_DIR}=    flan-t5-large/flan-t5-large
${BLOOM_MODEL_S3_DIR}=    bloom-560m/bloom-560m-caikit
${FLAN_STORAGE_URI}=    s3://${S3.BUCKET_3.NAME}/${FLAN_MODEL_S3_DIR}/
${FLAN_GRAMMAR_STORAGE_URI}=    s3://${S3.BUCKET_3.NAME}/${FLAN_GRAMMAR_MODEL_S3_DIR}/
${FLAN_LARGE_STORAGE_URI}=    s3://${S3.BUCKET_3.NAME}/${FLAN_LARGE_MODEL_S3_DIR}/
${BLOOM_STORAGE_URI}=    s3://${S3.BUCKET_3.NAME}/${BLOOM_MODEL_S3_DIR}/
${CAIKIT_ALLTOKENS_ENDPOINT}=    caikit.runtime.Nlp.NlpService/TextGenerationTaskPredict
${CAIKIT_STREAM_ENDPOINT}=    caikit.runtime.Nlp.NlpService/ServerStreamingTextGenerationTaskPredict
${CAIKIT_ALLTOKENS_ENDPOINT_HTTP}=    api/v1/task/text-generation
${CAIKIT_STREAM_ENDPOINT_HTTP}=    api/v1/task/server-streaming-text-generation

${SCRIPT_TARGET_OPERATOR}=    rhods    # rhods or brew
${SCRIPT_BREW_TAG}=    ${EMPTY}    # ^[0-9]+$


*** Test Cases ***
Verify External Dependency Operators Can Be Deployed
    [Documentation]    Checks the pre-required Operators can be installed
    ...                and configured
    [Tags]    ODS-2326
    Pass Execution    message=Installation done as part of Suite Setup.

Verify User Can Serve And Query A Model
    [Documentation]    Basic tests for preparing, deploying and querying a LLM model
    ...                using Kserve and Caikit+TGIS runtime
    [Tags]    Smoke    Tier1    ODS-2341
    [Setup]    Set Project And Runtime    namespace=${TEST_NS}
    ${test_namespace}=    Set Variable     ${TEST_NS}
    ${flan_model_name}=    Set Variable    flan-t5-small-caikit
    ${models_names}=    Create List    ${flan_model_name}
    Compile Inference Service YAML    isvc_name=${flan_model_name}
    ...    sa_name=${DEFAULT_BUCKET_SA_NAME}
    ...    model_storage_uri=${FLAN_STORAGE_URI}
    Deploy Model Via CLI    isvc_filepath=${LLM_RESOURCES_DIRPATH}/caikit_isvc_filled.yaml
    ...    namespace=${test_namespace}
    Wait For Pods To Be Ready    label_selector=serving.kserve.io/inferenceservice=${flan_model_name}
    ...    namespace=${test_namespace}
    Query Model Multiple Times    model_name=${flan_model_name}
    ...    endpoint=${CAIKIT_ALLTOKENS_ENDPOINT}    n_times=1
    ...    namespace=${test_namespace}
    Query Model Multiple Times    model_name=${flan_model_name}
    ...    endpoint=${CAIKIT_STREAM_ENDPOINT}    n_times=1    streamed_response=${TRUE}
    ...    namespace=${test_namespace}
    [Teardown]    Clean Up Test Project    test_ns=${test_namespace}
    ...    isvc_names=${models_names}

Verify User Can Deploy Multiple Models In The Same Namespace
    [Documentation]    Checks if user can deploy and query multiple models in the same namespace
    [Tags]    Sanity    Tier1    ODS-2371
    [Setup]    Set Project And Runtime    namespace=${TEST_NS}-multisame
    ${test_namespace}=    Set Variable     ${TEST_NS}-multisame
    ${model_one_name}=    Set Variable    bloom-560m-caikit
    ${model_two_name}=    Set Variable    flan-t5-small-caikit
    ${models_names}=    Create List    ${model_one_name}    ${model_two_name}
    Compile Inference Service YAML    isvc_name=${model_one_name}
    ...    sa_name=${DEFAULT_BUCKET_SA_NAME}
    ...    model_storage_uri=${BLOOM_STORAGE_URI}
    Deploy Model Via CLI    isvc_filepath=${LLM_RESOURCES_DIRPATH}/caikit_isvc_filled.yaml
    ...    namespace=${test_namespace}
    Compile Inference Service YAML    isvc_name=${model_two_name}
    ...    sa_name=${DEFAULT_BUCKET_SA_NAME}
    ...    model_storage_uri=${FLAN_STORAGE_URI}
    Deploy Model Via CLI    isvc_filepath=${LLM_RESOURCES_DIRPATH}/caikit_isvc_filled.yaml
    ...    namespace=${test_namespace}
    Wait For Pods To Be Ready    label_selector=serving.kserve.io/inferenceservice=${model_one_name}
    ...    namespace=${test_namespace}
    Wait For Pods To Be Ready    label_selector=serving.kserve.io/inferenceservice=${model_two_name}
    ...    namespace=${test_namespace}
    Query Model Multiple Times    model_name=${model_one_name}
    ...    n_times=5    namespace=${test_namespace}
    Query Model Multiple Times    model_name=${model_two_name}
    ...    n_times=10    namespace=${test_namespace}
    Query Model Multiple Times    model_name=${model_one_name}
    ...    n_times=5    namespace=${test_namespace}
    Query Model Multiple Times    model_name=${model_two_name}
    ...    n_times=10    namespace=${test_namespace}
    [Teardown]    Clean Up Test Project    test_ns=${test_namespace}
    ...    isvc_names=${models_names}

Verify User Can Deploy Multiple Models In Different Namespaces
    [Documentation]    Checks if user can deploy and query multiple models in the different namespaces
    [Tags]    Sanity    Tier1    ODS-2378
    [Setup]    Run Keywords    Set Project And Runtime    namespace=singlemodel-multi1
    ...        AND
    ...        Set Project And Runtime    namespace=singlemodel-multi2
    ${model_one_name}=    Set Variable    bloom-560m-caikit
    ${model_two_name}=    Set Variable    flan-t5-small-caikit
    ${models_names_ns_1}=    Create List    ${model_one_name}
    ${models_names_ns_2}=    Create List    ${model_two_name}
    Compile Inference Service YAML    isvc_name=${model_one_name}
    ...    sa_name=${DEFAULT_BUCKET_SA_NAME}
    ...    model_storage_uri=${BLOOM_STORAGE_URI}
    Deploy Model Via CLI    isvc_filepath=${LLM_RESOURCES_DIRPATH}/caikit_isvc_filled.yaml
    ...    namespace=singlemodel-multi1
    Compile Inference Service YAML    isvc_name=${model_two_name}
    ...    sa_name=${DEFAULT_BUCKET_SA_NAME}
    ...    model_storage_uri=${FLAN_STORAGE_URI}
    Deploy Model Via CLI    isvc_filepath=${LLM_RESOURCES_DIRPATH}/caikit_isvc_filled.yaml
    ...    namespace=singlemodel-multi2
    Wait For Pods To Be Ready    label_selector=serving.kserve.io/inferenceservice=${model_one_name}
    ...    namespace=singlemodel-multi1
    Wait For Pods To Be Ready    label_selector=serving.kserve.io/inferenceservice=${model_two_name}
    ...    namespace=singlemodel-multi2
    Query Model Multiple Times    model_name=${model_one_name}    n_times=2
    ...    namespace=singlemodel-multi1
    Query Model Multiple Times    model_name=${model_two_name}    n_times=2
    ...    namespace=singlemodel-multi2
    [Teardown]    Run Keywords    Clean Up Test Project    test_ns=singlemodel-multi1    isvc_names=${models_names_ns_1}
    ...           AND
    ...           Clean Up Test Project    test_ns=singlemodel-multi2    isvc_names=${models_names_ns_2}

Verify Model Upgrade Using Canaray Rollout
    [Documentation]    Checks if user can apply Canary Rollout as deployment strategy
    [Tags]    Sanity    Tier1    ODS-2372
    [Setup]    Set Project And Runtime    namespace=canary-model-upgrade
    ${test_namespace}=    Set Variable    canary-model-upgrade
    ${isvc_name}=    Set Variable    canary-caikit
    ${model_name}=    Set Variable    flan-t5-small-caikit
    ${isvcs_names}=    Create List    ${isvc_name}
    ${canary_percentage}=    Set Variable    ${30}
    Compile Deploy And Query LLM model   isvc_name=${isvc_name}
    ...    sa_name=${DEFAULT_BUCKET_SA_NAME}
    ...    model_storage_uri=${FLAN_STORAGE_URI}
    ...    model_name=${model_name}
    ...    namespace=${test_namespace}
    ...    validate_response=${FALSE}
    Log To Console    Applying Canary Tarffic for Model Upgrade
    ${model_name}=    Set Variable    bloom-560m-caikit
    Compile Deploy And Query LLM model   isvc_name=${isvc_name}
    ...    sa_name=${DEFAULT_BUCKET_SA_NAME}
    ...    model_storage_uri=${BLOOM_STORAGE_URI}
    ...    model_name=${model_name}
    ...    canaryTrafficPercent=${canary_percentage}
    ...    namespace=${test_namespace}
    ...    validate_response=${FALSE}
    ...    n_queries=${0}
    Traffic Should Be Redirected Based On Canary Percentage    exp_percentage=${canary_percentage}
    ...    isvc_name=${isvc_name}    model_name=${model_name}    namespace=${test_namespace}
    Log To Console    Remove Canary Tarffic For Model Upgrade
    Compile Deploy And Query LLM model    isvc_name=${isvc_name}
    ...    sa_name=${DEFAULT_BUCKET_SA_NAME}
    ...    model_name=${model_name}
    ...    model_storage_uri=${BLOOM_STORAGE_URI}
    ...    namespace=${test_namespace}
    Traffic Should Be Redirected Based On Canary Percentage    exp_percentage=${100}
    ...    isvc_name=${isvc_name}    model_name=${model_name}    namespace=${test_namespace}
    [Teardown]   Clean Up Test Project    test_ns=${test_namespace}
    ...    isvc_names=${isvcs_names}

Verify Model Pods Are Deleted When No Inference Service Is Present
    [Documentation]    Checks if model pods gets successfully deleted after
    ...                deleting the KServe InferenceService object
    [Tags]    Tier2    ODS-2373
    [Setup]    Set Project And Runtime    namespace=no-infer-kserve
    ${flan_isvc_name}=    Set Variable    flan-t5-small-caikit
    ${model_name}=    Set Variable    flan-t5-small-caikit
    ${models_names}=    Create List    ${model_name}
    Compile Deploy And Query LLM model   isvc_name=${flan_isvc_name}
    ...    sa_name=${DEFAULT_BUCKET_SA_NAME}
    ...    model_storage_uri=${FLAN_STORAGE_URI}
    ...    model_name=${model_name}
    ...    namespace=no-infer-kserve
    Delete InfereceService    isvc_name=${flan_isvc_name}    namespace=no-infer-kserve
    ${rc}    ${out}=    Run And Return Rc And Output    oc wait pod -l serving.kserve.io/inferenceservice=${flan_isvc_name} -n no-infer-kserve --for=delete --timeout=200s
    Should Be Equal As Integers    ${rc}    ${0}
    [Teardown]   Clean Up Test Project    test_ns=no-infer-kserve
    ...    isvc_names=${models_names}   isvc_delete=${FALSE}

Verify User Can Change The Minimum Number Of Replicas For A Model
    [Documentation]    Checks if user can change the minimum number of replicas
    ...                of a deployed model
    [Tags]    Sanity    Tier1    ODS-2376
    [Setup]    Set Project And Runtime    namespace=${TEST_NS}-reps
    ${test_namespace}=    Set Variable     ${TEST_NS}-reps
    ${model_name}=    Set Variable    flan-t5-small-caikit
    ${models_names}=    Create List    ${model_name}
    Compile Inference Service YAML    isvc_name=${model_name}
    ...    sa_name=${DEFAULT_BUCKET_SA_NAME}
    ...    model_storage_uri=${FLAN_STORAGE_URI}
    ...    min_replicas=1
    Deploy Model Via CLI    isvc_filepath=${LLM_RESOURCES_DIRPATH}/caikit_isvc_filled.yaml
    ...    namespace=${test_namespace}
    Wait For Pods To Be Ready    label_selector=serving.kserve.io/inferenceservice=${model_name}
    ...    namespace=${test_namespace}    exp_replicas=1
    Query Model Multiple Times    model_name=${model_name}    n_times=3
    ...    namespace=${test_namespace}
    ${rev_id}=    Set Minimum Replicas Number    n_replicas=3    model_name=${model_name}
    ...    namespace=${test_namespace}
    Wait For Pods To Be Terminated    label_selector=serving.knative.dev/revisionUID=${rev_id}
    ...    namespace=${test_namespace}    timeout=360s
    Wait For Pods To Be Ready    label_selector=serving.kserve.io/inferenceservice=${model_name}
    ...    namespace=${test_namespace}    exp_replicas=3
    Query Model Multiple Times    model_name=${model_name}    n_times=3
    ...    namespace=${test_namespace}
    ${rev_id}=    Set Minimum Replicas Number    n_replicas=1    model_name=${model_name}
    ...    namespace=${test_namespace}
    Wait For Pods To Be Terminated    label_selector=serving.knative.dev/revisionUID=${rev_id}
    ...    namespace=${test_namespace}    timeout=360s
    Wait For Pods To Be Ready    label_selector=serving.kserve.io/inferenceservice=${model_name}
    ...    namespace=${test_namespace}    exp_replicas=1
    Query Model Multiple Times    model_name=${model_name}    n_times=3
    ...    namespace=${test_namespace}
    [Teardown]   Clean Up Test Project    test_ns=${test_namespace}
    ...    isvc_names=${models_names}

Verify User Can Autoscale Using Concurrency
    [Documentation]    Checks if model successfully scale up based on concurrency metrics (KPA)
    [Tags]    Sanity    Tier1    ODS-2377
    [Setup]    Set Project And Runtime    namespace=autoscale-con
    ${test_namespace}=    Set Variable    autoscale-con
    ${flan_model_name}=    Set Variable    flan-t5-small-caikit
    ${model_name}=    Create List    ${flan_model_name}
    Compile Inference Service YAML    isvc_name=${flan_model_name}
    ...    sa_name=${DEFAULT_BUCKET_SA_NAME}
    ...    model_storage_uri=${FLAN_STORAGE_URI}
    ...    auto_scale=True
    Deploy Model Via CLI    isvc_filepath=${LLM_RESOURCES_DIRPATH}/caikit_isvc_filled.yaml
    ...    namespace=${test_namespace}
    Wait For Pods To Be Ready    label_selector=serving.kserve.io/inferenceservice=${flan_model_name}
    ...    namespace=${test_namespace}
    Query Model Multiple Times    model_name=${flan_model_name}    n_times=10
    ...    namespace=${test_namespace}    validate_response=${FALSE}    background=${TRUE}
    Wait For Pods Number    number=1    comparison=GREATER THAN
    ...    label_selector=serving.kserve.io/inferenceservice=${flan_model_name}
    ...    namespace=${test_namespace}
    Wait For Pods To Be Ready    label_selector=serving.kserve.io/inferenceservice=${flan_model_name}
    ...    namespace=${test_namespace}
    [Teardown]   Clean Up Test Project    test_ns=${test_namespace}
    ...    isvc_names=${model_name}

Verify User Can Validate Scale To Zero
    [Documentation]    Checks if model successfully scale down to 0 if there's no traffic
    [Tags]    Sanity    Tier1    ODS-2379
    [Setup]    Set Project And Runtime    namespace=autoscale-zero
    ${flan_model_name}=    Set Variable    flan-t5-small-caikit
    ${model_name}=    Create List    ${flan_model_name}
    Compile Inference Service YAML    isvc_name=${flan_model_name}
    ...    sa_name=${DEFAULT_BUCKET_SA_NAME}
    ...    model_storage_uri=${FLAN_STORAGE_URI}
    Deploy Model Via CLI    isvc_filepath=${LLM_RESOURCES_DIRPATH}/caikit_isvc_filled.yaml
    ...    namespace=autoscale-zero
    Wait For Pods To Be Ready    label_selector=serving.kserve.io/inferenceservice=${flan_model_name}
    ...    namespace=autoscale-zero
    ${host}=    Get KServe Inference Host Via CLI    isvc_name=${flan_model_name}   namespace=autoscale-zero
    ${body}=    Set Variable    '{"text": "At what temperature does liquid Nitrogen boil?"}'
    ${header}=    Set Variable    'mm-model-id: ${flan_model_name}'
    Query Model With GRPCURL   host=${host}    port=443
    ...    endpoint="caikit.runtime.Nlp.NlpService/TextGenerationTaskPredict"
    ...    json_body=${body}    json_header=${header}
    ...    insecure=${TRUE}
    Set Minimum Replicas Number    n_replicas=0    model_name=${flan_model_name}
    ...    namespace=autoscale-zero
    Wait For Pods To Be Ready    label_selector=serving.kserve.io/inferenceservice=${flan_model_name}
    ...    namespace=autoscale-zero
    Wait For Pods To Be Terminated    label_selector=serving.kserve.io/inferenceservice=${flan_model_name}
    ...    namespace=autoscale-zero
    Query Model With GRPCURL   host=${host}    port=443
    ...    endpoint="caikit.runtime.Nlp.NlpService/TextGenerationTaskPredict"
    ...    json_body=${body}    json_header=${header}
    ...    insecure=${TRUE}
    Wait For Pods To Be Ready    label_selector=serving.kserve.io/inferenceservice=${flan_model_name}
    ...    namespace=autoscale-zero
    Wait For Pods To Be Terminated    label_selector=serving.kserve.io/inferenceservice=${flan_model_name}
    ...    namespace=autoscale-zero
    [Teardown]   Clean Up Test Project    test_ns=autoscale-zero
    ...    isvc_names=${model_name}

Verify User Can Set Requests And Limits For A Model
    [Documentation]    Checks if user can set HW request and limits on their inference service object
    [Tags]    Sanity    Tier1    ODS-2380
    [Setup]    Set Project And Runtime    namespace=hw-res
    ${test_namespace}=    Set Variable    hw-res
    ${flan_model_name}=    Set Variable    flan-t5-small-caikit
    ${models_names}=    Create List    ${flan_model_name}
    ${requests}=    Create Dictionary    cpu=1    memory=2Gi
    ${limits}=    Create Dictionary    cpu=2    memory=4Gi
    Compile Inference Service YAML    isvc_name=${flan_model_name}
    ...    sa_name=${DEFAULT_BUCKET_SA_NAME}
    ...    model_storage_uri=${FLAN_STORAGE_URI}
    ...    requests_dict=${requests}    limits_dict=${limits}
    Deploy Model Via CLI    isvc_filepath=${LLM_RESOURCES_DIRPATH}/caikit_isvc_filled.yaml
    ...    namespace=${test_namespace}
    Wait For Pods To Be Ready    label_selector=serving.kserve.io/inferenceservice=${flan_model_name}
    ...    namespace=${test_namespace}
    ${rev_id}=    Get Current Revision ID    model_name=${flan_model_name}
    ...    namespace=${test_namespace}
    Query Model Multiple Times    model_name=${flan_model_name}    n_times=1
    ...    namespace=${test_namespace}
    Container Hardware Resources Should Match Expected    container_name=kserve-container
    ...    pod_label_selector=serving.kserve.io/inferenceservice=${flan_model_name}
    ...    namespace=${test_namespace}    exp_requests=${requests}    exp_limits=${limits}
    ${new_requests}=    Create Dictionary    cpu=2    memory=3Gi
    Set Model Hardware Resources    model_name=${flan_model_name}    namespace=hw-res
    ...    requests=${new_requests}    limits=${NONE}
    Wait For Pods To Be Terminated    label_selector=serving.knative.dev/revisionUID=${rev_id}
    ...    namespace=${test_namespace}
    Wait For Pods To Be Ready    label_selector=serving.kserve.io/inferenceservice=${flan_model_name}
    ...    namespace=${test_namespace}    exp_replicas=1
    Container Hardware Resources Should Match Expected    container_name=kserve-container
    ...    pod_label_selector=serving.kserve.io/inferenceservice=${flan_model_name}
    ...    namespace=${test_namespace}    exp_requests=${new_requests}    exp_limits=${NONE}
    [Teardown]   Clean Up Test Project    test_ns=${test_namespace}
    ...    isvc_names=${models_names}

Verify Model Can Be Served And Query On A GPU Node
    [Documentation]    Basic tests for preparing, deploying and querying a LLM model on GPU node
    ...                using Kserve and Caikit+TGIS runtime
    [Tags]    Sanity    Tier1    ODS-2381    Resources-GPU
    [Setup]    Set Project And Runtime    namespace=singlemodel-gpu
    ${test_namespace}=    Set Variable    singlemodel-gpu
    ${model_name}=    Set Variable    flan-t5-small-caikit
    ${models_names}=    Create List    ${model_name}
    ${requests}=    Create Dictionary    nvidia.com/gpu=1
    ${limits}=    Create Dictionary    nvidia.com/gpu=1
    Compile Inference Service YAML    isvc_name=${model_name}
    ...    sa_name=${DEFAULT_BUCKET_SA_NAME}
    ...    model_storage_uri=${FLAN_STORAGE_URI}
    ...    requests_dict=${requests}    limits_dict=${limits}
    Deploy Model Via CLI    isvc_filepath=${LLM_RESOURCES_DIRPATH}/caikit_isvc_filled.yaml
    ...    namespace=${test_namespace}
    Wait For Pods To Be Ready    label_selector=serving.kserve.io/inferenceservice=${model_name}
    ...    namespace=${test_namespace}
    Container Hardware Resources Should Match Expected    container_name=kserve-container
    ...    pod_label_selector=serving.kserve.io/inferenceservice=${model_name}
    ...    namespace=${test_namespace}    exp_requests=${requests}    exp_limits=${limits}
    Model Pod Should Be Scheduled On A GPU Node    label_selector=serving.kserve.io/inferenceservice=${model_name}
    ...    namespace=${test_namespace}
    Query Model Multiple Times    model_name=${model_name}    n_times=10
    ...    namespace=${test_namespace}
    Query Model Multiple Times    model_name=${model_name}    n_times=5
    ...    namespace=${test_namespace}    endpoint=${CAIKIT_STREAM_ENDPOINT}
    ...    streamed_response=${TRUE}
    [Teardown]   Clean Up Test Project    test_ns=${test_namespace}
    ...    isvc_names=${model_name}

Verify Non Admin Can Serve And Query A Model
    [Documentation]    Basic tests leveraging on a non-admin user for preparing, deploying and querying a LLM model
    ...                using Kserve and Caikit+TGIS runtime
    [Tags]    Smoke    Tier1    ODS-2326
    [Setup]    Run Keywords   Login To OCP Using API    ${TEST_USER_3.USERNAME}    ${TEST_USER_3.PASSWORD}  AND
    ...        Set Project And Runtime    namespace=non-admin-test
    ${test_namespace}=    Set Variable     non-admin-test
    ${flan_model_name}=    Set Variable    flan-t5-small-caikit
    ${models_names}=    Create List    ${flan_model_name}
    Compile Inference Service YAML    isvc_name=${flan_model_name}
    ...    sa_name=${DEFAULT_BUCKET_SA_NAME}
    ...    model_storage_uri=${FLAN_STORAGE_URI}
    Deploy Model Via CLI    isvc_filepath=${LLM_RESOURCES_DIRPATH}/caikit_isvc_filled.yaml
    ...    namespace=${test_namespace}
    Wait For Pods To Be Ready    label_selector=serving.kserve.io/inferenceservice=${flan_model_name}
    ...    namespace=${test_namespace}
    ${host}=    Get KServe Inference Host Via CLI    isvc_name=${flan_model_name}   namespace=${test_namespace}
    ${body}=    Set Variable    '{"text": "${EXP_RESPONSES}[queries][0][query_text]"}'
    ${header}=    Set Variable    'mm-model-id: ${flan_model_name}'
    Query Model Multiple Times    model_name=${flan_model_name}
    ...    endpoint=${CAIKIT_ALLTOKENS_ENDPOINT}    n_times=1
    ...    namespace=${test_namespace}
    Query Model Multiple Times    model_name=${flan_model_name}
    ...    endpoint=${CAIKIT_STREAM_ENDPOINT}    n_times=1    streamed_response=${TRUE}
    ...    namespace=${test_namespace}
    [Teardown]  Run Keywords   Login To OCP Using API    ${OCP_ADMIN_USER.USERNAME}    ${OCP_ADMIN_USER.PASSWORD}   AND
    ...        Clean Up Test Project    test_ns=${test_namespace}   isvc_names=${models_names}

Verify User Can Serve And Query Flan-t5 Grammar Syntax Corrector
    [Documentation]    Deploys and queries flan-t5-large-grammar-synthesis model
    [Tags]    Tier2    ODS-2441
    [Setup]    Set Project And Runtime    namespace=grammar-model
    ${test_namespace}=    Set Variable     grammar-model
    ${flan_model_name}=    Set Variable    flan-t5-large-grammar-synthesis-caikit
    ${models_names}=    Create List    ${flan_model_name}
    Compile Inference Service YAML    isvc_name=${flan_model_name}
    ...    sa_name=${DEFAULT_BUCKET_SA_NAME}
    ...    model_storage_uri=${FLAN_GRAMMAR_STORAGE_URI}
    Deploy Model Via CLI    isvc_filepath=${LLM_RESOURCES_DIRPATH}/caikit_isvc_filled.yaml
    ...    namespace=${test_namespace}
    Wait For Pods To Be Ready    label_selector=serving.kserve.io/inferenceservice=${flan_model_name}
    ...    namespace=${test_namespace}
    Query Model Multiple Times    model_name=${flan_model_name}
    ...    endpoint=${CAIKIT_ALLTOKENS_ENDPOINT}    n_times=1
    ...    namespace=${test_namespace}    query_idx=1
    Query Model Multiple Times    model_name=${flan_model_name}
    ...    endpoint=${CAIKIT_STREAM_ENDPOINT}    n_times=1    streamed_response=${TRUE}
    ...    namespace=${test_namespace}    query_idx=${1}
    [Teardown]    Clean Up Test Project    test_ns=${test_namespace}
    ...    isvc_names=${models_names}

Verify User Can Serve And Query Flan-t5 Large
    [Documentation]    Deploys and queries flan-t5-large model
    [Tags]    Tier2    ODS-2434
    [Setup]    Set Project And Runtime    namespace=flan-t5-large3
    ${test_namespace}=    Set Variable     flan-t5-large3
    ${flan_model_name}=    Set Variable    flan-t5-large
    ${models_names}=    Create List    ${flan_model_name}
    Compile Inference Service YAML    isvc_name=${flan_model_name}
    ...    sa_name=${DEFAULT_BUCKET_SA_NAME}
    ...    model_storage_uri=${FLAN_LARGE_STORAGE_URI}
    Deploy Model Via CLI    isvc_filepath=${LLM_RESOURCES_DIRPATH}/caikit_isvc_filled.yaml
    ...    namespace=${test_namespace}
    Wait For Pods To Be Ready    label_selector=serving.kserve.io/inferenceservice=${flan_model_name}
    ...    namespace=${test_namespace}
    Query Model Multiple Times    model_name=${flan_model_name}
    ...    endpoint=${CAIKIT_ALLTOKENS_ENDPOINT}    n_times=1
    ...    namespace=${test_namespace}    query_idx=${0}
    Query Model Multiple Times    model_name=${flan_model_name}
    ...    endpoint=${CAIKIT_STREAM_ENDPOINT}    n_times=1    streamed_response=${TRUE}
    ...    namespace=${test_namespace}    query_idx=${0}
    [Teardown]    Clean Up Test Project    test_ns=${test_namespace}
    ...    isvc_names=${models_names}

Verify Runtime Upgrade Does Not Affect Deployed Models
    [Documentation]    Upgrades the caikit runtime inthe same NS where a model
    ...                is already deployed. The expecation is that the current model
    ...                must remain unchanged after the runtime upgrade.
    ...                ATTENTION: this is an approximation of the runtime upgrade scenario, however
    ...                the real case scenario will be defined once RHODS actually ships the Caikit runtime.
    [Tags]    Sanity    Tier1    ODS-2404
    [Setup]    Set Project And Runtime    namespace=${TEST_NS}
    ${test_namespace}=    Set Variable     ${TEST_NS}
    ${flan_model_name}=    Set Variable    flan-t5-small-caikit
    ${models_names}=    Create List    ${flan_model_name}
    Compile Inference Service YAML    isvc_name=${flan_model_name}
    ...    sa_name=${DEFAULT_BUCKET_SA_NAME}
    ...    model_storage_uri=${FLAN_STORAGE_URI}
    Deploy Model Via CLI    isvc_filepath=${LLM_RESOURCES_DIRPATH}/caikit_isvc_filled.yaml
    ...    namespace=${test_namespace}
    Wait For Pods To Be Ready    label_selector=serving.kserve.io/inferenceservice=${flan_model_name}
    ...    namespace=${test_namespace}
    Query Model Multiple Times    model_name=${flan_model_name}
    ...    endpoint=${CAIKIT_ALLTOKENS_ENDPOINT}    n_times=1
    ...    namespace=${test_namespace}
    ${created_at}    ${caikitsha}=    Get Model Pods Creation Date And Image URL    model_name=${flan_model_name}
    ...    namespace=${test_namespace}
    Upgrade Caikit Runtime Image    new_image_url=quay.io/opendatahub/caikit-tgis-serving:stable
    ...    namespace=${test_namespace}
    Sleep    5s    reason=Sleep, in case the runtime upgrade takes some time to start performing actions on the pods...
    Wait For Pods To Be Ready    label_selector=serving.kserve.io/inferenceservice=${flan_model_name}
    ...    namespace=${test_namespace}    exp_replicas=1
    ${created_at_after}    ${caikitsha_after}=    Get Model Pods Creation Date And Image URL    model_name=${flan_model_name}
    ...    namespace=${test_namespace}
    Should Be Equal    ${created_at}    ${created_at_after}
    Should Be Equal As Strings    ${caikitsha}    ${caikitsha_after}
    [Teardown]    Clean Up Test Project    test_ns=${test_namespace}
    ...    isvc_names=${models_names}

Verify User Can Access Model Metrics From UWM
    [Documentation]    Verifies that model metrics are available for users in the
    ...                OpenShift monitoring system (UserWorkloadMonitoring)
    ...                PARTIALLY DONE: it is checking number of requests, number of successful requests
    ...                and model pod cpu usage. Waiting for a complete list of expected metrics and
    ...                derived metrics.
    [Tags]    Smoke    Tier1    ODS-2401
    [Setup]    Set Project And Runtime    namespace=singlemodel-metrics    enable_metrics=${TRUE}
    ${test_namespace}=    Set Variable     singlemodel-metrics
    ${flan_model_name}=    Set Variable    flan-t5-small-caikit
    ${models_names}=    Create List    ${flan_model_name}
    ${thanos_url}=    Get OpenShift Thanos URL
    ${token}=    Generate Thanos Token
    Compile Inference Service YAML    isvc_name=${flan_model_name}
    ...    sa_name=${DEFAULT_BUCKET_SA_NAME}
    ...    model_storage_uri=${FLAN_STORAGE_URI}
    Deploy Model Via CLI    isvc_filepath=${LLM_RESOURCES_DIRPATH}/caikit_isvc_filled.yaml
    ...    namespace=${test_namespace}
    Wait For Pods To Be Ready    label_selector=serving.kserve.io/inferenceservice=${flan_model_name}
    ...    namespace=${test_namespace}
    TGI Caikit And Istio Metrics Should Exist    thanos_url=${thanos_url}    thanos_token=${token}
    Query Model Multiple Times    model_name=${flan_model_name}
    ...    endpoint=${CAIKIT_ALLTOKENS_ENDPOINT}    n_times=3
    ...    namespace=${test_namespace}
    Wait Until Keyword Succeeds    50 times    5s
    ...    User Can Fetch Number Of Requests Over Defined Time    thanos_url=${thanos_url}    thanos_token=${token}
    ...    model_name=${flan_model_name}    query_kind=single    namespace=${test_namespace}    period=5m    exp_value=3
    Wait Until Keyword Succeeds    20 times    5s
    ...    User Can Fetch Number Of Successful Requests Over Defined Time    thanos_url=${thanos_url}    thanos_token=${token}
    ...    model_name=${flan_model_name}    namespace=${test_namespace}    period=5m    exp_value=3
    Wait Until Keyword Succeeds    20 times    5s
    ...    User Can Fetch CPU Utilization    thanos_url=${thanos_url}    thanos_token=${token}
    ...    model_name=${flan_model_name}    namespace=${test_namespace}    period=5m
    Query Model Multiple Times    model_name=${flan_model_name}
    ...    endpoint=${CAIKIT_STREAM_ENDPOINT}    n_times=1    streamed_response=${TRUE}
    ...    namespace=${test_namespace}    query_idx=${0}
    Wait Until Keyword Succeeds    30 times    5s
    ...    User Can Fetch Number Of Requests Over Defined Time    thanos_url=${thanos_url}    thanos_token=${token}
    ...    model_name=${flan_model_name}    query_kind=stream    namespace=${test_namespace}    period=5m    exp_value=1
    [Teardown]    Clean Up Test Project    test_ns=${test_namespace}
    ...    isvc_names=${models_names}

Verify User Can Query A Model Using HTTP Calls
    [Documentation]    From RHOAI 2.5 HTTP is allowed and default querying protocol.
    ...                This tests deploys the runtime enabling HTTP port and send queries to the model
    [Tags]    ODS-2501    Smoke    Tier1
    [Setup]    Set Project And Runtime    namespace=kserve-http    protocol=http
    ${test_namespace}=    Set Variable     kserve-http
    ${model_name}=    Set Variable    flan-t5-small-caikit
    ${models_names}=    Create List    ${model_name}
    Compile Inference Service YAML    isvc_name=${model_name}
    ...    sa_name=${DEFAULT_BUCKET_SA_NAME}
    ...    model_storage_uri=${FLAN_STORAGE_URI}
    Deploy Model Via CLI    isvc_filepath=${LLM_RESOURCES_DIRPATH}/caikit_isvc_filled.yaml
    ...    namespace=${test_namespace}
    Wait For Pods To Be Ready    label_selector=serving.kserve.io/inferenceservice=${model_name}
    ...    namespace=${test_namespace}
    Query Model Multiple Times    model_name=${model_name}    protocol=http
    ...    endpoint=${CAIKIT_ALLTOKENS_ENDPOINT_HTTP}    n_times=1    streamed_response=${FALSE}
    ...    namespace=${test_namespace}    query_idx=${0}
    # temporarily disabling stream response validation. Need to re-design the expected response json file
    # because format of streamed response with http is slightly different from grpc
    Query Model Multiple Times    model_name=${model_name}    protocol=http
    ...    endpoint=${CAIKIT_STREAM_ENDPOINT_HTTP}    n_times=1    streamed_response=${TRUE}
    ...    namespace=${test_namespace}    query_idx=${0}    validate_response=${FALSE}
    [Teardown]    Clean Up Test Project    test_ns=${test_namespace}
    ...    isvc_names=${models_names}


*** Keywords ***
Install Model Serving Stack Dependencies
    [Documentation]    Instaling And Configuring dependency operators: Service Mesh and Serverless.
    ...                This is likely going to change in the future and it will include a way to skip installation.
    ...                Caikit runtime will be shipped Out-of-the-box and will be removed from here.
    Skip If Component Is Not Enabled    kserve
    RHOSi Setup
    IF    ${SKIP_PREREQS_INSTALL} == ${FALSE}
        IF    ${SCRIPT_BASED_INSTALL} == ${FALSE}
            Install Service Mesh Stack
            Deploy Service Mesh CRs
            Install Serverless Stack
            Deploy Serverless CRs
            Configure KNative Gateways
        ELSE
            Run Install Script
        END
    END
    Load Expected Responses

Clean Up Test Project
    [Arguments]    ${test_ns}    ${isvc_names}    ${isvc_delete}=${TRUE}
    IF    ${isvc_delete} == ${TRUE}
        FOR    ${index}    ${isvc_name}    IN ENUMERATE    @{isvc_names}
              Log    Deleting ${isvc_name}
              Delete InfereceService    isvc_name=${isvc_name}    namespace=${test_ns}
        END
    ELSE
        Log To Console     InferenceService Delete option not provided by user
    END
    Wait Until Keyword Succeeds    10    1s    Namespace Should Be Removed From ServiceMeshMemberRoll
    ...    namespace=${test_ns}
    ${rc}    ${out}=    Run And Return Rc And Output    oc delete project ${test_ns}
    Should Be Equal As Integers    ${rc}    ${0}
    ${rc}    ${out}=    Run And Return Rc And Output    oc wait --for=delete namespace ${test_ns} --timeout=300s
    Should Be Equal As Integers    ${rc}    ${0}

Load Expected Responses
    [Documentation]    Loads the json file containing the expected answer for each
    ...                query and model
    ${exp_responses}=    Load Json File    ${EXP_RESPONSES_FILEPATH}
    Set Suite Variable    ${EXP_RESPONSES}    ${exp_responses}

Install Service Mesh Stack
    [Documentation]    Installs the operators needed for Service Mesh operator purposes
    Install ISV Operator From OperatorHub Via CLI    operator_name=${SERVICEMESH_OP_NAME}
    ...    subscription_name=${SERVICEMESH_SUB_NAME}
    ...    catalog_source_name=redhat-operators
    Install ISV Operator From OperatorHub Via CLI    operator_name=${KIALI_OP_NAME}
    ...    subscription_name=${KIALI_SUB_NAME}
    ...    catalog_source_name=redhat-operators
    Install ISV Operator From OperatorHub Via CLI    operator_name=${JAEGER_OP_NAME}
    ...    subscription_name=${JAEGER_SUB_NAME}
    ...    catalog_source_name=redhat-operators
    Wait Until Operator Subscription Last Condition Is
    ...    type=CatalogSourcesUnhealthy    status=False
    ...    reason=AllCatalogSourcesHealthy    subcription_name=${SERVICEMESH_SUB_NAME}
    Wait Until Operator Subscription Last Condition Is
    ...    type=CatalogSourcesUnhealthy    status=False
    ...    reason=AllCatalogSourcesHealthy    subcription_name=${KIALI_SUB_NAME}
    Wait Until Operator Subscription Last Condition Is
    ...    type=CatalogSourcesUnhealthy    status=False
    ...    reason=AllCatalogSourcesHealthy    subcription_name=${JAEGER_SUB_NAME}
    # Sleep   30s
    Wait For Pods To Be Ready    label_selector=name=istio-operator
    ...    namespace=${DEFAULT_OP_NS}
    Wait For Pods To Be Ready    label_selector=name=jaeger-operator
    ...    namespace=${DEFAULT_OP_NS}
    Wait For Pods To Be Ready    label_selector=name=kiali-operator
    ...    namespace=${DEFAULT_OP_NS}


Deploy Service Mesh CRs
    [Documentation]    Deploys CustomResources for ServiceMesh operator
    ${rc}    ${out}=    Run And Return Rc And Output    oc new-project ${SERVICEMESH_CR_NS}
    # Should Be Equal As Integers    ${rc}    ${0}
    Copy File     ${SERVICEMESH_CONTROLPLANE_FILEPATH}    ${LLM_RESOURCES_DIRPATH}/smcp_filled.yaml
    ${rc}    ${out}=    Run And Return Rc And Output
    ...    sed -i 's/{{SERVICEMESH_CR_NS}}/${SERVICEMESH_CR_NS}/g' ${LLM_RESOURCES_DIRPATH}/smcp_filled.yaml
    Copy File     ${SERVICEMESH_ROLL_FILEPATH}    ${LLM_RESOURCES_DIRPATH}/smmr_filled.yaml
    ${rc}    ${out}=    Run And Return Rc And Output
    ...    sed -i "s/{{SERVICEMESH_CR_NS}}/${SERVICEMESH_CR_NS}/g" ${LLM_RESOURCES_DIRPATH}/smmr_filled.yaml
    Copy File     ${SERVICEMESH_PEERAUTH_FILEPATH}    ${LLM_RESOURCES_DIRPATH}/peer_auth_filled.yaml
    ${rc}    ${out}=    Run And Return Rc And Output
    ...    sed -i "s/{{SERVICEMESH_CR_NS}}/${SERVICEMESH_CR_NS}/g" ${LLM_RESOURCES_DIRPATH}/peer_auth_filled.yaml
    ${rc}    ${out}=    Run And Return Rc And Output
    ...    sed -i "s/{{SERVERLESS_CR_NS}}/${SERVERLESS_CR_NS}/g" ${LLM_RESOURCES_DIRPATH}/peer_auth_filled.yaml
    ${rc}    ${out}=    Run And Return Rc And Output
    ...    sed -i "s/{{KSERVE_NS}}/${KSERVE_NS}/g" ${LLM_RESOURCES_DIRPATH}/peer_auth_filled.yaml
    ${rc}    ${out}=    Run And Return Rc And Output
    ...    oc apply -f ${LLM_RESOURCES_DIRPATH}/smcp_filled.yaml
    ${rc}    ${out}=    Run And Return Rc And Output
    ...    oc apply -f ${LLM_RESOURCES_DIRPATH}/smcp_filled.yaml
    Should Be Equal As Integers    ${rc}    ${0}
    Wait For Pods To Be Ready    label_selector=app=istiod
    ...    namespace=${SERVICEMESH_CR_NS}
    Wait For Pods To Be Ready    label_selector=app=prometheus
    ...    namespace=${SERVICEMESH_CR_NS}
    Wait For Pods To Be Ready    label_selector=app=istio-ingressgateway
    ...    namespace=${SERVICEMESH_CR_NS}
    Wait For Pods To Be Ready    label_selector=app=istio-egressgateway
    ...    namespace=${SERVICEMESH_CR_NS}
    Wait For Pods To Be Ready    label_selector=app=jaeger
    ...    namespace=${SERVICEMESH_CR_NS}
    Wait For Pods To Be Ready    label_selector=app=kiali
    ...    namespace=${SERVICEMESH_CR_NS}
    Copy File     ${SERVICEMESH_ROLL_FILEPATH}    ${LLM_RESOURCES_DIRPATH}/smmr_filled.yaml
    ${rc}    ${out}=    Run And Return Rc And Output
    ...    sed -i 's/{{SERVICEMESH_CR_NS}}/${SERVICEMESH_CR_NS}/g' ${LLM_RESOURCES_DIRPATH}/smmr_filled.yaml
    Should Be Equal As Integers    ${rc}    ${0}
    ${rc}    ${out}=    Run And Return Rc And Output
    ...    sed -i 's/{{KSERVE_NS}}/${KSERVE_NS}/g' ${LLM_RESOURCES_DIRPATH}/smmr_filled.yaml
    Should Be Equal As Integers    ${rc}    ${0}
    ${rc}    ${out}=    Run And Return Rc And Output
    ...    oc apply -f ${LLM_RESOURCES_DIRPATH}/smmr_filled.yaml
    Should Be Equal As Integers    ${rc}    ${0}
    # Add Namespace To ServiceMeshMemberRoll    namespace=${KSERVE_NS}
    Add Peer Authentication    namespace=${SERVICEMESH_CR_NS}
    Add Peer Authentication    namespace=${KSERVE_NS}

Add Peer Authentication
    [Documentation]    Add a service to the service-to-service auth system of ServiceMesh
    [Arguments]    ${namespace}
    Copy File     ${SERVICEMESH_PEERAUTH_FILEPATH}    ${LLM_RESOURCES_DIRPATH}/peer_auth_${namespace}.yaml
    ${rc}    ${out}=    Run And Return Rc And Output
    ...    sed -i 's/{{NAMESPACE}}/${namespace}/g' ${LLM_RESOURCES_DIRPATH}/peer_auth_${namespace}.yaml
    Should Be Equal As Integers    ${rc}    ${0}
    ${rc}    ${out}=    Run And Return Rc And Output
    ...    oc apply -f ${LLM_RESOURCES_DIRPATH}/peer_auth_${namespace}.yaml
    Should Be Equal As Integers    ${rc}    ${0}

Install Serverless Stack
    [Documentation]    Install the operators needed for Serverless operator purposes
    ${rc}    ${out}=    Run And Return Rc And Output    oc create namespace ${SERVERLESS_NS}
    Install ISV Operator From OperatorHub Via CLI    operator_name=${SERVERLESS_OP_NAME}
    ...    namespace=${SERVERLESS_NS}
    ...    subscription_name=${SERVERLESS_SUB_NAME}
    ...    catalog_source_name=redhat-operators
    ...    operator_group_name=serverless-operators
    ...    operator_group_ns=${SERVERLESS_NS}
    ...    operator_group_target_ns=${NONE}
    Wait Until Operator Subscription Last Condition Is
    ...    type=CatalogSourcesUnhealthy    status=False
    ...    reason=AllCatalogSourcesHealthy    subcription_name=${SERVERLESS_SUB_NAME}
    ...    namespace=${SERVERLESS_NS}
    # Sleep   30s
    Wait For Pods To Be Ready    label_selector=name=knative-openshift
    ...    namespace=${SERVERLESS_NS}
    Wait For Pods To Be Ready    label_selector=name=knative-openshift-ingress
    ...    namespace=${SERVERLESS_NS}
    Wait For Pods To Be Ready    label_selector=name=knative-operator
    ...    namespace=${SERVERLESS_NS}

Deploy Serverless CRs
    [Documentation]    Deploys the CustomResources for Serverless operator
    ${rc}    ${out}=    Run And Return Rc And Output    oc new-project ${SERVERLESS_CR_NS}
    Add Peer Authentication    namespace=${SERVERLESS_CR_NS}
    Add Namespace To ServiceMeshMemberRoll    namespace=${SERVERLESS_CR_NS}
    Copy File     ${SERVERLESS_KNATIVECR_FILEPATH}    ${LLM_RESOURCES_DIRPATH}/knativeserving_istio_filled.yaml
    ${rc}    ${out}=    Run And Return Rc And Output
    ...    sed -i 's/{{SERVERLESS_CR_NS}}/${SERVERLESS_CR_NS}/g' ${LLM_RESOURCES_DIRPATH}/knativeserving_istio_filled.yaml
    Should Be Equal As Integers    ${rc}    ${0}
    ${rc}    ${out}=    Run And Return Rc And Output
    ...    oc apply -f ${LLM_RESOURCES_DIRPATH}/knativeserving_istio_filled.yaml
    Should Be Equal As Integers    ${rc}    ${0}
    Sleep   15s
    Wait For Pods To Be Ready    label_selector=app=controller
    ...    namespace=${SERVERLESS_CR_NS}
    Wait For Pods To Be Ready    label_selector=app=net-istio-controller
    ...    namespace=${SERVERLESS_CR_NS}
    Wait For Pods To Be Ready    label_selector=app=net-istio-webhook
    ...    namespace=${SERVERLESS_CR_NS}
    Wait For Pods To Be Ready    label_selector=app=autoscaler-hpa
    ...    namespace=${SERVERLESS_CR_NS}
    Wait For Pods To Be Ready    label_selector=app=domain-mapping
    ...    namespace=${SERVERLESS_CR_NS}
    Wait For Pods To Be Ready    label_selector=app=webhook
    ...    namespace=${SERVERLESS_CR_NS}
    Wait For Pods To Be Ready    label_selector=app=activator
    ...    namespace=${SERVERLESS_CR_NS}
    Wait For Pods To Be Ready    label_selector=app=autoscaler
    ...    namespace=${SERVERLESS_CR_NS}
    Enable Toleration Feature In KNativeServing    knative_serving_ns=${SERVERLESS_CR_NS}

Configure KNative Gateways
    [Documentation]    Sets up the KNative (Serverless) Gateways
    ${base_dir}=    Set Variable    ods_ci/tmp/certs
    ${exists}=    Run Keyword And Return Status
    ...    Directory Should Exist    ${base_dir}
    IF    ${exists} == ${FALSE}
        Create Directory    ${base_dir}
    END
    ${rc}    ${domain_name}=    Run And Return Rc And Output
    ...    oc get ingresses.config.openshift.io cluster -o jsonpath='{.spec.domain}' | awk -F'.' '{print $(NF-1)"."$NF}'
    Should Be Equal As Integers    ${rc}    ${0}
    ${rc}    ${common_name}=    Run And Return Rc And Output
    ...    oc get ingresses.config.openshift.io cluster -o jsonpath='{.spec.domain}'|sed 's/apps.//'
    Should Be Equal As Integers    ${rc}    ${0}
    ${rc}    ${out}=    Run And Return Rc And Output    ./${WILDCARD_GEN_SCRIPT_FILEPATH} ${base_dir} ${domain_name} ${common_name}
    Should Be Equal As Integers    ${rc}    ${0}
    ${rc}    ${out}=    Run And Return Rc And Output
    ...    oc create secret tls wildcard-certs --cert=${base_dir}/wildcard.crt --key=${base_dir}/wildcard.key -n ${SERVICEMESH_CR_NS}
    Copy File     ${SERVERLESS_GATEWAYS_FILEPATH}    ${LLM_RESOURCES_DIRPATH}/gateways_filled.yaml
    ${rc}    ${out}=    Run And Return Rc And Output
    ...    sed -i 's/{{SERVICEMESH_CR_NS}}/${SERVICEMESH_CR_NS}/g' ${LLM_RESOURCES_DIRPATH}/gateways_filled.yaml
    Should Be Equal As Integers    ${rc}    ${0}
    ${rc}    ${out}=    Run And Return Rc And Output
    ...    sed -i 's/{{SERVERLESS_CR_NS}}/${SERVERLESS_CR_NS}/g' ${LLM_RESOURCES_DIRPATH}/gateways_filled.yaml
    Should Be Equal As Integers    ${rc}    ${0}
    ${rc}    ${out}=    Run And Return Rc And Output
    ...    oc apply -f ${LLM_RESOURCES_DIRPATH}/gateways_filled.yaml
    Should Be Equal As Integers    ${rc}    ${0}


Set Up Test OpenShift Project
    [Documentation]    Creates a test namespace and track it under ServiceMesh
    [Arguments]    ${test_ns}
    ${rc}    ${out}=    Run And Return Rc And Output    oc get project ${test_ns}
    IF    "${rc}" == "${0}"
        Log    message=OpenShift Project ${test_ns} already present. Skipping project setup...
        ...    level=WARN
        RETURN
    END
    ${rc}    ${out}=    Run And Return Rc And Output    oc new-project ${test_ns}
    Should Be Equal As Numbers    ${rc}    ${0}
    # Add Peer Authentication    namespace=${test_ns}
    # Add Namespace To ServiceMeshMemberRoll    namespace=${test_ns}

Deploy Caikit Serving Runtime
    [Documentation]    Create the ServingRuntime CustomResource in the test ${namespace}.
    ...                This must be done before deploying a model which needs Caikit.
    [Arguments]    ${namespace}    ${protocol}
    ${rc}    ${out}=    Run And Return Rc And Output    oc get ServingRuntime caikit-tgis-runtime -n ${namespace}
    IF    "${rc}" == "${0}"
        Log    message=ServingRuntime caikit-tgis-runtime in ${namespace} NS already present. Skipping runtime setup...
        ...    level=WARN
        RETURN
    END
    ${runtime_final_filepath}=    Replace String    string=${CAIKIT_FILEPATH}    search_for={{protocol}}
    ...    replace_with=${protocol}
    ${rc}    ${out}=    Run And Return Rc And Output
    ...    oc apply -f ${runtime_final_filepath} -n ${namespace}
    Should Be Equal As Integers    ${rc}    ${0}

Set Project And Runtime
    [Documentation]    Creates the DS Project (if not exists), creates the data connection for the models,
    ...                creates caikit runtime. This can be used as test setup
    [Arguments]    ${namespace}    ${enable_metrics}=${FALSE}    ${protocol}=grpc
    Set Up Test OpenShift Project    test_ns=${namespace}
    Create Secret For S3-Like Buckets    endpoint=${MODELS_BUCKET.ENDPOINT}
    ...    region=${MODELS_BUCKET.REGION}    namespace=${namespace}
    # temporary step - caikit will be shipped OOTB
    Deploy Caikit Serving Runtime    namespace=${namespace}    protocol=${protocol}
    IF   ${enable_metrics} == ${TRUE}
        Oc Apply    kind=ConfigMap    src=${UWM_CONFIG_FILEPATH}
        Oc Apply    kind=ConfigMap    src=${UWM_ENABLE_FILEPATH}
    ELSE
        Log    message=Skipping UserWorkloadMonitoring enablement.
    END

Create Secret For S3-Like Buckets
    [Documentation]    Configures the cluster to fetch models from a S3-like bucket
    [Arguments]    ${name}=${DEFAULT_BUCKET_SECRET_NAME}    ${sa_name}=${DEFAULT_BUCKET_SA_NAME}
    ...            ${namespace}=${TEST_NS}    ${endpoint}=${S3.AWS_DEFAULT_ENDPOINT}
    ...            ${region}=${S3.AWS_DEFAULT_REGION}    ${access_key_id}=${S3.AWS_ACCESS_KEY_ID}
    ...            ${access_key}=${S3.AWS_SECRET_ACCESS_KEY}    ${use_https}=${USE_BUCKET_HTTPS}
    ${rc}    ${out}=    Run And Return Rc And Output    oc get secret ${name} -n ${namespace}
    IF    "${rc}" == "${0}"
        Log    message=Secret ${name} in ${namespace} NS already present. Skipping secret setup...
        ...    level=WARN
        RETURN
    END
    Copy File     ${BUCKET_SECRET_FILEPATH}    ${LLM_RESOURCES_DIRPATH}/bucket_secret_filled.yaml
    Copy File     ${BUCKET_SA_FILEPATH}    ${LLM_RESOURCES_DIRPATH}/bucket_sa_filled.yaml
    ${endpoint}=    Replace String   ${endpoint}    https://    ${EMPTY}
    ${endpoint_escaped}=    Escape String Chars    str=${endpoint}
    ${accesskey_escaped}=    Escape String Chars    str=${access_key}
    ${rc}    ${out}=    Run And Return Rc And Output
    ...    sed -i 's/{{ENDPOINT}}/${endpoint_escaped}/g' ${LLM_RESOURCES_DIRPATH}/bucket_secret_filled.yaml
    ${rc}    ${out}=    Run And Return Rc And Output
    ...    sed -i 's/{{USE_HTTPS}}/${use_https}/g' ${LLM_RESOURCES_DIRPATH}/bucket_secret_filled.yaml
    ${rc}    ${out}=    Run And Return Rc And Output
    ...    sed -i 's/{{REGION}}/${region}/g' ${LLM_RESOURCES_DIRPATH}/bucket_secret_filled.yaml
    ${rc}    ${out}=    Run And Return Rc And Output
    ...    sed -i 's/{{ACCESS_KEY_ID}}/${access_key_id}/g' ${LLM_RESOURCES_DIRPATH}/bucket_secret_filled.yaml
    ${rc}    ${out}=    Run And Return Rc And Output
    ...    sed -i 's/{{SECRET_ACCESS_KEY}}/${accesskey_escaped}/g' ${LLM_RESOURCES_DIRPATH}/bucket_secret_filled.yaml
        ${rc}    ${out}=    Run And Return Rc And Output
    ...    sed -i 's/{{NAME}}/${name}/g' ${LLM_RESOURCES_DIRPATH}/bucket_secret_filled.yaml
    ${rc}    ${out}=    Run And Return Rc And Output
    ...    sed -i 's/{{NAME}}/${sa_name}/g' ${LLM_RESOURCES_DIRPATH}/bucket_sa_filled.yaml
    ${rc}    ${out}=    Run And Return Rc And Output
    ...    oc apply -f ${LLM_RESOURCES_DIRPATH}/bucket_secret_filled.yaml -n ${namespace}
    Should Be Equal As Integers    ${rc}    ${0}
    Run Keyword And Ignore Error    Run    oc create -f ${LLM_RESOURCES_DIRPATH}/bucket_sa_filled.yaml -n ${namespace}
    Add Secret To Service Account    sa_name=${sa_name}    secret_name=${name}    namespace=${namespace}

Compile Inference Service YAML
    [Documentation]    Prepare the Inference Service YAML file in order to deploy a model
    [Arguments]    ${isvc_name}    ${sa_name}    ${model_storage_uri}    ${canaryTrafficPercent}=${EMPTY}
    ...            ${min_replicas}=1   ${scaleTarget}=1   ${scaleMetric}=concurrency  ${auto_scale}=${NONE}
    ...            ${requests_dict}=&{EMPTY}    ${limits_dict}=&{EMPTY}
    IF   '${auto_scale}' == '${NONE}'
        ${scaleTarget}=    Set Variable    ${EMPTY}
        ${scaleMetric}=    Set Variable    ${EMPTY}
    END
    Set Test Variable    ${isvc_name}
    Set Test Variable    ${min_replicas}
    Set Test Variable    ${sa_name}
    Set Test Variable    ${model_storage_uri}
    Set Test Variable    ${scaleTarget}
    Set Test Variable    ${scaleMetric}
    Set Test Variable    ${canaryTrafficPercent}
    Create File From Template    ${INFERENCESERVICE_FILEPATH}    ${LLM_RESOURCES_DIRPATH}/caikit_isvc_filled.yaml
    IF    ${requests_dict} != &{EMPTY}
        Log    Adding predictor model requests to ${LLM_RESOURCES_DIRPATH}/caikit_isvc_filled.yaml: ${requests_dict}    console=True
        FOR    ${index}    ${resource}    IN ENUMERATE    @{requests_dict.keys()}
            Log    ${index}- ${resource}:${requests_dict}[${resource}]
            ${rc}    ${out}=    Run And Return Rc And Output
            ...    yq -i '.spec.predictor.model.resources.requests."${resource}" = "${requests_dict}[${resource}]"' ${LLM_RESOURCES_DIRPATH}/caikit_isvc_filled.yaml
            Should Be Equal As Integers    ${rc}    ${0}    msg=${out}
        END
    END
    IF    ${limits_dict} != &{EMPTY}
        Log    Adding predictor model limits to ${LLM_RESOURCES_DIRPATH}/caikit_isvc_filled.yaml: ${limits_dict}    console=True
        FOR    ${index}    ${resource}    IN ENUMERATE    @{limits_dict.keys()}
            Log    ${index}- ${resource}:${limits_dict}[${resource}]
            ${rc}    ${out}=    Run And Return Rc And Output
            ...    yq -i '.spec.predictor.model.resources.limits."${resource}" = "${limits_dict}[${resource}]"' ${LLM_RESOURCES_DIRPATH}/caikit_isvc_filled.yaml
            Should Be Equal As Integers    ${rc}    ${0}    msg=${out}
        END
    END

Model Response Should Match The Expectation
    [Documentation]    Checks that the actual model response matches the expected answer.
    ...                The goals are:
    ...                   - to ensure we are getting an answer from the model (e.g., not an empty text)
    ...                   - to check that we receive the answer from the right model
    ...                when multiple ones are deployed
    [Arguments]    ${model_response}    ${model_name}    ${query_idx}    ${streamed_response}=${FALSE}
    IF    ${streamed_response} == ${FALSE}
        Should Be Equal As Integers    ${model_response}[generated_tokens]    ${EXP_RESPONSES}[queries][${query_idx}][models][${model_name}][generatedTokenCount]
        ${cleaned_response_text}=    Replace String Using Regexp    ${model_response}[generated_text]    \\s+    ${SPACE}
        ${cleaned_exp_response_text}=    Replace String Using Regexp    ${EXP_RESPONSES}[queries][${query_idx}][models][${model_name}][response_text]    \\s+    ${SPACE}
        ${cleaned_response_text}=    Strip String    ${cleaned_response_text}
        ${cleaned_exp_response_text}=    Strip String    ${cleaned_exp_response_text}
        Should Be Equal    ${cleaned_response_text}    ${cleaned_exp_response_text}
    ELSE
        # temporarily disabling these lines - will be finalized in later stage due to a different format
        # of streamed reponse when using http protocol instead of grpc
        # ${cleaned_response_text}=    Replace String Using Regexp    ${model_response}    data:(\\s+)?"    "
        # ${cleaned_response_text}=    Replace String Using Regexp    ${cleaned_response_text}    data:(\\s+)?{    {
        # ${cleaned_response_text}=    Replace String Using Regexp    ${cleaned_response_text}    data:(\\s+)?}    }
        # ${cleaned_response_text}=    Replace String Using Regexp    ${cleaned_response_text}    data:(\\s+)?]    ]
        # ${cleaned_response_text}=    Replace String Using Regexp    ${cleaned_response_text}    data:(\\s+)?\\[    [
        ${cleaned_response_text}=    Replace String Using Regexp    ${model_response}    \\s+    ${EMPTY}
        ${rc}    ${cleaned_response_text}=    Run And Return Rc And Output    echo -e '${cleaned_response_text}'
        ${cleaned_response_text}=    Replace String Using Regexp    ${cleaned_response_text}    "    '
        ${cleaned_response_text}=    Replace String Using Regexp    ${cleaned_response_text}
        ...    [-]?\\d.\\d+[e]?[-]?\\d+    <logprob_removed>
        Log    ${cleaned_response_text}
        ${cleaned_exp_response_text}=    Replace String Using Regexp
        ...    ${EXP_RESPONSES}[queries][${query_idx}][models][${model_name}][streamed_response_text]
        ...    [-]?\\d.\\d+[e]?[-]?\\d+    <logprob_removed>
        ${cleaned_exp_response_text}=    Replace String Using Regexp    ${cleaned_exp_response_text}    \\s+    ${EMPTY}
        Should Be Equal    ${cleaned_response_text}    ${cleaned_exp_response_text}
    END

Query Model Multiple Times
    [Documentation]    Queries and checks the responses of the given models in a loop
    ...                running ${n_times}. For each loop run it queries all the model in sequence
    [Arguments]    ${model_name}    ${namespace}    ${isvc_name}=${model_name}
    ...            ${endpoint}=${CAIKIT_ALLTOKENS_ENDPOINT}    ${n_times}=10
    ...            ${streamed_response}=${FALSE}    ${query_idx}=0    ${validate_response}=${TRUE}
    ...            ${protocol}=grpc    &{args}
    IF    ${validate_response} == ${FALSE}
        ${skip_json_load_response}=    Set Variable    ${TRUE}
    ELSE
        ${skip_json_load_response}=    Set Variable    ${streamed_response}    # always skip if using streaming endpoint
    END
    ${host}=    Get KServe Inference Host Via CLI    isvc_name=${isvc_name}   namespace=${namespace}
    IF    "${protocol}" == "grpc"
        ${body}=    Set Variable    '{"text": "${EXP_RESPONSES}[queries][${query_idx}][query_text]"}'
        ${header}=    Set Variable    'mm-model-id: ${model_name}'
    ELSE IF    "${protocol}" == "http"
        ${body}=    Set Variable    {"model_id": "${model_name}","inputs": "${EXP_RESPONSES}[queries][0][query_text]"}
        ${headers}=    Create Dictionary     Cookie=${EMPTY}    Content-type=application/json
    ELSE
        Fail    msg=The ${protocol} protocol is not supported by ods-ci. Please use either grpc or http.
    END
    FOR    ${counter}    IN RANGE    0    ${n_times}    1
        Log    ${counter}
        IF    "${protocol}" == "grpc"
            ${res}=    Query Model With GRPCURL   host=${host}    port=443
            ...    endpoint=${endpoint}
            ...    json_body=${body}    json_header=${header}
            ...    insecure=${TRUE}    skip_res_json=${skip_json_load_response}
            ...    &{args}
        ELSE IF    "${protocol}" == "http"
            ${payload}=     Prepare Payload     body=${body}    str_to_json=${TRUE}
            &{args}=       Create Dictionary     url=https://${host}:443/${endpoint}   expected_status=any
            ...             headers=${headers}   json=${payload}    timeout=10  verify=${False}
            ${res}=    Run Keyword And Continue On Failure     Perform Request     request_type=POST
            ...    skip_res_json=${skip_json_load_response}    &{args}
            Run Keyword And Continue On Failure    Status Should Be  200
        END
        Log    ${res}
        IF    ${validate_response} == ${TRUE}
            Run Keyword And Continue On Failure
            ...    Model Response Should Match The Expectation    model_response=${res}    model_name=${model_name}
            ...    streamed_response=${streamed_response}    query_idx=${query_idx}
        END
    END

Compile Deploy And Query LLM model
    [Documentation]    Group together the test steps for preparing, deploying
    ...                and querying a model
    [Arguments]    ${model_storage_uri}    ${model_name}    ${isvc_name}=${model_name}
    ...            ${canaryTrafficPercent}=${EMPTY}   ${namespace}=${TEST_NS}  ${sa_name}=${DEFAULT_BUCKET_SA_NAME}
    ...            ${n_queries}=${1}    ${query_idx}=${0}    ${validate_response}=${TRUE}
    Compile Inference Service YAML    isvc_name=${isvc_name}
    ...    sa_name=${sa_name}
    ...    model_storage_uri=${model_storage_uri}
    ...    canaryTrafficPercent=${canaryTrafficPercent}
    Deploy Model Via CLI    isvc_filepath=${LLM_RESOURCES_DIRPATH}/caikit_isvc_filled.yaml
    ...    namespace=${namespace}
    Wait For Pods To Be Ready    label_selector=serving.kserve.io/inferenceservice=${isvc_name}
    ...    namespace=${namespace}
    Query Model Multiple Times    isvc_name=${isvc_name}    model_name=${model_name}
    ...    endpoint=${CAIKIT_ALLTOKENS_ENDPOINT}    n_times=${n_queries}    streamed_response=${FALSE}
    ...    namespace=${namespace}    query_idx=${query_idx}    validate_response=${validate_response}

Run Install Script
    [Documentation]    Install KServe serving stack using
    ...                https://github.com/opendatahub-io/caikit-tgis-serving/blob/main/demo/kserve/scripts/README.md
    ${rc}=    Run And Return Rc    git clone https://github.com/opendatahub-io/caikit-tgis-serving
    Should Be Equal As Integers    ${rc}    ${0}
    IF    "${SCRIPT_TARGET_OPERATOR}" == "brew"
        ${rc}=    Run And Watch Command    TARGET_OPERATOR=${SCRIPT_TARGET_OPERATOR} BREW_TAG=${SCRIPT_BREW_TAG} CHECK_UWM=false ./scripts/install/kserve-install.sh
        ...    cwd=caikit-tgis-serving/demo/kserve
    ELSE
        ${rc}=    Run And Watch Command    DEPLOY_ODH_OPERATOR=false TARGET_OPERATOR=${SCRIPT_TARGET_OPERATOR} CHECK_UWM=false ./scripts/install/kserve-install.sh
        ...    cwd=caikit-tgis-serving/demo/kserve
    END
    Should Be Equal As Integers    ${rc}    ${0}

Upgrade Caikit Runtime Image
    [Documentation]    Replaces the image URL of the Caikit Runtim with the given
    ...    ${new_image_url}
    [Arguments]    ${new_image_url}    ${namespace}
    ${rc}    ${out}=    Run And Return Rc And Output
    ...    oc patch ServingRuntime caikit-tgis-runtime -n ${namespace} --type=json -p="[{'op': 'replace', 'path': '/spec/containers/0/image', 'value': '${new_image_url}'}]"    # robocop: disable
    Should Be Equal As Integers    ${rc}    ${0}

Get Model Pods Creation Date And Image URL
    [Documentation]    Fetches the creation date and the caikit runtime image URL.
    ...                Useful in upgrade scenarios
    [Arguments]    ${model_name}    ${namespace}
    ${created_at}=    Oc Get    kind=Pod    label_selector=serving.kserve.io/inferenceservice=${model_name}
    ...    namespace=${namespace}    fields=["metadata.creationTimestamp"]
    ${rc}    ${caikitsha}=    Run And Return Rc And Output
    ...    oc get pod --selector serving.kserve.io/inferenceservice=${model_name} -n ${namespace} -ojson | jq '.items[].spec.containers[].image' | grep caikit-tgis    # robocop: disable
    Should Be Equal As Integers    ${rc}    ${0}
    RETURN    ${created_at}    ${caikitsha}

User Can Fetch Number Of Requests Over Defined Time
    [Documentation]    Fetches the `tgi_request_count` metric and checks that it reports the expected
    ...                model information (name, namespace, pod name and type of request).
    ...                If ${exp_value} is given, it checks also the metric value
    [Arguments]    ${thanos_url}    ${thanos_token}    ${model_name}    ${namespace}
    ...           ${query_kind}=single    ${period}=30m    ${exp_value}=${EMPTY}
    ${resp}=    Prometheus.Run Query    https://${thanos_url}    ${thanos_token}    tgi_request_count[${period}]
    Log    ${resp.json()["data"]}
    Check Query Response Values    response=${resp}    exp_namespace=${namespace}
    ...    exp_model_name=${model_name}    exp_query_kind=${query_kind}    exp_value=${exp_value}

User Can Fetch Number Of Successful Requests Over Defined Time
    [Documentation]    Fetches the `tgi_request_success` metric and checks that it reports the expected
    ...                model information (name, namespace and type of request).
    ...                If ${exp_value} is given, it checks also the metric value
    [Arguments]    ${thanos_url}    ${thanos_token}    ${model_name}    ${namespace}
    ...            ${query_kind}=single    ${period}=30m    ${exp_value}=${EMPTY}
    ${resp}=    Prometheus.Run Query    https://${thanos_url}    ${thanos_token}    tgi_request_success[${period}]
    Log    ${resp.json()["data"]}
    Check Query Response Values    response=${resp}    exp_namespace=${namespace}
    ...    exp_model_name=${model_name}    exp_query_kind=${query_kind}    exp_value=${exp_value}

User Can Fetch CPU Utilization
    [Documentation]    Fetches the `pod:container_cpu_usage:sum` metric and checks that it reports the expected
    ...                model information (pod name and namespace).
    ...                If ${exp_value} is given, it checks also the metric value
    [Arguments]    ${thanos_url}    ${thanos_token}    ${namespace}    ${model_name}    ${period}=30m    ${exp_value}=${EMPTY}
    ${resp}=    Prometheus.Run Query    https://${thanos_url}    ${thanos_token}    pod:container_cpu_usage:sum{namespace="${namespace}"}[${period}]
    ${pod_name}=    Oc Get    kind=Pod    namespace=${namespace}
    ...    label_selector=serving.kserve.io/inferenceservice=${model_name}
    ...    fields=['metadata.name']
    Log    ${resp.json()["data"]}
    Check Query Response Values    response=${resp}    exp_namespace=${namespace}
    ...    exp_pod_name=${pod_name}[0][metadata.name]    exp_value=${exp_value}

TGI Caikit And Istio Metrics Should Exist
    [Documentation]    Checks that the `tgi_`, `caikit_` and `istio_` metrics exist.
    ...                Returns the list of metrics names
    [Arguments]    ${thanos_url}    ${thanos_token}
    ${tgi_metrics_names}=    Get Thanos Metrics List    thanos_url=${thanos_url}    thanos_token=${thanos_token}
    ...    search_text=tgi
    Should Not Be Empty    ${tgi_metrics_names}
    ${tgi_metrics_names}=    Split To Lines    ${tgi_metrics_names}
    ${caikit_metrics_names}=    Get Thanos Metrics List    thanos_url=${thanos_url}    thanos_token=${thanos_token}
    ...    search_text=caikit
    ${caikit_metrics_names}=    Split To Lines    ${caikit_metrics_names}
    ${istio_metrics_names}=    Get Thanos Metrics List    thanos_url=${thanos_url}    thanos_token=${thanos_token}
    ...    search_text=istio
    ${istio_metrics_names}=    Split To Lines    ${istio_metrics_names}
    ${metrics}=    Append To List    ${tgi_metrics_names}    @{caikit_metrics_names}    @{istio_metrics_names}
    RETURN    ${metrics}

Check Query Response Values    # robocop:disable
    [Documentation]    Implements the metric checks for `User Can Fetch Number Of Requests Over Defined Time`
    ...                `User Can Fetch Number Of Successful Requests Over Defined Time` and `User Can Fetch CPU Utilization`.
    ...                It searches among the available metric values for the specific model
    [Arguments]    ${response}    ${exp_namespace}    ${exp_model_name}=${EMPTY}    ${exp_query_kind}=${EMPTY}    ${exp_value}=${EMPTY}    ${exp_pod_name}=${EMPTY}
    ${json_results}=    Set Variable    ${response.json()["data"]["result"]}
    FOR    ${index}    ${result}    IN ENUMERATE    @{json_results}
        Log    ${index}: ${result}
        ${value_keyname}=    Run Keyword And Return Status
        ...    Dictionary Should Contain Key    ${result}    value
        IF    ${value_keyname} == ${TRUE}
            ${curr_value}=    Set Variable    ${result["value"][-1]}
        ELSE
            ${curr_value}=    Set Variable    ${result["values"][-1][-1]}
        END
        ${source_namespace}=    Set Variable    ${result["metric"]["namespace"]}
        ${checked}=    Run Keyword And Return Status    Should Be Equal As Strings    ${source_namespace}    ${exp_namespace}
        IF    ${checked} == ${FALSE}
            Continue For Loop
        ELSE
            Log    message=Metrics source namespaced succesfully checked. Going to next step.      
        END
        IF    "${exp_model_name}" != "${EMPTY}"
            ${source_model}=    Set Variable    ${result["metric"]["job"]}
            ${checked}=    Run Keyword And Return Status    Should Be Equal As Strings    ${source_model}
            ...    ${exp_model_name}-metrics
            IF    ${checked} == ${FALSE}
                Continue For Loop
            ELSE
                Log    message=Metrics source model succesfully checked. Going to next step.      
            END
            IF    "${exp_query_kind}" != "${EMPTY}"
                ${source_query_kind}=    Set Variable    ${result["metric"]["kind"]}
                ${checked}=    Run Keyword And Return Status    Should Be Equal As Strings    ${source_query_kind}
                ...    ${exp_query_kind}
                IF    ${checked} == ${FALSE}
                    Continue For Loop
                ELSE
                    Log    message=Metrics query kind succesfully checked. Going to next step.      
                END
            END
        END
        IF    "${exp_pod_name}" != "${EMPTY}"
            ${source_pod}=    Set Variable    ${result["metric"]["pod"]}
            ${checked}=    Run Keyword And Return Status    Should Be Equal As Strings    ${source_pod}
            ...    ${exp_pod_name}
            IF    ${checked} == ${FALSE}
                Continue For Loop
            ELSE
                Log    message=Metrics source pod succesfully checked. Going to next step.      
            END
        END
        IF    "${exp_value}" != "${EMPTY}"
            Run Keyword And Continue On Failure    Should Be Equal As Strings    ${curr_value}    ${exp_value}
        ELSE
            Run Keyword And Continue On Failure    Should Not Be Empty    ${curr_value}
        END
        IF    ${checked} == ${TRUE}
            Log    message=The desired query result has been found.
            Exit For Loop
        END
    END
    IF    ${checked} == ${FALSE}
        Fail    msg=The metric you are looking for has not been found. Check the query parameter and try again 
    END

Traffic Should Be Redirected Based On Canary Percentage
    [Documentation]    Sends an arbitrary number of queries ${total} and checks the amount of
    ...                them which gets redirected to the given ${model_name}
    ...                matches the expected probability ${exp_percentage}.
    ...                It applies an arbitrary toleration margin of ${toleration}
    [Arguments]    ${exp_percentage}    ${isvc_name}    ${model_name}    ${namespace}
    ${total}=    Set Variable    ${20}
    ${hits}=    Set Variable    ${0}
    ${toleration}=    Set Variable    ${20}
    FOR    ${counter}    IN RANGE    ${0}    ${total}
        Log    ${counter}
        ${status}=    Run Keyword And Return Status
        ...    Query Model Multiple Times    isvc_name=${isvc_name}    model_name=${model_name}    n_times=1
        ...    namespace=${namespace}
        IF    ${status} == ${TRUE}
            ${hits}=    Evaluate    ${hits}+1
        END
    END
    Log    ${hits}
    ${actual_percentage}=    Evaluate    (${hits}/${total})*100
    ${diff}=    Evaluate    abs(${exp_percentage}-${actual_percentage})
    IF    ${diff} > ${toleration} or ${actual_percentage} == ${0}
        Fail    msg=Percentage of traffic redirected to new revision is greater than toleration ${toleration}%
    END
