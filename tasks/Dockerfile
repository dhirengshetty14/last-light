FROM debian:bookworm-slim
ARG TARGETARCH
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates curl unzip libx11-6 libxcursor1 libxinerama1 libxi6 libxrandr2 libfontconfig1 libasound2 libgl1 libxrender1 && rm -rf /var/lib/apt/lists/*
RUN case "$TARGETARCH" in arm64) a=arm64; sum=5dd0d86405cf7e8adf79fb6377b38ba682a2846cb378ffe5364f38c01ad29b9d ;; amd64) a=x86_64; sum=cadd3204e728a35d3f13adb7fd0d7902636b79f6b95c40c265eb73b6c35329e4 ;; *) exit 2 ;; esac && \
    f="Godot_v4.7.2-stable_linux.$a" && curl -fsSL --retry 3 "https://github.com/godotengine/godot/releases/download/4.7.2-stable/$f.zip" -o /tmp/engine.zip && \
    echo "$sum  /tmp/engine.zip" | sha256sum -c - && unzip -p /tmp/engine.zip "$f" > /usr/local/bin/godot && chmod +x /usr/local/bin/godot && rm /tmp/engine.zip
WORKDIR /nursery
COPY tasks/headless.godot project.godot
COPY game/cargo_body.gd game/contracts.gd game/flight_sim.gd game/star_match.gd ./game/
COPY learning/response_policy.gd learning/star_policy.gd ./learning/
COPY tasks/grader.gd tasks/star_grader.gd ./tasks/
WORKDIR /workspace
