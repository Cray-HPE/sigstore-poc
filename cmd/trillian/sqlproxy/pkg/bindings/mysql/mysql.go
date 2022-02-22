/*
Copyright 2021 Chainguard, Inc.
SPDX-License-Identifier: Apache-2.0
*/

package cloudsql

import (
	"fmt"
	"io/ioutil"
	"path/filepath"

	"github.com/kelseyhightower/envconfig"
)

type envConfig struct {
	MountPath string `envconfig:"MYSQL_BINDINGS" default:"/var/bindings/mysql" required:"true"`
}

func (e *envConfig) SecretPath(key string) string {
	return filepath.Join(e.MountPath, "secrets", key)
}

func (e *envConfig) ReadKey(key string) (string, error) {
	data, err := ioutil.ReadFile(e.SecretPath(key))
	if err != nil {
		return "", err
	}
	return string(data), nil
}

func ConnStrFromBindings(database string) (string, error) {
	var env envConfig
	if err := envconfig.Process("", &env); err != nil {
		return "", fmt.Errorf("failed to process env var: %w", err)
	}

	host, err := env.ReadKey("host")
	if err != nil {
		return "", err
	}
	username, err := env.ReadKey("username")
	if err != nil {
		return "", err
	}
	password, err := env.ReadKey("password")
	if err != nil {
		return "", err
	}
	return fmt.Sprintf("%s:%s@tcp(%s:3306)/%s?charset=utf8mb4&parseTime=true", username, password, host, database), nil
}
