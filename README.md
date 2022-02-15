# S3 SFTP

## Installation

### Adding a new user
1. Add the user to the environment variable `TF_VAR_USERS` in `doppler` with this pattern `TF_VAR_USERS=user:pass;`
2. Taint and apply the instance in the correct terraform workspace (most likely `alder`, to do this `terraform workspace select alder`): `terraform taint aws_instance.web && doppler run terraform apply`
3. Sit back and wait for it to complete
