FROM node:16-alpine AS builder-web

WORKDIR /app
COPY ./web/ ./

RUN npm install
RUN npm run build


FROM golang:alpine as builder
ENV GO111MODULE=on
ENV GOPROXY=https://goproxy.cn,direct

WORKDIR /app

COPY . .
COPY --from=builder-web /app/build /app/server/resource/build

RUN sed -i 's/dl-cdn.alpinelinux.org/mirrors.ustc.edu.cn/g' /etc/apk/repositories
RUN #apk add upx
RUN go mod tidy
RUN sh get_arch.sh
RUN echo "Hello, my CPU architecture is $(uname -m)"
RUN go env;CGO_ENABLED=0 GOOS=linux GOARCH=$ARCH go build -ldflags '-s -w' -o next-terminal main.go
RUN #upx next-terminal


FROM alpine:latest

ENV TZ Asia/Shanghai
ENV DB sqlite
ENV SQLITE_FILE './data/sqlite/next-terminal.db'
ENV SERVER_PORT 8088
ENV SERVER_ADDR 0.0.0.0:$SERVER_PORT
ENV SSHD_PORT 8089
ENV SSHD_ADDR 0.0.0.0:$SSHD_PORT
ENV TIME_ZONE=Asia/Shanghai
RUN ln -snf /usr/share/zoneinfo/$TIME_ZONE /etc/localtime && echo $TIME_ZONE > /etc/timezone

WORKDIR /usr/local/next-terminal
RUN touch config.yml

COPY --from=builder /app/next-terminal ./
COPY --from=builder /app/LICENSE ./

EXPOSE $SERVER_PORT $SSHD_PORT

RUN sed -i 's/dl-cdn.alpinelinux.org/mirrors.ustc.edu.cn/g' /etc/apk/repositories
RUN apk add tzdata
RUN cp /usr/share/zoneinfo/${TZ} /etc/localtime
RUN echo ${TZ} > /etc/timezone
ENTRYPOINT ./next-terminal