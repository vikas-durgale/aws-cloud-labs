resource "aws_dynamodb_table" "lab" {
  name         = local.dynamodb_table_name
  hash_key     = "pk"
  billing_mode = "PAY_PER_REQUEST"

  attribute {
    name = "pk"
    type = "S"
  }
}