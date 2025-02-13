#!/bin/sh

set -e
set -x

# Export additional environment variables
export PROTOCOL_HEADER=x-forwarded-proto
export HOST_HEADER=x-forwarded-host
export DATABASE_URL="file:/usr/src/app/data/prod.db?connection_limit=1"
export PUBLIC_DEFAULT_CURRENCY=${DEFAULT_CURRENCY}

# Ensure the Caddyfile is in the correct location
if [ ! -f /etc/caddy/Caddyfile ]; then
    echo "Caddyfile not found in /etc/caddy"
    exit 1
fi

# Export environment variables from a file (if needed)
if [ -f /usr/src/app/shinyenv.env ]; then
    export $(cat /usr/src/app/shinyenv.env | xargs)
fi

# Start Caddy
caddy start --config /etc/caddy/Caddyfile

# Run Prisma commands
pnpm prisma migrate deploy
pnpm prisma db seed
pnpm db:patch

# Start the application
pnpm start
