FROM docker.io/library/node:24-alpine
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci --omit=dev && npm cache clean --force
COPY server.js ./
USER node
ENV PORT=9100
EXPOSE 9100
CMD ["node", "server.js"]
