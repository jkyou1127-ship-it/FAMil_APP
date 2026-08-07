FROM node:22-slim

WORKDIR /app

COPY package.json package-lock.json ./
RUN npm ci --omit=dev

COPY . .

RUN mkdir -p data uploads/profiles

ENV PORT=4000
EXPOSE 4000

# 컨테이너를 재시작해도 데이터가 남도록, 배포 환경에서 /app/data 와
# /app/uploads 를 영구 볼륨으로 마운트하는 것을 권장합니다.
VOLUME ["/app/data", "/app/uploads"]

CMD ["node", "src/server.js"]
