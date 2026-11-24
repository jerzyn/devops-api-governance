FROM docker.io/library/node:24-alpine
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci --omit=dev && npm cache clean --force
COPY server.js ./
USER node
# --watch-path: backend-deployer copies a PR's code in, and the server
# reloads (watching the folder survives files being replaced; Node 24 for it).
CMD ["node", "--watch-path=/app", "server.js"]
