# Spiffe specific configuration

Configuring Spiffe to be used as an authentication mechanism
to acquire Signing Certificates from Fulcio requires a few moving
parts. This directory holds information pertaining to it.

It's very much WIP, but it contains enough information to be able
to repro setting it up on a publicly accessible GKE cluster.

It also contains a small [sample program](./testapp/cmd/main.go) that
can be used to test both the acquisition of a SVID as well as usingthat to fetch a signing certificate from Fulcio.

