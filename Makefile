.PHONY: help deploy destroy init plan apply

help:
	@echo "stayhub-infra Commands:"
	@echo "  make deploy   Run full deploy script (ECR + images + Terraform + S3 + CloudFront)"
	@echo "  make destroy  Run full teardown script (empty S3 + terraform destroy)"
	@echo "  make init     Initialize OpenTofu/Terraform"
	@echo "  make plan     Generate execution plan"
	@echo "  make apply    Apply infrastructure changes"

deploy:
	./deploy.sh

destroy:
	./destroy.sh

init:
	$$(command -v tofu || command -v terraform) init

plan:
	$$(command -v tofu || command -v terraform) plan

apply:
	$$(command -v tofu || command -v terraform) apply -auto-approve
