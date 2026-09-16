output "namespace" {
  description = "Namespace do Ontos"
  value       = kubernetes_namespace.ontos.metadata[0].name
}

output "nodeport_url" {
  description = "URL de acesso via NodePort"
  value       = "http://localhost:30080"
}

output "ingress_url" {
  description = "URL de acesso via Ingress Traefik"
  value       = "http://localhost"
}

output "app_service_name" {
  description = "Nome do serviço da aplicação"
  value       = kubernetes_service.ontos_app.metadata[0].name
}

output "postgres_service_name" {
  description = "Nome do serviço PostgreSQL"
  value       = kubernetes_service.postgres.metadata[0].name
}
