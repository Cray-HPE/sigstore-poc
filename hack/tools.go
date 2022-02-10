//go:build tools
// +build tools

/*
Copyright 2022 Chainguard, Inc.
SPDX-License-Identifier: Apache-2.0
*/

package tools

import (
	// Import things that we build using ko
	_ "github.com/google/certificate-transparency-go/trillian/ctfe/ct_server"
)
