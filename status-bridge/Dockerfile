FROM node:22-alpine
WORKDIR /app
COPY package.json .
RUN npm install --omit=dev
COPY server.js health-monitor.js .
EXPOSE 9100
CMD ["sh","-c","node health-monitor.js & exec node server.js"]
