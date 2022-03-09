# Spiffe specific configuration

Configuring Spiffe to be used as an authentication mechanism
to acquire Signing Certificates from Fulcio requires a few moving
parts. This directory holds information pertaining to it.

It's very much WIP, but it contains enough information to be able
to repro setting it up on a publicly accessible GKE cluster. The reason for
publicly accessible is that it uses ACME to get a certificate so that we can
get OIDC working. Setting up a cluster with own certificates is a followup work
that we should do to make sure we can run e2e tests against this in our CI/CD
pipeline.

I have also created a small
[sample program](https://github.com/vaikas/spiffefulciotest) that can be used
to test both the acquisition of a SVID as well as using that to fetch a signing certificate from Fulcio.


