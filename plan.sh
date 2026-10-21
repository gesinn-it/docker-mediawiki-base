#!/bin/bash
# Decides which entries of matrix.json have to be (re)built and prints them as a JSON array.
# Human readable reasons go to stderr.
#
# Environment:
#   IMAGE_REPOSITORY   published image, e.g. gesinn/mediawiki-base
#   FORCE              "true" rebuilds everything
#   ALWAYS_BUILD       "true" skips change detection (e.g. push: the repository content changed)
#   ONLY_MEDIAWIKI     optional, restrict to one MediaWiki major version
#   ONLY_PHP           optional, restrict to one PHP version
set -euo pipefail

cd "$(dirname "$(readlink -f "$BASH_SOURCE")")"
source ./helpers.sh

: "${IMAGE_REPOSITORY:?}"
force="${FORCE:-false}"
always="${ALWAYS_BUILD:-false}"
only_mw="${ONLY_MEDIAWIKI:-}"
only_php="${ONLY_PHP:-}"

plan='[]'
while read -r entry; do
	mw="$(jq -r .mediawiki_version <<< "$entry")"
	php="$(jq -r .php_version <<< "$entry")"
	label="MediaWiki ${mw} / PHP ${php}"

	if [[ -n "$only_mw" && "$only_mw" != "$mw" ]] || [[ -n "$only_php" && "$only_php" != "$php" ]]; then
		echo "skip    ${label}: not selected" >&2
		continue
	fi

	base_digest="$(php_base_digest "$php")"

	if [[ "$force" == "true" ]]; then
		reason="forced"
	elif [[ "$always" == "true" ]]; then
		reason="repository content changed"
	else
		IFS=':' read -r ref_type ref_value ref_sha <<< "$(mediawiki_ref "$mw")"
		if [[ "$ref_type" == "tag" ]]; then
			full_version="$ref_value"
		else
			full_version="${mw}-dev-${ref_sha:0:7}"
		fi
		# the fully qualified tag contains the resolved MediaWiki version, so a new
		# release or a new commit on a REL1_XX branch leads to a tag that does not exist yet
		published="${IMAGE_REPOSITORY}:${full_version}-php${php}-apache"
		published_digest="$(docker buildx imagetools inspect "$published" \
			--format '{{index .Manifest.Annotations "org.opencontainers.image.base.digest"}}' 2>/dev/null || true)"

		if [[ -z "$published_digest" || "$published_digest" == "<no value>" ]]; then
			reason="${published} is not published or has no base digest label"
		elif [[ "$published_digest" != "$base_digest" ]]; then
			reason="php:${php}-apache changed (${published_digest:7:12} -> ${base_digest:7:12})"
		else
			echo "up-to-date ${label}: ${published} was built on php:${php}-apache ${base_digest:7:12}" >&2
			continue
		fi
	fi

	echo "rebuild ${label}: ${reason}" >&2
	plan="$(jq -c --arg mw "$mw" --arg php "$php" --arg digest "$base_digest" --arg reason "$reason" \
		'. + [{mediawiki_version:$mw, php_version:$php, php_base_digest:$digest, reason:$reason}]' <<< "$plan")"
done < <(jq -c '.[]' matrix.json)

echo "$plan"
