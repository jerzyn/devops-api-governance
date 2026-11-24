FROM docker.io/library/node:24-alpine

WORKDIR /app
COPY server.js ./

EXPOSE 8081
ENV PORT=8081

# Healthcheck hits the /health route so compose can gate dependents on readiness.
HEALTHCHECK --interval=10s --timeout=3s --retries=5 \
  CMD wget -q -O /dev/null http://localhost:8081/health || exit 1

# --watch-path: backend-deployer copies a PR's code in, and the server
# reloads (watching the folder survives files being replaced; Node 24 for it).
CMD ["node", "--watch-path=/app", "server.js"]
