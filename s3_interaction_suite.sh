#!/usr/bin/bash

####
# Name: S3 interaction suite
# Description: Read meta, download objects from or upload to S3-compatible storage
# Req: read-write access on current working directory, cURL v7.64 and higher.
# Note: for cURL v8.2 and lower. cURL 8.3+ can automatically generate signatures and sign data.
# Note: to get object metadata (size, etc., user cURL option --head)

perform_basic_utility_checks() {
    ############################################################
    # DESCR: Check that all base utilities needed for
    #        supporting the program is available
    ############################################################

    declare -a tools=( 'awk' 'basename' 'cut' 'getopt' 'head' 'logger' 'tail' 'test' );
    declare exists='';
    declare -i w_exc=-1;

    # check tooling exists
    for utility in "${tools[@]}"
    
    do
        exists="$(which "$utility")";
        w_exc=$?;

        if [ "${exists}" = "" ] || [ ${w_exc} -ne 0 ]; then
            echo "Cannot start script ${0}, utility \"${utility}\" is missing!";
            exit 1;
        fi;
    done;

    return 0;
}
perform_basic_utility_checks;

# constants and variables declaration
declare STR_NAME="$(basename "$0")";
declare STR_SHORT_O="b:,r:,f:,t:,a:,s:,o:,l:,h";
declare STR_LONG_O="backend:,request:,s3-fqdn:,sig-string:,access-key:,secret-key:,object-name:,local-file:,help";
declare args_passed="";

declare backend='OLDCURL';
declare req='';
declare fqdn='';
declare sigstring='aws:amz:ru-central1:s3';
declare key_id='';
declare key_s='';
declare obj='';
declare local_path='';

declare dt_val='';  # used as global var in all three methods
declare str_to_sign='';  # used as global var in all three methods
declare signature='';  # used as global var in all three methods

declare -i method_result=-1;

# functions declaration
oldcurl_get_data_from_s3() {

    ############################################################
    # DESCR: Perform HTTP GET on S3, and saves result locally
    # ARGS:
    #    (1) - S3 FQDN
    #    (2) - Access key ID
    #    (3) - Secret key
    #    (4) - Object name (with bucket)
    #    (5) - Local file name (optional)
    ############################################################

    logger --id --rfc5424 --tag 'debug' --priority 'local7.debug' -- "[$STR_NAME]: oldcurl_get_data_from_s3, func called with args($#): [$*].";
    # dt_val, signature, str_to_sign - variables from global scope
    declare response_code="";

    dt_val="$(date -R)";
    str_to_sign="GET\n\napplication/octet-stream\n${dt_val}\n/${4}";
    signature="$(echo -en "${str_to_sign}" | openssl sha1 -hmac "${3}" -binary | base64)";

    if [ "${5}" == "" ]; then
        logger --id --rfc5424 --tag 'debug' --priority 'local7.debug' -- "[$STR_NAME]: oldcurl_get_data_from_s3, Argument \'local path\' is not set. Downloaded data will be saved with s3-object name.";
        response_code="$(curl \
                            --location \
                            --silent \
                            --remote-name \
                            --request 'GET' \
                            --header "Host: ${1}" \
                            --header "Date: ${dt_val}" \
                            --header 'Content-Type: application/octet-stream' \
                            --header "Authorization: AWS ${2}:${signature}" \
                            --write-out "%{http_code}" \
                            --url "https://${1}/${4}";)";
    else
        logger --id --rfc5424 --tag 'debug' --priority 'local7.debug' -- "[$STR_NAME]: oldcurl_get_data_from_s3, Argument \'local path\' is set. Downloaded data will be saved as ${5}.";
        response_code="$(curl \
                            --location \
                            --silent \
                            --output "${5}" \
                            --request 'GET' \
                            --header "Host: ${1}" \
                            --header "Date: ${dt_val}" \
                            --header 'Content-Type: application/octet-stream' \
                            --header "Authorization: AWS ${2}:${signature}" \
                            --write-out "%{http_code}" \
                            --url "https://${1}/${4}";)";
    fi;

    if [ "${response_code}" == "200" ]; then
        logger --id --rfc5424 --tag 'debug' --priority 'local7.debug' -- "[$STR_NAME]: oldcurl_get_data_from_s3, Response code: ${response_code}. Request executed successfully.";
        logger --id --rfc5424 --tag 'debug' --priority 'local7.debug' -- "[$STR_NAME]: oldcurl_get_data_from_s3, Function exited with code 0.";
        return 0;
    else
        logger --id --rfc5424 --stderr --tag 'warning' --priority 'local7.warning' -- "[$STR_NAME]: oldcurl_get_data_from_s3,  Response code: ${response_code}. Something went wrong.";
        return 1;
    fi;
}

