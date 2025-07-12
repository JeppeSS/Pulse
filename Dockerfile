FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    clang \
    curl \
    lld \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /opt/odin

ADD --checksum=sha256:271a200a8c5428cdd9377b6116829b8ae70ffaaa639295acef83a5529264313b https://github.com/odin-lang/Odin/releases/download/dev-2025-07/odin-linux-amd64-dev-2025-07.tar.gz odin.tar.gz

RUN tar -xzf odin.tar.gz \
 && mv odin-linux-amd64-dev-2025-07/* . \
 && rm -rf odin-linux-amd64-dev-2025-07 odin.tar.gz


ENV PATH="/opt/odin:${PATH}"

WORKDIR /app

COPY ./src /app


EXPOSE 3030/udp
RUN odin build /app -o:speed -out:pulse

CMD ["./pulse"]