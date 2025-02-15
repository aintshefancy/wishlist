# Stage 1: Build stage
FROM node:lts-slim AS build

WORKDIR /usr/src/app

RUN apt-get update \
    && apt-get install -y --no-install-recommends build-essential python3 openssl git bash \
    && rm -rf /var/lib/apt/lists/*

COPY ./ .
RUN npm i -g pnpm@latest-9
RUN pnpm i --frozen-lockfile
RUN pnpm prisma generate
RUN pnpm run build
RUN pnpm prune --prod

# Stage 2: Application stage
FROM node:lts-slim AS app

ENV NODE_ENV=production
ENV BODY_SIZE_LIMIT=5000000

WORKDIR /usr/src/app

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
    openssl debian-keyring debian-archive-keyring apt-transport-https curl gpg ca-certificates bash

RUN curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
RUN curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | tee /etc/apt/sources.list.d/caddy-stable.list

RUN apt-get update \
    && apt-get install -y --no-install-recommends caddy \
    && rm -rf /var/lib/apt/lists/*

FROM cloudflare/cloudflared:latest

WORKDIR /usr/src/app

COPY --from=build /usr/src/app/build ./build/
COPY --from=build /usr/src/app/node_modules ./node_modules/
COPY ["package.json", "pnpm-lock.yaml", "entrypoint.sh", "Caddyfile", "./"]
COPY ./templates/ ./templates
COPY ./prisma/ ./prisma/

RUN npm i -g pnpm@latest-9
RUN chmod +x entrypoint.sh

VOLUME /usr/src/app/uploads
VOLUME /usr/src/app/data

ENV DEFAULT_CURRENCY=USD
ENV TOKEN_TIME=72

ENTRYPOINT ["/bin/bash", "entrypoint.sh"]
