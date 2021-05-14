  
terraform {
	backend "s3" {
		bucket = "terraform.dyno.com"
		key    = "terraform.tfstate"
		region = "us-east-1"
		profile = "dyno"
		workspace_key_prefix = "s3sftp"
	}
}

# VARIABLES
variable "USERS" {
  type = string
}

# PROVIDERS
provider "aws" {
	region = "us-east-1"
	profile = "dyno.${terraform.workspace}"
}

data "aws_vpc" "default" {
  default = true
}

data "aws_route53_zone" "dyno" {
  name = "${terraform.workspace}.dynoanalytics.xyz"
}

resource "aws_route53_record" "sftp" {  
  zone_id = data.aws_route53_zone.dyno.zone_id
  name    = "sftp.${terraform.workspace}.dynoanalytics.xyz"
  # type    = "A"  
  # records = [aws_instance.web.public_ip]  
  type    = "CNAME"  
  records = [aws_instance.web.public_dns]  
  ttl     = "300"
}

resource "aws_s3_bucket" "sftp" {
  bucket = "dyno.${terraform.workspace}.sftp.com"
  versioning {
    enabled = true
  }
}

resource "aws_iam_role_policy" "s3fs_policy" {
  name = "S3FS-Policy"
  role = aws_iam_role.s3fs_role.id

  policy = <<-EOF
  {
      "Version": "2012-10-17",
      "Statement": [
          {
              "Effect": "Allow",
              "Action": ["s3:ListBucket"],
              "Resource": [
                  "${aws_s3_bucket.sftp.arn}"
              ]
          },
          {
              "Effect": "Allow",
              "Action": [
                  "s3:PutObject",
                  "s3:GetObject",
                  "s3:DeleteObject"
              ],
              "Resource": [
                  "${aws_s3_bucket.sftp.arn}/*"
              ]
          }
      ]
  }
  EOF
}

resource "aws_iam_role" "s3fs_role" {
  name = "S3FS-Role"

  assume_role_policy = <<-EOF
  {
    "Version": "2012-10-17",
    "Statement": [
      {
        "Action": "sts:AssumeRole",
        "Principal": {
          "Service": "ec2.amazonaws.com"
        },
        "Effect": "Allow",
        "Sid": ""
      }
    ]
  }
  EOF
}

resource "aws_iam_instance_profile" "s3fs_profile" {
  name = "S3FS-Profile"
  role = aws_iam_role.s3fs_role.name
}

resource "aws_security_group" "sg_22" {
  name = "sg_22"
  vpc_id = data.aws_vpc.default.id
  ingress {
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  # tags {
  #   "Environment" = var.environment_tag
  # }
}

resource "aws_key_pair" "ec2key" {
  key_name = "S3FS"
  public_key = file("S3FS.pub")
}

# resource "aws_key_pair" "deployer" {
#   key_name   = "S3FS"
#   public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDIwZTJnQnwXALyA5XrjSWsdgVnCKVK/Bb8Xzu7WYaj+g6lZtmGPpC/wO/KQQD/zZYjchIHBY1FBw1Cue+HJWDx56OvBm2gpve2dnghBPFAWvboTwCgD6ntFVxIITebCDFCwkBl0TsLlbtNS0b2niJ15nJQAiS/sFRSpO/77SHTw+LZH/HUwPA+NaD8MPyWU4klZ00+floq3/pWZlgd9lJJbNcI0BJAoMJZS0h7P+BG7QQ+zAZvF+VGzkLAyOvnMxcZFAXrOJ8cmVoTNlxx7h3SryzH/7+U5j8D589UXfUnNzdagPIcpRxlaRpYewTQftLXGAGsaQHmBcrxhRNkaEZKSEmSRtjqzob6+8RAkyPO8kot+cQBUjUGXUHRh+fbOi/Uw4u/+hVoWX+k/QqVb0p8e2z51X5n9V6+SX5us8H786kD6MWbHuzAqknYhqgFZiM2U1cFbuSNhxTxpOMjM+E0Q4Ne4ifQsxVQ+N5ndsNK5A82EgmPIKyNEZFG6J5Aej8= joseja17@Joses-MacBook-Pro.local"
# }

resource "aws_instance" "web" {
  tags =  {
    name = aws_key_pair.ec2key.key_name
  }
  # ...
  ami = "ami-0323c3dd2da7fb37d"
  instance_type = "t3.micro"
  iam_instance_profile = aws_iam_instance_profile.s3fs_profile.name
  # subnet_id = aws_subnet.subnet_public.id
  vpc_security_group_ids = [aws_security_group.sg_22.id]
  key_name = aws_key_pair.ec2key.key_name

  connection {
    type     = "ssh"
    user     = "ec2-user"
    password = ""
    host = self.public_ip
    private_key = file(aws_key_pair.ec2key.key_name)
  }

  provisioner "file" {
    source      = "setup.sh"
    destination = "/tmp/setup.sh"
  }

  provisioner "file" {
    source      = "sshd_config.txt"
    destination = "/tmp/sshd_config.txt"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/setup.sh",
      "sudo /tmp/setup.sh ${terraform.workspace} us-east-1 \"${var.USERS}\"",
    ]
  }

  provisioner "local-exec" {
    command = "aws --profile dyno.${terraform.workspace} ec2 reboot-instances --instance-ids ${self.id}"
  }

}

output "public_ip" {
  value = aws_instance.web.public_ip
}