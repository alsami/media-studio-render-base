## Project

The public base image of Media Studio's render job: `ghcr.io/alsami/media-studio-render-base`. Start with [README.md](README.md). The image holds the tools and the whisper model; the private repository adds its job host on top and pins this image by digest. There is no application code here.

## Rules

- **`tools.lock` is the source of truth** for every version in the image. The Dockerfile reads it and installs nothing else. A change to a version is a change to the lock, never to the Dockerfile.
- **A pull request builds the image as its check** (`build` workflow): the build, the smoke check and `check-lock.sh` must pass before the owner merges.
- **No secrets, no private names.** Nothing about the private repository's internals, cloud accounts or channels. The repository is public.
- Keep the reasons in the Dockerfile's comments; they record problems that were solved once.
- Scripts pass `shellcheck` (`shellcheck check-lock.sh`).
- After the merge, the digest of the pushed image is in the run's summary; the owner gives it to the private repository.

## Commits and pull requests

- One commit per change, a change being one thing that can be understood and reverted on its own.
- Every message starts with a prefix and a colon: `build:`, `ci:`, `docs:`, `feat:`, `fix:`, `chore:`, `refactor:`.
- **Every change goes through a pull request that the owner merges.** Work on a branch, never push to `main`.
- Rebase onto `main`, never merge `main` into a branch.

## Writing

Plain, short sentences for the owner. The reason next to each rule.
