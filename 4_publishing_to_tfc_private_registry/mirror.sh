#!/bin/bash
set -e

function usage() {
  echo "
  
  $0 usage:
    host=app.terraform.io \\
    organization_name=<org> \\
    token=<token> \\
    gpg_key_id=<key_id> \\
    provider_name=random \\
    provider_version=3.1.0 \\
    $0
    
  to delete instead:
    clean=yes \\
    host=app.terraform.io \\
    organization_name=<org> \\
    token=<token> \\
    gpg_key_id=<key_id> \\
    provider_name=random \\
    provider_version=3.1.0 \\
    $0
  "
}

function main() {

  local clean=${clean:-no}

  [[ -z "$token" ]] && echo "Please set token to a valid Terraform Cloud/Enterprise API token (try something like: cat ~/.terraform.d/credentials.tfrc.json | jq -r '.credentials.\"app.terraform.io\".token')" && usage && exit 1
  [[ -z "$host" ]] && echo "Please set host to the hostname of your Terraform Enterprise instance (set to 'app.terraform.io' if using Terraform Cloud)" && usage && exit 1
  [[ -z "$organization_name" ]] && echo "Please set organization_name to the Terraform Cloud/Enterprise organization name (ex: example-org-abcdef)" && usage && exit 1
  [[ -z "$provider_name" ]] && echo "Please set provider_name to the name of the provider (ex: random)" && usage && exit 1
  [[ -z "$provider_version" ]] && echo "Please set provider_version to the version of the provider (ex: 1.0.0)" && usage && exit 1
  [[ -z "$gpg_key_id" ]] && echo "Please set gpg_key_id (ex: 0123456789ABCDEF" && usage && exit 1

  ## check that jq is installed
  if ! command -v jq &> /dev/null
  then
    echo "error: jq is required by this script and could not be found. Please install jq and try again."
    exit 1
  fi

  # 
  if [[ $clean == "yes" ]]; then
    echo "cleaning up..."
    delete
  else
    echo "mirroring provider ${provider_name} ${provider_version} as ${host}/${organization_name}/${provider_name}..."
    create
  fi

}

function create() {
  
  provider_download_dir="providers/${provider_name}/${provider_version}"
  provider_shasums_file="${provider_download_dir}/terraform-provider-${provider_name}_${provider_version}_SHA256SUMS"
  provider_shasums_file_sig="${provider_download_dir}/terraform-provider-${provider_name}_${provider_version}_SHA256SUMS.sig"

  os="darwin" arch="amd64" download_public_provider
	os="darwin" arch="arm64" download_public_provider
	os="linux" arch="amd64" download_public_provider
	os="windows" arch="amd64" download_public_provider

  ## Sign the shasums file we just downloaded with our own GPG key
  echo -n "Re-signing the shasums file we just downloaded with our own GPG key, creating $(basename "${provider_shasums_file_sig}")"
  gpg \
    --detach-sign \
    --default-key "${gpg_key_id}" \
    --output "${provider_shasums_file_sig}" \
    "${provider_shasums_file}"

  # Verify the new signature
  echo "verifying GPG signature..."
  gpg \
    --verify "${provider_shasums_file_sig}" \
    "${provider_shasums_file}"

  # create and upload the necessary objects into the private registry
  create_gpg_key_id

  create_provider
  create_provider_version

  os="darwin" arch="amd64" create_provider_version_platform
	os="darwin" arch="arm64" create_provider_version_platform
	os="linux" arch="amd64" create_provider_version_platform
	os="windows" arch="amd64" create_provider_version_platform

  # upload the provider zip files
	os="darwin" arch="amd64" upload_provider_version_platform_zip
	os="darwin" arch="arm64" upload_provider_version_platform_zip
	os="linux" arch="amd64" upload_provider_version_platform_zip
	os="windows" arch="amd64" upload_provider_version_platform_zip
}

function delete() {

  os="darwin" arch="amd64" delete_provider_version_platform
	os="darwin" arch="arm64" delete_provider_version_platform
	os="linux" arch="amd64" delete_provider_version_platform
	os="windows" arch="amd64" delete_provider_version_platform

  delete_provider_version
  delete_provider

  delete_gpg_key_id

  rm -rf ./providers/
}

### utility functions ###

