# The public base image of Media Studio's render job: the tools the channels' script bundles call, and the
# faster-whisper model. Every version comes from tools.lock, the base image too: the build passes it as an argument.
# The private repository adds its job host on top (FROM this image by digest) and nothing else.
ARG RUNTIME_IMAGE

FROM ${RUNTIME_IMAGE} AS tools
COPY tools.lock /tmp/tools.lock
# Only the snapshot is a source, so apt resolves the dependencies of the pinned packages from the same day in
# every build. APT::Snapshot alone is not enough: it keeps the live archive as a source next to the snapshot.
RUN <<'EOF'
set -eu
snapshot="$(awk '$1 == "snapshot" && $2 == "ubuntu" { print $3 }' /tmp/tools.lock)"
packages="$(awk '$1 == "apt" { print $2 "=" $3 }' /tmp/tools.lock)"
sed -i -E "s#^URIs: .*#URIs: https://snapshot.ubuntu.com/ubuntu/$snapshot/#" /etc/apt/sources.list.d/ubuntu.sources
apt-get -o Acquire::Retries=5 update
# The snapshot service answers 503 for single files now and then. A further attempt downloads only what is missing.
attempt=1
until DEBIAN_FRONTEND=noninteractive apt-get -o Acquire::Retries=5 install -y --no-install-recommends $packages; do
  [ "$attempt" -lt 3 ] || exit 1
  attempt=$((attempt + 1))
  sleep 30
done
rm -rf /var/lib/apt/lists/*
EOF
# Paths the scripts read that the packages put elsewhere, each a link to a file of a package.
RUN <<'EOF'
set -eu
awk '$1 == "link" { print $2, $3 }' /tmp/tools.lock | while read -r path target; do
  mkdir -p "$(dirname "$path")"
  ln -s "$target" "$path"
done
EOF
# --no-deps: the lock lists every dependency, and pip check proves that none is missing.
RUN <<'EOF'
set -eu
python3 -m venv /opt/venv
awk '$1 == "pip" { print $2 "==" $3 }' /tmp/tools.lock > /tmp/requirements.txt
/opt/venv/bin/pip install --no-cache-dir --disable-pip-version-check --no-deps -r /tmp/requirements.txt
/opt/venv/bin/pip check
rm /tmp/requirements.txt
EOF
# The steps call python3; this makes it the one with the packages.
ENV PATH=/opt/venv/bin:$PATH

FROM tools AS models
ENV HF_HOME=/opt/huggingface
# Only the files faster-whisper reads. refs/main is written as well, because faster-whisper looks the model up
# by that name when it may not go online.
RUN <<'EOF'
set -eu
awk '$1 == "model" { print $2, $3 }' /tmp/tools.lock | while read -r repository revision; do
  python3 - "$repository" "$revision" <<'PY'
import os, sys
from huggingface_hub import snapshot_download

repository, revision = sys.argv[1], sys.argv[2]
path = snapshot_download(repository, revision=revision, allow_patterns=[
    "config.json", "preprocessor_config.json", "model.bin", "tokenizer.json", "vocabulary.*"])
commit = os.path.basename(path)
main = os.path.join(os.path.dirname(os.path.dirname(path)), "refs", "main")
os.makedirs(os.path.dirname(main), exist_ok=True)
with open(main, "w") as file:
    file.write(commit)
print("MODEL", repository, revision, "->", commit)
PY
done
# huggingface_hub writes its cache files through a temporary file, readable by its owner only (mode 600), and the
# steps run as another user: the library found the model's tree cache file unreadable and looked the files up again in
# every step. Readable by everyone and writable by no one: a step reads the model and cannot change it.
chmod -R a+rX,go-w /opt/huggingface
EOF

FROM tools
# The model is baked in, so a render never downloads it: nothing may go online for it.
ENV HF_HOME=/opt/huggingface \
    HF_HUB_OFFLINE=1
COPY --from=models /opt/huggingface /opt/huggingface
# The lock the image was built from, so a user of the image reads the versions from the image and not from a copy.
# The commit comes last, so a new commit does not rebuild the layers above.
COPY tools.lock /opt/media-studio-render-base/tools.lock
ARG COMMIT=unknown
RUN echo "$COMMIT" > /opt/media-studio-render-base/VERSION
LABEL org.opencontainers.image.source="https://github.com/alsami/media-studio-render-base" \
      org.opencontainers.image.description="Media Studio render base image: ffmpeg, Python tools, yt-dlp and the whisper model, from a locked list" \
      org.opencontainers.image.revision="$COMMIT"
# No USER and no ENTRYPOINT: the image that builds on this one sets them.
