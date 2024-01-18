#!/bin/bash

if [ -z $1 ]; then
   echo "Missing PYTHON_BASE first argument"
   exit 1
fi

PYTHON_BASE=$1

PYTHON_BIN=${PYTHON_BASE}/bin/python3
if [ ! -x ${PYTHON_BIN} ]; then
   echo "Python ${PYTHON_BIN} is not executable"
   exit 1
fi

# So the PATH has pip3, pipenv, pg_config
export PATH=/usr/local/bin/:${PYTHON_BASE}/bin/:/usr/lib/postgresql/14/bin:${PATH}

#PIPENV_BIN=${PYTHON_BASE}/bin/pipenv
PIPENV_BIN=`which pipenv`
if [ ! -x ${PIPENV_BIN} ]; then
   echo "Pipenv ${PIPENV_BIN} is not executable"
   exit 1
fi

PIPENV_HOME=`pwd`
# Where all our Pipenv's are kept
export WORKON_HOME=/soft/python-pipenv

# Save output also to file
exec &> >(tee -a ${PIPENV_HOME}/pipenv-build.log)

echo "*****************************************************"
echo "***** Installing Pipenv                         *****"
echo "* PYTHON_BASE=${PYTHON_BASE}"
echo "* PIPENV_HOME=${PIPENV_HOME}"

${PIPENV_BIN} --rm
${PIPENV_BIN} --python ${PYTHON_BASE}/bin/python3 --bare install --deploy

# Where the VirtualEnv is located
PIPENV_VENV=`pipenv --venv`
echo "* PIPENV_VENV=${PIPENV_VENV}"

# Compile
${PYTHON_BIN} -m compileall -q ${PIPENV_VENV}

# SeLinux
echo "chcon -R system_u:object_r:lib_t:s0 ${PIPENV_VENV}"
chcon -R system_u:object_r:lib_t:s0 ${PIPENV_VENV}
echo "chcon -t lib_t mod_wsgi..."
find ${PIPENV_VENV} -name mod_wsgi\*.so -exec chcon -v -t lib_t {} \;

echo "*****************************************************"
