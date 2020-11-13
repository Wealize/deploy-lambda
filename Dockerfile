FROM python:alpine

COPY LICENSE README.md /

RUN pip install --upgrade --no-cache-dir awscli aws-sam-cli yq pipenv

COPY entrypoint.sh /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
