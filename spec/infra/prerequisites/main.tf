resource "aws_kms_key" "test_key" {
  description             = "This key is used to encrypt bucket objects"
  deletion_window_in_days = 10
}

resource "aws_s3_bucket" "access_log_bucket" {
  bucket = var.access_log_bucket_name
}

resource "aws_s3_bucket_public_access_block" "access_log_bucket" {
  bucket                  = aws_s3_bucket.access_log_bucket.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
