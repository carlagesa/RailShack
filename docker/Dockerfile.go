FROM golang:1.24-alpine AS build

ARG SERVICE
WORKDIR /src
COPY libs/gokit ./libs/gokit
COPY services/${SERVICE} ./services/${SERVICE}
WORKDIR /src/services/${SERVICE}
RUN CGO_ENABLED=0 go build -trimpath -o /out/service .

FROM gcr.io/distroless/static-debian12:nonroot
ENV PORT=8080
COPY --from=build /out/service /service
EXPOSE 8080
ENTRYPOINT ["/service"]
