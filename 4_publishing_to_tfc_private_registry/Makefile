## you know what's funny? if all you're doing is assigning variables,
## tfvars files can act as makefiles, which means you can include them
include terraform.tfvars

TOKEN ?= <YOUR_TOKEN_HERE>
ORGANIZATION_NAME ?= <YOUR_ORG_HERE>
HOST := app.terraform.io
PROVIDER_NAME := aws
PROVIDER_VERSION := 4.8.0
GPG_KEY_ID := 5394EE26F51F84D0

mirror:
	host=${HOST} \
	organization_name=${ORGANIZATION_NAME} \
	token=${TOKEN} \
	gpg_key_id=${GPG_KEY_ID} \
	provider_name=${PROVIDER_NAME} \
	provider_version=${PROVIDER_VERSION} \
	./mirror.sh


clean:
	clean=yes \
	host=${HOST} \
	organization_name=${ORGANIZATION_NAME} \
	token=${TOKEN} \
	gpg_key_id=${GPG_KEY_ID} \
	provider_name=${PROVIDER_NAME} \
	provider_version=${PROVIDER_VERSION} \
	./mirror.sh