oldcurl_head_data_from_s3() {

    ############################################################
    # DESCR: Perform HTTP HEAD on S3
    # ARGS:
    #    (1) - S3 FQDN
    #    (2) - Access key ID
    #    (3) - Secret key
    #    (4) - Object name (with bucket)
    ############################################################

    logger --id --rfc5424 --tag 'debug' --priority 'local7.debug' -- "[$STR_NAME]: oldcurl_head_data_from_s3, func called with args($#): [$*].";
    # dt_val, signature, str_to_sign - variables from global scope
    declare response="";
    declare response_code="";
    declare cont_len="";

    dt_val="$(date -R)";
    str_to_sign="GET\n\napplication/octet-stream\n${dt_val}\n/${4}";
    signature="$(echo -en "${str_to_sign}" | openssl sha1 -hmac "${3}" -binary | base64)";

    response="$(curl \
                    --location \
                    --silent \
                    --head \
                    --header "Host: ${1}" \
                    --header "Date: ${dt_val}" \
                    --header 'Content-Type: application/octet-stream' \
                    --header "Authorization: AWS ${2}:${signature}" \
                    --write-out "%{http_code},header%{content-length}" \
                    --output '/dev/null' \
                    --url "https://${1}/${4}";)";
    response_code=$(echo "${response}" | tail --lines 1 | cut --delimiter=',' --fields=1;);
    cont_len=$(echo "${response}" | tail --lines 1 | cut --delimiter=',' --fields=2;);

    if [ "${response_code}" == "200" ]; then
        logger --id --rfc5424 --tag 'debug' --priority 'local7.debug' -- "[$STR_NAME]: oldcurl_head_data_from_s3, Response code: ${response_code}. Request executed successfully.";
        logger --id --rfc5424 --stderr --tag 'info' --priority 'local7.info' -- "[$STR_NAME]: oldcurl_head_data_from_s3, Object ${4} exists and has length ${cont_len} bytes."
        logger --id --rfc5424 --tag 'debug' --priority 'local7.debug' -- "[$STR_NAME]: oldcurl_head_data_from_s3, Function exited with code 0.";
        return 0;
    elif [ "${response_code}" == "404" ]; then
        logger --id --rfc5424 --stderr --tag 'info' --priority 'local7.info' -- "[$STR_NAME]: oldcurl_head_data_from_s3, Response code: ${response_code}. Requested object is missing on the resource.";
        return 0;
    else
        logger --id --rfc5424 --stderr --tag 'warning' --priority 'local7.warning' -- "[$STR_NAME]: oldcurl_head_data_from_s3,  Response code: ${response_code}. Something went wrong.";
        return 1;
    fi;
}

