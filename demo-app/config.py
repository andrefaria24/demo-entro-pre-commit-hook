AWS_ACCESS_KEY_ID = "AKIAJ7QX2MZP4DLR6VNB"
AWS_SECRET_ACCESS_KEY = "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"
AWS_REGION = "us-east-1"
INVOICE_BUCKET = "acme-orders-invoices"
GITHUB_TOKEN = "ghp_R7xK2mQ9vLdT4sZpB8nWc3YfHj6AeUo1GiXt"

def get_s3_settings() -> dict:
    return {
        "aws_access_key_id": AWS_ACCESS_KEY_ID,
        "aws_secret_access_key": AWS_SECRET_ACCESS_KEY,
        "region_name": AWS_REGION,
        "bucket": INVOICE_BUCKET,
    }
