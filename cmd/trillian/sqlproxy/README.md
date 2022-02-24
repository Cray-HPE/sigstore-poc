# SQLProxy

This repository contains our version of the sidecar proxy that's built on top of
the [CloudSQL proxy](gcr.io/cloudsql-docker/gce-proxy:1.27.0). This allows us to
create identical deployments in prod as well as tests and control via
environmental flags which database we're targeting.

## SQL proxy

As mentioned above, the Proxy is a sidecar that handles authentication to
the GCP Cloud SQL. If run in a non-cloud SQL environment, for example trillian
createdb job, it will be a nop. Because the sidecar is meant to be a long
running process and there's no good way to tell when the "main" container is
done running, and hence the proxy should exit cleanly, we have added a signaling
mechanism that uses filesystem to signal when it's time to exit. This requires
that both the "main" and the proxy container both mount the same filesystem,
typically an emptydir and they agree on the directory for it. For this, we use
an env variable `EXIT_DIR`. The "main" container simply needs to create _any_
file in this directory, which will signal the proxy to exit. Reasoning for
any file, rather than a specific is to just make it simpler to utilize this
mechanism. It's probably the easiest to create a defer function that creates
an [empty file](../trillian/cmd/createdb/main.go). One thing to keep
in mind is that if you use the defer mechanism is to make sure you do not call
log.Fatal since that will prevent any defer functions from running.

Configuring which environment the proxy is running in is done with env
variable `ORM_DRIVER`. Setting it to `cloudsql` means it will connect to GCP
cloud SQL instance defined by `INSTANCES` environmental variable. In addition
to these flags, the serviceaccount that the pod is running as must have
access to the Cloud SQL.



