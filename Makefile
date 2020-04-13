# This script deploys the lambda2sqs API.
# This script is called by the `deploy.sh` file in this folder
# We use this to deploy the lambda API with Travis CI
# The hardcoded variable TRAVIS_PROFILE below will be overridden when .travis.yml runs
TRAVIS_PROFILE = ins-dev

# We create a function to simplify getting variables from aws parameter store.

define ssm
$(shell aws --profile $(TRAVIS_PROFILE) ssm get-parameters --names $1 --with-decryption --query Parameters[0].Value --output text)
endef

# We get the profile information in we have in AWS DEV.
# These are for the DEV, PROD and DEMO environment

TRAVIS_PROFILE_DEV = $(call ssm,TRAVIS_PROFILE_DEV)
TRAVIS_PROFILE_PROD = $(call ssm,TRAVIS_PROFILE_PROD)
TRAVIS_PROFILE_DEMO = $(call ssm,TRAVIS_PROFILE_DEMO)

# We create a function to simplify getting variables for aws parameter store from the PROD.

define ssm-prod
$(shell aws --profile $(TRAVIS_PROFILE_PROD) ssm get-parameters --names $1 --with-decryption --query Parameters[0].Value --output text)
endef

# We create a function to simplify getting variables for aws parameter store from the DEMO.

define ssm-demo
$(shell aws --profile $(TRAVIS_PROFILE_DEMO) ssm get-parameters --names $1 --with-decryption --query Parameters[0].Value --output text)
endef

# We prepare the variables that will be needed

PROJECT = lambda2sqs
STACK_NAME ?= $(PROJECT)
DEPLOY_S3_PREFIX ?= $(PROJECT)
# DO WE NEED THIS VARIABLE???
AWS_REGION = ap-southeast-1
# END - WE NEED THIS VARIABLE???

# We also need variables that are coming from AWS Parameter Store
# - S3_BUCKET_NAME
# - LAMBDA_TO_RDS_SECURITY_GROUP
# - DEFAULT_SECURITY_GROUP
# - PRIVATE_SUBNET_1
# - PRIVATE_SUBNET_2
# - PRIVATE_SUBNET_3

# The command that we can execute

build: push-bin process-bin

push-bin: push/
	cd push; GO111MODULE=on go mod tidy; GOOS=linux GOARCH=amd64 go build -o ../push-bin .

process-bin: process/
	cd process; GO111MODULE=on go mod tidy; GOOS=linux GOARCH=amd64 go build -o ../process-bin .

push-logs: sam logs -n ut_lambda2sqs_push -t 

process-logs: sam logs -n ut_lambda2sqs_process -t

invoke: push-bin
	sam local invoke Push -e tests/foo.json

destroy: aws cloudformation delete-stack \
	--stack-name $(STACK_NAME)

validate: template.yaml
	sam validate --profile $(TRAVIS_PROFILE) --template template.yaml

dev: build
	sam package --profile $(TRAVIS_PROFILE_DEV) --template-file template.yaml --s3-bucket $(call ssm,S3_BUCKET_NAME) --s3-prefix $(DEPLOY_S3_PREFIX) --output-template-file packaged.yaml
	sam deploy --profile $(TRAVIS_PROFILE_DEV) --template-file ./packaged.yaml --stack-name $(STACK_NAME) --capabilities CAPABILITY_IAM \
	--parameter-overrides DefaultSecurityGroup=$(call ssm,DEFAULT_SECURITY_GROUP),$(call ssm,LAMBDA_TO_RDS_SECURITY_GROUP) PrivateSubnets=$(call ssm,PRIVATE_SUBNET_1),$(call ssm,PRIVATE_SUBNET_2),$(call ssm,PRIVATE_SUBNET_3)
	# The current TRAVIS_PROFILE is: 
	echo '# The TRAVIS_PROFILE:' $(TRAVIS_PROFILE)
	# The profile we will use for deployment is
	echo '# The TRAVIS_PROFILE_DEV:' $(TRAVIS_PROFILE_DEV)
	# We have defined the following variables:
	echo '# The project name: ' $(PROJECT)
	echo '# The stack name: ' $(STACK_NAME)
	echo '# The Deploy S3 Prefix: ' $(DEPLOY_S3_PREFIX)
	# We will use the following information from the AWS parameter store:
	# - S3_BUCKET_NAME
	echo '# The S3_BUCKET_NAME:' $(call ssm,S3_BUCKET_NAME)
	# - LAMBDA_TO_RDS_SECURITY_GROUP
	echo '# The LAMBDA_TO_RDS_SECURITY_GROUP: ' $(call ssm,LAMBDA_TO_RDS_SECURITY_GROUP)
	# - DEFAULT_SECURITY_GROUP
	echo '# The DEFAULT_SECURITY_GROUP: ' $(call ssm,DEFAULT_SECURITY_GROUP)
	# - PRIVATE_SUBNET_1
	echo '# The PRIVATE_SUBNET_1: ' $(call ssm,PRIVATE_SUBNET_1)
	# - PRIVATE_SUBNET_2
	echo '# The PRIVATE_SUBNET_2: ' $(call ssm,PRIVATE_SUBNET_2)
	# - PRIVATE_SUBNET_3
	echo '# The PRIVATE_SUBNET_3: ' $(call ssm,PRIVATE_SUBNET_3)
	# END this is dev in Makefile

