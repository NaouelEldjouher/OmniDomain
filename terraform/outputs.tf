output "env_config" {
  value = <<EOT
AMR_STATIC_BUCKET="${aws_s3_bucket.amr_static_assets.bucket}"
AMR_COMPUTE_BUCKET="${aws_s3_bucket.amr_compute_storage.bucket}"
AMR_BATCH_QUEUE=${aws_batch_job_queue.amr_queue.arn}
AMR_EC2_QUEUE=${aws_batch_job_queue.amr_ec2_queue.arn}
AMR_JOB_ROLE_ARN=${aws_iam_role.amr_job_role.arn}
AMR_SUBNETS=${join(",", var.subnet_ids)}
AMR_SECURITY_GROUPS=${aws_security_group.amr_sg.id}
AWS_DEFAULT_REGION=${trimspace(var.region)}
EOT
}