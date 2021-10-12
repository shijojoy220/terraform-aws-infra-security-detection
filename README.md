# terraform-aws-infra-security-detection-pvt

### Basic Usage

```bash
terraform init
terraform validate
terraform apply
```
### Advanced Usage

### Initialize and Validate Infrastructure:
```bash
terraform init
terraform validate
```
### Create Infrastructure:
```bash
terraform plan --out tfapply
terraform apply --auto-approve tfapply
```
### Destroy Infrastructure:
```bash
terraform plan --destroy --out tfdestroy
terraform apply --auto-approve tfdestroy