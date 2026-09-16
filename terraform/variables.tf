variable "namespace" {
  description = "Namespace do Kubernetes para o Ontos"
  type        = string
  default     = "ontos"
}

variable "app_image" {
  description = "Imagem docker do Ontos"
  type        = string
  default     = "ontos:lab"
}

variable "postgres_image" {
  description = "Imagem docker do PostgreSQL"
  type        = string
  default     = "postgres:16-alpine"
}

variable "postgres_db" {
  description = "Nome do banco de dados"
  type        = string
  default     = "app_ontos"
}

variable "postgres_user" {
  description = "Usuário do PostgreSQL"
  type        = string
  default     = "ontos_app_user"
}

variable "postgres_password" {
  description = "Senha do PostgreSQL"
  type        = string
  default     = "ontos_lab_password"
  sensitive   = true
}

variable "postgres_storage_size" {
  description = "Tamanho do PVC do PostgreSQL"
  type        = string
  default     = "2Gi"
}

variable "storage_class_name" {
  description = "StorageClass do cluster Kubernetes (k3s)"
  type        = string
  default     = "local-path"
}
