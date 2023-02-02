default: init plan
clean-all: destroy clean

init:
	terraform init -upgrade

plan:
	terraform plan

apply:
	terraform apply -auto-approve

destroy:
	terraform destroy -auto-approve
	terraform.tfstate terraform.tfstate.backup

clean:
	rm -rf .terraform .terraform.lock.hcl 