oldcurl_put_data_to_s3() {

    ############################################################
    # DESCR: Perform HTTP PUT on S3, and saves result locally
    # ARGS:
    #    (1) - S3 FQDN
    #    (2) - Access key ID
    #    (3) - Secret key
    #    (4) - Object name (with bucket)
    #    (5) - Local file name 
    ############################################################

    logger --id --rfc5424 --tag 'debug' --priority 'local7.debug' -- "[$STR_NAME]: oldcurl_put_data_to_s3, func called with args($#): [$*].";
    # dt_val, signature, str_to_sign - variables from global scope
    declare response_code="";

    if [ "${5}" == "" ]; then
        logger --id --rfc5424 --stderr --tag 'error' --priority 'local7.error' -- "[$STR_NAME]: oldcurl_put_data_to_s3, file name not set: \'${5}\'.";
        return 1;
    fi;
    if [ ! -f "${5}" ]; then
        logger --id --rfc5424 --stderr --tag 'error' --priority 'local7.error' -- "[$STR_NAME]: oldcurl_put_data_to_s3, file \'${5}\' does not exist!";
        return 1; 
    fi;
    if [ ! -r "${5}" ]; then
        logger --id --rfc5424 --stderr --tag 'error' --priority 'local7.error' -- "[$STR_NAME]: oldcurl_put_data_to_s3, file \'${5}\' is not readable!";
        return 1;
    fi;

    dt_val="$(date -R)";
    str_to_sign="PUT\n\napplication/octet-stream\n${dt_val}\n/${4}";
    signature="$(echo -en "${str_to_sign}" | openssl sha1 -hmac "${3}" -binary | base64)";

    response_code="$(curl \
                        --location \
                        --silent \
                        --request 'PUT' \
                        --header "Host: ${1}" \
                        --header "Date: ${dt_val}" \
                        --header 'Content-Type: application/octet-stream' \
                        --header "Authorization: AWS ${2}:${signature}" \
                        --write-out "%{http_code}" \
                        --upload-file "${5}" \
                        --url "https://${1}/${4}";)";

    if [ "${response_code}" == "200" ]; then
        logger --id --rfc5424 --tag 'debug' --priority 'local7.debug' -- "[$STR_NAME]: oldcurl_put_data_to_s3, Response code: ${response_code}. Request executed successfully.";
        logger --id --rfc5424 --tag 'debug' --priority 'local7.debug' -- "[$STR_NAME]: oldcurl_put_data_to_s3, func exited with code 0.";
        return 0;
    else
        logger --id --rfc5424 --stderr --tag 'warning' --priority 'local7.warning' -- "[$STR_NAME]: oldcurl_put_data_to_s3, Response code: ${response_code}. Something went wrong.";
        return 1;
    fi;
}

curl_get_data_from_s3() {

    ############################################################
    # DESCR: Perform HTTP GET on S3, and saves result locally
    # ARGS:
    #    (1) - S3 FQDN
    #    (2) - Access key ID
    #    (3) - Secret key
    #    (4) - AWS sign string
    #    (5) - Object name (with bucket)
    #    (6) - Local file name (optional)
    ############################################################

    logger --id --rfc5424 --tag 'debug' --priority 'local7.debug' -- "[$STR_NAME]: curl_get_data_from_s3, func called with args($#): [$*].";

    declare response_code="";

    if [ "${6}" == "" ]; then
        logger --id --rfc5424 --tag 'debug' --priority 'local7.debug' -- "[$STR_NAME]: curl_get_data_from_s3, Argument \'local path\' is not set. Downloaded data will be saved with s3-object name.";
        response_code="$(curl \
                           --location \
                           --silent \
                           --remote-name \
                           --request 'GET' \
                           --header 'Content-Type: application/octet-stream' \
                           --aws-sigv4 "${4}" \
                           --user "${2}:${3}" \
                           --write-out "%{response_code}" \
                           --url "https://${1}/${5}";)";
    else
        logger --id --rfc5424 --tag 'debug' --priority 'local7.debug' -- "[$STR_NAME]: curl_get_data_from_s3, Argument \'local path\' is set. Downloaded data will be saved as ${6}.";
        response_code="$(curl \
                           --location \
                           --silent \
                           --output "${6}" \
                           --request 'GET' \
                           --header 'Content-Type: application/octet-stream' \
                           --aws-sigv4 "${4}" \
                           --user "${2}:${3}" \
                           --write-out "%{response_code}" \
                           --url "https://${1}/${5}";)";
    fi;

    if [ "${response_code}" == "200" ]; then
        logger --id --rfc5424 --tag 'debug' --priority 'local7.debug' -- "[$STR_NAME]: curl_get_data_from_s3, Response code: ${response_code}. Request executed successfully.";
        logger --id --rfc5424 --tag 'debug' --priority 'local7.debug' -- "[$STR_NAME]: curl_get_data_from_s3, func exited with code 0.";
        return 0;
    else
        logger --id --rfc5424 --stderr --tag 'warning' --priority 'local7.warning' -- "[$STR_NAME]: curl_get_data_from_s3,  Response code: ${response_code}. Something went wrong.";
        return 1;
    fi;
}

