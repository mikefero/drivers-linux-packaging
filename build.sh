#!/bin/bash

# Debug statements [if needed]
#set -x #Trace
#set -n #Check Syntax

WORKING_DIRECTORY="$(pwd)"
BASH_FILENAME="$(basename ${0})"
SCRIPT_DIRECTORY=""$(dirname ${0})""

# Constants
PACKAGES_DIRECTORY="${SCRIPT_DIRECTORY}/packages"
CPP_CORE_ARGUMENT="--cpp-core"
CPP_DSE_ARGUMENT="--cpp-dse"
LIBUV_ARGUMENT="--libuv"
CLEAN_ARGUMENT="--clean"
HELP_ARGUMENT="--help"

##
# Convert a passed in string to lowercase
#
# @param ${1} String to convert to lowercase
# @return String converted to lowercase
##
to_lower() {
  local string="${1}"
  echo "${string}" | tr "[:upper:]" "[:lower:]"
}

##
# Convert the time in seconds into a readable format
#
# @param ${1} Duration in seconds
# @return Readable duration format
##
function to_duration {
  # Calculate the values for the duration
  local duration=${1}
  local days=$((duration / 60 / 60 / 24))
  local hours=$((duration / 60 / 60 % 24))
  local minutes=$((duration / 60 % 60))
  local seconds=$((duration % 60))

  # Convert the duration (if values are valid)
  local duration_format=
  (( ${days} > 0 )) && duration_format="${duration_format}${days} days "
  (( ${days} > 0 || ${hours} > 0 )) && duration_format="${duration_format}$[hours] hours "
  (( ${days} > 0 || ${hours} > 0 || ${minutes} > 0 )) && duration_format="${duration_format}${minutes} minutes "
  duration_format="${duration_format}${seconds} seconds"

  # Return the readable format
  echo "${duration_format}"
}

##
# Create the packaging directory (if it does not exist)
#
# @param ${1} Directory to create in `package` directory
##
function create_packaging_directory {
  local directory="${PACKAGES_DIRECTORY}/${1}"
  if [ ! -d "${directory}" ]
  then
    mkdir -p ${directory}
  fi
}

##
# Print the usage of the script
#
# @param ${1} Exit code to use when exiting
##
print_usage() {
  printf "Usage: `basename ${0}` [OPTION...]\n\n"
  printf "    %-27s%s\n" "${CLEAN_ARGUMENT}" "enable packing directory clean"
  printf "    %-27s%s\n" "${HELP_ARGUMENT}" "display this message"
  printf "\nDependencies:\n"
  printf "    %-27s%s\n" "${LIBUV_ARGUMENT}=(version)" "libuv driver dependency version to build"
  printf "\nDrivers:\n"
  printf "    DataStax C/C++ Driver:\n"
  printf "      %-25s%s\n" "${CPP_CORE_ARGUMENT}=(branch|tag)" "DataStax C/C++ driver version to build"
  printf "      %-25s%s\n" "${CPP_DSE_ARGUMENT}=(branch|tag)" "DataStax C/C++ DSE driver version to build"
  exit $1
}

