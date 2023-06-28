#!/bin/bash
set -euo pipefail

cd "$(dirname "$(readlink -f "$BASH_SOURCE")")"

source ./helpers.sh

if [ "$#" -ne 3 ]; then
  echo "not enough arguments provided"
  exit 1
fi

github_mw_version="$1"
github_php_version="$2"
github_image_variant="$3"

mediawikiVersion="$(mediawiki_version $github_mw_version)"


extras="${variantExtras[$github_image_variant]}"
cmd="${variantCmds[$github_image_variant]}"
base="${variantBases[$github_image_variant]}"

sed -r \
	-e 's!%%MEDIAWIKI_VERSION%%!'"$mediawikiVersion"'!g' \
	-e 's!%%MEDIAWIKI_MAJOR_VERSION%%!'"$github_mw_version"'!g' \
	-e 's!%%PHP_VERSION%%!'"$github_php_version"'!g' \
	-e 's!%%VARIANT%%!'"$github_image_variant"'!g' \
	-e 's!%%APCU_VERSION%%!'"${peclVersions[APCu]}"'!g' \
	-e 's@%%VARIANT_EXTRAS%%@'"$extras"'@g' \
	-e 's!%%CMD%%!'"$cmd"'!g' \
	"Dockerfile-${base}.template" > "./Dockerfile"