curl_head_data_from_s3() {

    ############################################################
    # DESCR: Perform HTTP GET on S3, and saves result locally
    # ARGS:
    #    (1) - S3 FQDN
    #    (2) - Access key ID
    #    (3) - Secret key
    #    (4) - AWS sign string
    #    (5) - Object name (with bucket)
    ############################################################

    logger --id --rfc5424 --tag 'debug' --priority 'local7.debug' -- "[$STR_NAME]: oldcurl_head_data_from_s3, func called with args($#): [$*].";

    declare response="";
    declare response_code="";
    declare cont_len="";

    response="$(curl \
                    --silent \
                    --location \
                    --head \
                    --aws-sigv4 "${4}" \
                    --user "${2}:${3}" \
                    --url "https://${1}/${5}" \
                    --write-out "%{response_code},%header{content-length}";)";
    response_code=$(echo "${response}" | tail --lines 1 | cut --delimiter=',' --fields=1;);
    cont_len=$(echo "${response}" | tail --lines 1 | cut --delimiter=',' --fields=2;);

    if [ "${response_code}" == "200" ]; then
        logger --id --rfc5424 --tag 'debug' --priority 'local7.debug' -- "[$STR_NAME]: curl_head_data_from_s3, Response code: ${response_code}. Request executed successfully.";
        logger --id --rfc5424 --stderr --tag 'info' --priority 'local7.info' -- "[$STR_NAME]: curl_head_data_from_s3, Object ${5} exists and has length ${cont_len} bytes."
        logger --id --rfc5424 --tag 'debug' --priority 'local7.debug' -- "[$STR_NAME]: curl_head_data_from_s3, Function exited with code 0.";
        return 0;
    elif [ "${response_code}" == "404" ]; then
        logger --id --rfc5424 --stderr --tag 'info' --priority 'local7.info' -- "[$STR_NAME]: curl_head_data_from_s3, Response code: ${response_code}. Requested object is missing on the resource.";
        return 0;
    else
        logger --id --rfc5424 --stderr --tag 'warning' --priority 'local7.warning' -- "[$STR_NAME]: curl_head_data_from_s3,  Response code: ${response_code}. Something went wrong.";
        return 1;
    fi;
}

