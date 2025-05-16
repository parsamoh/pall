FROM node:18-alpine

WORKDIR /app

# copy only package files & install deps
COPY package*.json ./
RUN npm ci --production

# copy app code
COPY . .

EXPOSE 443

CMD ["node", "server.js"]

