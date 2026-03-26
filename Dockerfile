FROM node:lts@sha256:bb20cf73b3ad7212834ec48e2174cdcb5775f6550510a5336b842ae32741ce6c AS build
WORKDIR /app
COPY site .
RUN npm i
RUN npm run build

FROM httpd:2.4@sha256:331548c5249bdeced0f048bc2fb8c6b6427d2ec6508bed9c1fec6c57d0b27a60 AS runtime
COPY --from=build /app/dist /usr/local/apache2/htdocs/
EXPOSE 80