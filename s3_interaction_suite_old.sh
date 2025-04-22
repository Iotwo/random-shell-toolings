#!/usr/bin/bash

####
# Name: S3 interaction suite
# Description: Read meta, download objects from or upload to S3-compatible storage
# Req: read-write access on current working directory, cURL v7.64 and higher.
# Note: for cURL v8.2 and lower. cURL 8.3+ can automatically generate signatures and sign data.
# Note: to get object metadata (size, etc., user cURL option --head)
# TBD: add opt for choosing backend (curl <=8.2, curl 8.3+, wget, netcat)

# constants and variables declaration
declare STR_NAME="$(basename "$0")";
declare STR_SHORT_O="r:,f:,a:,s:,o:,l:,h";
declare STR_LONG_O="request:,s3-fqdn:,access-key:,secret-key:,object-name:,local-file:,help";
declare args_passed="";

declare req="";
declare fqdn="";
declare key_id="";
declare key_s="";
declare obj="";
declare local_path="";

declare dt_val="";  # used as global var in all three methods
declare str_to_sign="";  # used as global var in all three methods
declare signature="";  # used as global var in all three methods

declare -i method_result=-1;

# functions declaration
get_data_from_s3() {

	############################################################
	# DESCR: Perform HTTP GET on S3, and saves result locally
	# ARGS:
	#	(1) - S3 FQDN
	#	(2) - Access key ID
	#	(3) - Secret key
	#	(4) - Object name (with bucket)
	#	(5) - Local file name (optional)
	############################################################

	logger --id --rfc5424 --tag 'debug' --priority 'local7.debug' -- "[$STR_NAME]: get_data_from_s3,  func called with args($#): [$*].";
	# dt_val, signature, str_to_sign - variables from global scope
	declare response_code="";

	dt_val="$(date -R)";
	str_to_sign="GET\n\napplication/octet-stream\n${dt_val}\n/${4}";
	signature="$(echo -en "${str_to_sign}" | openssl sha1 -hmac "${3}" -binary | base64)";

	if [ "$5" == "" ]; then
		logger --id --rfc5424 --tag 'debug' --priority 'local7.debug' -- "[$STR_NAME]: get_data_from_s3,  Argument \'local path\' is not set. Downloaded data will be saved with s3-object name.";
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
		logger --id --rfc5424 --tag 'debug' --priority 'local7.debug' -- "[$STR_NAME]: get_data_from_s3,  Argument \'local path\' is set. Downloaded data will be saved as $5.";
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
		logger --id --rfc5424 --tag 'debug' --priority 'local7.debug' -- "[$STR_NAME]: get_data_from_s3,  Response code: ${response_code}. Request executed successfully.";
		logger --id --rfc5424 --tag 'debug' --priority 'local7.debug' -- "[$STR_NAME]: get_data_from_s3, func exited with code 0.";
		return 0;
	else
		logger --id --rfc5424 --stderr --tag 'warning' --priority 'local7.warning' -- "[$STR_NAME]: get_data_from_s3,  Response code: ${response_code}. Something went wrong.";
		return 1;
	fi;
}

head_data_from_s3() {

	############################################################
	# DESCR: Perform HTTP HEAD on S3
	# ARGS:
	#	(1) - S3 FQDN
	#	(2) - Access key ID
	#	(3) - Secret key
	#	(4) - Object name (with bucket)
	############################################################

	logger --id --rfc5424 --tag 'debug' --priority 'local7.debug' -- "[$STR_NAME]: head_data_from_s3, func called with args($#): [$*].";
	# dt_val, signature, str_to_sign - variables from global scope
	declare response_code="";

	dt_val="$(date -R)";
	str_to_sign="GET\n\napplication/octet-stream\n${dt_val}\n/${4}";
	signature="$(echo -en "${str_to_sign}" | openssl sha1 -hmac "${3}" -binary | base64)";

	response_code="$(curl \
						--location \
						--silent \
						--head \
						--header "Host: ${1}" \
						--header "Date: ${dt_val}" \
						--header 'Content-Type: application/octet-stream' \
						--header "Authorization: AWS ${2}:${signature}" \
						--write-out "%{http_code}" \
						--output '/dev/null' \
		    			--url "https://${1}/${4}";)";

	if [ "${response_code}" == "200" ]; then
		logger --id --rfc5424 --tag 'debug' --priority 'local7.debug' -- "[$STR_NAME]: head_data_from_s3,  Response code: ${response_code}. Request executed successfully.";
		logger --id --rfc5424 --tag 'debug' --priority 'local7.debug' -- "[$STR_NAME]: head_data_from_s3, func exited with code 0.";
		return 0;
	else
		logger --id --rfc5424 --stderr --tag 'warning' --priority 'local7.warning' -- "[$STR_NAME]: head_data_from_s3,  Response code: ${response_code}. Something went wrong.";
		return 1;
	fi;
}

perform_basic_checks() {
	############################################################
	# DESCR: Check that all needed tooling is available and all
	#        needed permissions are granted
	# ARGS:
	############################################################

	declare -a tools=( 'basename' 'base64' 'curl' 'date' 'getopt' 'logger' 'openssl' 'test')
	declare exists='';
	declare -i w_exc=-1;

	# check tooling exists
	for utility in "${tools[@]}"
	do
		exists="$(which "$utility")";
		w_exc=$#;

		if [ "${exists}" = "" ] || [ ${w_exc} -ne 0 ]; then
			echo "Cannot start script ${0}, ${utility} is missing!";
			exit 1;
        fi;
	done;

	#may be also check directory rights

	return 0;
}

