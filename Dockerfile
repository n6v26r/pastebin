FROM archlinux:latest AS builder

RUN pacman -Syu --noconfirm zig base-devel git

WORKDIR /app

COPY . .

RUN zig build --release=fast

FROM archlinux:latest

RUN pacman -Syu --noconfirm lib32-glibc cronie bash tzdata nginx && pacman -Scc --noconfirm

ENV TZ=UTC

WORKDIR /app

COPY --from=builder /app/zig-out/bin/pastebin /app/pastebin
COPY --from=builder /app/public /app/public
COPY nginx.conf /etc/nginx/nginx.conf

VOLUME ["/app/pastes"]

COPY crontab /etc/crontab

RUN ln -sf /dev/stdout /var/log/cron.log

EXPOSE 8080

CMD ["/bin/bash", "-c", "crond -n & /app/pastebin & nginx -g 'daemon off;'"]
# CMD ["/bin/bash", "-c", "crond -n & /app/pastebin"]
# CMD ["/bin/bash", "-c", "/app/pastebin"]
