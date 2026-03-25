#!/usr/bin/bash

#####
# Name: S3 interaction suite
# Description: Read meta, download objects from or upload to S3-compatible storage
# Req: read-write access on current working directory


# constants and variables declaration
declare STR_NAME="$(basename "${0}")";
declare STR_SHORT_O=":b:,r:,f:,p:,S:,a:,s:,o:,l:,h";
#declare args_passed="";

declare backend='OLDCURL';
declare req='';
declare fqdn='';
declare port='443';
declare sigstring='aws:amz:ru-central1:s3';
declare key_id='';
declare key_s='';
declare obj='';
declare local_path='';

declare -i method_result=-1;

# functions declaration

function perform_basic_utility_checks() {
    ############################################################
    # DESCR: Check that all base utilities needed for
    #        supporting the program is available
    ############################################################

    declare -a tools=( 'awk' 'base64' 'basename' 'date' 'cut' 'getopts' 'head' 'logger' 'openssl' 'tail' 'test' 'wc' '[[' );
    declare exists='';
    declare -i w_exc=-1;

    # check toolings exist
    for utility in "${tools[@]}"
    do {
        exists="$(command -v "${utility}")";
        w_exc=${?};

        if [ -z "${exists}" ] || [ ${w_exc} -ne 0 ]; 
        then {
            echo "Cannot start script ${0}, utility \"${utility}\" is missing!";
            exit 1;
        }
        fi;
    }
    done;

    return 0;
}

function perform_access_checks() {
    ############################################################
    # DESCR: Checks if target directory or target uploaded file
    #        is accessible for read/write operations
    # ARGS:
    #   (1) - exact file name
    ############################################################

    logger --id --rfc5424 --tag 'debug' --priority 'local7.debug' -- "[${STR_NAME}]: perform_access_checks, func called with args(${#}): [${*}].";

    if [ -z "${1}" ]; 
    then {
        logger --id --rfc5424 --stderr --tag 'error' --priority 'local7.error' -- "[${STR_NAME}]: perform_access_checks, file name not set: \'${1}\'.";
        return 1;
    }
    fi;
    if [ ! -f "${1}" ]; 
    then {
        logger --id --rfc5424 --stderr --tag 'error' --priority 'local7.error' -- "[${STR_NAME}]: perform_access_checks, file \'${1}\' does not exist!";
        return 1; 
    }
    fi;
    if [ ! -r "${1}" ]; 
    then {
        logger --id --rfc5424 --stderr --tag 'error' --priority 'local7.error' -- "[${STR_NAME}]: perform_access_checks, file \'${1}\' is not readable!";
        return 1;
    }
    fi;
    if [ ! -w "${1}" ]; 
    then {
        logger --id --rfc5424 --stderr --tag 'error' --priority 'local7.error' -- "[${STR_NAME}]: perform_access_checks, file \'${1}\' is not writable!";
        return 1;
    }
    fi;

    logger --id --rfc5424 --tag 'debug' --priority 'local7.debug' -- "[${STR_NAME}]: perform_access_checks, all checks passed."

    return 0;
}

function perform_args_checks() {
    ############################################################
    # DESCR: Checks if target directory or target uploaded file
    #        is accessible for read/write operations
    # ARGS:
    #   (1) - request type
    #   (2) - backend
    ############################################################

    logger --id --rfc5424 --tag 'debug' --priority 'local7.debug' -- "[${STR_NAME}]: perform_args_checks, checking request type.";
    case "${1}" in
        'GET' | 'HEAD' | 'PUT')
            logger --id --rfc5424 --tag 'debug' --priority 'local7.debug' -- "[${STR_NAME}]: perform_args_checks, request type is correct.";
            ;;
        *)
            logger --id --rfc5424 --tag 'error' --priority 'local7.error' -- "[${STR_NAME}]: perform_args_checks, unsupported request type.";
            return 1;
            ;;
    esac;

    logger --id --rfc5424 --tag 'debug' --priority 'local7.debug' -- "[${STR_NAME}]: perform_args_checks, checking backend value.";
    case "${1}" in
        'GET' | 'HEAD' | 'PUT')
            logger --id --rfc5424 --tag 'debug' --priority 'local7.debug' -- "[${STR_NAME}]: perform_args_checks, backend value is correct.";
            ;;
        *)
            logger --id --rfc5424 --tag 'error' --priority 'local7.error' -- "[${STR_NAME}]: perform_args_checks, unsupported backend.";
            return 1;
            ;;
    esac;

    return 0;
}