put_data_to_s3() {

	############################################################
	# DESCR: Perform HTTP PUT on S3, and saves result locally
	# ARGS:
	#	(1) - S3 FQDN
	#	(2) - Access key ID
	#	(3) - Secret key
	#	(4) - Object name (with bucket)
	#	(5) - Local file name 
	############################################################

	logger --id --rfc5424 --tag 'debug' --priority 'local7.debug' -- "[$STR_NAME]: post_data_to_s3, func called with args($#): [$*].";
	# dt_val, signature, str_to_sign - variables from global scope
	declare response_code="";

	if [ "${5}" == "" ]; then
		logger --id --rfc5424 --stderr --tag 'error' --priority 'local7.error' -- "[$STR_NAME]: post_data_to_s3, file name not set: \'${5}\'.";
		return 1;
	fi;
	if [ ! -f "${5}" ]; then
		logger --id --rfc5424 --stderr --tag 'error' --priority 'local7.error' -- "[$STR_NAME]: post_data_to_s3, file \'${5}\' does not exist!";
		return 1; 
	fi;
	if [ ! -r "${5}" ]; then
		logger --id --rfc5424 --stderr --tag 'error' --priority 'local7.error' -- "[$STR_NAME]: post_data_to_s3, file \'${5}\' is not readable!";
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
		logger --id --rfc5424 --tag 'debug' --priority 'local7.debug' -- "[$STR_NAME]: put_data_to_s3,  Response code: ${response_code}. Request executed successfully.";
		logger --id --rfc5424 --tag 'debug' --priority 'local7.debug' -- "[$STR_NAME]: put_data_to_s3, func exited with code 0.";
		return 0;
	else
		logger --id --rfc5424 --stderr --tag 'warning' --priority 'local7.warning' -- "[$STR_NAME]: put_data_to_s3,  Response code: ${response_code}. Something went wrong.";
		return 1;
	fi;
}

print_help() {
	logger --id --rfc5424 --tag 'debug' --priority 'local7.debug' -- "[$STR_NAME]: help, func called.";
	echo "Name: S3 interaction suite";
	echo "Description: Read meta, download objects from or upload to S3-compatible storage";
	echo "Req: read-write access on current working directory, cURL v7.64 and higher.";
	echo "Note: for cURL v8.2 and lower. cURL 8.3+ can automatically generate signatures and sign data.";
	echo "Usage $0 [options]";
	echo -e "\t-r|--request <REQUEST> : set operation type to perform with s3-storage. Available variants: GET , HEAD, PUT.";
	echo -e "\t-f|--s3-fqdn <FQDN> : set S3-compatible storage fully-qualified domain name.";
	echo -e "\t-a|--access-key <your access key> : set S3 connection access key";
	echo -e "\t-s|--secret-key <your secret key> : set S3 connection secret key";
	echo -e "\t-o|--object-name <target object name> : set desired object name to interact with, including s3-bucket. Ommit leading slash Example: bucket/path/to/object";
	echo -e "\t-l|--local-file <target local file name> : set desired local file to interact with. Set as absolute path. Example: /absolute/path/to/file[.ext]. May be ommitted in GET request.";
	echo -e "\t-h|--help : call this help.";
	echo -e "\tExample: $0 -r GET -f s3.storage.ru -a myaccesskeytos3 -s mysecretkeytos3 -o bucket/target/object/name"
}


perform_basic_checks;

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
		'-r'|'--request') 
			req=$2;
			shift '2';;
		'-f'|'--s3-fqdn')
			fqdn=$2;
			shift '2';;
		'-a'|'--access-key')
			key_id=$2;
			shift '2';;
		'-s'|'--secret-key')
			key_s=$2;
			shift '2';;
		'-o'|'--object-name')
			obj=$2;
			shift '2';;
		'-l'|'--local-file')
			case "$2" in
                "")
					shift '2' ;;
                *) 
					local_path=$2;
					shift '2' ;;
            esac ;;
		'-h'|'--help')
			print_help;
			exit 0;;
		'--')
			shift '1';
			break;;
		*)
			logger --id --rfc5424 --stderr --tag 'error' --priority 'user.error' -- "[$STR_NAME]: $0 called with unexpected option. Print help and exit.";
			echo "Unexpected option: $1";
			print_help;
			logger --id --rfc5424 --stderr --tag 'info' --priority 'user.info' -- "[$STR_NAME]: $0 finished with error: Unexpected agrument: '$1'.";
			exit 1;;
	esac;
done;
logger --id --rfc5424 --tag 'debug' --priority 'user.debug' -- "[$STR_NAME]: Arguments: (request:$req; fqdn:$fqdn; access-key:$key_id; secret-key:$key_s; object-name:$obj; local-path:$local_path).";

# executions
case "$req" in
	'GET') 
		get_data_from_s3 "$fqdn" "$key_id" "$key_s" "$obj" "$local_path";
		method_result=$?;;
	'HEAD') 
		head_data_from_s3 "$fqdn" "$key_id" "$key_s" "$obj";
		method_result=$?;;
	'PUT')
		put_data_to_s3 "$fqdn" "$key_id" "$key_s" "$obj" "$local_path";
		method_result=$?;;
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
