# =============================================================================
# OmniDomain — EFS (Elastic File System)
# Shared filesystem for tool databases mounted into Batch compute nodes
#
# Databases stored here:
#   /mnt/databases/eggnog/      — eggNOG-mapper (~50GB)
#   /mnt/databases/busco/       — BUSCO lineages (~600MB each)
#   /mnt/databases/helixer/     — Helixer models (~500MB)
#   /mnt/databases/dbcan/       — dbCAN (~2GB)
#   /mnt/databases/nlr/         — NLR-Annotator assets (~2MB)
#   /mnt/databases/checkm2/     — CheckM2 (~3GB)
#   /mnt/databases/funannotate/ — Funannotate (~20GB)
# =============================================================================

resource "aws_efs_file_system" "databases" {
  creation_token   = "omni-databases"
  performance_mode = "generalPurpose"
  throughput_mode  = "bursting"

  # Automatically move files not accessed in 30 days to cheaper IA storage
  lifecycle_policy {
    transition_to_ia = "AFTER_30_DAYS"
  }

  tags = {
    Name = "omni-databases"
  }
}

# Security group — allow NFS traffic from Batch compute nodes
resource "aws_security_group" "efs" {
  name        = "omni-efs-sg"
  description = "Allow NFS from Batch compute nodes"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port       = 2049
    to_port         = 2049
    protocol        = "tcp"
    security_groups = [aws_security_group.batch.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Mount targets — one per subnet so all Batch nodes can access EFS
resource "aws_efs_mount_target" "databases" {
  for_each = toset(data.aws_subnets.default.ids)

  file_system_id  = aws_efs_file_system.databases.id
  subnet_id       = each.value
  security_groups = [aws_security_group.efs.id]
}

# Access point — scoped to /databases directory
resource "aws_efs_access_point" "databases" {
  file_system_id = aws_efs_file_system.databases.id

  root_directory {
    path = "/databases"
    creation_info {
      owner_uid   = 1000
      owner_gid   = 1000
      permissions = "755"
    }
  }
}
