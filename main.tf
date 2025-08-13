terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws    = { source = "hashicorp/aws", version = ">= 5.0" }
    random = { source = "hashicorp/random", version = ">= 3.5" }
  }
}

provider "aws" {
  region = var.aws_region   # if you don't have variables.tf, change to region = "us-east-1"
}

# Unique bucket name each run
resource "random_id" "suffix" {
  byte_length = 4
}

locals {
  bucket_name = "tf-site-${random_id.suffix.hex}"
}

# Bucket
resource "aws_s3_bucket" "site" {
  bucket = local.bucket_name
  tags = { project = "lab3-terraform-github-actions" }
}

# Turn OFF bucket-level public blocks so ACLs work (lab only)
resource "aws_s3_bucket_public_access_block" "site" {
  bucket                  = aws_s3_bucket.site.id
  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

# Website hosting
resource "aws_s3_bucket_website_configuration" "site" {
  bucket = aws_s3_bucket.site.id
  index_document { suffix = "index.html" }
  error_document { key    = "index.html" }
  depends_on = [aws_s3_bucket_public_access_block.site]
}

# Enable object ACLs
resource "aws_s3_bucket_ownership_controls" "site" {
  bucket = aws_s3_bucket.site.id
  rule { object_ownership = "ObjectWriter" }
}

# Make the bucket public via ACL (lab only)
resource "aws_s3_bucket_acl" "site" {
  bucket = aws_s3_bucket.site.id
  acl    = "public-read"
  depends_on = [aws_s3_bucket_ownership_controls.site]
}

# Upload the page (object itself public)
resource "aws_s3_object" "index" {
  bucket       = aws_s3_bucket.site.id
  key          = "index.html"
  source       = "${path.module}/index.html"
  content_type = "text/html"
  etag         = filemd5("${path.module}/index.html")
  acl          = "public-read"
  depends_on   = [aws_s3_bucket_acl.site]
}

# Outputs
output "bucket_name" {
  value       = aws_s3_bucket.site.bucket
  description = "Name of the S3 bucket"
}

output "website_endpoint" {
  value       = aws_s3_bucket_website_configuration.site.website_endpoint
  description = "S3 static website URL"
}