function perform_tooling_utility_checks() {
    ############################################################
    # DESCR: Check that all needed tooling is available and all
    #        needed permissions are granted
    # ARGS: 
    #   (1) - used backend
    ############################################################

    logger --id --rfc5424 --tag 'debug' --priority 'local7.debug' -- "[${STR_NAME}]: perform_tooling_utility_checks, func called with args(${#}): [${*}].";

    declare FLOAT_OLD_CURL_MAX_VER='8.2.1';

    declare current_curl_ver='';
    declare exists='';

    logger --id --rfc5424 --tag 'debug' --priority 'local7.debug' -- "[${STR_NAME}]: perform_tooling_utility_checks, checking backend ${1} exists...";
    case "${1}" in
        'OLDCURL' | 'CURL')
            exists="$(command -v 'curl';)";
            current_curl_ver=$(curl --version | awk -F' ' '{print $2;}' | head -n 1;)
            logger --id --rfc5424 --tag 'debug' --priority 'local7.debug' -- "[${STR_NAME}]: perform_tooling_utility_checks, gathered cURL version is ${current_curl_ver}";
            ;;
        'WGET')
            exists="$(command -v 'wget';)";
            ;;
        'OPENSSL')
            exists="$(command -v 'openssl';)";
            ;;
        'NETCAT')
            exists="$(command -v 'netcat';)";
            ;;
        *)
            logger --id --rfc5424 --stderr --tag 'error' --priority 'local7.error' -- "[${STR_NAME}]: perform_tooling_utility_checks, Unsupported backend type. Aborting.";
            exit 1;
            ;;
    esac;
    if [ -z "${exists}" ];
    then {
        logger --id --rfc5424 --stderr --tag 'error' --priority 'local7.error' -- "[${STR_NAME}]: perform_tooling_utility_checks, backend ${1} does not persist in the system. Aborting with error.";
        exit 1;
    }
    fi;

    case "${1}" in
        'CURL')
            exists=$(printf '%s\n' "${FLOAT_OLD_CURL_MAX_VER}" "${current_curl_ver}" | sort --numeric-sort - | head --lines 1 -);  # highest curl's version stored here
            ;;
        'OLDCURL')
            # note a --reverse key here!
            exists=$(printf '%s\n' "${FLOAT_OLD_CURL_MAX_VER}" "${current_curl_ver}" | sort --version-sort --reverse - | head --lines=1 -);  # highest curl's version stored here
            ;;
        *)
            logger --id --rfc5424 --tag 'debug' --priority 'local7.debug' -- "[${STR_NAME}]: perform_tooling_utility_checks, choosen backend persist.";
            return 0;
            ;;
    esac;

    if [ "${exists}" == "${FLOAT_OLD_CURL_MAX_VER}" ];
    then {
        logger --id --rfc5424 --stderr --tag 'error' --priority 'local7.error' -- "[${STR_NAME}]: perform_tooling_utility_checks, gathered cURL version is not supported by this backend option. Aborting.";
        exit 1;
    }
    fi;

    logger --id --rfc5424 --tag 'debug' --priority 'local7.debug' -- "[${STR_NAME}]: perform_tooling_utility_checks, choosen backend persist.";

    return 0;
}

