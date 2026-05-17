resource "aws_security_group" "additional_node_sg" {
  name        = "cloudaura-${var.environment}-node-additional-sg"
  description = "Additional security group for EKS worker nodes"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "Allow all internal traffic between nodes"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Environment = var.environment
    Name        = "cloudaura-${var.environment}-node-additional-sg"
  }
}
