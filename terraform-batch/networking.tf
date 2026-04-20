resource "aws_security_group" "batch" {
  name        = "${var.prefix}-batch-sg"
  description = "Security group for Batch Fargate tasks"
  vpc_id      = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.prefix}-batch-sg"
  }
}
