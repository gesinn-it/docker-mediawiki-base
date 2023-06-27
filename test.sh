#!/bin/bash
set -euo pipefail

cd "$(dirname "$(readlink -f "$BASH_SOURCE")")"

readarray -t wm_versions < <(yq eval '.[] | keys | .[]' matrix.yaml)

for wm_version in "${wm_versions[@]}"; do
    echo ${wm_version} defaultversion: ;

    # base image without PHP version in tag
    default_version=$(yq eval  ".mediawiki.\"${wm_version}\".default" matrix.yaml)
    echo defaultversion: ${default_version};


    # PHP version array
    readarray -t php_versions < <(yq eval ".mediawiki.\"${wm_version}\".versions | .[]" matrix.yaml)

    for php_version in "${php_versions[@]}"; do
        echo "PHPVERSION for mw ${wm_version}: ${php_version}";
    done 
    
done
# Print the default versions
# echo "Default versions:"
# while read -r version default; do
#   echo "MediaWiki version $version: $default"
# done <<< "$default_versions"

# Print all versions
#echo "All versions:"
#cat values.yaml | yq eval '.mediawiki | to_entries[] | {version: .key, default: .value.default, versions: .value.versions}' - | jq -r '.version as $version | "MediaWiki version \($version): \(.default)\nAvailable versions: \(.versions)"'
