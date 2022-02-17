data "template_file" "deny_unencrypted_object_uploads_fragment" {
  template = file("${path.module}/policy-fragments/deny-unencrypted-object-uploads.json.tpl")

  vars = {
    bucket_name = var.bucket_name
    sse_algorithm = var.kms_key_arn != null ? "aws:kms" : "AES256"
  }
}

data "template_file" "deny_unencrypted_inflight_operations_fragment" {
  template = file("${path.module}/policy-fragments/deny-unencrypted-inflight-operations.json.tpl")

  vars = {
    bucket_name = var.bucket_name
  }
}

data "template_file" "encrypted_bucket_policy" {
  template = coalesce(var.bucket_policy_template, file("${path.module}/policies/bucket-policy.json.tpl"))

  vars = {
    bucket_name = var.bucket_name
    deny_unencrypted_object_upload_fragment = data.template_file.deny_unencrypted_object_uploads_fragment.rendered
    deny_unencrypted_inflight_operations_fragment = data.template_file.deny_unencrypted_inflight_operations_fragment.rendered
  }
}

locals {
  access_bucket_name = (var.access_log_bucket_name != null
  ? var.access_log_bucket_name
  : "${var.bucket_name}-access-log")
}
data "template_file" "deny_unencrypted_inflight_operations_fragment_access_bucket" {
  template = file("${path.module}/policy-fragments/deny-unencrypted-inflight-operations.json.tpl")
  vars = {
    bucket_name = local.access_bucket_name
  }
}

data "template_file" "access_bucket_policy" {
  template = file("${path.module}/policies/access-bucket-policy.json.tpl")

  vars = {
    bucket_name = local.access_bucket_name
    deny_unencrypted_inflight_operations_fragment = data.template_file.deny_unencrypted_inflight_operations_fragment_access_bucket.rendered
  }
}

resource "aws_s3_bucket" "access_log_bucket" {
  bucket = local.access_bucket_name
  acl    = "log-delivery-write"
  count = var.enable_access_logging == "yes" ? 1 : 0

  versioning {
    enabled = false
  }

  dynamic "server_side_encryption_configuration" {
    for_each = var.kms_key_arn != null ? [1] : []
    content {
      rule {
        apply_server_side_encryption_by_default {
          kms_master_key_id = var.kms_key_arn
          sse_algorithm = "aws:kms"
        }
        bucket_key_enabled = var.bucket_key_enabled
      }
    }
  }

  tags = merge({
    Name = var.bucket_name
  }, var.tags)
}

resource "aws_s3_bucket" "encrypted_bucket" {
  bucket = var.bucket_name

  acl = var.acl

  force_destroy = var.allow_destroy_when_objects_present == "yes"

  dynamic "server_side_encryption_configuration" {
    for_each = var.kms_key_arn != null ? [1] : []
    content {
      rule {
        apply_server_side_encryption_by_default {
          kms_master_key_id = var.kms_key_arn
          sse_algorithm = "aws:kms"
        }
        bucket_key_enabled = var.bucket_key_enabled
      }
    }
  }

  dynamic logging {
    for_each = var.enable_access_logging == "yes" ? [1] : []
    content {
      target_bucket = aws_s3_bucket.access_log_bucket[0].id
      target_prefix = "log/"
    }
  }

  versioning {
    enabled = true
    mfa_delete = var.mfa_delete
  }

  tags = merge({
    Name = var.bucket_name
  }, var.tags)
}

data "aws_iam_policy_document" "encrypted_bucket_policy_document" {
  source_json = var.source_policy_json
  override_json = data.template_file.encrypted_bucket_policy.rendered
}

resource "aws_s3_bucket_policy" "encrypted_bucket" {
  bucket = aws_s3_bucket.encrypted_bucket.id
  policy = data.aws_iam_policy_document.encrypted_bucket_policy_document.json
}

data "aws_iam_policy_document" "access_bucket_policy_document" {
  source_json = var.source_policy_json
  override_json = data.template_file.access_bucket_policy.rendered
}

resource "aws_s3_bucket_policy" "access_bucket" {
  count = var.enable_access_logging == "yes" ? 1 : 0
  bucket = aws_s3_bucket.access_log_bucket[0].id
  policy = data.aws_iam_policy_document.access_bucket_policy_document.json
}




