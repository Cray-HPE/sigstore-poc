FROM python:3.10-slim@sha256:ca2a31f21938f24bab02344bf846a90cc2bff5bd0e5a53b24b5dfcb4519ea8a3

# LABEL about the custom image
LABEL maintainer="vaikas@chainguard.dev"
LABEL version="0.1"
LABEL description="Build Python container"

WORKDIR /app
RUN echo "Running copy"
COPY venv .
RUN echo "Done running copy"
ENV VIRTUAL_ENV=/app/venv
RUN python3 -m venv $VIRTUAL_ENV
ENV PATH="$VIRTUAL_ENV/bin:$PATH"

RUN ls -lR /app
# Copy the actual application source code here.
# Need to add another workspace for it to be included.
RUN echo 'print("hello world!")' > ./hello.py
RUN ls ./
RUN cat ./hello.py
CMD ["python", "./hello.py"]
