resource "aws_vpc" "Chisom" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name        = "dev-Chisom-vpc"
    Environment = "Dev"
    Project     = "Chisom-aws"
  }

}


resource "aws_subnet" "public_1" {
  vpc_id                  = aws_vpc.Chisom.id
  cidr_block              = var.public_subnet_1_cidr
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

  tags = {
    Name = "public-subnet-1"
  }
}

resource "aws_subnet" "public_2" {
  vpc_id                  = aws_vpc.Chisom.id
  cidr_block              = var.public_subnet_2_cidr
  availability_zone       = data.aws_availability_zones.available.names[1]
  map_public_ip_on_launch = true

  tags = {
    Name = "public-subnet-2"
  }
}

resource "aws_subnet" "private_1" {
  vpc_id            = aws_vpc.Chisom.id
  cidr_block        = var.private_subnet_1_cidr
  availability_zone = data.aws_availability_zones.available.names[0]

  tags = {
    Name = "private_1"
  }
}

resource "aws_subnet" "private_2" {
  vpc_id            = aws_vpc.Chisom.id
  cidr_block        = var.private_subnet_2_cidr
  availability_zone = data.aws_availability_zones.available.names[1]

  tags = {
    Name = "private_2"
  }
}


resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.Chisom.id

  tags = {
    Name = "Chisom-igw"
  }
}


resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.Chisom.id

  tags = {
    Name = "public-route-table"
  }
}


resource "aws_route" "public_internet_access" {
  route_table_id = aws_route_table.public_rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id = aws_internet_gateway.igw.id
}

resource "aws_route_table_association" "public_1_assoc" {
  subnet_id = aws_subnet.public_1.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "public_2_assoc" {
  subnet_id = aws_subnet.public_2.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_eip" "nat_eip" {
  domain = "vpc"

  tags = {
    Name = "nat-eip"
  }
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id = aws_subnet.public_1.id

  tags = {
    Name = "Chisom-nat-gateway"
  }
}


resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.Chisom.id

  tags = {
    Name = "private-route-table"
  }
}

resource "aws_route" "private_nat_access" {
  route_table_id = aws_route_table.private_rt.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id = aws_nat_gateway.nat.id
}

resource "aws_route_table_association" "private_1_assoc" {
  subnet_id = aws_subnet.private_1.id
  route_table_id = aws_route_table.private_rt.id
}

resource "aws_route_table_association" "private_2_assoc" {
  subnet_id = aws_subnet.private_2.id
  route_table_id = aws_route_table.private_rt.id
}


resource "aws_security_group" "alb_sg" {
  name = "alb-security-group"
  description = "Allow HTTP traffic"
  vpc_id = aws_vpc.Chisom.id

  ingress {
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "alb_sg"
  }
}


resource "aws_security_group" "ec2_sg" {
  name = "ec2-security-group"
  vpc_id = aws_vpc.Chisom.id

  ingress {
    from_port = 80
    to_port = 80
    protocol = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
    tags = {
      Name = "ec2_sg"
  }
}


resource "aws_lb_target_group" "web_tg" {
  name = "web-target-group"
  port = 80
  protocol = "HTTP"
  vpc_id = aws_vpc.Chisom.id

  health_check {
    path = "/"
    protocol = "HTTP"
  }
}

resource "aws_alb_listener" "http_listener" {
  load_balancer_arn = aws_alb.web_alb.arn
  port = 80
  protocol = "HTTP"

  default_action {
    type = "forward"
    target_group_arn = aws_lb_target_group.web_tg.arn
  }
}


resource "aws_alb" "web_alb" {
  name = "chisom-alb"
  internal = false
  load_balancer_type = "application"
  security_groups = [aws_security_group.alb_sg.id]

  subnets = [
    aws_subnet.public_1.id,
    aws_subnet.public_2.id
  ]

  access_logs {
    bucket = aws_s3_bucket.alb_logs.id
    prefix = "alb-logs"
    enabled = true
  }

  tags = {
    Name = "Chisom-alb"
  }
}


resource "aws_launch_template" "web_template" {
  name_prefix = "web-template"
  image_id = data.aws_ami.amazon_linux.id
  instance_type = "t3.micro"

  iam_instance_profile {
    name = aws_iam_instance_profile.ssm_profile.name
  }

  vpc_security_group_ids = [ aws_security_group.ec2_sg.id ]

  user_data = base64encode(file("user-data.sh"))

tag_specifications {
  resource_type = "instance"

  tags = {
    Name = "Chisom-aws" 

  }
 }
}


resource "aws_autoscaling_group" "web_asg" {
  
  min_size = 2
  desired_capacity = 2
  max_size = 6

  vpc_zone_identifier = [ 
    aws_subnet.private_1.id,
    aws_subnet.private_2.id
   ]

   target_group_arns = [aws_lb_target_group.web_tg.arn]

   launch_template {
     id = aws_launch_template.web_template.id
     version = "$Latest"
   }

   tag {
     key = "Chisom-web-tg"
     value = "Chisom-asg-instance"
     propagate_at_launch = true
   }
}

resource "aws_s3_bucket" "alb_logs" {
  bucket = "chisom-aws-alb-access-logs-2k26"

  tags = {
    Name = "alb-access-logs"
  }
}

resource "aws_s3_bucket_ownership_controls" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id

  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_acl" "alb_logs_acl" {
  depends_on = [aws_s3_bucket_ownership_controls.alb_logs]

  bucket = aws_s3_bucket.alb_logs.id
  acl    = "private"
}


resource "aws_s3_bucket_policy" "alb_logging_policy" {
  bucket = aws_s3_bucket.alb_logs.id

  policy = data.aws_iam_policy_document.alb_log_policy.json
}


resource "aws_autoscaling_policy" "cpu_scaling" {
  name                   = "cpu-target-tracking"
  autoscaling_group_name = aws_autoscaling_group.web_asg.name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }

    target_value = 60.0
  }
}

resource "aws_iam_role" "ssm_role" {
  name = "ec2-ssm-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}


resource "aws_iam_role_policy_attachment" "ssm_policy" {
  role = aws_iam_role.ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ssm_profile" {
  name = "ec2-ssm-profile"
  role = aws_iam_role.ssm_role.name
}


resource "aws_wafv2_web_acl" "web_acl" {
  name  = "chisom-web-acl"
  scope = "REGIONAL"

  default_action {
    allow {}
  }

  rule {
    name     = "AWSManagedCommonRules"
    priority = 1

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "common-rule-metric"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "web-acl-metric"
    sampled_requests_enabled   = true
  }
}

resource "aws_wafv2_web_acl_association" "alb_association" {
  
  resource_arn = aws_alb.web_alb.arn
  web_acl_arn = aws_wafv2_web_acl.web_acl.arn
}