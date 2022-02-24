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
	"context"
	"flag"
	"fmt"
	"time"

	"github.com/golang/glog"
	"github.com/google/trillian"
	"github.com/google/trillian/client"
	"github.com/google/trillian/client/rpcflags"
	"github.com/pkg/errors"
	"google.golang.org/grpc"
	"google.golang.org/protobuf/types/known/durationpb"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/client-go/kubernetes"
	"k8s.io/client-go/rest"
	"knative.dev/pkg/logging"
	"knative.dev/pkg/signals"
)

const (
	// Key in the configmap holding the value of the tree.
	treeKey = "treeID"
)

var (
	ns              = flag.String("namespace", "rekor-system", "Namespace where to update the configmap in")
	cmname          = flag.String("configmap", "rekor-config", "Name of the configmap where the treeID lives")
	adminServerAddr = flag.String("admin_server", "log-server.trillian-system.svc:80", "Address of the gRPC Trillian Admin Server (host:port)")
	treeState       = flag.String("tree_state", trillian.TreeState_ACTIVE.String(), "State of the new tree")
	treeType        = flag.String("tree_type", trillian.TreeType_LOG.String(), "Type of the new tree")
	displayName     = flag.String("display_name", "", "Display name of the new tree")
	description     = flag.String("description", "", "Description of the new tree")
	maxRootDuration = flag.Duration("max_root_duration", time.Hour, "Interval after which a new signed root is produced despite no submissions; zero means never")
)

func main() {
	flag.Parse()
	ctx := signals.NewContext()
	config, err := rest.InClusterConfig()
	if err != nil {
		logging.FromContext(ctx).Fatalf("Failed to get InClusterConfig: %v", err)
	}
	clientset, err := kubernetes.NewForConfig(config)
	if err != nil {
		logging.FromContext(ctx).Fatalf("Failed to get clientset: %v", err)
	}
	cm, err := clientset.CoreV1().ConfigMaps(*ns).Get(ctx, *cmname, metav1.GetOptions{})
	if err != nil {
		logging.FromContext(ctx).Fatalf("Failed to get the configmap %s/%s: %v", *ns, *cmname, err)
	}

	if cm.Data == nil {
		cm.Data = make(map[string]string)
	}
	if treeID, ok := cm.Data[treeKey]; ok {
		logging.FromContext(ctx).Infof("Found existing TreeID: %s", treeID)
		return
	}

	tree, err := createTree(ctx)
	if err != nil {
		logging.FromContext(ctx).Fatalf("Failed to create the trillian tree: %v", err)
	}
	cm.Data[treeKey] = fmt.Sprint(tree.TreeId)
	logging.FromContext(ctx).Infof("Created a new tree %d updating configmap %s/%s", tree.TreeId, *ns, *cmname)

	_, err = clientset.CoreV1().ConfigMaps(*ns).Update(ctx, cm, metav1.UpdateOptions{})
	if err != nil {
		logging.FromContext(ctx).Fatalf("Failed to update the configmap: %v", err)
	}
}

func createTree(ctx context.Context) (*trillian.Tree, error) {
	req, err := newRequest()
	if err != nil {
		return nil, err
	}

	dialOpts, err := rpcflags.NewClientDialOptionsFromFlags()
	if err != nil {
		return nil, errors.Wrap(err, "failed to determine dial options")
	}

	conn, err := grpc.Dial(*adminServerAddr, dialOpts...)
	if err != nil {
		return nil, errors.Wrap(err, "failed to dial")
	}
	defer conn.Close()

	adminClient := trillian.NewTrillianAdminClient(conn)
	logClient := trillian.NewTrillianLogClient(conn)

	return client.CreateAndInitTree(ctx, req, adminClient, logClient)
}

func newRequest() (*trillian.CreateTreeRequest, error) {
	ts, ok := trillian.TreeState_value[*treeState]
	if !ok {
		return nil, fmt.Errorf("unknown TreeState: %v", *treeState)
	}

	tt, ok := trillian.TreeType_value[*treeType]
	if !ok {
		return nil, fmt.Errorf("unknown TreeType: %v", *treeType)
	}

	ctr := &trillian.CreateTreeRequest{Tree: &trillian.Tree{
		TreeState:       trillian.TreeState(ts),
		TreeType:        trillian.TreeType(tt),
		DisplayName:     *displayName,
		Description:     *description,
		MaxRootDuration: durationpb.New(*maxRootDuration),
	}}
	glog.Infof("Creating tree %+v", ctr.Tree)

	return ctr, nil
}
