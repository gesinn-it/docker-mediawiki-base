#!/bin/bash
declare -A peclVersions=(
	[APCu]="5.1.24"
	[ast]="1.1.3"
)

function mediawiki_ref() {
	local major_version="$1"

	# Stage 1 – Tag lookup
	local tag
	tag=$(git ls-remote --sort=version:refname --tags https://github.com/wikimedia/mediawiki.git \
		| cut -d/ -f3 \
		| tr -d '^{}' \
		| grep -E "^${major_version}\." \
		| tail -1)

	if [[ -n "$tag" ]]; then
		echo "tag:${tag}"
		return 0
	fi

	# Stage 2 – Branch fallback
	local branch="REL$(echo "$major_version" | tr '.' '_')"
	local sha
	sha=$(git ls-remote --heads https://github.com/wikimedia/mediawiki.git "$branch" \
		| cut -f1)

	if [[ -n "$sha" ]]; then
		echo "branch:${branch}:${sha:0:7}"
		return 0
	fi

	echo "Error: No tag or branch found for MediaWiki version ${major_version}" >&2
	exit 1
}

function generate_tags () {
	local imageRepository=$1
	local mediawikiFullVersion=$2
	local mediawikiVersion=$3
	local phpVersion=$4
	local phpDefault=$5
	local variant='apache'

	if [[ ${phpVersion} == ${phpDefault}  ]]; then
		TAGS="${imageRepository}:${mediawikiVersion}-${variant},"
		TAGS+="${imageRepository}:${mediawikiFullVersion}-${variant},"

		# main tags, eg. gesinn/docker-mediawiki-base:1.40
		TAGS+="${imageRepository}:${mediawikiVersion},"
		TAGS+="${imageRepository}:${mediawikiFullVersion},"
	fi

	TAGS+="${imageRepository}:${mediawikiFullVersion}-php${phpVersion},"
	TAGS+="${imageRepository}:${mediawikiFullVersion}-php${phpVersion}-${variant},"
	TAGS+="${imageRepository}:${mediawikiVersion}-php${phpVersion},"
	TAGS+="${imageRepository}:${mediawikiVersion}-php${phpVersion}-${variant}"

	echo $TAGS
}


declare -A variantExtras=(
	[apache]='\n# Enable Short URLs\nRUN set -eux; \\\n\ta2enmod rewrite; \\\n\t{ \\\n\t\techo \"<Directory /var/www/html>\"; \\\n\t\techo \"  RewriteEngine On\"; \\\n\t\techo \"  RewriteCond %{REQUEST_FILENAME} !-f\"; \\\n\t\techo \"  RewriteCond %{REQUEST_FILENAME} !-d\"; \\\n\t\techo \"  RewriteRule ^ %{DOCUMENT_ROOT}/index.php [L]\"; \\\n\t\techo \"</Directory>\"; \\\n\t} > \"$APACHE_CONFDIR/conf-available/short-url.conf\"; \\\n\ta2enconf short-url\n\n# Enable AllowEncodedSlashes for VisualEditor\nRUN sed -i \"s/<\\/VirtualHost>/\\tAllowEncodedSlashes NoDecode\\n<\\/VirtualHost>/\" \"$APACHE_CONFDIR/sites-available/000-default.conf\"'
)
declare -A variantCmds=(
	[apache]='apache2-foreground'
)
declare -A variantBases=(
	[apache]='debian'
)