prod: build
	sam package --profile $(TRAVIS_PROFILE_PROD) --template-file template.yaml --s3-bucket $(call ssm-prod,S3_BUCKET_NAME) --s3-prefix $(DEPLOY_S3_PREFIX) --output-template-file packaged.yaml
	sam deploy --profile $(TRAVIS_PROFILE_PROD) --template-file ./packaged.yaml --stack-name $(STACK_NAME) --capabilities CAPABILITY_IAM \
	--parameter-overrides DefaultSecurityGroup=$(call ssm-prod,DEFAULT_SECURITY_GROUP),$(call ssm-prod,LAMBDA_TO_RDS_SECURITY_GROUP)  PrivateSubnets=$(call ssm-prod,PRIVATE_SUBNET_1),$(call ssm-prod,PRIVATE_SUBNET_2),$(call ssm-prod,PRIVATE_SUBNET_3)
	# add more info to facilitate debugging
	# START this is `prod` in Makefile
	# The current TRAVIS_PROFILE is: 
	echo '# The ' $(TRAVIS_PROFILE)
	# The profile we will use for deployment is
	echo '# The ' $(TRAVIS_PROFILE_PROD)
	# We have defined the following variables:
	echo '# The project name:' echo $(PROJECT)
	echo '# The stack name: ' $(STACK_NAME)
	echo '# The Deploy S3 Prefix: ' $(DEPLOY_S3_PREFIX)
	# We will use the following information from the AWS parameter store:
	# - S3_BUCKET_NAME
	echo '# The S3_BUCKET_NAME: ' $(call ssm-prod,S3_BUCKET_NAME)
	# - LAMBDA_TO_RDS_SECURITY_GROUP
	echo '# The LAMBDA_TO_RDS_SECURITY_GROUP: ' $(call ssm-prod,LAMBDA_TO_RDS_SECURITY_GROUP)
	# - DEFAULT_SECURITY_GROUP
	echo '# The DEFAULT_SECURITY_GROUP: ' $(call ssm-prod,DEFAULT_SECURITY_GROUP)
	# - PRIVATE_SUBNET_1
	echo '# The PRIVATE_SUBNET_1: ' $(call ssm-prod,PRIVATE_SUBNET_1)
	# - PRIVATE_SUBNET_2
	echo '# The PRIVATE_SUBNET_2: ' $(call ssm-prod,PRIVATE_SUBNET_2)
	# - PRIVATE_SUBNET_3
	echo '# The PRIVATE_SUBNET_3: ' $(call ssm-prod,PRIVATE_SUBNET_3)
	# END this is `prod` in Makefile

demo: build
	sam package --profile $(TRAVIS_PROFILE_DEMO) --template-file template.yaml --s3-bucket $(call ssm-demo,S3_BUCKET_NAME) --s3-prefix $(DEPLOY_S3_PREFIX) --output-template-file packaged.yaml
	sam deploy --profile $(TRAVIS_PROFILE_DEMO) --template-file ./packaged.yaml --stack-name $(STACK_NAME) --capabilities CAPABILITY_IAM \
	--parameter-overrides DefaultSecurityGroup=$(call ssm-demo,DEFAULT_SECURITY_GROUP),$(call ssm-demo,LAMBDA_TO_RDS_SECURITY_GROUP)  PrivateSubnets=$(call ssm-demo,PRIVATE_SUBNET_1),$(call ssm-demo,PRIVATE_SUBNET_2),$(call ssm-demo,PRIVATE_SUBNET_3)
	# add more info to facilitate debugging
	# START this is `demo` in Makefile
	# The current TRAVIS_PROFILE is: 
	echo '# The ' $(TRAVIS_PROFILE)
	# The profile we will use for deployment is
	echo '# The '$(TRAVIS_PROFILE_DEMO)
	# We have defined the following variables:
	echo '# The project name:' echo $(PROJECT)
	echo '# The stack name: ' $(STACK_NAME)
	echo '# The Deploy S3 Prefix: ' $(DEPLOY_S3_PREFIX)
	# We will use the following information from the AWS parameter store:
	# - S3_BUCKET_NAME
	echo '# The S3_BUCKET_NAME' $(call ssm-demo,S3_BUCKET_NAME)
	# - LAMBDA_TO_RDS_SECURITY_GROUP
	echo '# The LAMBDA_TO_RDS_SECURITY_GROUP' $(call ssm-demo,LAMBDA_TO_RDS_SECURITY_GROUP)
	# - DEFAULT_SECURITY_GROUP
	echo '# The DEFAULT_SECURITY_GROUP: ' $(call ssm-demo,DEFAULT_SECURITY_GROUP)
	# - PRIVATE_SUBNET_1
	echo '# The PRIVATE_SUBNET_1' $(call ssm-demo,PRIVATE_SUBNET_1)
	# - PRIVATE_SUBNET_2
	echo '# The PRIVATE_SUBNET_2' $(call ssm-demo,PRIVATE_SUBNET_2)
	# - PRIVATE_SUBNET_3
	echo '# The PRIVATE_SUBNET_3' $(call ssm-demo,PRIVATE_SUBNET_3)
	# END this is demo in Makefile

lint:
	cfn-lint template.yaml

clean:
	rm -f push-bin process-bin
