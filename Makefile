export GOPATH = $(shell pwd)

all: fmt
	 go build cron

fmt:
	go fmt cron
