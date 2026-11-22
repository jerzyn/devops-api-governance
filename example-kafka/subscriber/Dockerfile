FROM docker.io/library/node:24-alpine
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci --omit=dev && npm cache clean --force
COPY subscriber.js ./
USER node
CMD ["node", "subscriber.js"]
