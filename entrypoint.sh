#!/bin/bash

################################################################################
################################################################################
########################## Github AWS Lambda Deploy ############################
################################################################################
################################################################################


###########
# Globals #
###########
AWS_REGION=''                               # AWS region to deploy
S3_BUCKET=''                                # AWS S3 bucket to package and deploy
AWS_SAM_TEMPLATE=''                         # Path to the SAM template in the user repository
CHECK_NAME='GitHub AWS Lambda Deploy'   # Name of the GitHub Action
CHECK_ID=''                                 # GitHub Check ID that is created
AWS_STACK_NAME=''                           # AWS Cloud Formation Stack name of SAM
SAM_CMD='sam'                               # Path to AWS SAM Exec
RUNTIME=''                                  # Runtime for AWS SAM App

###################
# GitHub ENV Vars #
###################
GITHUB_SHA="${GITHUB_SHA}"                        # GitHub sha from the commit
GITHUB_EVENT_PATH="${GITHUB_EVENT_PATH}"          # Github Event Path
GITHUB_TOKEN=''                                   # GitHub token
GITHUB_WORKSPACE="${GITHUB_WORKSPACE}"            # Github Workspace
GITHUB_URL='https://api.github.com'               # GitHub API URL

###################
# AWS Secret Vars #
###################
# shellcheck disable=SC2034
AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY}"             # aws_access_key_id to auth
# shellcheck disable=SC2034
AWS_SECRET_ACCESS_KEY="${AWS_SECRET_KEY}"         # aws_secret_access_key to auth

##############
# Built Vars #
##############
GITHUB_ORG=''           # Name of the GitHub Org
GITHUB_REPO=''          # Name of the GitHub repo
USER_CONFIG_FILE="$GITHUB_WORKSPACE/.github/aws-config.yml"   # File with users configurations
START_DATE=$(date +"%Y-%m-%dT%H:%M:%SZ")                      # YYYY-MM-DDTHH:MM:SSZ
FINISHED_DATE=''        # YYYY-MM-DDTHH:MM:SSZ when complete
ACTION_CONCLUSTION=''   # success, failure, neutral, cancelled, timed_out, or action_required.
ACTION_OUTPUT=''        # String to pass back to the user on the output
ERROR_FOUND=0           # Set to 1 if any errors occur in the build before the package and deploy
ERROR_CAUSE=''          # String to pass of error that was detected

################
# Default Vars #
################
DEFAULT_OUTPUT='json'                     # Default Output format
DEFAULT_REGION='us-west-2'                # Default region to deploy
LOCAL_CONFIG_FILE='/root/.aws/config'     # AWS Config file
AWS_PACKAGED='packaged.yml'               # Created SAM Package
DEBUG=0                                   # Debug=0 OFF | Debug=1 ON


######################################################
# Variables we need to set in the ~/.aws/credentials #
# aws_access_key_id                                  #
# aws_secret_access_key                              #
######################################################

#################################################
# Variables we need to set in the ~/.aws/config #
# region                                        #
# output                                        #
#################################################

