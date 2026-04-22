# moto — Node runtime sandbox for agent code execution.
# Agents POST code/commands to :3001 and get back stdout/stderr.
# Ships with chromium + common rendering deps so screenshotting works.

FROM node:22-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates curl git tini \
      chromium \
      fonts-liberation fonts-noto fonts-noto-cjk fonts-noto-color-emoji \
      libasound2 libgbm1 libnss3 libxss1 libxtst6 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY package.json ./
RUN npm install --omit=dev

COPY server.mjs ./

ENV NODE_ENV=production PORT=3001
ENV PUPPETEER_SKIP_DOWNLOAD=true
ENV PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium

EXPOSE 3001
ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["node", "server.mjs"]
