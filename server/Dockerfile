FROM node:22-slim
WORKDIR /app
COPY package.json package-lock.json* ./
RUN npm install --omit=dev
COPY src ./src
ENV PORT=8080
ENV DB_PATH=/app/data/famil.db
VOLUME ["/app/data"]
EXPOSE 8080
CMD ["node", "src/server.js"]
