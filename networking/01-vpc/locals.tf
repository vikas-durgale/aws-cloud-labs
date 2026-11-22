locals {
  name_prefix    = "${var.project}-${var.lab}"
  vpc_cidr_block = "10.20.0.0/20"

  subnets = {
    public-a = {
      cidr              = "10.20.0.0/24"
      availability_zone = "ap-southeast-1a"
      tier              = "public"
    }

    public-b = {
      cidr              = "10.20.1.0/24"
      availability_zone = "ap-southeast-1b"
      tier              = "public"
    }

    private-app-a = {
      cidr              = "10.20.4.0/24"
      availability_zone = "ap-southeast-1a"
      tier              = "app"
    }

    private-app-b = {
      cidr              = "10.20.5.0/24"
      availability_zone = "ap-southeast-1b"
      tier              = "app"
    }

    private-db-a = {
      cidr              = "10.20.8.0/24"
      availability_zone = "ap-southeast-1a"
      tier              = "db"
    }

    private-db-b = {
      cidr              = "10.20.9.0/24"
      availability_zone = "ap-southeast-1b"
      tier              = "db"
    }
  }

  route_tables = {
    public = {
      name = "public-rt"
    }

    app = {
      name = "private-app-rt"
    }

    db = {
      name = "private-db-rt"
    }
  }

  common_tags = {
    Project     = var.project
    Environment = var.environment
    ManagedBy   = "terraform"
    Lab         = var.lab
  }
}