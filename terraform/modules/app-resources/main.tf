resource "aws_ecr_repository" "bvault_app_repo" {
  name                 = "bvault_app"
  image_tag_mutability = "IMMUTABLE_WITH_EXCLUSION"

  image_tag_mutability_exclusion_filter {
    filter      = "latest*"
    filter_type = "WILDCARD"
  }
}