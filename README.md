# docker-mediawiki-base
MediaWiki Docker base image in the style of the official MediaWiki image but with PHP variants. Released on [dockerhub](https://hub.docker.com/r/gesinn/mediawiki-base). Simply run the GitHub Actions workflow on new MediaWiki releases to generate images (dont't forget to trigger workflows on https://github.com/gesinn-it/docker-mediawiki afterwards).

## Image tagging scheme

The CI pipeline supports two build types, resolved automatically via `mediawiki_ref()`:

**Stable (tagged) builds** — when a signed release tag exists for the requested major version:

```
gesinn/mediawiki-base:1.43.2-php8.2-apache   ← fully qualified
gesinn/mediawiki-base:1.43.2-php8.2          ← variant omitted (apache is default)
gesinn/mediawiki-base:1.43.2                 ← default php + default variant
gesinn/mediawiki-base:1.43-php8.2-apache     ← floating major version
gesinn/mediawiki-base:1.43                   ← floating major version, defaults only
```

**Pre-release (branch) builds** — when no release tag exists yet and a `REL1_XX` branch is used instead:

```
gesinn/mediawiki-base:1.46-dev-a1b2c3d-php8.4-apache   ← fully qualified
gesinn/mediawiki-base:1.46-dev-a1b2c3d-php8.4          ← variant omitted
gesinn/mediawiki-base:1.46-dev-a1b2c3d                 ← default php + default variant
```

The `-dev-<sha7>` infix identifies the pre-release nature and the exact commit. No floating `1.46` tags are published for branch builds to avoid misleading consumers. Downstream repos (e.g. `gesinn-it/docker-mediawiki`) can reference pre-release images by setting `MEDIAWIKI_VERSION=1.46-dev-a1b2c3d` without any further changes.