curl_put_data_to_s3() {
    ############################################################
    # DESCR: Perform HTTP PUT on S3, and saves result locally
    # ARGS:
    #    (1) - S3 FQDN
    #    (2) - Access key ID
    #    (3) - Secret key
    #    (4) - AWS sign string
    #    (5) - Object name (with bucket)
    #    (6) - Local file name 
    ############################################################

    logger --id --rfc5424 --tag 'debug' --priority 'local7.debug' -- "[$STR_NAME]: curl_put_data_from_s3, func called with args($#): [$*].";
    # dt_val, signature, str_to_sign - variables from global scope
    declare response_code="";

    if [ "${5}" == "" ]; then
        logger --id --rfc5424 --stderr --tag 'error' --priority 'local7.error' -- "[$STR_NAME]: curl_put_data_from_s3, file name not set: \'${6}\'.";
        return 1;
    fi;
    if [ ! -f "${5}" ]; then
        logger --id --rfc5424 --stderr --tag 'error' --priority 'local7.error' -- "[$STR_NAME]: curl_put_data_from_s3, file \'${6}\' does not exist!";
        return 1; 
    fi;
    if [ ! -r "${5}" ]; then
        logger --id --rfc5424 --stderr --tag 'error' --priority 'local7.error' -- "[$STR_NAME]: curl_put_data_from_s3, file \'${6}\' is not readable!";
        return 1;
    fi;

    response_code="$(curl \
                         --location \
                         --silent \
                         --request 'PUT' \
                         --header 'Content-Type: application/octet-stream' \
                         --aws-sigv4 "${4}" \
                         --user "${2}:${3}" \
                         --write-out "%{response_code}" \
                         --upload-file "${6}" \
                         --url "https://${1}/${5}";)";

    if [ "${response_code}" == "200" ]; then
        logger --id --rfc5424 --tag 'debug' --priority 'local7.debug' -- "[$STR_NAME]: curl_put_data_from_s3, Response code: ${response_code}. Request executed successfully.";
        logger --id --rfc5424 --tag 'debug' --priority 'local7.debug' -- "[$STR_NAME]: curl_put_data_from_s3, func exited with code 0.";
        return 0;
    else
        logger --id --rfc5424 --stderr --tag 'warning' --priority 'local7.warning' -- "[$STR_NAME]: curl_put_data_from_s3, Response code: ${response_code}. Something went wrong.";
        return 1;
    fi;
}

wget_get_data_from_s3(

    #wget --verbose --server-response --header "Date: ${dt_val}" --header 'Content-Type: application/octet-stream' --header "Authorization: AWS ${a_k}:${signature}" "https://${host}/${bucket}/${object}"

) {}

wget_put_data_to_s3() {}

perform_access_checks() {
	############################################################
	# DESCR: Checks if target directory or target uploaded file
	#        is accessible for read/write operations
	############################################################

    return 0;
}

