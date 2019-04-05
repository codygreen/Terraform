#--------compute/main.tf--------

# Create resources for service discovery
resource "aws_service_discovery_private_dns_namespace" "f5-demo" {
  name        = "${var.dns_domain_internal}"
  description = "F5 Demo Local Zone"
  vpc         = "${var.vpc}"
}

resource "aws_service_discovery_service" "f5-demo" {
  name = "f5-demo"

  dns_config {
    namespace_id = "${aws_service_discovery_private_dns_namespace.f5-demo.id}"

    dns_records {
      ttl  = 10
      type = "A"
    }
  }
}

#Create the Cluster
resource "aws_ecs_cluster" "ecs-f5-demo" {
  name = "ecs-f5-demo"
}

# Create Task Definition
resource "aws_ecs_task_definition" "app" {
  family                   = "f5-demo-app"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "${var.cpu}"
  memory                   = "${var.memory}"

  container_definitions = <<EOF
[
  {
    "name": "f5-demo-app",
    "image": "${var.image}",
    "cpu": ${var.cpu},
    "memory": ${var.memory},
    "portMappings": [
      {
        "containerPort": 80,
        "hostPort": 80
      }
    ]
  }
]
EOF
}

resource "aws_ecs_service" "f5-demo" {
  name            = "f5-demo-app"
  cluster         = "${aws_ecs_cluster.ecs-f5-demo.id}"
  task_definition = "${aws_ecs_task_definition.app.arn}"
  desired_count   = 2
  launch_type     = "FARGATE"

  network_configuration {
    security_groups  = ["${var.security_group}"]
    subnets          = ["${var.subnet}"]
    assign_public_ip = true
  }

  service_registries {
    registry_arn = "${aws_service_discovery_service.f5-demo.arn}"
  }
}
