# RDS Postgres (subredes privadas, sin salida a internet) + la cola SQS
# de clics con su DLQ. Un solo módulo porque ambos son "el almacenamiento
# de datos de linkly" y siempre se despliegan juntos.

resource "aws_db_subnet_group" "this" {
  name       = "${var.name}-db"
  subnet_ids = var.private_subnet_ids
  tags       = var.tags
}

resource "aws_security_group" "rds" {
  name_prefix = "${var.name}-rds-"
  description = "Postgres de linkly: solo acepta trafico desde los nodos de EKS"
  vpc_id      = var.vpc_id

  ingress {
    description     = "Postgres desde los nodos EKS"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [var.node_security_group_id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = var.tags

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_db_instance" "this" {
  identifier     = "${var.name}-postgres"
  engine         = "postgres"
  engine_version = "16"
  instance_class = "db.t4g.micro"

  allocated_storage = 20
  storage_encrypted = true

  db_name  = "linkly"
  username = "linkly"
  # AWS genera y rota la contraseña en Secrets Manager — no la vemos ni
  # la escribimos en ningún sitio.
  manage_master_user_password = true

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = false

  # Es una demo: sin snapshot final para poder hacer `terraform destroy`
  # sin fricción al final del día.
  skip_final_snapshot = true

  tags = var.tags
}

resource "aws_sqs_queue" "dlq" {
  name = "${var.name}-clicks-dlq"
  tags = var.tags
}

resource "aws_sqs_queue" "clicks" {
  name = "${var.name}-clicks"

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dlq.arn
    maxReceiveCount     = 5
  })

  tags = var.tags
}
