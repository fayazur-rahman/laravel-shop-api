output "repository_urls" {
  description = "Push/pull URLs, keyed by repository name."
  value       = { for name, r in aws_ecr_repository.this : name => r.repository_url }
}