function create_gpg_key_id() {

  echo; echo "Creating GPG public key object in TFE/C for GPG key ${gpg_key_id}..."

  # local gpg_public_key_file="keys/gpg-${gpg_key_id}.pub"
  # mkdir -p keys/

  # gpg --armor --export "${gpg_key_id}" > "${gpg_public_key_file}"
  gpg_public_key_contents=$(gpg --armor --export "${gpg_key_id}" | awk '{printf "%s\\n", $0}')
	# gpg_public_key_contents=$(awk '{printf "%s\\n", $0}' "${gpg_public_key_file}")

	# Create GPG key, output its key-id
	(
	curl -s -X POST --location "https://${host}/api/registry/private/v2/gpg-keys" \
		-H "Authorization: Bearer ${token}" \
		-H "Content-Type: application/vnd.api+json" \
		-d@- <<EOF
{
  "data": {
    "type": "gpg-keys",
    "attributes": {
      "namespace": "${organization_name}",
      "ascii-armor": "${gpg_public_key_contents}"
    }
  }
}
EOF
	) | jq '.data.attributes."key-id"'

}

function create_provider_version_platform() {

  echo; echo "Creating provider_version_platform object in TFE/C: ${provider_name} ${provider_version} ${os:?} ${arch:?}..."

  # in bash, ${var:?} checks if var is set, if not, it exits with an error
  local -r provider_zip_file="${provider_download_dir}/terraform-provider-${provider_name}_${provider_version}_${os}_${arch}.zip"
  local -r provider_zip_file_name=$(basename "${provider_zip_file}")
  local -r zip_shasum=$(shasum -a 256 "${provider_zip_file}" | head -c 64)

	curl -s \
		-H "Authorization: Bearer ${token}" \
		-H "Content-Type: application/vnd.api+json" \
    -X POST \
    --location "https://${host}/api/v2/organizations/${organization_name}/registry-providers/private/${organization_name}/${provider_name}/versions/${provider_version}/platforms" \
		-d@- <<EOF
{
  "data": {
    "type": "registry-provider-version-platforms",
    "attributes": {          
      "os": "${os}",
      "arch": "${arch}",
      "shasum": "${zip_shasum}",
      "filename": "${provider_zip_file_name}"
    }
  }
}
EOF

}

function create_provider_version() {

  echo; echo "Creating provider_version object in TFE/C: ${provider_name} ${provider_version}..."

  ## create the object in TFE/C

	curl -s \
		-H "Authorization: Bearer ${token}" \
		-H "Content-Type: application/vnd.api+json" \
    -X POST \
    --location "https://${host}/api/v2/organizations/${organization_name}/registry-providers/private/${organization_name}/${provider_name}/versions" \
		-d@- <<EOF
{
  "data": {
    "type": "registry-provider-versions",
    "attributes": {
      "version": "${provider_version}",
      "key-id": "${gpg_key_id}"
    }
  }
}
EOF

  ## upload the validation files to the provider version in TFE/C

  # Read the provider version to get upload urls (that include a token)
	response=$(curl -s -X GET --location "https://${host}/api/v2/organizations/${organization_name}/registry-providers/private/${organization_name}/${provider_name}/versions/${provider_version}" \
		-H "Authorization: Bearer ${token}" \
		-H "Content-Type: application/vnd.api+json")

	shasum=$(echo "$response" | jq -r '.data.links."shasums-upload"')
	shasum_sig=$(echo "$response" | jq -r '.data.links."shasums-sig-upload"')

  # Upload the shasums and shasums.sig files
	curl -T "${provider_shasums_file}" "${shasum}"
	curl -T "${provider_shasums_file_sig}" "${shasum_sig}"

}

function create_provider() {

  echo; echo "Creating provider object in TFE/C: ${provider_name}..."

	curl -s \
		-H "Authorization: Bearer ${token}" \
		-H "Content-Type: application/vnd.api+json" \
    -X POST \
    --location "https://${host}/api/v2/organizations/${organization_name}/registry-providers" \
		-d@- <<EOF
{
  "data": {
    "type": "registry-providers",
    "attributes": {
      "registry-name": "private",
      "namespace": "${organization_name}",
      "name": "${provider_name}"
    }
  }
}
EOF

}

function delete_gpg_key_id() {

  echo; echo "Deleting gpg key object from TFE/C: ${gpg_key_id}..."
	curl -s \
    -H "Authorization: Bearer ${token}" \
    -H "Content-Type: application/vnd.api+json" \
    -X DELETE \
    --location "https://${host}/api/registry/private/v2/gpg-keys/${organization_name}/${gpg_key_id}"
}

function delete_provider_version_platform() {

  echo; echo "Deleting provider_version_platform object from TFE/C: ${provider_name:?} ${provider_version:?} ${os:?} ${arch:?}..."
	curl -s \
    -H "Authorization: Bearer ${token}" \
    -X DELETE \
    --location "https://${host}/api/v2/organizations/${organization_name}/registry-providers/private/${organization_name}/${provider_name}/versions/${provider_version}/platforms/${os}/${arch}"
}

