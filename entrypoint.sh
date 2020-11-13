#!/bin/bash

################################################################################
################################################################################
########################## Github AWS Lambda Deploy ############################
################################################################################
################################################################################


###########
# Globals #
###########
SAM_CMD='sam'                               # Path to AWS SAM Exec

###################
# GitHub ENV Vars #
###################
GITHUB_WORKSPACE="${GITHUB_WORKSPACE}"            # Github Workspace

##############
# Built Vars #
##############
ACTION_CONCLUSTION=''   # success, failure, neutral, cancelled, timed_out, or action_required.
ACTION_OUTPUT=''        # String to pass back to the user on the output
ERROR_FOUND=0           # Set to 1 if any errors occur in the build before the package and deploy
ERROR_CAUSE=''          # String to pass of error that was detected

################
# Default Vars #
################
AWS_PACKAGED='packaged.yml'               # Created SAM Package


ValidateAWSCLI() {
  echo "--------------------------------------------"
  echo "Validating AWS information..."

  VALIDATE_AWS_CMD=$(which aws)

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
}

BuidApp() {
  echo "--------------------------------------------"
  echo "Building the SAM application..."

  pipenv install
  pipenv install -d

  BUILD_CMD=$(cd "$GITHUB_WORKSPACE" ; "$SAM_CMD" build --use-container)

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

  SAM_DEPLOY_CMD=$(cd "$GITHUB_WORKSPACE"; "$SAM_CMD" deploy --template-file "$GITHUB_WORKSPACE/$AWS_PACKAGED" --resolve-s3)

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


if [ $ERROR_FOUND -eq 0 ]; then
  GetGitHubVars
fi

if [ $ERROR_FOUND -eq 0 ]; then
  ValidateAWSCLI
fi

if [ $ERROR_FOUND -eq 0 ]; then
  RunDeploy
fi

exit $ERROR_FOUND