function perform_request_to_s3() {
    ############################################################
    # DESCR: This method performs http request to s3-storage 
    #        with selected backend and arguments
    # ARGS: 
    #   (1) - HTTP method
    #   (2) - selected backend
    #   (3) - S3 FQDN
    #   (4) - S3 destination port
    #   (5) - Access key ID
    #   (6) - Secret key
    #   (7) - Object name (with bucket)
    #   (8) - Local file name (optional)
    #   (9) - AWS sigstring (optional)
    ############################################################

    logger --id --rfc5424 --tag 'debug' --priority 'local7.debug' -- "[${STR_NAME}]: perform_request_to_s3, func called with args(${#}): [${*}].";

    declare dt_val='';  # used as global var in
    declare str_to_sign='';  # used as global var 
    declare signature='';  # used as global var 

    declare response='';
    declare response_code='';
    declare -i exit_code=0;

    declare query_line='';
    declare header_host='';
    declare header_content_len='0';
    declare header_content_type='Content-Type: application/octet-stream';
    declare header_date='';
    declare header_authorization='';
    declare header_accept='Accept: */*';
    declare header_user_agent='';

    dt_val="$(date -R)";
    str_to_sign="${1}\n\napplication/octet-stream\n${dt_val}\n/${7}";
    signature="$(echo -en "${str_to_sign}" | openssl sha1 -hmac "${6}" -binary | base64 -)";

    if [ "${1}" == "PUT" ]; then {
        logger --id --rfc5424 --tag 'debug' --priority 'local7.debug' -- "[${STR_NAME}]: perform_request_to_s3, checking file permissions for ${1} request.";
        perform_access_checks "${8}";
        response_code=${?};
        if [ ${response_code} -ne 0 ];  then {
            logger --id --rfc5424 --stderr --tag 'error' --priority 'local7.error' -- "[${STR_NAME}]: perform_request_to_s3, ${1} request cannot be performed, not enough permissions.";
            return 1;
        }
        fi;
        logger --id --rfc5424 --tag 'debug' --priority 'local7.debug' -- "[${STR_NAME}]: perform_request_to_s3, file permissions checks passed.";
    }
    fi;

    query_line="${1} /${7} HTTP/1.1";
    header_authorization="Authorization: AWS ${5}:${signature}";
    header_date="Date: ${dt_val}";
    header_host="Host: ${3}";
    if [[ -z "${8}" ]];
    then { header_content_len="Contetn-Length: $(wc --bytes < "${8}")"; };
    fi;

    logger --id --rfc5424 --tag 'debug' --priority 'local7.debug' -- "[${STR_NAME}]: perform_request_to_s3, ${2} selected as backend.";
    case "${2}" in
        'CURL') 
            logger --id --rfc5424 --tag 'debug' --priority 'local7.debug' -- "[${STR_NAME}]: perform_request_to_s3, performing \'${1}\' request.";
            case "${1}" in 
                'GET')
                    if [ -z "${7}" ]; then {
                        logger --id --rfc5424 --tag 'debug' --priority 'local7.debug' -- "[${STR_NAME}]: perform_request_to_s3, Argument \'local path\' is not set. Downloaded data will be saved with s3-object name.";
                        response="$(curl --location --silent --request 'GET' \
                                           --header "${header_content_type}" \
                                           --aws-sigv4 "${9}" \
                                           --user "${5}:${6}" \
                                           --write-out "%{response_code}" \
                                           --url "https://${3}:${4}/${7}" \
                                           --remote-name;)";
                    }
                    else {
                        logger --id --rfc5424 --tag 'debug' --priority 'local7.debug' -- "[${STR_NAME}]: perform_request_to_s3, Argument \'local path\' is set. Downloaded data will be saved as ${8}.";
                        response="$(curl --location --silent --request 'GET' \
                                           --header "${header_content_type}" \
                                           --aws-sigv4 "${9}" \
                                           --user "${5}:${6}" \
                                           --write-out "%{response_code}" \
                                           --url "https://${3}:${4}/${7}" \
                                           --output "${8}";)";
                    }
                    fi;
                    ;;
                'HEAD')
                    response="$(curl --silent --location --head \
                                    --header "${header_content_type}" \
                                    --aws-sigv4 "${9}" \
                                    --user "${5}:${6}" \
                                    --write-out "%{response_code}" \
                                    --url "https://${3}:${4}/${7}";)";
                    ;;
                'PUT')
                    response="$(curl --location --silent --request 'PUT' \
                         --header "${header_content_type}" \
                         --aws-sigv4 "${5}" \
                         --user "${3}:${4}" \
                         --write-out "%{response_code}" \
                         --url "https://${1}:${2}/${6}" \
                         --upload-file "${7}";)";
                    ;;
            esac;

            logger --id --rfc5424 --tag 'debug' --priority 'local7.debug' -- "[${STR_NAME}]: perform_request_to_s3, request performed. Parsing result.";
            response_code=${response};
            logger --id --rfc5424 --tag 'debug' --priority 'local7.debug' -- "[${STR_NAME}]: perform_request_to_s3, Result parsed.";
            ;;
        'NETCAT')
            logger --id --rfc5424 --tag 'debug' --priority 'local7.debug' -- "[${STR_NAME}]: perform_request_to_s3, performing \'${1}\' request.";
            (printf '%s\r\n' "${query_line}";
             printf '%s\r\n' "${header_accept}";
             printf '%s\r\n' "${header_content_len}";
             printf '%s\r\n' "${header_content_type}";
             printf '%s\r\n' "${header_date}";
             printf '%s\r\n' "${header_host}";
             printf '%s\r\n' "${header_user_agent}";
             printf '%s\r\n' "${header_authorization}";
             printf '\r\n';
             if [ "${1}" == 'PUT' ]; then { cat "${8}"; }
             fi; ) |\
            netcat "${3}" "${4}" > "${8}.tmp";
            
            logger --id --rfc5424 --tag 'debug' --priority 'local7.debug' -- "[${STR_NAME}]: perform_request_to_s3, request performed. Parsing result.";
            response_code=$(head --silent --lines=1 "${8}.tmp" | awk -F' ' '/HTTP\/[0-9.]+/{print $2}';);
            logger --id --rfc5424 --tag 'debug' --priority 'local7.debug' -- "[${STR_NAME}]: perform_request_to_s3, Result parsed.";
            ;;
        'OLDCURL')
            logger --id --rfc5424 --tag 'debug' --priority 'local7.debug' -- "[${STR_NAME}]: perform_request_to_s3, perform_request_to_s3, performing \'${1}\' request.";
            case "${1}" in 
                'GET')
                    if [ -z "${8}" ]; then {
                        logger --id --rfc5424 --tag 'debug' --priority 'local7.debug' -- "[${STR_NAME}]: Argument \'local path\' is not set. Downloaded data will be saved with s3-object name.";
                        response="$(curl --location --silent --request 'GET' \
                                        --header "${header_host}" \
                                        --header "${header_date}" \
                                        --header "${header_content_type}" \
                                        --header "${header_authorization}" \
                                        --write-out "%{http_code}" \
                                        --url "https://${3}:${4}/${7}" \
                                        --remote-name ;)";
                    }
                    else {
                        logger --id --rfc5424 --tag 'debug' --priority 'local7.debug' -- "[${STR_NAME}]: Argument \'local path\' is set. Downloaded data will be saved as ${5}.";
                        response="$(curl --location --silent --request 'GET' \
                                        --header "${header_host}" \
                                        --header "${header_date}" \
                                        --header "${header_content_type}" \
                                        --header "${header_authorization}" \
                                        --write-out "%{http_code}" \
                                        --url "https://${3}:${4}/${7}" \
                                        --output "${8}";)";
                    }
                    fi;
                    ;;
                'HEAD')
                    response="$(curl --location --silent --head \
                                    --header "${header_host}" \
                                    --header "${header_date}" \
                                    --header "${header_content_type}" \
                                    --header "${header_authorization}" \
                                    --write-out "%{http_code}" \
                                    --output '/dev/null' \
                                    --url "https://${3}:${4}/${7}";)";
                    ;;
                'PUT')
                    response="$(curl --location --silent --request 'PUT' \
                                    --header "${header_host}" \
                                    --header "${header_date}" \
                                    --header "${header_content_type}" \
                                    --header "${header_authorization}" \
                                    --write-out "%{http_code}" \
                                    --url "https://${3}:${4}/${7}" \
                                    --upload-file "${8}";)";
                    ;;
            esac;

            logger --id --rfc5424 --tag 'debug' --priority 'local7.debug' -- "[${STR_NAME}]: perform_request_to_s3, request performed. Parsing result.";
            response_code=${response};
            logger --id --rfc5424 --tag 'debug' --priority 'local7.debug' -- "[${STR_NAME}]: perform_request_to_s3, Result parsed.";
            ;;
        'OPENSSL')
            logger --id --rfc5424 --tag 'debug' --priority 'local7.debug' -- "[${STR_NAME}]: perform_request_to_s3, performing \'${1}\' request.";
            (printf '%s\r\n' "${query_line}";
             printf '%s\r\n' "${header_accept}";
             printf '%s\r\n' "${header_content_len}";
             printf '%s\r\n' "${header_content_type}";
             printf '%s\r\n' "${header_date}";
             printf '%s\r\n' "${header_host}";
             printf '%s\r\n' "${header_user_agent}";
             printf '%s\r\n' "${header_authorization}";
             printf '\r\n';
             if [ "${1}" == 'PUT' ]; then { cat "${8}"; }
             fi; ) |\
            openssl s_client -quiet -ign_eof -connect "${3}:${4}" > "${8}.tmp";

            logger --id --rfc5424 --tag 'debug' --priority 'local7.debug' -- "[${STR_NAME}]: perform_request_to_s3, request performed. Parsing result.";
            response_code=$(head --silent --lines=1 "${8}.tmp" | awk -F' ' '/HTTP\/[0-9.]+/{print $2}';);
            logger --id --rfc5424 --tag 'debug' --priority 'local7.debug' -- "[${STR_NAME}]: perform_request_to_s3, Result parsed.";
            ;;
        'WGET')
            logger --id --rfc5424 --tag 'debug' --priority 'local7.debug' -- "[${STR_NAME}]: perform_request_to_s3, performing \'${1}\' request.";
            case "${1}" in 
                'GET')
                    if [ -z "${8}" ]; then {
                        logger --id --rfc5424 --tag 'debug' --priority 'local7.debug' -- "[${STR_NAME}]: perform_request_to_s3, ";
                        response="$(wget --quiet --no-check-certificate --no-http-keep-alive --server-response --method='GET' \
                                        --header="${header_authorization}" \
                                        --header="${header_content_type}" \
                                        --header="${header_date}" \
                                        --header="${header_host}" \
                                        "https://${3}:${4}/${7}" 2>&1;)";
                    }
                    else {
                        logger --id --rfc5424 --tag 'debug' --priority 'local7.debug' -- "[${STR_NAME}]: perform_request_to_s3, ";
                        response="$(wget --quiet --no-check-certificate --no-http-keep-alive --server-response --method='GET' \
                                        --header="${header_authorization}" \
                                        --header="${header_content_type}" \
                                        --header="${header_date}" \
                                        --header="${header_host}" \
                                        --output-document="${8}" \
                                        "https://${3}:${4}/${7}" 2>&1)";
                    }
                    fi;
                    ;;
                'HEAD')
                    response="$(wget --quiet --no-check-certificate --no-http-keep-alive --server-response --method='HEAD' \
                                    --header="${header_authorization}" \
                                    --header="${header_content_type}" \
                                    --header="${header_date}" \
                                    --header="${header_host}" \
                                    --spider  \
                                    "https://${3}:${4}/${7}" 2>&1)";
                    ;;
                'PUT')
                    response="$(wget --quiet --no-check-certificate --no-http-keep-alive --server-response --method='PUT' \
                                    --header="${header_authorization}" \
                                    --header="${header_content_type}" \
                                    --header="${header_date}" \
                                    --header="${header_host}" \
                                    --header= "${header_content_len}"\
                                    --body-file="${8}" \
                                    "https://${3}:${4}/${7}" 2>&1;)";
                    ;;
            esac;

            logger --id --rfc5424 --tag 'debug' --priority 'local7.debug' -- "[${STR_NAME}]: perform_request_to_s3, request performed. Parsing result.";
            response_code=$(echo -en "${response}" | awk -F' ' '/HTTP\/[0-9.]+/{print $2}');
            logger --id --rfc5424 --tag 'debug' --priority 'local7.debug' -- "[${STR_NAME}]: perform_request_to_s3, Result parsed.";
            ;;
    esac;

    logger --id --rfc5424 --tag 'debug' --priority 'local7.debug' -- "[${STR_NAME}]: perform_request_to_s3, Processing response...";
    if [ "${response_code}" == "200" ]; then {
        logger --id --rfc5424 --tag 'debug' --priority 'local7.debug' -- "[$STR_NAME]: perform_request_to_s3, Request executed successfully.";
        
        case "${1}" in
            'GET')
                logger --id --rfc5424 --stderr --tag 'info' --priority 'local7.info' -- "[$STR_NAME]: perform_request_to_s3, Response code: ${response_code}. Object ${7} downloaded.";
                if [ "${2}" == "NETCAT" ] || [ "${2}" == "OPENSSL" ]; then {
                    logger --id --rfc5424 --tag 'debug' --priority 'local7.debug' -- "[${STR_NAME}]: perform_request_to_s3, Processing recieved object...";
                    logger --id --rfc5424 --stderr --tag 'info' --priority 'local7.info' -- "[${STR_NAME}]: perform_request_to_s3, Might work incorrectly with binary types!";
                    tr -d '\r' < "${8}.tmp" | sed '1,/^$/d' > "${8}";
                }
                fi;
                ;;
            'HEAD')
                logger --id --rfc5424 --stderr --tag 'info' --priority 'local7.info' -- "[$STR_NAME]: perform_request_to_s3, Response code: ${response_code}. Object ${7} exists."
            ;;
            'PUT')
                logger --id --rfc5424 --stderr --tag 'info' --priority 'local7.info' -- "[$STR_NAME]: perform_request_to_s3, Response code: ${response_code}. Object ${8} uploaded as ${7}";
            ;;
        esac;

        exit_code=0;
    }
    elif [ "${response_code}" == "404" ]; then {
        logger --id --rfc5424 --tag 'debug' --priority 'local7.debug' -- "[$STR_NAME]: perform_request_to_s3, Request executed successfully.";
        logger --id --rfc5424 --stderr --tag 'info' --priority 'local7.info' -- "[$STR_NAME]: perform_request_to_s3, Response code: ${response_code}. Requested object is missing on the resource.";

        exit_code=0;
    }
    else {
        logger --id --rfc5424 --stderr --tag 'warning' --priority 'local7.warning' -- "[$STR_NAME]: perform_request_to_s3, Something went wrong.";
        if [ "${2}" == "NETCAT" ] || [ "${2}" == "OPENSSL" ]; then { cat "${6}.tmp"; }
        fi;

        exit_code=1;
    }
    fi;

    if [ "${2}" == "NETCAT" ] || [ "${2}" == "OPENSSL" ]; then {
        logger --id --rfc5424 --tag 'debug' --priority 'local7.debug' -- "[${STR_NAME}]: perform_request_to_s3, Performing cleanup, removing ${8}.tmp.";
        rm -f "${8}.tmp";
    }
    fi;


    logger --id --rfc5424 --tag 'debug' --priority 'local7.debug' -- "[$STR_NAME]: perform_request_to_s3, Function exited with code ${exit_code}.";
    return ${exit_code};
}

