output "bvault_ecr_repo" {
  value = aws_ecr_repository.bvault_app_repo.repository_url
}