ValidateConfigurationFile() {
  echo "--------------------------------------------"
  echo "Validating input file..."

  if [ ! -f "$USER_CONFIG_FILE" ]; then
    echo "ERROR! Failed to find configuration file in user repository!"

    ERROR_FOUND=1
    ERROR_CAUSE='Failed to find configuration file in user repository!'
  else
    echo "Success! Found User config file at:[$USER_CONFIG_FILE]"
  fi

  if [ $ERROR_CODE -ne 0 ] || [ "$S3_BUCKET" == "null" ]; then
    echo "ERROR! Failed to get [s3_bucket]!"
    echo "ERROR:[$S3_BUCKET]"

    ERROR_FOUND=1
    ERROR_CAUSE='Failed to get [s3_bucket]!'
  else
    echo "Successfully found:[s3_bucket]"
  fi

  AWS_STACK_NAME=$(yq -r .aws_stack_name "$USER_CONFIG_FILE")

  ERROR_CODE=$?

  if [ $ERROR_CODE -ne 0 ] || [ "$AWS_STACK_NAME" == "null" ]; then
    echo "ERROR! Failed to get [aws_stack_name]!"
    echo "ERROR:[$AWS_STACK_NAME]"

    ERROR_FOUND=1
    ERROR_CAUSE='Failed to get [aws_stack_name]!'
  else
    echo "Successfully found:[aws_stack_name]"
  fi

  AWS_STACK_NAME_NO_WHITESPACE="$(echo "${AWS_STACK_NAME}" | tr -d '[:space:]')"
  AWS_STACK_NAME=$AWS_STACK_NAME_NO_WHITESPACE

  AWS_SAM_TEMPLATE=$(yq -r .sam_template "$USER_CONFIG_FILE")

  ERROR_CODE=$?

  if [ $ERROR_CODE -ne 0 ] || [ "$AWS_SAM_TEMPLATE" == "null" ]; then
    echo "ERROR! Failed to get [sam_template]!"
    echo "ERROR:[$AWS_SAM_TEMPLATE]"

    ERROR_FOUND=1
    ERROR_CAUSE='Failed to get [sam_template]!'
  else
    echo "Successfully found:[sam_template]"
  fi

  AWS_SAM_TEMPLATE_NO_WHITESPACE="$(echo "${AWS_SAM_TEMPLATE}" | tr -d '[:space:]')"
  AWS_SAM_TEMPLATE=$AWS_SAM_TEMPLATE_NO_WHITESPACE

  AWS_REGION=$(yq -r .region "$USER_CONFIG_FILE")

  ERROR_CODE=$?

  if [ $ERROR_CODE -ne 0 ] || [ "$AWS_REGION" == "null" ]; then
    echo "ERROR! Failed to get [region]!"
    echo "ERROR:[$AWS_REGION]"
    echo "No value provided... Defaulting to:[$DEFAULT_REGION]"
    AWS_REGION="$DEFAULT_REGION"
  else
    echo "Successfully found:[region]"
  fi

  AWS_REGION_NO_WHITESPACE="$(echo "${AWS_REGION}" | tr -d '[:space:]')"
  AWS_REGION=$AWS_REGION_NO_WHITESPACE
}


CreateLocalConfiguration() {
  echo "--------------------------------------------"
  echo "Creating local configuration file..."

  MK_DIR_CMD=$(mkdir /root/.aws)

  ERROR_CODE=$?

  if [ $ERROR_CODE -ne 0 ]; then
    echo "ERROR! Failed to create root directory!"
    echo "ERROR:[$MK_DIR_CMD]"

    ERROR_FOUND=1
    ERROR_CAUSE='Failed to create root directory!'
  fi

  CREATE_CONFIG_CMD=$(echo -e "[default]\nregion=$AWS_REGION\noutput=$DEFAULT_OUTPUT" >> $LOCAL_CONFIG_FILE )

  ERROR_CODE=$?

  if [ $ERROR_CODE -ne 0 ]; then
    echo "ERROR! Failed to create file:[$LOCAL_CONFIG_FILE]!"
    echo "ERROR:[$CREATE_CONFIG_CMD]"

    ERROR_FOUND=1
    ERROR_CAUSE="Failed to create file:[$LOCAL_CONFIG_FILE]!"
  else
    echo "Successfully created:[$LOCAL_CONFIG_FILE]"
  fi
}

