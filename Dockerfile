FROM python:3.8-slim

COPY LICENSE README.md /

RUN apt-get update && \
    apt-get install -y --no-install-recommends build-essential  && \
    pip install --upgrade pip && \
    pip awscli aws-sam-cli && \
    pip install poetry

COPY entrypoint.sh /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