perform_tooling_utility_checks() {
    ############################################################
    # DESCR: Check that all needed tooling is available and all
    #        needed permissions are granted
    # ARGS: 
    #   (1) - used backend
    ############################################################

    logger --id --rfc5424 --tag 'debug' --priority 'local7.debug' -- "[$STR_NAME]: perform_tooling_utility_checks, func called with args($#): [$*].";

    declare FLOAT_OLD_CURL_MAX_VER='8.2.1';

    declare -a old_curl_tools=( 'base64' 'date' 'openssl' );
    declare -a wget_tools=( 'base64' 'date' 'openssl' );
    declare -a netcat_tools=();
    declare current_curl_ver='';
    declare exists='';
    declare -i w_exc=-1;

    case "$1" in
        'OLDCURL')
            logger --id --rfc5424 --tag 'debug' --priority 'local7.debug' -- "[$STR_NAME]: perform_tooling_utility_checks, argument value is OLDCURL, cURL v8.2- choosen as backend.";
            logger --id --rfc5424 --tag 'debug' --priority 'local7.debug' -- "[$STR_NAME]: perform_tooling_utility_checks, checking cURL v8.2- exists...";
            exists="$(which 'curl';)";
            w_exc=$?;
            logger --id --rfc5424 --tag 'debug' --priority 'local7.debug' -- "[$STR_NAME]: perform_tooling_utility_checks, unix.which returned:\"${exists}\" and exited with code - ${w_exc};";
            if [ "${exists}" = "" ] || [ ${w_exc} -ne 0 ]; then
                logger --id --rfc5424 --stderr --tag 'error' --priority 'local7.error' -- "[$STR_NAME]: perform_tooling_utility_checks, cURL v8.2- does not persist in the system. Aborting with error.";
                exit 1;
            fi;
            #check curl version
            current_curl_ver=$(curl --version | awk -F' ' '{print $2;}' | head -n 1;)
            logger --id --rfc5424 --tag 'debug' --priority 'local7.debug' -- "[$STR_NAME]: perform_tooling_utility_checks, gathered cURL version is $current_curl_ver";
            #echo "$(echo -e "$FLOAT_OLD_CURL_MAX_VER\n$current_curl_ver" | sort -V | head -n1)"
            if [ "$(printf '%s\n' "$FLOAT_OLD_CURL_MAX_VER" "$current_curl_ver" | sort --numeric-sort | head --lines 1)" = "$FLOAT_OLD_CURL_MAX_VER" ]; then 
                logger --id --rfc5424 --stderr --tag 'error' --priority 'local7.error' -- "[$STR_NAME]: perform_tooling_utility_checks, gathered cURL version is not supported by this backend option. Aborting.";
                exit 1;
             else
                 logger --id --rfc5424 --tag 'debug' --priority 'local7.debug' -- "[$STR_NAME]: perform_tooling_utility_checks, cURL v8.2- persists in the system. Checking the rest utilities.";
             fi;
    
            for utility in "${old_curl_tools[@]}"
            do
                logger --id --rfc5424 --tag 'debug' --priority 'local7.debug' -- "[$STR_NAME]: perform_tooling_utility_checks, checking utility \"${utility}\" exists.";
                exists="$(which "$utility")";
                w_exc=$?;
                if [ "${exists}" = "" ] || [ ${w_exc} -ne 0 ]; then
                    logger --id --rfc5424 --stderr --tag 'error' --priority 'local7.error' -- "[$STR_NAME]: perform_tooling_utility_checks, utility \"${utility}\" is missing. Aborting.";
                    exit 1;
                fi;
            done;
            ;;
        'CURL')
            logger --id --rfc5424 --tag 'debug' --priority 'local7.debug' -- "[$STR_NAME]: perform_tooling_utility_checks, argument value is CURL, cURL v8.3+ choosen as backend.";
            logger --id --rfc5424 --tag 'debug' --priority 'local7.debug' -- "[$STR_NAME]: perform_tooling_utility_checks, checking cURL v8.3+ exists...";
            exists="$(which 'curl';)";
            w_exc=$?;
            logger --id --rfc5424 --tag 'debug' --priority 'local7.debug' -- "[$STR_NAME]: perform_tooling_utility_checks, unix.which returned:\"${exists}\" and exited with code - ${w_exc};";
            if [ "${exists}" = "" ] || [ ${w_exc} -ne 0 ]; then
                logger --id --rfc5424 --stderr --tag 'error' --priority 'local7.error' -- "[$STR_NAME]: perform_tooling_utility_checks, cURL v8.3+ does not persist in the system. Aborting with error.";
                exit 1;
            fi;
            #check curl version
            current_curl_ver=$(curl --version | awk -F' ' '{print $2;}' | head -n 1;)
            logger --id --rfc5424 --tag 'debug' --priority 'local7.debug' -- "[$STR_NAME]: perform_tooling_utility_checks, gathered cURL version is $current_curl_ver";
            #echo "$(echo -e "$FLOAT_OLD_CURL_MAX_VER\n$current_curl_ver" | sort -V | head -n1)"
            if [ "$(printf '%s\n' "$FLOAT_OLD_CURL_MAX_VER" "$current_curl_ver" | sort --numeric-sort | head --lines 1)" = "$FLOAT_OLD_CURL_MAX_VER" ]; then 
                logger --id --rfc5424 --tag 'debug' --priority 'local7.debug' -- "[$STR_NAME]: perform_tooling_utility_checks, cURL v8.2- persists in the system. Checking the rest utilities.";
            else
                logger --id --rfc5424 --stderr --tag 'error' --priority 'local7.error' -- "[$STR_NAME]: perform_tooling_utility_checks, gathered cURL version is not supported by this backend option. Aborting.";
                exit 1;
            fi;
            ;;
        'WGET')
            logger --id --rfc5424 --stderr --tag 'error' --priority 'local7.error' -- "[$STR_NAME]: perform_tooling_utility_checks, usage of wget as backend is not implemented yet. Aborting.";
            exit 1;
            ;;
        'NETCAT')
            logger --id --rfc5424 --stderr --tag 'error' --priority 'local7.error' -- "[$STR_NAME]: perform_tooling_utility_checks, usage of netcat as backend is not implemented yet. Aborting.";
            exit 1;
            ;;
        *)
            logger --id --rfc5424 --stderr --tag 'error' --priority 'local7.error' -- "[$STR_NAME]: perform_tooling_utility_checks, Unsupported backend type. Aborting.";
            exit 1;
            ;;
    esac;
    logger --id --rfc5424 --tag 'debug' --priority 'local7.debug' -- "[$STR_NAME]: perform_tooling_utility_checks, backend and all needed utilities persist.";

    return 0;
}

