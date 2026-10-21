#!/bin/bash
# Triggers the build in gesinn-it/docker-mediawiki for the planned entries, one after the other (each downstream
# run builds several images in parallel, running them all at once exceeds the Docker Hub rate limits).
#
# Usage: trigger_downstream.sh <plan-json> <build-timestamp>
#
# Environment:
#   GH_TOKEN           token that may dispatch workflows in the downstream repository and read its runs
#   IMAGE_REPOSITORY   published image, e.g. gesinn/mediawiki-base
#   CHECK_PUBLISHED    "true": only trigger entries whose per-build tag <version>-php<v>-apache-<timestamp> exists,
#                      i.e. entries that were pushed by this run (the others failed or were skipped)
#   DOWNSTREAM_REPO    default gesinn-it/docker-mediawiki
set -uo pipefail

cd "$(dirname "$(readlink -f "$BASH_SOURCE")")"
source ./helpers.sh

plan="${1:?plan json}"
timestamp="${2:?build timestamp}"
: "${IMAGE_REPOSITORY:?}"
repo="${DOWNSTREAM_REPO:-gesinn-it/docker-mediawiki}"
check="${CHECK_PUBLISHED:-true}"

failed=0
while read -r entry; do
	mw="$(jq -r .mediawiki_version <<< "$entry")"
	php="$(jq -r .php_version <<< "$entry")"
	ref="$(jq -r '.downstream_ref // "main"' <<< "$entry")"
	enabled="$(jq -r '.downstream // false' <<< "$entry")"
	label="MediaWiki ${mw} / PHP ${php} (${repo}@${ref})"

	if [[ "$enabled" != "true" ]]; then
		echo "skip     ${label}: downstream trigger disabled"
		continue
	fi

	if [[ "$check" == "true" ]]; then
		IFS=':' read -r ref_type ref_value ref_sha <<< "$(mediawiki_ref "$mw")"
		if [[ "$ref_type" == "tag" ]]; then full="$ref_value"; else full="${mw}-dev-${ref_sha:0:7}"; fi
		tag="${IMAGE_REPOSITORY}:${full}-php${php}-apache-${timestamp}"
		if ! docker buildx imagetools inspect "$tag" > /dev/null 2>&1; then
			echo "skip     ${label}: ${tag} was not published by this run"
			continue
		fi
	fi

	echo "trigger  ${label}"
	before="$(date -u -d '-20 seconds' +%Y-%m-%dT%H:%M:%SZ)"
	if ! gh workflow run main.yml --repo "$repo" --ref "$ref" \
		-f mediawiki_version="$mw" -f php_version="$php" -f build_timestamp="$timestamp"; then
		echo "::error::could not dispatch the downstream build for ${label}"
		failed=1
		continue
	fi

	run_id=''
	for _ in $(seq 1 30); do
		run_id="$(gh run list --repo "$repo" --workflow main.yml --branch "$ref" --event workflow_dispatch --limit 10 \
			--json databaseId,createdAt \
			--jq "[.[] | select(.createdAt >= \"${before}\")] | sort_by(.createdAt) | .[0].databaseId // empty")"
		[[ -n "$run_id" ]] && break
		sleep 5
	done
	if [[ -z "$run_id" ]]; then
		echo "::error::downstream run for ${label} did not show up"
		failed=1
		continue
	fi

	echo "waiting  https://github.com/${repo}/actions/runs/${run_id}"
	if gh run watch "$run_id" --repo "$repo" --interval 30 --exit-status > /dev/null 2>&1; then
		echo "done     ${label}"
	else
		echo "::error::downstream build failed for ${label}: https://github.com/${repo}/actions/runs/${run_id}"
		failed=1
	fi
done < <(jq -c '.[]' <<< "$plan")

exit "$failed"
