#!/bin/bash
declare -A peclVersions=(
	[APCu]="5.1.24"
)

function mediawiki_version() {
	git ls-remote --sort=version:refname --tags https://github.com/wikimedia/mediawiki.git \
		| cut -d/ -f3 \
		| tr -d '^{}' \
		| grep -E "^$1" \
		| tail -1
}

function generate_tags () {
	local imageRepository=$1
	local mediawikiFullVersion=$2
	local mediawikiVersion=$3
	local phpVersion=$4
	local phpDefault=$5
	local variant=$6

	if [[ ${phpVersion} == ${phpDefault}  ]]; then
		TAGS="${imageRepository}:${mediawikiVersion}-${variant},"
		TAGS+="${imageRepository}:${mediawikiFullVersion}-${variant},"

		# main tags, eg. gesinn/docker-mediawiki-base:1.40
		# are only generated for apache variant of image
		if [[ ${variant} == "apache" ]];then
			TAGS+="${imageRepository}:${mediawikiVersion},"
			TAGS+="${imageRepository}:${mediawikiFullVersion},"
		fi
	fi

	TAGS+="${imageRepository}:${mediawikiFullVersion}-php${phpVersion},"
	TAGS+="${imageRepository}:${mediawikiFullVersion}-php${phpVersion}-${variant},"
	TAGS+="${imageRepository}:${mediawikiVersion}-php${phpVersion},"
	TAGS+="${imageRepository}:${mediawikiVersion}-php${phpVersion}-${variant}"

	echo $TAGS
}


declare -A variantExtras=(
	[apache]='\n# Enable Short URLs\nRUN set -eux; \\\n\ta2enmod rewrite; \\\n\t{ \\\n\t\techo \"<Directory /var/www/html>\"; \\\n\t\techo \"  RewriteEngine On\"; \\\n\t\techo \"  RewriteCond %{REQUEST_FILENAME} !-f\"; \\\n\t\techo \"  RewriteCond %{REQUEST_FILENAME} !-d\"; \\\n\t\techo \"  RewriteRule ^ %{DOCUMENT_ROOT}/index.php [L]\"; \\\n\t\techo \"</Directory>\"; \\\n\t} > \"$APACHE_CONFDIR/conf-available/short-url.conf\"; \\\n\ta2enconf short-url\n\n# Enable AllowEncodedSlashes for VisualEditor\nRUN sed -i \"s/<\\/VirtualHost>/\\tAllowEncodedSlashes NoDecode\\n<\\/VirtualHost>/\" \"$APACHE_CONFDIR/sites-available/000-default.conf\"'
	[fpm]=''
	[fpm-alpine]=''
)
declare -A variantCmds=(
	[apache]='apache2-foreground'
	[fpm]='php-fpm'
	[fpm-alpine]='php-fpm'
)
declare -A variantBases=(
	[apache]='debian'
	[fpm]='debian'
	[fpm-alpine]='alpine'
)