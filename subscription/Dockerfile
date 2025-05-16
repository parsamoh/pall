FROM node:18-alpine

WORKDIR /app

# copy only package files & install deps
COPY package*.json ./
RUN npm install

# copy app code
COPY . .

EXPOSE 443

CMD ["node", "server.js"]

