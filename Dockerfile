# syntax=docker/dockerfile:1

FROM node:20-bookworm AS ui
WORKDIR /app
COPY ui/package.json ui/yarn.lock ./ui/
RUN cd ui && yarn install --frozen-lockfile --ignore-engines
COPY schema.graphql ./schema.graphql
COPY ui ./ui
RUN cd ui && yarn generate && yarn build

FROM golang:1.25-bookworm AS build
WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY . .
COPY --from=ui /app/ui/build ./ui/build
RUN go install golang.org/x/tools/cmd/goimports@v0.1.10 && \
    go install github.com/99designs/gqlgen@v0.17.85 && \
    gqlgen

ARG VERSION=dev
ARG COMMIT=unknown
ARG DATE
RUN CGO_ENABLED=1 go build \
    -tags 'netgo osusergo sqlite_omit_load_extension' \
    -ldflags "-s -w -linkmode external -extldflags '-static' -X main.BuildDate=${DATE} -X main.BuildMode=prod -X main.BuildCommit=${COMMIT} -X main.BuildVersion=${VERSION}" \
    -o /out/traggo .

FROM scratch
WORKDIR /opt/traggo
COPY --from=build /out/traggo ./traggo
COPY --from=build /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/
COPY LICENSE README.md .env.sample ./
EXPOSE 3030
ENTRYPOINT ["./traggo"]