GetGitHubVars() {
  echo "--------------------------------------------"
  echo "Gathering GitHub information..."

  if [ -z "$GITHUB_SHA" ]; then
    echo "ERROR! Failed to get [GITHUB_SHA]!"
    echo "ERROR:[$GITHUB_SHA]"

    ERROR_FOUND=1
    ERROR_CAUSE='Failed to get [GITHUB_SHA]!'
  else
    echo "Successfully found:[GITHUB_SHA]"
  fi

  
  if [ -z "$GITHUB_WORKSPACE" ]; then
    echo "ERROR! Failed to get [GITHUB_WORKSPACE]!"
    echo "ERROR:[$GITHUB_WORKSPACE]"

    ERROR_FOUND=1
    ERROR_CAUSE='Failed to get [GITHUB_WORKSPACE]!'
  else
    echo "Successfully found:[GITHUB_WORKSPACE]"
  fi


  if [ -z "$GITHUB_EVENT_PATH" ]; then
    echo "ERROR! Failed to get [GITHUB_EVENT_PATH]!"
    echo "ERROR:[$GITHUB_EVENT_PATH]"

    ERROR_FOUND=1
    ERROR_CAUSE='Failed to get [GITHUB_EVENT_PATH]!'
  else
    echo "Successfully found:[GITHUB_EVENT_PATH]"
  fi


  GITHUB_ORG=$(cat "$GITHUB_EVENT_PATH" | jq -r '.repository.owner.login' )

  if [ -z "$GITHUB_ORG" ]; then
    echo "ERROR! Failed to get [GITHUB_ORG]!"
    echo "ERROR:[$GITHUB_ORG]"

    ERROR_FOUND=1
    ERROR_CAUSE='Failed to get [GITHUB_ORG]!'
  else
    echo "Successfully found:[GITHUB_ORG]"
  fi

  GITHUB_REPO=$(cat "$GITHUB_EVENT_PATH"| jq -r '.repository.name' )

  if [ -z "$GITHUB_REPO" ]; then
    echo "ERROR! Failed to get [GITHUB_REPO]!"
    echo "ERROR:[$GITHUB_REPO]"

    ERROR_FOUND=1
    ERROR_CAUSE='Failed to get [GITHUB_REPO]!'
  else
    echo "Successfully found:[GITHUB_REPO]"
  fi
}


ValidateAWSCLI() {
  echo "--------------------------------------------"
  echo "Validating AWS information..."

  VALIDATE_AWS_CMD=$(which aws )

  ERROR_CODE=$?

  if [ $ERROR_CODE -ne 0 ]; then
    echo "ERROR! Failed to find aws cli!"
    echo "ERROR:[$VALIDATE_AWS_CMD]"

    ERROR_FOUND=1
    ERROR_CAUSE='Failed to find aws cli!'
  else
    echo "Successfully validated:[aws cli]"
  fi

  VALIDATE_SAM_CMD=$(which "$SAM_CMD" )

  ERROR_CODE=$?

  if [ $ERROR_CODE -ne 0 ]; then
    echo "ERROR! Failed to find aws sam cli!"
    echo "ERROR:[$VALIDATE_SAM_CMD]"

    ERROR_FOUND=1
    ERROR_CAUSE='Failed to find aws sam cli!'
  else
    echo "Successfully validated:[aws sam cli]"
  fi
}


RunDeploy() {
  echo "--------------------------------------------"
  echo "Running AWS Deploy Process..."

  if [ $ERROR_FOUND -eq 0 ]; then
    BuidApp
  fi

  if [ $ERROR_FOUND -eq 0 ]; then
    DeployTemplate
  fi

  if [ $ERROR_FOUND -eq 0 ]; then
    GetOutput
  fi
}
BuidApp() {
  echo "--------------------------------------------"
  echo "Building the SAM application..."

  BUILD_CMD=$(cd "$GITHUB_WORKSPACE" ; "$SAM_CMD" build -t "$AWS_SAM_TEMPLATE")

  ERROR_CODE=$?

  if [ $ERROR_CODE -ne 0 ]; then
    echo "ERROR! Failed to build SAM application!"
    echo "ERROR:[$BUILD_CMD]"

    ERROR_FOUND=1
    ERROR_CAUSE="Failed to build SAM application:[$BUILD_CMD]!"
  else
    echo "Successfully built local AWS SAM Application"
  fi
}