# Parse the command line arguments
CPP_CORE_VERSION=
CPP_DSE_VERSION=
LIBUV_VERSION=INVALID_VERSION
CLEAN_ENABLED=false
ARGUMENT_COUNT=${#}
if [ ${ARGUMENT_COUNT} -gt 0 ]
then
  # Iterate through each argument
  for ((I = 0; I < ARGUMENT_COUNT; ++I))
  do
    # Ensure full command line argument are present
    if [[ ${1} =~ .*=.* ]]
    then
      # Get the current argument and value
      ARG=$(echo $(to_lower ${1}) | awk -F= '{print $1}')
      VALUE=$(echo $(to_lower ${1}) | awk -F= '{print $2}')
      shift

      if [ "${ARG}" == "${CPP_CORE_ARGUMENT}" ]
      then
        CPP_CORE_VERSION=${VALUE}
      elif [ "${ARG}" == "${CPP_DSE_ARGUMENT}" ]
      then
        CPP_DSE_VERSION=${VALUE}
      elif [ "${ARG}" == "${LIBUV_ARGUMENT}" ]
      then
        LIBUV_VERSION=${VALUE}
      fi
    else
      if [ "${1}" == "${CLEAN_ARGUMENT}" ]
      then
        CLEAN_ENABLED=true
      elif [ "${1}" == "${HELP_ARGUMENT}" ]
      then
        print_usage 0
      fi
      
      # Move to the next argument
      shift
    fi
  done
fi

# Determine if the script should continue to process package build
CONTINUE_PACKAGE_BUILD=true
if [ "${LIBUV_VERSION}" == "INVALID_VERSION" ]
then
  printf "libuv version is required\n"
  CONTINUE_PACKAGE_BUILD=false
fi
if [ -z "${CPP_CORE_VERSION}" ] && [ -z ${CPP_DSE_VERSION} ]
then
  printf "DataStax C/C++ driver [core|DSE] version is required\n"
  CONTINUE_PACKAGE_BUILD=false
fi
if [ -n "${CPP_DSE_VERSION}" ] && [ ! -e "${SCRIPT_DIRECTORY}/id_rsa" ]
then
  printf "Private key is required: Ensure '${SCRIPT_DIRECTORY}/id_rsa' exists\n"
  CONTINUE_PACKAGE_BUILD=false
fi
if [ "${CONTINUE_PACKAGE_BUILD}" == "false" ]
then
  print_usage 1
fi

# Determine if the packaging directories should be cleaned
if [ "${CLEAN_ENABLED}" == "true" ]
then
  printf "Cleaning packaging directory [${PACKAGES_DIRECTORY}] ..."
  rm -rf ${PACKAGES_DIRECTORY}
  printf " done.\n"
fi

#Get the starting time
START_TIME=$(date +%s)

#Perform the linux packaging
declare -a FAILED_DISTROS
VAGRANT_BOXES=( "vagrant/centos/6" "vagrant/centos/7" "vagrant/ubuntu/12.04" "vagrant/ubuntu/14.04" "vagrant/ubuntu/16.04" )
# Iterate through each vagrant box
for vagrant_box in ${VAGRANT_BOXES[@]}
do
  # Create the packages directory (strip vagrant from path)
  DISTRO=${vagrant_box#vagrant/}
  create_packaging_directory ${DISTRO}

  # Build the packing for the vagrant box
  pushd ${SCRIPT_DIRECTORY}/${vagrant_box} > /dev/null 2>&1
  CORE=${CPP_CORE_VERSION} DSE=${CPP_DSE_VERSION} LIBUV=${LIBUV_VERSION} vagrant box update
  CORE=${CPP_CORE_VERSION} DSE=${CPP_DSE_VERSION} LIBUV=${LIBUV_VERSION} vagrant up
  PACKAGING_ERROR_CODE=${?}
  CORE=${CPP_CORE_VERSION} DSE=${CPP_DSE_VERSION} LIBUV=${LIBUV_VERSION} vagrant destroy -f
  popd > /dev/null 2>&1

  # Determine if there was an issue creating the packages
  if [ ${PACKAGING_ERROR_CODE} -ne 0 ]
  then
    FAILED_INDEX=${FAILED_DISTROS[@]}
    FAILED_DISTROS[${FAILED_INDEX}]=${DISTRO}
  fi
done

#Calculate the build time
END_TIME=$(date +%s)
PACKAGING_TIME=$((${END_TIME} - ${START_TIME}))
DURATION=$(to_duration ${PACKAGING_TIME})
printf "\nPackaging took ${DURATION}\n"

# Determine if the packaging was successful or not
if [ -z ${FAILED_DISTROS} ]
then
  printf "\n\nAll packages were created successfully\n"
else
  printf "\n\n### Failed to Create All Packages ###\n"
  # Iterate through each failed distro
  for failed_distro in ${FAILED_DISTROS[@]}
  do
    printf "  ${failed_distro}\n"
  done
  printf "### Failed to Create All Packages ###\n"
  exit 2
fi
