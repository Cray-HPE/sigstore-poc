# Pipeline Notes and Principles

This document describes the reasoning and principles behind the way the
pipelines are constructed. As they currently stand they are a starting point
and will most certainly require changes and additions as we learn more about
the way things are built. The sections in this document are not listed in the
order of importance or priority, but rather is a collection of points that
should be kept in mind as one goes to build new pipelines, or modify existing
ones.

# API first

While Pipeline (and Task) resources are not strictly an API, it should be
considered as such. Each Pipeline and Task should have clearly defined roles
and responsibilities and the input/output arguments should be given thought just
like when one were to write an API for a library. Since there are different
pipelines being built (currently only Python and Go), having a convention that's
consistent between the Pipelines makes it easier to re-use Tasks in Pipelines
and for a new Pipeline to look and feel familiar if a user is familiar with an
existing Pipeline or Task. For example, if the way you specify which Dockerfile
to use to build Docker containers is called `dockerfile` in one task and
`Dockerfile` in another, it will cause friction. Furthermore, standardizing
these will make cataloguing and documenting them easier.

# Roles and responsibilities

It's entirely possible to define a Task that does pretty much everything that a
Pipeline does, it is preferable to design Tasks that have very clear definition
of what they do. Not only does it make them more reusable, but it also makes
it easier to test them and document them. It also has the added benefit of
being able to inject new Tasks into the Pipeline for only certain builds that
require them. One example of this might be running `codegen` for some classes
of builds, while others may not need them. Lastly, this sets things up nicely
for future where there will be better support for creating attestations and in
particular restricting what a Task is allowed to do, for example a compile step
should not have any access to network, but rather a Task ahead of it should be
responsible for fetching all the necessary dependencies making it possible to
ensure that nothing new was introduced in the compile step.

# Workspaces

Workspaces are the fundamental unit of sharing input/output between each Task in
a Pipeline. This is part of the API mentality mentioned above, but given its own
section because this is what allows locking down what is available to a Task,
and what the Task is limited to output. Furthermore, this makes it again easier
to test and define Tasks because you can create different inputs run the Task
and verify the outputs as well as create Attestations based on those for later
policy / verification decisions.

# Additional Workspaces

One option for speeding up the stages in the pipeline is to define Workspace
that's used as a Cache between Tasks in a Pipeline. This has not been
implemented, but one could define a Workspace that should be used for this
purpose, and any Tasks that could benefit from it could then utilize this cache
by following a well-defined semantics for defining it (by convention for
example). Furthermore, if it is not necessary, one could always just use an
`EmptyDir` to pass in to these tasks.

# Overview of the existing Pipelines

This section runs through the breakdown of the existing Pipelines demonstrating
some principles above, and how they manifest themselves in the Task
definitions. There are few `OPTIONAL` steps that have not been implemented yet
but one could see them fitting in quite nicely as necessary.

These Pipelines are for building a container image from a source repo, but
using these techniques you can see them being used for doing things like
`presubmit` checks to ensure that what's being checked in should be allowed
to be checked in. Some examples would be doing things like running Lint,
Spellcheck, License, boilerplate, etc. tooling to ensure the Source code hygiene
is maintained.

## Fetch Source

This step does precisely what one would expect, it will clone the specified
GitHub repo into a Workspace.

## Install Dependencies

Based on source fetched, it may require additional capabilities,
for example, installing `pip` modules. We do not want that to be
part of the creation of the image, since it will require network
access and compilations and maybe even additional tooling that is
not desireable to have in the final container. Therefore, this step
is responsible for installing all the required dependencies and
writing them to a Workspace.

In the Python pipeline, we create a Python `venv` and install all
the dependencies there and now the Python environment is ready to
be used by later stages.

In the Go pipeline, we install the required Go modules and write
them to a Workspace that's then again ready to be used by later
stages.

## (OPTIONAL) Verify dependencies

In some repos for Go, the dependencies are vendored in, but even if they have
been vendored in and checked in, a step should be ran to validate what has been
checked in matches the actual dependencies.

## (OPTIONAL) Codegen

One example of running codegen would be generating Protos from the source. Even
if these are checked into the original repo, one could run this Task to ensure
the results of the checked in code have not been tampered with, or mistakes
have not been made. For example, a user could gen these with old tooling by
mistake and check it in.

## Create Container

This steps takes the source and already installed dependencies and turns that
into a container. For Python, we use `kaniko` which is well suited to run in
a k8s cluster, and for Go we use `ko` to demonstrate flexibility in the tooling.
You could just as well use `kaniko` to build the Go container.

## Create SBOM

Once the image has been created, we create the SBOM for it.

## Run vulnerability scan

Once the image has been created, we run a Trivy scan for it.

# Further notes

It's worth pointing out that by having Tasks with well-defined APIs, for example
Trivy scan, we can easily re-use it in both the Python / Go Pipelines, and the
Pipelines only have to have specialized Tasks that are necessary for the
particular language / tooling.