function delete_provider_version() {

  echo; echo "Deleting provider_version object from TFE/C: ${provider_name} ${provider_version}..."
	curl -s \
    -H "Authorization: Bearer ${token}" \
		-H "Content-Type: application/vnd.api+json" \
    -X DELETE \
    --location "https://${host}/api/v2/organizations/${organization_name}/registry-providers/private/${organization_name}/${provider_name}/versions/${provider_version}"
}

function delete_provider() {

  echo; echo "Deleting provider object from TFE/C: ${provider_name}..."
	curl -s \
  -H "Authorization: Bearer ${token}" \
  -H "Content-Type: application/vnd.api+json" \
  -X DELETE \
  --location "https://${host}/api/v2/organizations/${organization_name}/registry-providers/private/${organization_name}/${provider_name}"
	
}

function download_public_provider() {

  local -r provider_zip_file="${provider_download_dir:?}/terraform-provider-${provider_name:?}_${provider_version:?}_${os:?}_${arch:?}.zip"

  echo; echo "Downloading public provider to ${provider_download_dir}: ${provider_name} ${provider_version} ${os} ${arch}..."

	# create folder
	mkdir -p "${provider_download_dir}"

	## example: https://releases.hashicorp.com/terraform-provider-random/3.1.0/terraform-provider-random_3.1.0_linux_amd64.zip
	curl -s -X GET \
		-o "${provider_zip_file:?}" \
		--location "https://releases.hashicorp.com/terraform-provider-${provider_name}/${provider_version}/terraform-provider-${provider_name}_${provider_version}_${os}_${arch}.zip"

	## example: https://releases.hashicorp.com/terraform-provider-random/3.1.0/terraform-provider-random_3.1.0_SHA256SUMS
	curl -s -X GET \
		-o "${provider_shasums_file:?}" \
		--location "https://releases.hashicorp.com/terraform-provider-${provider_name}/${provider_version}/terraform-provider-${provider_name}_${provider_version}_SHA256SUMS"

	## example: https://releases.hashicorp.com/terraform-provider-random/3.1.0/terraform-provider-random_3.1.0_SHA256SUMS.sig
	## normally you'd also need this file, but we're not going to download it because we're going to sign the shasums file ourselves with our own GPG key
  # curl -s -X GET \
	# 	-o "${provider_shasums_file_sig}" \
	# 	--location "https://releases.hashicorp.com/terraform-provider-${provider_name}/${provider_version}/terraform-provider-${provider_name}_${provider_version}_SHA256SUMS.sig"

}

## might not need this
function list_gpg_key_ids() {

	curl -s -X GET --location "https://${host}/api/registry/private/v2/gpg-keys?filter%5Bnamespace%5D=${organization_name}" \
		-H "Authorization: Bearer ${token}" | jq '.data[] | .attributes."key-id"'
}

function upload_provider_version_platform_zip() {

  echo; echo "Uploading files for public provider ${provider_name:?} ${provider_version:?} to TFE/C private registry as ${host}/${organization_name}/${provider_name}: ${provider_name} ${provider_version} ${os:?} ${arch:?}..."

  local -r provider_zip_file="${provider_download_dir}/terraform-provider-${provider_name}_${provider_version}_${os:?}_${arch:?}.zip"

	binary_url=$(curl -s -X GET --location "https://${host}/api/v2/organizations/${organization_name}/registry-providers/private/${organization_name}/${provider_name}/versions/${provider_version}/platforms/${os}/${arch}" \
		-H "Authorization: Bearer ${token}" \
		-H "Content-Type: application/vnd.api+json" | jq -r '.data.links."provider-binary-upload"')

	curl -T "${provider_zip_file}" "${binary_url}"

}

function upload_provider_version_shasums() {

  echo; echo "Uploading shasums to TFE/C for ${host}/${organization_name}/${provider_name}} ${provider_version}..."

	# Read the provider version to get upload urls (that include a token)
	response=$(curl -s -X GET --location "https://${host}/api/v2/organizations/${organization_name}/registry-providers/private/${organization_name}/${provider_name}/versions/${provider_version}" \
		-H "Authorization: Bearer ${token}" \
		-H "Content-Type: application/vnd.api+json")

	shasum=$(echo "$response" | jq -r '.data.links."shasums-upload"')
	shasum_sig=$(echo "$response" | jq -r '.data.links."shasums-sig-upload"')

	curl -T "${provider_shasums_file}" "${shasum}"
	curl -T "${provider_shasums_file_sig}" "${shasum_sig}"

}

main