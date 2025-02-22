# Stage 1: Build
FROM node:20-slim AS builder

WORKDIR /app

# Copy package files and install dependencies (including devDependencies for TypeScript)
COPY package.json package-lock.json ./
RUN npm install --only=development

# Copy the rest of the source code
COPY . .

# Compile TypeScript
RUN npx tsc

# Stage 2: Production Image
FROM node:20-alpine

WORKDIR /app

# Install only production dependencies
COPY package.json package-lock.json ./
RUN npm install --only=production

# Copy compiled JavaScript files
COPY --from=builder /app/dist /app/dist

EXPOSE 3000

CMD ["node", "dist/index.js"]
