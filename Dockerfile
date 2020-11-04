FROM python:alpine

COPY LICENSE README.md /

RUN pip install --upgrade --no-cache-dir awscli aws-sam-cli yq pipenv

RUN echo complete -C '/usr/local/bin/aws_completer' aws >> ~/.bashrc

COPY entrypoint.sh /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