function print_help() {
    logger --id --rfc5424 --tag 'debug' --priority 'local7.debug' -- "[${STR_NAME}]: help, func called.";
    echo "Name: S3 interaction suite";
    echo "Description: Read meta, download objects from or upload to S3-compatible storage";
    echo "Req: read-write access on current working directory, cURL v7.64 and higher.";
    echo "Note: for cURL v8.2 and lower. cURL 8.3+ can automatically generate signatures and sign data.";
    echo "Usage ${0} [options]";
    echo -e "\t-b|--backend <backend-util> : set backend to perform http-session.";
    echo -e "\tAvailable variants:";
    echo -e "\t\t OLDCURL - cURL of version 8.2 and lower (used by default).";
    echo -e "\t\t CURL - cURL of version 8.3 and higher.";
    echo -e "\t\t WGET - wget utility.";
    echo -e "\t\t NETCAT - netcat utility (only HTTP!).";
    echo -e "\t\t OPENSSL - openssl s_client utility."
    echo -e "\t-r <REQUEST> : set operation type to perform with s3-storage. Available variants: GET, HEAD, PUT.";
    echo -e "\t-f <FQDN> : set S3-compatible storage fully-qualified domain name.";
    echo -e "\t-p <REMOTE PORT> : set remote port. Default is 443 (HTTPS)."
    echo -e "\t-a <your S3 access key> : set S3 connection access key";
    echo -e "\t-s <your S3 secret key> : set S3 connection secret key";
    echo -e "\t-S <S3 signature> : (optional) set S3 connection signature string";
    echo -e "\t-o <target object name> : set desired object name to interact with, including s3-bucket. Ommit leading slash Example: bucket/path/to/object";
    echo -e "\t-l <target local file name> : (optional) set desired local file to interact with. Set as absolute path. Example: /absolute/path/to/file[.ext]. May be ommitted in GET request.";
    echo -e "\t-h : call this help.";
    echo -e "\tExample: ${0} -b OLDCURL -r GET -f s3.storage.ru -a myaccesskeytos3 -s mysecretkeytos3 -o bucket/target/object/name";
    echo -e "\tExample: ${0} -b WGET -r PUT -f s3.storage.ru -p 9000 -a myaccesskeytos3 -s mysecretkeytos3 -o bucket/target/object/name -l /path/to/upload/file";
}

