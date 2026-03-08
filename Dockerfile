FROM node:24-bookworm-slim

WORKDIR /app

ENV PYTHON=/usr/bin/python3
ENV NODE_ENV=production
ENV NODE_OPTIONS=--no-node-snapshot

RUN apt-get update && apt-get install -y --no-install-recommends \
  python3 \
  g++ \
  build-essential \
  git \
  && rm -rf /var/lib/apt/lists/*

COPY stackview/ ./

RUN rm -rf node_modules packages/*/node_modules
RUN corepack enable
RUN yarn install --immutable
RUN yarn tsc
RUN yarn build:backend
RUN tar xzf packages/backend/dist/bundle.tar.gz

EXPOSE 7007

CMD ["node", "packages/backend", "--config", "app-config.yaml", "--config", "app-config.production.yaml"]
