#!/bin/bash
set -euo pipefail

cd "$(dirname "$(readlink -f "$BASH_SOURCE")")"

source ./helpers.sh

if [ "$#" -ne 2 ]; then
  echo "not enough arguments provided"
  exit 1
fi

github_mw_version="$1"
github_php_version="$2"
github_image_variant='apache'

mw_ref="$(mediawiki_ref "$github_mw_version")"
mw_type="${mw_ref%%:*}"
mw_rest="${mw_ref#*:}"

tmpSetup=$(mktemp)
trap 'rm -f "$tmpSetup"' EXIT

if [[ "$mw_type" == "tag" ]]; then
  mediawikiVersion="$mw_rest"
  cat > "$tmpSetup" << 'SETUP'
# MediaWiki setup
RUN set -eux; \
	fetchDeps=" \
		gnupg \
		dirmngr \
	"; \
	apt-get update; \
	apt-get install -y --no-install-recommends $fetchDeps; \
	\
	curl -fSL "https://releases.wikimedia.org/mediawiki/${MEDIAWIKI_MAJOR_VERSION}/mediawiki-${MEDIAWIKI_VERSION}.tar.gz" -o mediawiki.tar.gz; \
	curl -fSL "https://releases.wikimedia.org/mediawiki/${MEDIAWIKI_MAJOR_VERSION}/mediawiki-${MEDIAWIKI_VERSION}.tar.gz.sig" -o mediawiki.tar.gz.sig; \
	export GNUPGHOME="$(mktemp -d)"; \
	# Fetch and import keys from the official Wikimedia key bundle \
	curl -fsSL https://www.mediawiki.org/keys/keys.txt | gpg --import;  \
	gpg --batch --verify mediawiki.tar.gz.sig mediawiki.tar.gz; \
	tar -x --strip-components=1 -f mediawiki.tar.gz; \
	gpgconf --kill all; \
	rm -r "$GNUPGHOME" mediawiki.tar.gz.sig mediawiki.tar.gz; \
	chown -R www-data:www-data extensions skins cache images; \
	\
	apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false $fetchDeps; \
	rm -rf /var/lib/apt/lists/*
SETUP
elif [[ "$mw_type" == "branch" ]]; then
  mw_branch="${mw_rest%%:*}"
  mw_sha="${mw_rest#*:}"
  mediawikiVersion="${github_mw_version}-dev-${mw_sha}"
  cat > "$tmpSetup" << SETUP
# MediaWiki setup (branch: ${mw_branch}@${mw_sha})
RUN set -eux; \\
	git clone --depth 1 --branch ${mw_branch} https://github.com/wikimedia/mediawiki.git .; \\
	git checkout ${mw_sha}; \\
	chown -R www-data:www-data extensions skins cache images
SETUP
else
  echo "Error: unexpected mediawiki_ref output: ${mw_ref}" >&2
  exit 1
fi


extras="${variantExtras[$github_image_variant]}"
cmd="${variantCmds[$github_image_variant]}"
base="${variantBases[$github_image_variant]}"

sed -r \
	-e 's!%%MEDIAWIKI_VERSION%%!'"$mediawikiVersion"'!g' \
	-e 's!%%MEDIAWIKI_MAJOR_VERSION%%!'"$github_mw_version"'!g' \
	-e 's!%%PHP_VERSION%%!'"$github_php_version"'!g' \
	-e 's!%%VARIANT%%!'"$github_image_variant"'!g' \
	-e 's!%%APCU_VERSION%%!'"${peclVersions[APCu]}"'!g' \
	-e 's!%%AST_VERSION%%!'"${peclVersions[ast]}"'!g' \
	-e 's@%%VARIANT_EXTRAS%%@'"$extras"'@g' \
	-e 's!%%CMD%%!'"$cmd"'!g' \
	"Dockerfile-${base}.template" \
| awk -v tmpfile="$tmpSetup" '
/%%MEDIAWIKI_SETUP%%/ {
	while ((getline line < tmpfile) > 0) print line
	close(tmpfile)
	next
}
{ print }
' > "./Dockerfile"