# Program start
perform_basic_utility_checks;

logger --id --rfc5424 --stderr --tag 'info' --priority 'user.info' -- "[${STR_NAME}]: Start ${0}." 


# argument parsing
if [ ${#} -eq 0 ]; then {
    logger --id --rfc5424 --stderr --tag 'info' --priority 'user.info' -- "[${STR_NAME}]: Script called with ${#} arguments. Printing help and exit." 
    print_help;
    logger --id --rfc5424 --stderr --tag 'info' --priority 'user.info' -- "[${STR_NAME}]: ${0} finished.";
    exit 0;
}
else {
    logger --id --rfc5424 --tag 'debug' --priority 'user.debug' -- "[${STR_NAME}]: Arguments count: ${#}. Arguments: (${*}).";
}
fi;

# agument processing
while getopts "${STR_SHORT_O}" name; do {
    case "${name}" in
        'a')  # s3 bucket access key
             key_id="${OPTARG}";
             ;;
        'b')  # used backend utility
             backend="${OPTARG}";
             ;;
        'f')  # s3 FQDN
             fqdn="${OPTARG}";
             ;;
        'h')  # call help
             print_help;
             exit 0;
             ;;
        'l')  # local file name to be used in interaction
             case "$2" in
                 "")
                    ;;
                 *) 
                    local_path="${OPTARG}";
                    ;;
             esac;
             ;;
        'o')  # target s3 object
             obj="${OPTARG}";
             ;;
        'p') # s3 remote port
             port="${OPTARG}";
             ;;
        'r')  # operation to perform with the object
             req="${OPTARG}";
             ;;
        's') # s3 bucket secret key
             key_s="${OPTARG}";
             ;;
        'S') # s3 signature string
             sigstring="${OPTARG}";
             ;;
        '--')
            break;
            ;;
        *)
            logger --id --rfc5424 --stderr --tag 'error' --priority 'user.error' -- "[${STR_NAME}]: ${0} called with unexpected option. Print help and exit.";
            echo "Unexpected option: ${1}";
            print_help;
            logger --id --rfc5424 --stderr --tag 'info' --priority 'user.info' -- "[${STR_NAME}]: ${0} finished with error: Unexpected agrument: '${1}'.";
            exit 1;
            ;;
    esac;
}
done;
perform_args_checks "${req}" "${backend}";
method_result=${?};
if [ ${method_result} -ne 0 ]; then {
    logger --id --rfc5424 --stderr --tag 'error' --priority 'user.error' -- "[${STR_NAME}]: Arguments incorrect. Aborting";
    exit 1;
}
fi;
logger --id --rfc5424 --tag 'debug' --priority 'user.debug' -- "[${STR_NAME}]: Arguments: (backend:${backend}; request:${req}; fqdn:${fqdn}; port:${port}; access-key:${key_id}; secret-key:${key_s}; object-name:${obj}; local-path:${local_path}; aws-sigv4-string:${sigstring}).";

perform_tooling_utility_checks "${backend}";

# executions
perform_request_to_s3 "${req}" "${backend}" "${fqdn}" "${port}" "${key_id}" "${key_s}" "${obj}" "${local_path}" "${sigstring}";
method_result=${?};
logger --id --rfc5424 --tag 'debug' --priority 'user.debug' -- "[${STR_NAME}]: subroutine return code: ${method_result}";

# process result
if [ ${method_result} -eq 0 ]; then {
    logger --id --rfc5424 --stderr --tag 'info' --priority 'user.info' -- "[${STR_NAME}]: Task executed successfully.";
    logger --id --rfc5424 --stderr --tag 'info' --priority 'user.info' -- "[${STR_NAME}]: ${0} finished.";
}
    exit 0;
else {
    logger --id --rfc5424 --stderr --tag 'warning' --priority 'user.warning' -- "[${STR_NAME}]: Error occured on task execution.";
    logger --id --rfc5424 --stderr --tag 'info' --priority 'user.info' -- "[${STR_NAME}]: ${0} finished with error code 1.";
    exit 1;
}
fi;
