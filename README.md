# Deploy Python based Lambda

This Github Action is intended to deploy Python Lambdas to AWS

## Usage

An example workflow to deploy your python lambda


```yaml
on: push

name: Deploy python lambda

jobs:
  build:
    runs-on: ubuntu-latest
    timeout-minutes: 10

    steps:

    - uses: actions/checkout@v1

    - name: Deploy to AWS
      uses: wealize/deploy-lambda
      env:
        AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
        AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
```

Before running this workflow, you must have a file called samconfig.toml with the following parameters

```toml
version = 0.1
[default]
[default.deploy]
[default.deploy.parameters]
stack_name = "your-stack-name"
s3_prefix = "your-stack-name"
region = "your-region"
confirm_changeset = true
capabilities = "CAPABILITY_IAM"
```