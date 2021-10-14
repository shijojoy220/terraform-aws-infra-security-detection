
# Declare the data source
data "aws_availability_zones" "available" {
  state = "available"
}
# get public ip - Optional
data "http" "myip" {
  url = "http://ipv4.icanhazip.com"
}

##############################
# VPC Creation
##############################

resource "aws_vpc" "vpc" {
  cidr_block           = var.vpc_cidr
  instance_tenancy     = "default"
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = {
    Name        = "${var.project}-vpc"
    project     = var.project,
    environment = var.project_env
  }
}

###############################
# Internet Gateway
###############################

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name        = "${var.project}-igw"
    project     = var.project,
    environment = var.project_env
  }
}

##############################
# Subnet Public 1
##############################

resource "aws_subnet" "public1" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 3, 0)
  map_public_ip_on_launch = true
  availability_zone       = data.aws_availability_zones.available.names[0]

  tags = {
    Name        = "${var.project}-public1"
    project     = var.project,
    environment = var.project_env
  }
}

##############################
# Subnet Public 2
##############################

resource "aws_subnet" "public2" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 3, 1)
  map_public_ip_on_launch = true
  availability_zone       = data.aws_availability_zones.available.names[1]

  tags = {
    Name        = "${var.project}-public2"
    project     = var.project,
    environment = var.project_env
  }
}

##############################
# Subnet Public 3
##############################

resource "aws_subnet" "public3" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 3, 2)
  map_public_ip_on_launch = true
  availability_zone       = data.aws_availability_zones.available.names[2]

  tags = {
    Name        = "${var.project}-public3"
    project     = var.project,
    environment = var.project_env
  }
}


#################################
# Route Table for public network
#################################
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
  tags = {
    Name        = "${var.project}-public"
    project     = var.project,
    environment = var.project_env
  }
}

##################################
# Rout table association public 1
##################################

resource "aws_route_table_association" "public1" {
  subnet_id      = aws_subnet.public1.id
  route_table_id = aws_route_table.public.id
}

##################################
# Rout table association public 2
##################################

resource "aws_route_table_association" "public2" {
  subnet_id      = aws_subnet.public2.id
  route_table_id = aws_route_table.public.id
}

##################################
# Rout table association public 3
##################################

resource "aws_route_table_association" "public3" {
  subnet_id      = aws_subnet.public3.id
  route_table_id = aws_route_table.public.id
}

##################################
# Create Securty group
##################################

resource "aws_security_group" "sg" {
  name        = "${var.project}-vm-sg"
  description = var.desc
  vpc_id      = aws_vpc.vpc.id

  ingress {
    description = "TLS from VPC"
    from_port   = var.port
    to_port     = var.port
    protocol    = "tcp"
    cidr_blocks = ["${chomp(data.http.myip.body)}/32"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project}-vm-sg",
    project     = var.project,
    environment = var.project_env
  }
}

##################################
# Create key pair
##################################

resource "aws_key_pair" "app" {
  key_name   = "${var.project}-vm-key"
  public_key = var.public_key
  tags = {
    project     = var.project,
    environment = var.project_env
  }
}

##################################
# Create VM
##################################

resource "aws_instance" "app" {
  ami                    = var.ami
  instance_type          = var.instance_type
  count                  = 1
  vpc_security_group_ids = [aws_security_group.sg.id]
  subnet_id              = aws_subnet.public1.id
  key_name               = aws_key_pair.app.key_name
  monitoring             = "true"

  root_block_device {
    volume_type = "gp2"
    volume_size = var.vm_volume_size
  }

  tags = {
    Name        = "${var.project}-vm",
    project     = var.project,
    environment = var.project_env
  }

}

##################################
# S3 Bucket
##################################

resource "aws_s3_bucket" "bucket" {
  bucket              = "${var.project}-${var.project_env}-logs-21-bucket"
  acl                 = "private"

  tags = {
    project     = var.project,
    environment = var.project_env
  }
}

resource "aws_s3_bucket_public_access_block" "example" {
  bucket = aws_s3_bucket.bucket.id

  block_public_acls   = true
  block_public_policy = true
  ignore_public_acls  = true
  restrict_public_buckets = true
}

##################################
# Lambda
##################################

# Create inline policy
resource "aws_iam_role" "iam_for_lambda" {
  name = "${var.project}-function-role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

# Create s3 access policy

resource "aws_iam_policy" "policy" {
  name        = "${var.project}-lambda-s3-putobject-policy"
  description = "policy for access s3 bucket from lambda"

  policy = <<EOT
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "ExampleStmt",
      "Action": [
        "s3:PutObject"
      ],
      "Effect": "Allow",
      "Resource": [
        "${aws_s3_bucket.bucket.arn}/*"
      ]
    }
  ]
}
EOT
}

# Attach iam policy to role 

resource "aws_iam_role_policy_attachment" "attachment" {
  role       = aws_iam_role.iam_for_lambda.name
  policy_arn = aws_iam_policy.policy.arn
}


# create function
resource "aws_lambda_function" "test_lambda" {
  filename      = "lambda_function_payload.zip"
  function_name = "${var.project}-state-change-detect"
  role          = aws_iam_role.iam_for_lambda.arn
  handler       = "lambda_function.lambda_handler"

  source_code_hash = filebase64sha256("lambda_function_payload.zip")

  runtime = "python3.7"

  environment {
    variables = {
      BUCKET_REGION = var.region
      BUCKET_NAME   = "${var.project}-${var.project_env}-logs-21-bucket"
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.lambda_logs,
    aws_cloudwatch_log_group.example,
  ]
}

# Create log group and attch access

resource "aws_cloudwatch_log_group" "example" {
  name              = "/aws/lambda/${var.project}-state-change-detect"
  retention_in_days = 14
}

resource "aws_iam_policy" "lambda_logging" {
  name        = "lambda_logging"
  path        = "/"
  description = "IAM policy for logging from a lambda"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "arn:aws:logs:${var.region}:*:*",
      "Effect": "Allow"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.iam_for_lambda.name
  policy_arn = aws_iam_policy.lambda_logging.arn
}

# cloudwatch events

resource "aws_cloudwatch_event_rule" "console" {
  name        = "${var.project}-ec2-status-events"
  description = "Capture all EC2 Status events"

  event_pattern = <<PATTERN
{
  "source": [
    "aws.ec2"
  ],
  "detail-type": [
    "EC2 Instance State-change Notification"
  ],
  "detail": {
    "state": [
      "running",
      "stopping"
    ]
  }
}
PATTERN
}

resource "aws_cloudwatch_event_target" "example" {
  arn  = aws_lambda_function.test_lambda.arn
  rule = aws_cloudwatch_event_rule.console.id
}

