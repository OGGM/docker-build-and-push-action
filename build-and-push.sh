#!/bin/bash
set -e

if [[ -n "${INPUT_ONLY_ON_REPO}" && "${INPUT_ONLY_ON_REPO^^}" != "${GITHUB_REPOSITORY^^}" ]]; then
    echo "Skipping on unexpected repository"
    exit 0
fi

if [[ -z "${INPUT_PATH}" || -z "${INPUT_NAME}" ]]; then
    echo "Required input parameter is empty"
    exit -1
fi

if [[ -n "${INPUT_USER}" && -n "${INPUT_PASS}" ]]; then
    echo "Logging into docker registry..."
    printf '%s\n' "${INPUT_PASS}" | docker login -u "${INPUT_USER}" --password-stdin "${INPUT_REGISTRY}"
    echo "Ok"
fi

set -x

if [[ ${INPUT_BUILDKIT} == true ]]; then
    export DOCKER_BUILDKIT=1
fi

cd "${INPUT_PATH}"
DATE_ID="$(date +%Y%m%d)"

EXTRA_ARGS=()
for BARG in ${INPUT_BUILD_ARGS//,/ }; do
    EXTRA_ARGS+=( --build-arg "${BARG}" )
done
if [[ ${INPUT_FORCE_PULL} != false ]]; then
    EXTRA_ARGS+=( --pull )
fi
if [[ ${INPUT_NO_CACHE} == true ]]; then
    EXTRA_ARGS+=( --no-cache )
fi

docker build "${EXTRA_ARGS[@]}" -t "${INPUT_TMP_TAG}" .

if [[ ${INPUT_NO_PUSH} != false ]]; then
    exit 0
fi

if [[ -n "${INPUT_PUSH_ON_REPO}" && "${INPUT_PUSH_ON_REPO^^}" != "${GITHUB_REPOSITORY^^}" ]]; then
    echo "Skipping upload on unexpected repository"
    exit 0
fi

for TAG in ${INPUT_TAGS//,/ }; do
    docker tag "${INPUT_TMP_TAG}" "${INPUT_NAME}:${TAG}"
    docker push "${INPUT_NAME}:${TAG}"
done

if [[ ${INPUT_DATE_TAG} != false ]]; then
    docker tag "${INPUT_TMP_TAG}" "${INPUT_NAME}:${DATE_ID}"
    docker push "${INPUT_NAME}:${DATE_ID}"
fi

if [[ ${INPUT_COMMIT_TAG} != false ]]; then
    docker tag "${INPUT_TMP_TAG}" "${INPUT_NAME}:${GITHUB_SHA}"
    docker push "${INPUT_NAME}:${GITHUB_SHA}"
fi
