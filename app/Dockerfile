FROM node:20-alpine

WORKDIR /usr/src/app

COPY package.json ./
RUN npm install --omit=dev --no-audit --no-fund

COPY server.js ./
COPY public ./public

ARG APP_VERSION=1.0.0
ENV APP_VERSION=${APP_VERSION}
ENV PORT=3000
ENV ENVIRONMENT=development
ENV BUILD_NUMBER=0

EXPOSE 3000

HEALTHCHECK --interval=10s --timeout=3s --start-period=5s --retries=3 \
  CMD wget -qO- http://localhost:3000/health || exit 1

CMD ["node", "server.js"]
