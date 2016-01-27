#! /usr/bin/env bash

#
# run_metrics.sh
#
# Runs a set of static code analyzers and generates artifacts. Also
# uploads the artifacts to s3 and does a comparison between the
# current commit and the base merge to determine code quality for the
# new code.
#
# Usage:
# run <project_path>
#
#

provision () {
    # creates a virtualenv with the specified requirements file
    #
    # :param venv: the path to where the virtualenv shoud be made
    # :param requirements_file: the path to the requirements file
    local venv="$1"
    local requirements_file="$2"

    [[ -z $(which virtualenv) ]] \
	&& echo "no virtualenv present, exiting." && exit 1
    [[ -z $(which git) ]] \
	&& echo "no git present, exiting." && exit 1

    if [[ ! -e "${venv}" ]]; then
	virtualenv "${venv}"
	"${venv}"/bin/pip install -r "$requirements_file"
    fi
}


check_commit () {
    # runs the chackers for a given commit, and generate artifacts
    #
    # :param project_path: the python package to be checked
    # :param working_dir: path to where the artifacts and venv is
    # :param commit_sha1: the commit agains whichs the checks are made
    local project_path="$1"
    local working_dir="$2"
    local commit_sha1="$3"
    local venv="${working_dir}/metrics_${commit_sha1}"
    local artifacts_dir="${working_dir}/artifacts/${commit_sha1}"


    [[ -d "${artifacts_dir}" ]] || mkdir -p "${artifacts_dir}"

    cd "${project_path}" && git checkout "${commit_sha1}"
    provision "${venv}" "${working_dir}/requirements.txt"
    "${venv}/bin/pip" install .. # the directory where the setup.py is located
    "${venv}/bin/pylint" --output-format=json \
			 --load-plugins pylint_django \
			 --rcfile "${working_dir}/pylintrc" \
		       "${project_path}" > "${artifacts_dir}/pylint-results.json"
    "${venv}/bin/radon" cc -j \
			"${project_path}" > "${artifacts_dir}/radon-results.json"

    ls -1 "${artifacts_dir}"/*
}

diff_pylint() {
    # compares the pylint output of the two pylint json-files
    #
    # :param working_dir: the directory where artifacts are located
    # :param head_sha1: the HEAD commit from the working branch
    # :param merge_base_sha1: the commit destination master branch
    local working_dir="$1"
    local head_sha1="$2"
    local merge_base_sha1="$3"
    local artifacts_dir="${working_dir}/artifacts/"
    local source="${working_dir}/artifacts/${head_sha1}"
    local destination="${working_dir}/artifacts/${merge_base_sha1}"

    /usr/bin/env python "${working_dir}/diff_pylint.py" \
		 "${source}/pylint-results.json" \
		 "${destination}/pylint-results.json"
}

diff_radon() {
    # compares the radon output of two radon json-files
    echo 'implement me'
}

run () {
    # run the checkers available and compares the artifacts generated
    #
    # :param project_path: the path to the python package to be
    #                      checked
    local project_path="$1"
    local working_dir=$(mktemp -d --tmpdir=/tmp)
    local head_sha1=$(cd "${project_path}" && git rev-parse HEAD)
    local merge_base_sha1=$(cd "${project_path}" && \
				   git merge-base HEAD "${GIT_ORIGIN_BRANCH:-master}")
    local here="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

    ln -s "${here}/pylintrc" "${working_dir}/pylintrc"
    ln -s "${here}/diff_pylint.py" "${working_dir}/diff_pylint.py"
    ln -s "${here}/requirements.txt" "${working_dir}/requirements.txt"

    check_commit "${project_path}" "${working_dir}" "${head_sha1}"
    check_commit "${project_path}" "${working_dir}" "${merge_base_sha1}"
    diff_pylint "${working_dir}" "${head_sha1}" "${merge_base_sha1}"
    git checkout "${head_sha1}"	# checkout to initial state

    echo "done!"
}

run "$@"
