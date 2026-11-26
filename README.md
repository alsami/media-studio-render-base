# media-studio-render-base

The public base image of Media Studio's render job: Ubuntu, ffmpeg, yt-dlp, deno, node, ImageMagick, sox, fonts, Python tools and the whisper model, from a locked list. Nothing private: the image is built here in public and pulled as a base by the private repository, which adds only its own job host on top.

`ghcr.io/alsami/media-studio-render-base`, for `linux/amd64`.

## What is in it

- `tools.lock` is the single source of every version: one line per tool, `<kind> <name> <version>` (`image`, `snapshot`, `dotnet`, `apt`, `pip`, `link`, `model`). Packages come from a dated Ubuntu snapshot, so a build today and a build next month install the same bytes.
- `Dockerfile` installs exactly the lock: the `tools` stage (apt packages, links, the Python venv in `/opt/venv`) and the `models` stage (the faster-whisper model in `/opt/huggingface`).
- `check-lock.sh` proves that the built image holds every locked version.
- The image carries its lock at `/opt/media-studio-render-base/tools.lock` and the commit it was built from at `/opt/media-studio-render-base/VERSION`, so a user of the image reads the versions from the image.

The image sets `PATH` (with `/opt/venv/bin` first), `HF_HOME=/opt/huggingface` and `HF_HUB_OFFLINE=1`. It sets no `USER` and no `ENTRYPOINT`; the image that builds on it does.

## How it is built

The workflow `build` builds the image for every pull request that changes the Dockerfile, the lock, the check or the workflow, and runs the smoke check and `check-lock.sh` on it. That build is the check of a pull request. On `main` it also pushes `sha-<12 characters of the commit>` and `latest` and writes the **digest** of the pushed image into the run's summary. Users pin the digest, not a tag.

## Raising a tool

1. Edit `tools.lock` (a version, or the snapshot date) in a branch.
2. Open a pull request. Its build installs the lock and checks it; a version that does not exist fails there.
3. After the merge, take the digest from the summary of the `build` run on `main`.
4. The private repository raises that digest in its Dockerfile in its own pull request. That pull request is the gate: nothing goes live before it is merged.

## Once, by the owner

GHCR creates a package private. After the first push, set `media-studio-render-base` (and the cache package `media-studio-render-base-cache`, if wanted) to **Public** in the package settings, so the private repository's build and everyone else can pull it without a token.