print_help() {
    logger --id --rfc5424 --tag 'debug' --priority 'local7.debug' -- "[$STR_NAME]: help, func called.";
    echo "Name: S3 interaction suite";
    echo "Description: Read meta, download objects from or upload to S3-compatible storage";
    echo "Req: read-write access on current working directory, cURL v7.64 and higher.";
    echo "Note: for cURL v8.2 and lower. cURL 8.3+ can automatically generate signatures and sign data.";
    echo "Usage $0 [options]";
    echo -e "\t-b|--backend <backend-util> : set backend to perform http-session.";
    echo -e "\tAvailable variants:";
    echo -e "\t\t OLDCURL - cURL of version 8.2 and lower (used by default).";
    echo -e "\t\t CURL - cURL of version 8.3 and higher.";
    echo -e "\t\t WGET - wget utility.";
    echo -e "\t\t NETCAT - netcat utility.";
    echo -e "\t-r|--request <REQUEST> : set operation type to perform with s3-storage. Available variants: GET , HEAD, PUT.";
    echo -e "\t-f|--s3-fqdn <FQDN> : set S3-compatible storage fully-qualified domain name.";
    echo -e "\t-a|--access-key <your access key> : set S3 connection access key";
    echo -e "\t-s|--secret-key <your secret key> : set S3 connection secret key";
    echo -e "\t-o|--object-name <target object name> : set desired object name to interact with, including s3-bucket. Ommit leading slash Example: bucket/path/to/object";
    echo -e "\t-l|--local-file <target local file name> : set desired local file to interact with. Set as absolute path. Example: /absolute/path/to/file[.ext]. May be ommitted in GET request.";
    echo -e "\t-h|--help : call this help.";
    echo -e "\tExample: $0 -b OLDCURL -r GET -f s3.storage.ru -a myaccesskeytos3 -s mysecretkeytos3 -o bucket/target/object/name"
}


logger --id --rfc5424 --stderr --tag 'info' --priority 'user.info' -- "[$STR_NAME]: Start $0." 
logger --id --rfc5424 --tag 'debug' --priority 'user.debug' -- "[$STR_NAME]: Arguments count: $#. Arguments: ($*).";

# argument parsing
if [ $# -eq 0 ]; then
    logger --id --rfc5424 --stderr --tag 'info' --priority 'user.info' -- "[$STR_NAME]: Script called with $# arguments. Printing help and exit." 
    print_help;
    logger --id --rfc5424 --stderr --tag 'info' --priority 'user.info' -- "[$STR_NAME]: $0 finished.";
    exit 0;
fi;
args_passed=$(getopt --name "$(basename "${0}")" --options "$STR_SHORT_O" --longoptions "$STR_LONG_O" -- "$@");
eval set -- "$args_passed";
logger --id --rfc5424 --tag 'debug' --priority 'user.debug' -- "[$STR_NAME]: Arguments parsed: ($args_passed).";

# agument processing
while true ; do
    case "$1" in
        '-b'|'--backend')
            backend=$2;
            shift '2';
            ;;
        '-r'|'--request') 
            req=$2;
            shift '2';
            ;;
        '-f'|'--s3-fqdn')
            fqdn=$2;
            shift '2';
            ;;
        '-t'|'--sig-string')
            sigstring=$2;
            shift '2';
            ;;
        '-a'|'--access-key')
            key_id=$2;
            shift '2';
            ;;
        '-s'|'--secret-key')
            key_s=$2;
            shift '2';
            ;;
        '-o'|'--object-name')
            obj=$2;
            shift '2';
            ;;
        '-l'|'--local-file')
            case "$2" in
                "")
                    shift '2';
                    ;;
                *) 
                    local_path=$2;
                    shift '2';
                    ;;
            esac;
            ;;
        '-h'|'--help')
            print_help;
            exit 0;
            ;;
        '--')
            shift '1';
            break;
            ;;
        *)
            logger --id --rfc5424 --stderr --tag 'error' --priority 'user.error' -- "[$STR_NAME]: $0 called with unexpected option. Print help and exit.";
            echo "Unexpected option: $1";
            print_help;
            logger --id --rfc5424 --stderr --tag 'info' --priority 'user.info' -- "[$STR_NAME]: $0 finished with error: Unexpected agrument: '$1'.";
            exit 1;
            ;;
    esac;
