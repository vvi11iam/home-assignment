FROM node:24.13-alpine AS build
WORKDIR /app
ENV NODE_ENV=production

COPY package.json package-lock.json ./
COPY patches ./patches

# Install only production deps and skip scripts for better caching.
RUN npm ci --omit=dev --ignore-scripts

COPY . .

# Apply patches and build CSS assets.
RUN ./node_modules/.bin/patch-package && npm run scss

FROM node:24.13-alpine AS runtime
WORKDIR /app
ENV NODE_ENV=production

COPY --from=build /app ./

EXPOSE 8080
CMD ["node", "app.js"]
