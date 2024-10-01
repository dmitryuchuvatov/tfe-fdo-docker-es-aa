# Networking
resource "aws_vpc" "vpc" {
  cidr_block       = var.vpc_cidr
  instance_tenancy = "default"

  tags = {
    Name = "${var.environment_name}-vpc"
  }
}

resource "aws_subnet" "public" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, 1)
  availability_zone = "${var.aws_region}a"

  tags = {
    Name = "${var.environment_name}-public-subnet"
  }
}

resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, 11)
  availability_zone = "${var.aws_region}c"

  tags = {
    Name = "${var.environment_name}-private-subnet"
  }
}

resource "aws_subnet" "private2" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, 12)
  availability_zone = "${var.aws_region}b"

  tags = {
    Name = "${var.environment_name}-private-subnet2"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = "${var.environment_name}-igw"
  }
}

resource "aws_route_table" "route" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "${var.environment_name}-rt"
  }
}

resource "aws_route_table_association" "route_association" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.route.id
}

resource "aws_security_group" "sg" {

  vpc_id = aws_vpc.vpc.id

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "PostgreSQL"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  ingress {
    description = "Redis"
    from_port   = 6379
    to_port     = 6379
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  ingress {
    description = "Vault"
    from_port   = 8201
    to_port     = 8201
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    description = "Egress - All"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    type = "${var.environment_name}-security-group"
  }
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nateip.id
  subnet_id     = aws_subnet.public.id

  tags = {
    Name = "${var.environment_name}-nat-gateway"
  }

  depends_on = [aws_internet_gateway.igw]
}

resource "aws_route_table" "routenat" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }

  tags = {
    Name = "${var.environment_name}-rt-nat"
  }
}

resource "aws_route_table_association" "routenat_association" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.routenat.id
}

resource "aws_route_table_association" "routenat_association2" {
  subnet_id      = aws_subnet.private2.id
  route_table_id = aws_route_table.routenat.id
}

resource "aws_network_interface" "nic" {
  subnet_id       = aws_subnet.public.id
  security_groups = [aws_security_group.sg.id]
}

resource "aws_eip" "eip" {
  domain                    = "vpc"
  associate_with_private_ip = aws_network_interface.nic.private_ip
  instance                  = aws_instance.bastion.id

  tags = {
    Name = "${var.environment_name}-eip"
  }
}

resource "aws_eip" "nateip" {
  domain                    = "vpc"
  associate_with_private_ip = aws_network_interface.nic.private_ip

  tags = {
    Name = "${var.environment_name}-eip-nat"
  }
}

# AMI
data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

# Bastion/Jump host
resource "aws_instance" "bastion" {
  ami                  = data.aws_ami.ubuntu.image_id
  instance_type        = "t2.micro"
  iam_instance_profile = aws_iam_instance_profile.profile.name
  key_name             = var.key_pair

  root_block_device {
    volume_size = 10
  }

  network_interface {
    network_interface_id = aws_network_interface.nic.id
    device_index         = 0
  }

  user_data = base64encode(templatefile("${path.module}/scripts/tfe_client.yaml", {
    certs_bucket = aws_s3_bucket.files.id
    pem_file     = var.pem_file
  }))

  tags = {
    Name = "${var.environment_name}-bastion"
  }
}

# IAM
resource "aws_iam_role" "role" {
  name = "${var.environment_name}-role-docker"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_iam_instance_profile" "profile" {
  name = "${var.environment_name}-profile-docker"
  role = aws_iam_role.role.name
}

resource "aws_iam_role_policy" "policy" {
  name = "${var.environment_name}-policy-docker"
  role = aws_iam_role.role.id

  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : "s3:ListBucket",
        "Resource" : "*"
      },
      {
        "Effect" : "Allow",
        "Action" : [
          "s3:PutObject",
          "s3:GetObject",
          "s3:DeleteObject"
        ],
        "Resource" : [
          "arn:aws:s3:::*/*"
        ]
      }
    ]
  })
}

# DNS
data "aws_route53_zone" "zone" {
  name         = var.tfe_domain
  private_zone = false
}

resource "aws_route53_record" "lb" {
  zone_id = data.aws_route53_zone.zone.zone_id
  name    = "${var.tfe_subdomain}.${var.tfe_domain}"
  type    = "CNAME"
  ttl     = "300"
  records = [aws_lb.tfe_lb.dns_name]
}

# Certificates
resource "tls_private_key" "private_key" {
  algorithm = "RSA"
}

resource "acme_registration" "reg" {
  account_key_pem = tls_private_key.private_key.private_key_pem
  email_address   = var.email
}

resource "acme_certificate" "certificate" {
  account_key_pem              = acme_registration.reg.account_key_pem
  common_name                  = "${var.tfe_subdomain}.${var.tfe_domain}"
  disable_complete_propagation = true

  dns_challenge {
    provider = "route53"

    config = {
      AWS_HOSTED_ZONE_ID = data.aws_route53_zone.zone.zone_id
    }
  }
}

# PostgreSQL database (RDS)
resource "aws_db_subnet_group" "db_subnet_group" {
  name       = "${var.environment_name}-db-subnetgroup"
  subnet_ids = [aws_subnet.public.id, aws_subnet.private.id]

  tags = {
    Name = "${var.environment_name}-db-subnet-group"
  }
}