done;
logger --id --rfc5424 --tag 'debug' --priority 'user.debug' -- "[$STR_NAME]: Arguments: (backend:$backend; request:$req; fqdn:$fqdn; access-key:$key_id; secret-key:$key_s; object-name:$obj; local-path:$local_path).";

perform_tooling_utility_checks "${backend}";

# executions
case "${req}" in
    'GET')
        case "${backend}" in
            'OLDCURL')
                oldcurl_get_data_from_s3 "$fqdn" "$key_id" "$key_s" "$obj" "$local_path";
                method_result=$?;
                ;;
            'CURL')
                curl_get_data_from_s3 "$fqdn" "$key_id" "$key_s" "$sigstring" "$obj" "$local_path";
                method_result=$?;
                ;;
            'WGET')
                echo'';
                ;;
            'NETCAT')
                echo'';
                ;;
        esac;
        ;;
    'HEAD')
        case "${backend}" in
            'OLDCURL')
                oldcurl_head_data_from_s3 "$fqdn" "$key_id" "$key_s" "$obj";
                method_result=$?;
                ;;
            'CURL')
                curl_head_data_from_s3 "$fqdn" "$key_id" "$key_s" "$sigstring" "$obj";
                method_result=$?;
                ;;
            'WGET')
                echo'';
                ;;
            'NETCAT')
                echo'';
                ;;
        esac;
        ;;
    'PUT')
        case "${backend}" in
            'OLDCURL')
                oldcurl_put_data_to_s3 "$fqdn" "$key_id" "$key_s" "$obj" "$local_path";
                method_result=$?;
                ;;
            'CURL')
                curl_put_data_to_s3 "$fqdn" "$key_id" "$key_s" "$sigstring" "$obj" "$local_path";
                method_result=$?;
                ;;
            'WGET')
                echo'';
                ;;
            'NETCAT')
                echo'';
                ;;
        esac;
        ;;
    *)
        logger --id --rfc5424 --stderr --tag 'error' --priority 'user.error' -- "[$STR_NAME]: $0 provided request method - ${req} - is incorrect. Aborting.";
        exit 1;
        ;;
esac;
logger --id --rfc5424 --tag 'debug' --priority 'user.debug' -- "[$STR_NAME]: subroutine return code: ${method_result}";

# process result
if [ ${method_result} -eq 0 ]; then
    logger --id --rfc5424 --stderr --tag 'info' --priority 'user.info' -- "[$STR_NAME]: Task executed successfully.";
    logger --id --rfc5424 --stderr --tag 'info' --priority 'user.info' -- "[$STR_NAME]: $0 finished.";
    exit 0;
else
    logger --id --rfc5424 --stderr --tag 'warning' --priority 'user.warning' -- "[$STR_NAME]: Error occured on task execution.";
    logger --id --rfc5424 --stderr --tag 'info' --priority 'user.info' -- "[$STR_NAME]: $0 finished with error code 1.";
    exit 1;
fi;
