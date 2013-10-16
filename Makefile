export GOPATH = $(shell pwd)
files = src/cron.go

all: fmt
	 go build $(files)

fmt:
	go fmt $(files)
