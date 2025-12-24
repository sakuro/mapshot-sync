# mapshot-sync

A tool to upload [Factorio](https://factorio.com/) [mapshot](https://mods.factorio.com/mod/mapshot) output to AWS S3 and serve it via CloudFront.

## Prerequisites

- [GNU Make](https://www.gnu.org/software/make/)
- [factorix](https://github.com/sakuro/factorix) CLI
- [jq](https://jqlang.github.io/jq/)
- [AWS CLI](https://aws.amazon.com/cli/)
- [mise](https://mise.jdx.dev/) (optional, for environment variable management)

## Installation

1. Clone this repository:

   ```bash
   git clone https://github.com/sakuro/mapshot-sync.git
   cd mapshot-sync
   ```

2. Create a `.env` file with required environment variables:

   ```bash
   MAPSHOT_BUCKET_NAME=your-s3-bucket-name
   CLOUDFRONT_DISTRIBUTION_ID=your-cloudfront-distribution-id
   ```

3. Ensure AWS CLI is configured with appropriate credentials.

## AWS Infrastructure Setup

This tool requires an S3 bucket and CloudFront distribution. Below is a Terraform example to set up the required infrastructure.

<details>
<summary>S3 Bucket</summary>

```hcl
resource "aws_s3_bucket" "mapshot" {
  bucket = "your-bucket-name"
}

resource "aws_s3_bucket_website_configuration" "mapshot" {
  bucket = aws_s3_bucket.mapshot.id

  index_document {
    suffix = "index.html"
  }
}

resource "aws_s3_bucket_public_access_block" "mapshot" {
  bucket = aws_s3_bucket.mapshot.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_policy" "mapshot" {
  bucket = aws_s3_bucket.mapshot.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "PublicReadGetObject"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.mapshot.arn}/*"
      }
    ]
  })

  depends_on = [aws_s3_bucket_public_access_block.mapshot]
}
```

</details>

<details>
<summary>ACM Certificate (in us-east-1)</summary>

CloudFront requires ACM certificates to be created in us-east-1.

```hcl
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}

resource "aws_acm_certificate" "mapshot" {
  provider          = aws.us_east_1
  domain_name       = "your-domain.example.com"
  validation_method = "DNS"
}
```

</details>

<details>
<summary>CloudFront Distribution</summary>

```hcl
resource "aws_cloudfront_origin_access_control" "mapshot" {
  name                              = "mapshot-oac"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_distribution" "mapshot" {
  enabled             = true
  default_root_object = "index.html"
  aliases             = ["your-domain.example.com"]

  origin {
    domain_name              = aws_s3_bucket.mapshot.bucket_regional_domain_name
    origin_id                = "s3-mapshot"
    origin_access_control_id = aws_cloudfront_origin_access_control.mapshot.id
  }

  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "s3-mapshot"
    viewer_protocol_policy = "redirect-to-https"
    cache_policy_id        = "658327ea-f89d-4fab-a63d-7e88639e58f6" # CachingOptimized
  }

  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate.mapshot.arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }
}
```

</details>

After applying the Terraform configuration, set `CLOUDFRONT_DISTRIBUTION_ID` to the distribution ID from the output.

## Usage

### Generate index and sync to S3

```bash
make
```

This runs both `index.html` and `sync` targets.

### Generate index.html only

```bash
make index.html
```

Generates an HTML index page listing all mapshot snapshots.

### Sync to S3 only

```bash
make sync
```

Uploads static files and mapshot data to S3, then invalidates CloudFront cache.

### Clean generated files

```bash
make clean
```

## License

MIT
