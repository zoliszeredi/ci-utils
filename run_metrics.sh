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
    local venv="$1/metrics"
    local here="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

    [[ -z $(which virtualenv) ]] \
	&& echo "no virtualenv present, exiting." && exit 1
    [[ -z $(which git) ]] \
	&& echo "no git present, exiting." && exit 1

    if [[ ! -e "${venv}" ]]; then
	virtualenv "${venv}"
	"${venv}"/bin/pip install -r requirements.txt
    fi

    ln -s "${here}/pylintrc" "${venv}/pylintrc"
    ln -s "${here}/diff_pylint.py" "${venv}/diff_pylint.py"
}


check_commit () {
    local project_path="$1"
    local commit_sha1="$3"
    local venv="$2/metrics"
    local artifacts_dir="${venv}/artifacts/${commit_sha1}"


    [[ -d "${artifacts_dir}" ]] || mkdir -p "${artifacts_dir}"

    cd "${project_path}" && git checkout "${commit_sha1}"
    "${venv}/bin/pip" install --upgrade ..
    "${venv}/bin/pylint" --output-format=json \
			 --load-plugins pylint_django \
			 --rcfile "${venv}/pylintrc" \
		       "${project_path}" > "${artifacts_dir}/pylint-results.json"
    "${venv}/bin/radon" cc -j \
			"${project_path}" > "${artifacts_dir}/radon-results.json"

    ls -1 "${artifacts_dir}"/*
}

diff_pylint() {
    # compares the pylint output of the two pylint json-files
    local working_dir="$1"
    local venv="${working_dir}/metrics"
    local artifacts_dir="${working_dir}/metrics/artifacts/"
    local after="${artifacts_dir}$2"
    local before="${artifacts_dir}$3"

    "${venv}/bin/python" "${venv}/diff_pylint.py" \
			 "${after}/pylint-results.json" \
			 "${before}/pylint-results.json"
}

diff_radon() {
    # compares the radon output of two radon json-files
    echo 'implement me'
}

run () {
    local project_path="$1"
    local working_dir=$(mktemp -d --tmpdir=/tmp)
    local head_sha1=$(cd "${project_path}" && git rev-parse HEAD)
    local merge_base_sha1=$(cd "${project_path}" && \
				   git merge-base HEAD "${GIT_ORIGIN_BRANCH:-master}")
    local venv="${working_dir}/metrics"
    local artifacts_dir="${venv}/artifacts/"

    provision "${working_dir}"
    check_commit "${project_path}" "${working_dir}" "${head_sha1}"
    check_commit "${project_path}" "${working_dir}" "${merge_base_sha1}"
    diff_pylint "${working_dir}" "${head_sha1}" "${merge_base_sha1}"
    git checkout "${head_sha1}"	# checkout to initial state

    echo "done!"
}

run "$@"
