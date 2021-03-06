//
//  MIT License
//
//  (C) Copyright 2022 Hewlett Packard Enterprise Development LP
//
//  Permission is hereby granted, free of charge, to any person obtaining a
//  copy of this software and associated documentation files (the "Software"),
//  to deal in the Software without restriction, including without limitation
//  the rights to use, copy, modify, merge, publish, distribute, sublicense,
//  and/or sell copies of the Software, and to permit persons to whom the
//  Software is furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included
//  in all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
//  THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR
//  OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
//  ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
//  OTHER DEALINGS IN THE SOFTWARE.
//
/*
Copyright 2021 Chainguard, Inc.
SPDX-License-Identifier: Apache-2.0
*/

package main

import (
	"io/ioutil"
	"log"
	"os"
	"os/exec"
	"strings"

	"github.com/fsnotify/fsnotify"
	"github.com/kelseyhightower/envconfig"
	"golang.org/x/net/context"
	"knative.dev/pkg/signals"
)

// Delegates to `/cloud_sql_proxy` if ORM_DRIVER is `cloudsql`.
// Assuming the base image is image: gcr.io/cloudsql-docker/gce-proxy.

type envConfig struct {
	Driver  string `envconfig:"ORM_DRIVER" required:"true"`
	ExitDir string `envconfig:"EXIT_DIR" required:"false"`
}

func main() {
	var env envConfig
	if err := envconfig.Process("", &env); err != nil {
		log.Fatalf("failed to process env var: %s", err)
	}

	// Add WithCancel to our normal signal catching so that if we are
	// watching a exitfile that we can then cleanly exit.
	ctx, cancel := context.WithCancel(signals.NewContext())

	if env.Driver == "cloudsql" {
		log.Printf("Starting the cloud sql proxy")

		cmd := exec.CommandContext(ctx, "/cloud_sql_proxy", "-enable_iam_login")
		cmd.Env = os.Environ()
		cmd.Stdout = os.Stdout
		cmd.Stderr = os.Stderr
		if err := cmd.Start(); err != nil {
			log.Panic(err)
		}
		if cmd.Process == nil {
			log.Panicf("process was started, but Process was not filled")
		}
	} else {
		log.Printf("Nothing to do. ORM_DRIVER=%s", env.Driver)
	}
	watcher, err := fsnotify.NewWatcher()
	if err != nil {
		log.Fatal(err)
	}
	if env.ExitDir != "" {
		// Make sure it's a directory we're watching and not a file.
		exitdir := strings.TrimSuffix(env.ExitDir, "/") + "/"
		if err := watcher.Add(exitdir); err != nil {
			log.Fatal(err)
		}
		log.Printf("Added a watch for exit directory: %s", env.ExitDir)
		// See if there are entries already there, say main container already
		// wrote the exit file.
		files, err := ioutil.ReadDir(exitdir)
		if err != nil {
			log.Fatal("failed to read exitdir for files: ", err)
		}
		if len(files) > 0 {
			log.Printf("Found exit file in %s, bailing...", exitdir)
			cancel()
		} else {
			defer watcher.Close()
			go func() {
				for {
					select {
					case event, ok := <-watcher.Events:
						if !ok {
							log.Println("Not OK from watcher.Events ", err)
							return
						}
						if event.Op&fsnotify.Create == fsnotify.Create {
							log.Println("Observed exit file, bailing... : ", event.Name)
							cancel()
							return
						}
					case err, ok := <-watcher.Errors:
						if !ok {
							log.Println("Not OK from watcher.Errors ", err)
							return
						}
						log.Println("error from watcher.Errors:", err)
					}
				}
			}()
		}
	}
	<-ctx.Done()
	log.Println("Exiting")
}
