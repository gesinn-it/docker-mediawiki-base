#!/bin/bash
set -euo pipefail


# create image tag, by using the two variables and the values in images.yaml


readarray -t mediawikiReleases < <(yq eval '.[] | keys | .[]' images.yaml)

if [ "$#" -ne 3 ]; then
  echo "not enough arguments provided"
  exit 1
fi



build_mw_version="$1"
build_php_version="$2"
build_mw_variant="$3"

default_php_version=$(yq eval  ".mediawiki.\"${build_mw_version}\".default" images.yaml)

full_mw_version=$(cat ./latest/${build_mw_version}/${build_php_version}/${build_mw_variant}/Dockerfile | sed -n -e 's/^.*ENV MEDIAWIKI_VERSION //p')

IMAGE_TAG="gesinn/docker-mediawiki-base-${build_mw_variant}:${full_mw_version}-php${build_php_version}"

if [ "$build_php_version" = "$default_php_version" ]; then
    echo "Strings are equal."
fi

echo $IMAGE_TAG