resource "aws_db_instance" "tfe_db" {
  allocated_storage      = 50
  identifier             = var.db_identifier
  db_name                = var.db_name
  engine                 = "postgres"
  engine_version         = "14.9"
  instance_class         = "db.m5.xlarge"
  username               = var.db_username
  password               = var.db_password
  parameter_group_name   = "default.postgres14"
  skip_final_snapshot    = true
  db_subnet_group_name   = aws_db_subnet_group.db_subnet_group.name
  vpc_security_group_ids = [aws_security_group.sg.id]
}

# Object storage (S3 bucket) for TFE
resource "aws_s3_bucket" "data" {
  bucket        = "${var.environment_name}-bucket"
  force_destroy = true

  tags = {
    Name = "${var.environment_name}-bucket"
  }
}

# Object storage (S3 bucket) for Bastion
resource "aws_s3_bucket" "files" {
  bucket = "${var.environment_name}-files"
}

resource "aws_s3_object" "object_pem" {
  bucket = aws_s3_bucket.files.bucket
  key    = var.pem_file
  source = var.pem_file
}

# Redis cache
resource "aws_elasticache_subnet_group" "redis_subnet_group" {
  name       = "${var.environment_name}-redis-subnetgroup"
  subnet_ids = [aws_subnet.private.id, aws_subnet.private2.id]
}

resource "aws_elasticache_cluster" "tfe_redis" {
  cluster_id           = "${var.environment_name}-redis"
  engine               = "redis"
  node_type            = "cache.t3.small"
  num_cache_nodes      = 1
  parameter_group_name = "default.redis7"
  engine_version       = "7.1"
  port                 = 6379
  security_group_ids   = [aws_security_group.sg.id]
  subnet_group_name    = aws_elasticache_subnet_group.redis_subnet_group.name
}

# Application Load Balancer
resource "aws_lb" "tfe_lb" {
  name               = "${var.environment_name}-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.sg.id]
  subnets            = [aws_subnet.public.id, aws_subnet.private.id]

  enable_deletion_protection = false

  tags = {
    Environment = "${var.environment_name}-lb"
  }
}

resource "aws_lb_target_group" "tfe_lbtarget" {
  name     = "${var.environment_name}-lb-targetgroup"
  port     = 443
  protocol = "HTTPS"
  vpc_id   = aws_vpc.vpc.id
}

resource "aws_lb_listener" "tfe_front_end" {
  load_balancer_arn = aws_lb.tfe_lb.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = aws_acm_certificate.lbcert.arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tfe_lbtarget.arn
  }
}

resource "aws_acm_certificate" "lbcert" {
  private_key       = acme_certificate.certificate.private_key_pem
  certificate_body  = acme_certificate.certificate.certificate_pem
  certificate_chain = acme_certificate.certificate.issuer_pem

  tags = {
    Environment = "${var.environment_name}-acm-cert"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Launch Template
resource "aws_launch_template" "tfe_launchtemp" {
  name_prefix   = "${var.environment_name}-launch-template"
  image_id      = data.aws_ami.ubuntu.image_id
  instance_type = var.instance_type
  key_name      = var.key_pair

  iam_instance_profile {
    name = aws_iam_instance_profile.profile.name
  }

  credit_specification {
    cpu_credits = "unlimited"
  }

  block_device_mappings {
    device_name = "/dev/sda1"

    ebs {
      delete_on_termination = true
      volume_size           = 50
    }
  }

  network_interfaces {
    security_groups = [aws_security_group.sg.id]
    subnet_id       = aws_subnet.private.id
  }

  user_data = base64encode(templatefile("${path.module}/scripts/tfe_server.yaml", {
    tfe_version     = var.tfe_version
    tfe_hostname    = "${var.tfe_subdomain}.${var.tfe_domain}"
    email           = var.email
    db_username     = var.db_username
    db_password     = var.db_password
    db_host         = aws_db_instance.tfe_db.endpoint
    db_name         = var.db_name
    storage_bucket  = aws_s3_bucket.data.id
    aws_region      = var.aws_region
    redis_host      = lookup(aws_elasticache_cluster.tfe_redis.cache_nodes[0], "address", "Redis address not found")
    full_chain      = base64encode("${acme_certificate.certificate.certificate_pem}${acme_certificate.certificate.issuer_pem}")
    private_key_pem = base64encode("${acme_certificate.certificate.private_key_pem}")
    tfe_license     = var.tfe_license
    enc_password    = var.enc_password
  }))

  tags = {
    Name = "${var.environment_name}-tfe"
  }
}

# Auto Scaling Group
resource "aws_autoscaling_group" "tfe_asg" {
  desired_capacity       = 2
  max_size               = 2
  min_size               = 1
  vpc_zone_identifier    = [aws_subnet.private.id]
  target_group_arns      = [aws_lb_target_group.tfe_lbtarget.arn]
  force_delete           = true
  force_delete_warm_pool = true

  launch_template {
    id      = aws_launch_template.tfe_launchtemp.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "${var.environment_name}-tfe-asg"
    propagate_at_launch = true
  }

  depends_on = [aws_nat_gateway.nat]
}