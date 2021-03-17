FROM amazon/aws-sam-cli-build-image-python3.8:latest

COPY LICENSE README.md /

RUN apt-get update && \
    apt-get install -y --no-install-recommends build-essential  && \
    pip install --upgrade pip && \
    pip install awscli aws-sam-cli && \
    pip install poetry

COPY entrypoint.sh /entrypoint.sh
RUN ls

ENTRYPOINT ["/entrypoint.sh"]
