FROM golang:1.21.9

WORKDIR /wanix

COPY . .

RUN go mod download

EXPOSE 7777

RUN make all

CMD ["go", "run", "./dev"]


