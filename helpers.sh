#!/bin/bash
declare -A peclVersions=(
	[APCu]="5.1.21"
)

function mediawiki_version() {
	git ls-remote --sort=version:refname --tags https://github.com/wikimedia/mediawiki.git \
		| cut -d/ -f3 \
		| tr -d '^{}' \
		| grep -E "^$1" \
		| tail -1
}

function generate_tags { args : string baseImageName , string mediawikiFullVersion , string mediawikiVersion , string phpVersion , string phpDefault , string variant } {
	if [[ ${phpVersion} == ${phpDefault}  ]]; then
		TAGS="${baseImageName}:${mediawikiFullVersion},${baseImageName}:${mediawikiVersion},${baseImageName}:${mediawikiFullVersion}-php${phpVersion},${baseImageName}:${mediawikiVersion}-php${phpVersion}"
	else
		TAGS="${baseImageName}:${mediawikiFullVersion}-php${phpVersion},${baseImageName}:${mediawikiVersion}-php${phpVersion}"
	fi
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