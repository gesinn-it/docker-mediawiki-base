# docker-mediawiki-base
MediaWiki Docker base image in the style of the official MediaWiki image but with PHP variants. Released on [dockerhub](https://hub.docker.com/r/gesinn/mediawiki-base). Images are built and published automatically, see [Build triggers](#build-triggers).

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

### Immutable per-build tags

In addition to the tags above, every build gets one immutable tag with the UTC build time (all entries of one workflow run share the same timestamp):

```
gesinn/mediawiki-base:1.43.2-php8.2-apache-20261021T0933
```

The latest 8 of these tags per MediaWiki major version and PHP version are kept, older ones are deleted by the cleanup job.

## Build triggers

The workflow (`.github/workflows/main.yml`) runs on:

| Trigger | Behaviour |
|---|---|
| push to `main` | rebuilds everything (the repository content changed) |
| schedule, every 6 hours | change detection: rebuilds only entries that changed (see below) |
| schedule, weekly (Sunday night) | forced rebuild of everything, picks up Debian updates for the packages installed by the template |
| manual (`workflow_dispatch`) | change detection by default, see inputs below |

The entries to build are listed in `matrix.json` (including the default PHP version of each MediaWiki version and whether the downstream build is triggered).

### Change detection

`plan.sh` decides per entry whether a build is needed. An entry is rebuilt if

- the digest of the upstream `php:<version>-apache` image differs from the one recorded in the published image (`org.opencontainers.image.base.digest`), or
- the resolved MediaWiki version differs, i.e. a new release tag or a new commit on the `REL1_XX` branch of a pre-release. The fully qualified tag (`<version>-php<php>-apache`) does not exist yet in that case.

If nothing changed, the run finishes without building or pushing anything; the log of the `plan` job states the reason for every entry.

### Rebuilding manually

Run the workflow via *Actions → CI to Docker Hub → Run workflow*. Inputs:

- `force`: rebuild all selected entries even if nothing changed
- `dry_run`: build for `linux/amd64` only, push nothing and do not trigger the downstream build
- `mediawiki_version`, `php_version`: restrict the run to one MediaWiki major version and/or PHP version (e.g. `1.43` / `8.2`); empty means all

Runs never overlap (`concurrency` group), and a failing entry does not stop the others.

### Image metadata

Every image carries these labels (as image labels and as annotations on the multi-arch index, so they can be read without pulling the image):

```
docker buildx imagetools inspect gesinn/mediawiki-base:1.43-php8.2-apache --format '{{json .Manifest.Annotations}}'
```

| Label | Content |
|---|---|
| `org.opencontainers.image.base.name` | upstream image, e.g. `docker.io/library/php:8.2-apache` |
| `org.opencontainers.image.base.digest` | digest of the upstream image the build used |
| `org.opencontainers.image.created` | build time (UTC) |
| `org.opencontainers.image.revision` | commit of this repository |
| `org.opencontainers.image.version`, `it.gesinn.mediawiki.version` | MediaWiki version |
| `it.gesinn.php.version` | effective PHP version, e.g. `8.2.34` |

The build uses exactly the upstream digest that is recorded in the labels (`FROM php:8.2-apache@sha256:...`).

### Downstream build

After a successful push of an entry, the workflow starts the build in [gesinn-it/docker-mediawiki](https://github.com/gesinn-it/docker-mediawiki) for exactly that MediaWiki/PHP combination (`workflow_dispatch` with `mediawiki_version` and `php_version`).

This requires the secret `DOWNSTREAM_DISPATCH_TOKEN`: a fine-grained personal access token with the repository permission *Actions: Read and write* on `gesinn-it/docker-mediawiki` only, available to this repository (repository or organisation secret).

## Maintenance branch `1.39`

MediaWiki 1.39 and PHP 8.1 are end of life; 1.39 is also built on PHP 8.2, which still receives security fixes. They are no longer built from `main`; the branch `1.39` contains the same tooling with a `matrix.json` that only holds 1.39 (PHP 8.2 as default, 8.1 as before). It publishes the same tags as before, including the immutable per-build tags and the labels.

- Run it manually (*Actions → CI to Docker Hub → Run workflow*, branch `1.39`); scheduled runs only exist on the default branch, and pushes only trigger builds on `main`.
- The downstream build is not triggered (`"downstream": false`).
- Upstream `php:8.1-apache` does not receive updates any more; use the PHP 8.2 images to get PHP security fixes. The floating tags `1.39` and `1.39.x` point to PHP 8.2.
