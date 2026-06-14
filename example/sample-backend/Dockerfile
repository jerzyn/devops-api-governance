FROM node:20-alpine

WORKDIR /app
COPY server.js ./

EXPOSE 8081
ENV PORT=8081

# Healthcheck hits the /health route so compose can gate dependents on readiness.
HEALTHCHECK --interval=10s --timeout=3s --retries=5 \
  CMD wget -q -O /dev/null http://localhost:8081/health || exit 1

CMD ["node", "server.js"]
