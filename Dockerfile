# Headless Last Light: the same Godot 4.7.2 the game is built with, for the tests, the evaluations,
# training and replays. A container has no display or GPU, so play the 3D game natively.
#
#   docker compose run --rm checks            every headless check (scripts/check.sh)
#   docker compose run --rm checks --full     plus the six full-game playtests
#   docker compose run --rm steal-eval        the steal test, results into learning/steal_eval.json
#
# The first two RUN lines match tasks/Dockerfile exactly, so the engine layer is shared and
# verified against the same checksums.
FROM debian:bookworm-slim
ARG TARGETARCH
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates curl unzip libx11-6 libxcursor1 libxinerama1 libxi6 libxrandr2 libfontconfig1 libasound2 libgl1 libxrender1 && rm -rf /var/lib/apt/lists/*
RUN case "$TARGETARCH" in arm64) a=arm64; sum=5dd0d86405cf7e8adf79fb6377b38ba682a2846cb378ffe5364f38c01ad29b9d ;; amd64) a=x86_64; sum=cadd3204e728a35d3f13adb7fd0d7902636b79f6b95c40c265eb73b6c35329e4 ;; *) exit 2 ;; esac && \
    f="Godot_v4.7.2-stable_linux.$a" && curl -fsSL --retry 3 "https://github.com/godotengine/godot/releases/download/4.7.2-stable/$f.zip" -o /tmp/engine.zip && \
    echo "$sum  /tmp/engine.zip" | sha256sum -c - && unzip -p /tmp/engine.zip "$f" > /usr/local/bin/godot && chmod +x /usr/local/bin/godot && rm /tmp/engine.zip
RUN apt-get update && apt-get install -y --no-install-recommends python3 && rm -rf /var/lib/apt/lists/*
ENV GODOT=/usr/local/bin/godot
WORKDIR /game
COPY . .
# Import every asset once at build time, so each run starts straight away.
RUN godot --headless --path /game --import > /tmp/import.log 2>&1 || (tail -n 40 /tmp/import.log; exit 1)
ENTRYPOINT ["sh", "scripts/check.sh"]
