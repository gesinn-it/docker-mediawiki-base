#!/bin/bash
# Regenerates the version table in README.md (between the <!-- versions:start --> and
# <!-- versions:end --> markers) from the labels of the published images.
# Every entry of matrix.json is looked up in the registry, not only the ones of the last run.
#
# Environment:
#   IMAGE_REPOSITORY   published image, default gesinn/mediawiki-base
set -euo pipefail

cd "$(dirname "$(readlink -f "$BASH_SOURCE")")"
source ./helpers.sh

repository="${IMAGE_REPOSITORY:-gesinn/mediawiki-base}"
readme="README.md"
start='<!-- versions:start -->'
end='<!-- versions:end -->'

grep -qxF "$start" "$readme" && grep -qxF "$end" "$readme" \
	|| { echo "Error: markers ${start} / ${end} not found in ${readme}" >&2; exit 1; }

table="| MediaWiki | PHP | Operating system | Apache | APCu |"$'\n'"|---|---|---|---|---|"
while read -r entry; do
	mw="$(jq -r .mediawiki_version <<< "$entry")"
	php="$(jq -r .php_version <<< "$entry")"
	php_default="$(jq -r .php_default <<< "$entry")"

	IFS=':' read -r ref_type ref_value ref_sha <<< "$(mediawiki_ref "$mw")"
	if [[ "$ref_type" == "tag" ]]; then
		full_version="$ref_value"
	else
		full_version="${mw}-dev-${ref_sha:0:7}"
	fi

	image="${repository}:${full_version}-php${php}-apache"
	annotations="$(docker buildx imagetools inspect "$image" --format '{{json .Manifest.Annotations}}')" \
		|| { echo "Error: cannot inspect ${image}" >&2; exit 1; }

	# labels that an older image does not carry yet are shown as n/a
	label() { jq -r --arg k "$1" '.[$k] // "n/a"' <<< "$annotations"; }
	os="$(label it.gesinn.os.version)"
	[[ "$os" == "n/a" ]] || os="${os^}"
	php_full="$(label it.gesinn.php.version)"
	[[ "$php" == "$php_default" ]] && php_full+=" (default)"
	[[ "$ref_type" == "tag" ]] || full_version+=" (pre-release)"

	table+=$'\n'"| ${full_version} | ${php_full} | ${os} | $(label it.gesinn.apache.version) | $(label it.gesinn.apcu.version) |"
done < <(jq -c '.[]' matrix.json)

tmp="$(mktemp)"
awk -v start="$start" -v end="$end" -v table="$table" '
	$0 == start { print; print table; skip = 1; next }
	$0 == end   { skip = 0 }
	!skip       { print }
' "$readme" > "$tmp"
cat "$tmp" > "$readme"
rm "$tmp"
