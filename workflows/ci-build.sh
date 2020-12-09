#!/bin/bash

BASE_DIR=${PWD}
CACHE_DIR=${PWD}/ci_cache


######################################################################
# Actions CI helpers
######################################################################

start_test()
{
    echo "::group::$2"
}

finish_test()
{
    echo "::endgroup::$2"
}


######################################################################
# Admesh setup
######################################################################

chmod +x ${BASE_DIR}/.github_scripts/travis/*.py

ADMESH_DIR=${CACHE_DIR}/admesh-0.98.4
mkdir -p ${CACHE_DIR}
cd ${CACHE_DIR}
if [ ! -d ${ADMESH_DIR} ]; then
  echo "Admesh cache miss; fetching and building ..."
  wget https://github.com/admesh/admesh/releases/download/v0.98.4/admesh-0.98.4.tar.gz
  tar -zxf admesh-0.98.4.tar.gz
  cd ${ADMESH_DIR}
  ./configure
  make
  chmod +x admesh
fi
cd ${BASE_DIR}
sudo ln -s ${ADMESH_DIR}/admesh /usr/bin/admesh


######################################################################
# STL / changed file Validation
######################################################################

start_test validate_stls "Validate STLs"

found_error=0

if [ "$GIT_PULL_REQUEST" == "" ]; then
  # Regular branch push, test all files
  find ${BASE_DIR} -type f -iname "*.STL" | xargs -n 1 -I {} bash -c '${BASE_DIR}/.github_scripts/workflows/validate-file.py "{}" || touch failed'
else
  cd ${BASE_DIR}
  git fetch --quiet
  # Compare head against the branch to merge into (PR)
  git diff --name-only --diff-filter=AMR -R HEAD origin/${GIT_PR_BASE_BRANCH} | xargs -n 1 -I {} bash -c '${BASE_DIR}/.github_scripts/workflows/validate-file.py "{}" || touch failed'
fi

if [ -f "failed" ]; then
    echo "Error occurred while validating STLs."
    exit 255
fi

finish_test validate_stls "Validate STLs"

######################################################################
# Markdown Validation
######################################################################

start_test validate_markdown "Validate Markdown"

cd ${BASE_DIR}

# Validate all markdown files (eg, README.md).
remark -u validate-links --no-stdout --frail .

finish_test validate_markdown "Validate Markdown"

