#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# This file is part of the xPack distribution.
#   (https://xpack.github.io)
# Copyright (c) 2020 Liviu Ionescu.
#
# Permission to use, copy, modify, and/or distribute this software 
# for any purpose is hereby granted, under the terms of the MIT license.
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# Safety settings (see https://gist.github.com/ilg-ul/383869cbb01f61a51c4d).

if [[ ! -z ${DEBUG} ]]
then
  set ${DEBUG} # Activate the expand mode if DEBUG is anything but empty.
else
  DEBUG=""
fi

set -o errexit # Exit if command failed.
set -o pipefail # Exit if pipe failed.
set -o nounset # Exit if variable not set.

# Remove the initial space and instead use '\n'.
IFS=$'\n\t'

# -----------------------------------------------------------------------------
# Identify the script location, to reach, for example, the helper scripts.

build_script_path="$0"
if [[ "${build_script_path}" != /* ]]
then
  # Make relative path absolute.
  build_script_path="$(pwd)/$0"
fi

script_folder_path="$(dirname "${build_script_path}")"
script_folder_name="$(basename "${script_folder_path}")"

# =============================================================================

scripts_folder_path="$(dirname $(dirname "${script_folder_path}"))/scripts"
helper_folder_path="${scripts_folder_path}/helper"

# -----------------------------------------------------------------------------

# Inner script to run inside Docker containers to build the 
# xPack distribution packages.

# For native builds, it runs on the host (macOS build cases,
# and development builds for GNU/Linux).

# -----------------------------------------------------------------------------

source "${scripts_folder_path}/defs-source.sh"

# This file is generated by the host build script.
source "${scripts_folder_path}/host-defs-source.sh"

# Helper functions.
source "${helper_folder_path}/common-functions-source.sh"
source "${helper_folder_path}/container-functions-source.sh"
source "${helper_folder_path}/common-libs-functions-source.sh"
source "${helper_folder_path}/common-apps-functions-source.sh"

# The order is important, it may override helper defs.
if [ -f "${scripts_folder_path}/common-functions-source.sh" ]
then
  source "${scripts_folder_path}/common-functions-source.sh"
fi
source "${scripts_folder_path}/common-libs-functions-source.sh"
source "${scripts_folder_path}/common-apps-functions-source.sh"
source "${scripts_folder_path}/common-versions-source.sh"

# -----------------------------------------------------------------------------

if [ ! -z "#{DEBUG}" ]
then
  echo $@
fi

WITH_STRIP="y"
WITH_PDF="y"
WITH_HTML="y"
IS_DEVELOP=""
IS_DEBUG=""
WITH_TESTS="y"
LINUX_INSTALL_RELATIVE_PATH=""
TEST_ONLY=""

if [ "$(uname)" == "Linux" ]
then
  JOBS="$(nproc)"
elif [ "$(uname)" == "Darwin" ]
then
  JOBS="$(sysctl hw.ncpu | sed 's/hw.ncpu: //')"
else
  JOBS="1"
fi

while [ $# -gt 0 ]
do

  case "$1" in

    --disable-strip)
      WITH_STRIP="n"
      shift
      ;;

    --disable-tests)
      WITH_TESTS="n"
      shift
      ;;

    --without-pdf)
      WITH_PDF="n"
      shift
      ;;

    --with-pdf)
      WITH_PDF="y"
      shift
      ;;

    --without-html)
      WITH_HTML="n"
      shift
      ;;

    --with-html)
      WITH_HTML="y"
      shift
      ;;

    --jobs)
      JOBS=$2
      shift 2
      ;;

    --develop)
      IS_DEVELOP="y"
      shift
      ;;

    --debug)
      IS_DEBUG="y"
      shift
      ;;

    --linux-install-relative-path)
      LINUX_INSTALL_RELATIVE_PATH="$2"
      shift 2
      ;;

    --test-only)
      TEST_ONLY="y"
      shift
      ;;

    *)
      echo "Unknown action/option $1"
      exit 1
      ;;

  esac

done

if [ "${IS_DEBUG}" == "y" ]
then
  WITH_STRIP="n"
fi

if [ "${TARGET_PLATFORM}" == "win32" ]
then
  export WITH_TESTS="n"
fi

# -----------------------------------------------------------------------------

start_timer

detect_container

set_xbb_env

set_compiler_env

# -----------------------------------------------------------------------------

echo
echo "Here we go..."
echo

tests_initialize

build_versions

# -----------------------------------------------------------------------------

if [ ! "${TEST_ONLY}" == "y" ]
then
  (
    if [ "${TARGET_PLATFORM}" == "win32" ]
    then
      # The Windows still has a reference to libgcc_s and libwinpthread
      DO_COPY_GCC_LIBS="y"
    fi

    prepare_app_folder_libraries

    # strip_libs
    strip_binaries

    copy_distro_files

    check_binaries

    create_archive

    # Change ownership to non-root Linux user.
    fix_ownership
  )
fi

# -----------------------------------------------------------------------------

# Final checks.
# To keep everything as pristine as possible, run tests
# only after the archive is packed.

prime_wine

unset_compiler_env

tests_run

# -----------------------------------------------------------------------------

stop_timer

exit 0

# -----------------------------------------------------------------------------