DeployTemplate() {
  echo "--------------------------------------------"
  echo "Deploying the template..."

  if [ ! -f "$GITHUB_WORKSPACE/$AWS_PACKAGED" ]; then
    echo "ERROR! Failed to find created package:[$AWS_PACKAGED]"

    ERROR_FOUND=1
    ERROR_CAUSE="Failed to find created package:[$AWS_PACKAGED]"
  fi

  SAM_DEPLOY_CMD=$(cd "$GITHUB_WORKSPACE"; "$SAM_CMD" deploy --template-file "$GITHUB_WORKSPACE/$AWS_PACKAGED" --stack-name "$AWS_STACK_NAME" --capabilities CAPABILITY_IAM --region "$AWS_REGION")

  ERROR_CODE=$?

  if [ $ERROR_CODE -ne 0 ]; then
    echo "ERROR! Failed to deploy SAM template!"
    echo "ERROR:[$SAM_DEPLOY_CMD]"
    ERROR_FOUND=1
    ACTION_CONCLUSTION='failure'
    ACTION_OUTPUT="Failed to deploy SAM App"
  else
    # Success
    echo "Successfully deployed AWS SAM Application"
    ACTION_CONCLUSTION='success'
    ACTION_OUTPUT="Successfully Deployed SAM App"
  fi
}


GetOutput() {
  # Need to get the generated output from the stack
  # to display back to the user for consumption

  echo "--------------------------------------------"
  echo "Gathering Output from deployed SAM application..."

  IFS=$'\n' # Set IFS to newline
  OUTPUT_CMD=($(aws cloudformation describe-stacks --stack-name "$AWS_STACK_NAME" --query "Stacks[0].Outputs[*]" --region "$AWS_REGION"))

  ERROR_CODE=$?

  if [ $ERROR_CODE -ne 0 ]; then
    echo "ERROR! Failed to get output from deployed SAM application!"
    echo "ERROR:[${OUTPUT_CMD[*]}]"

    ERROR_FOUND=1
    ACTION_CONCLUSTION='failure'
    ACTION_OUTPUT="Failed to get output from deployed SAM application"
  else

    echo "Output from deployed AWS SAM Application:[$AWS_STACK_NAME]:"
    for LINE in "${OUTPUT_CMD[@]}"
    do
      echo "$LINE"
    done
  fi
}



UpdateCheck() {
  echo "--------------------------------------------"
  echo "Updating GitHub Check..."

  FINISHED_DATE=$(date +"%Y-%m-%dT%H:%M:%SZ")

  if [ $ERROR_FOUND -ne 0 ]; then
    ACTION_CONCLUSTION='failure'
    ACTION_OUTPUT="$ERROR_CAUSE"
  fi

  UPDATE_CHECK_CMD=$( curl -k --fail -X PATCH \
    --url "$GITHUB_URL/repos/$GITHUB_ORG/$GITHUB_REPO/check-runs/$CHECK_ID" \
    -H 'accept: application/vnd.github.antiope-preview+json' \
    -H "authorization: Bearer $GITHUB_TOKEN" \
    -H 'content-type: application/json' \
    --data "{ \"name\": \"$CHECK_NAME\", \"head_sha\": \"$GITHUB_SHA\", \"status\": \"completed\", \"completed_at\": \"$FINISHED_DATE\" , \"conclusion\": \"$ACTION_CONCLUSTION\" , \"output\": { \"title\": \"AWS SAM Deploy Summary\" , \"text\": \"$ACTION_OUTPUT\"} }")

  ERROR_CODE=$?

  if [ $ERROR_CODE -ne 0 ]; then
    echo "ERROR! Failed to update GitHub Check!"
    echo "ERROR:[$UPDATE_CHECK_CMD]"
    exit 1
  else
    echo "Success! Updated Github Checks API"
  fi
}



if [ $ERROR_FOUND -eq 0 ]; then
  GetGitHubVars
fi

if [ $ERROR_FOUND -eq 0 ]; then
  ValidateConfigurationFile
fi

if [ $ERROR_FOUND -eq 0 ]; then
  CreateLocalConfiguration
fi

if [ $ERROR_FOUND -eq 0 ]; then
  ValidateAWSCLI
fi

if [ $ERROR_FOUND -eq 0 ]; then
  RunDeploy
fi

if [ $ERROR_FOUND -eq 0 ]; then
  exit 0
else
  exit 1
fi
