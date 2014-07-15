// Copyright (c) 2010-2014 Alexander Kojevnikov. All rights reserved.
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions
// are met:
// 1. Redistributions of source code must retain the above copyright
//    notice, this list of conditions and the following disclaimer.
// 2. Redistributions in binary form must reproduce the above copyright
//    notice, this list of conditions and the following disclaimer in the
//    documentation and/or other materials provided with the distribution.
//
// THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
// ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
// IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
// ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
// FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
// DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
// OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
// HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
// LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
// OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
// SUCH DAMAGE.

package main

import (
	"crypto/sha256"
	"fmt"
	"html"
	"io"
	"io/ioutil"
	"log"
	"net/http"
	"os"
	"path"
	"path/filepath"
	"regexp"
	"strings"
	"time"

	"github.com/gorilla/feeds"
)

func main() {
	feedTypes := map[string]string{
		"ports":     "https://raw.github.com/freebsd/freebsd-ports/master/UPDATING",
		"changes":   "https://raw.github.com/freebsd/freebsd-ports/master/CHANGES",
		"head":      "https://raw.github.com/freebsd/freebsd/master/UPDATING",
		"stable-8":  "https://raw.github.com/freebsd/freebsd/stable/8/UPDATING",
		"stable-9":  "https://raw.github.com/freebsd/freebsd/stable/9/UPDATING",
		"stable-10": "https://raw.github.com/freebsd/freebsd/stable/10/UPDATING",
	}

	for name, url := range feedTypes {
		generate(name, url)
	}
}

func generate(name string, url string) {
	text := download(url)
	atom := convert(name, text)

	dir, err := filepath.Abs(filepath.Dir(os.Args[0]))
	if err != nil {
		log.Fatal(err)
	}

	file, err := os.Create(path.Join(dir, "public", name+".atom"))
	if err != nil {
		log.Fatal(err)
	}
	defer file.Close()

	_, err = file.WriteString(atom)
	if err != nil {
		log.Fatal(err)
	}
}

func download(url string) (text string) {
	res, err := http.Get(url)
	if err != nil {
		log.Fatal(err)
	}

	bytes, err := ioutil.ReadAll(res.Body)
	res.Body.Close()
	if err != nil {
		log.Fatal(err)
	}

	return string(bytes)
}

func convert(name string, text string) (atom string) {
	site := "http://updating.versia.com/"
	now := time.Now()
	feedTitle := fmt.Sprintf("FreeBSD %s/UPDATING", name)
	if name == "changes" {
		feedTitle = "FreeBSD ports/CHANGES"
	}
	feed := &feeds.Feed{
		Title:   feedTitle,
		Link:    &feeds.Link{Href: site},
		Author:  &feeds.Author{"Alexander Kojevnikov", "alexander@kojevnikov.com"},
		Updated: now,
		Id:      site,
	}

	trim_header := true
	num_entries := 10
	date_regexp, _ := regexp.Compile("^(\\d{8}):")
	var date, title, content string

	for _, line := range strings.Split(text, "\n") {
		if matches := date_regexp.FindStringSubmatch(line); matches != nil {
			if !trim_header {
				// Add the previous entry.
				updated, _ := time.Parse("20060102", date)
				hash := sha256.New()
				io.WriteString(hash, date+title)

				feed.Add(&feeds.Item{
					Title:       title,
					Description: fmt.Sprintf("<pre>%s</pre>", content),
					Updated:     updated,
					Id:          fmt.Sprintf("%sentry/%x", site, hash.Sum(nil)),
					Link:        &feeds.Link{},
				})

				// Stop if we have enough entries.
				num_entries--
				if num_entries == 0 {
					break
				}
				title = ""
				content = ""
			}
			trim_header = false
			date = matches[1]
		} else if trim_header {
			continue
		} else if len(title) == 0 {
			content = fmt.Sprintf("%s:\n%s\n", date, html.EscapeString(line))
			title = html.EscapeString(strings.TrimSpace(line))
		} else {
			content += html.EscapeString(line) + "\n"
		}
	}

	atom, err := feed.ToAtom()
	if err != nil {
		log.Fatal(err)
	}
	return atom
}
