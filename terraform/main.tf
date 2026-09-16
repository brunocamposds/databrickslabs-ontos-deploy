resource "kubernetes_namespace" "ontos" {
  metadata {
    name = var.namespace
    labels = {
      "app.kubernetes.io/name"    = "ontos"
      "app.kubernetes.io/part-of" = "ontos-platform"
    }
  }
}

# ==============================================================================
# PostgreSQL Resources
# ==============================================================================

resource "kubernetes_secret" "postgres_secret" {
  metadata {
    name      = "postgres-secret"
    namespace = kubernetes_namespace.ontos.metadata[0].name
  }

  data = {
    POSTGRES_DB       = var.postgres_db
    POSTGRES_USER     = var.postgres_user
    POSTGRES_PASSWORD = var.postgres_password
  }
}

resource "kubernetes_config_map" "postgres_init_script" {
  metadata {
    name      = "postgres-init-script"
    namespace = kubernetes_namespace.ontos.metadata[0].name
  }

  data = {
    "01-init-schema.sql" = <<-EOT
      CREATE SCHEMA IF NOT EXISTS ${var.postgres_db};
      GRANT ALL ON SCHEMA ${var.postgres_db} TO ${var.postgres_user};
      GRANT ALL ON SCHEMA public TO ${var.postgres_user};
    EOT
  }
}

resource "kubernetes_persistent_volume_claim" "postgres_pvc" {
  wait_until_bound = false

  metadata {
    name      = "postgres-pvc"
    namespace = kubernetes_namespace.ontos.metadata[0].name
  }

  spec {
    access_modes       = ["ReadWriteOnce"]
    storage_class_name = var.storage_class_name

    resources {
      requests = {
        storage = var.postgres_storage_size
      }
    }
  }
}

resource "kubernetes_deployment" "postgres" {
  metadata {
    name      = "postgres"
    namespace = kubernetes_namespace.ontos.metadata[0].name
    labels = {
      app  = "postgres"
      tier = "database"
    }
  }

  spec {
    replicas = 1
    strategy {
      type = "Recreate"
    }

    selector {
      match_labels = {
        app = "postgres"
      }
    }

    template {
      metadata {
        labels = {
          app  = "postgres"
          tier = "database"
        }
      }

      spec {
        container {
          name              = "postgres"
          image             = var.postgres_image
          image_pull_policy = "IfNotPresent"

          env_from {
            secret_ref {
              name = kubernetes_secret.postgres_secret.metadata[0].name
            }
          }

          port {
            name           = "postgres"
            container_port = 5432
          }

          resources {
            requests = {
              cpu    = "100m"
              memory = "256Mi"
            }
            limits = {
              cpu    = "1000m"
              memory = "1Gi"
            }
          }

          volume_mount {
            name       = "postgres-storage"
            mount_path = "/var/lib/postgresql/data"
          }

          volume_mount {
            name       = "init-scripts"
            mount_path = "/docker-entrypoint-initdb.d"
          }

          readiness_probe {
            exec {
              command = ["pg_isready", "-U", var.postgres_user, "-d", var.postgres_db]
            }
            initial_delay_seconds = 5
            period_seconds        = 5
          }

          liveness_probe {
            exec {
              command = ["pg_isready", "-U", var.postgres_user, "-d", var.postgres_db]
            }
            initial_delay_seconds = 15
            period_seconds        = 10
          }
        }

        volume {
          name = "postgres-storage"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim.postgres_pvc.metadata[0].name
          }
        }

        volume {
          name = "init-scripts"
          config_map {
            name = kubernetes_config_map.postgres_init_script.metadata[0].name
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "postgres" {
  metadata {
    name      = "postgres"
    namespace = kubernetes_namespace.ontos.metadata[0].name
    labels = {
      app = "postgres"
    }
  }

  spec {
    type = "ClusterIP"
    selector = {
      app = "postgres"
    }

    port {
      name        = "postgres"
      port        = 5432
      target_port = 5432
    }
  }
}

# ==============================================================================
# Ontos App Resources
# ==============================================================================

resource "kubernetes_config_map" "ontos_config" {
  metadata {
    name      = "ontos-config"
    namespace = kubernetes_namespace.ontos.metadata[0].name
  }

  data = {
    ENV                      = "LOCAL"
    DEBUG                    = "true"
    LOG_LEVEL                = "INFO"
    APP_AUDIT_LOG_DIR        = "audit_logs"
    PGHOST                   = "postgres"
    PGPORT                   = "5432"
    PGDATABASE               = var.postgres_db
    PGUSER                   = var.postgres_user
    PGSCHEMA                 = var.postgres_db
    DB_USE_PASSWORD_AUTH     = "true"
    DATABRICKS_HOST          = "https://mock.databricks.local"
    DATABRICKS_WAREHOUSE_ID  = "mock_warehouse_lab"
    DATABRICKS_CATALOG       = var.postgres_db
    DATABRICKS_SCHEMA        = var.postgres_db
    MOCK_WORKSPACE_CLIENT    = "true"
    MOCK_USER_DETAILS        = "true"
    MOCK_USER_EMAIL          = "admin@ontos.local"
    MOCK_USER_NAME           = "Ontos Admin"
    MOCK_USER_GROUPS         = jsonencode(["admins"])
    APP_ADMIN_DEFAULT_GROUPS = jsonencode(["admins"])
    APP_DEMO_MODE            = "true"
  }
}

resource "kubernetes_secret" "ontos_secret" {
  metadata {
    name      = "ontos-secret"
    namespace = kubernetes_namespace.ontos.metadata[0].name
  }

  data = {
    PGPASSWORD        = var.postgres_password
    POSTGRES_PASSWORD = var.postgres_password
  }
}

resource "kubernetes_deployment" "ontos_app" {
  metadata {
    name      = "ontos-app"
    namespace = kubernetes_namespace.ontos.metadata[0].name
    labels = {
      app  = "ontos-app"
      tier = "frontend-backend"
    }
  }

  depends_on = [
    kubernetes_deployment.postgres,
    kubernetes_service.postgres
  ]

  spec {
    replicas = 1
    strategy {
      type = "Recreate"
    }

    selector {
      match_labels = {
        app = "ontos-app"
      }
    }

    template {
      metadata {
        labels = {
          app  = "ontos-app"
          tier = "frontend-backend"
        }
      }

      spec {
        container {
          name              = "ontos"
          image             = var.app_image
          image_pull_policy = "IfNotPresent"

          env_from {
            config_map_ref {
              name = kubernetes_config_map.ontos_config.metadata[0].name
            }
          }

          env_from {
            secret_ref {
              name = kubernetes_secret.ontos_secret.metadata[0].name
            }
          }

          port {
            name           = "http"
            container_port = 8000
          }

          resources {
            requests = {
              cpu    = "200m"
              memory = "512Mi"
            }
            limits = {
              cpu    = "2000m"
              memory = "2Gi"
            }
          }

          startup_probe {
            http_get {
              path = "/api/health"
              port = 8000
            }
            initial_delay_seconds = 15
            period_seconds        = 5
            timeout_seconds       = 3
            failure_threshold     = 60
          }

          readiness_probe {
            http_get {
              path = "/api/health"
              port = 8000
            }
            initial_delay_seconds = 5
            period_seconds        = 5
            timeout_seconds       = 3
            failure_threshold     = 3
          }

          liveness_probe {
            http_get {
              path = "/api/health"
              port = 8000
            }
            initial_delay_seconds = 15
            period_seconds        = 10
            timeout_seconds       = 3
            failure_threshold     = 3
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "ontos_app" {
  metadata {
    name      = "ontos-app"
    namespace = kubernetes_namespace.ontos.metadata[0].name
    labels = {
      app = "ontos-app"
    }
  }

  spec {
    type = "NodePort"
    selector = {
      app = "ontos-app"
    }

    port {
      name        = "http"
      port        = 8000
      target_port = 8000
      node_port   = 30080
    }
  }
}

resource "kubernetes_ingress_v1" "ontos_ingress" {
  metadata {
    name      = "ontos-ingress"
    namespace = kubernetes_namespace.ontos.metadata[0].name
    annotations = {
      "traefik.ingress.kubernetes.io/router.entrypoints" = "web"
    }
  }

  spec {
    rule {
      host = "ontos.local"
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = kubernetes_service.ontos_app.metadata[0].name
              port {
                number = 8000
              }
            }
          }
        }
      }
    }

    rule {
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = kubernetes_service.ontos_app.metadata[0].name
              port {
                number = 8000
              }
            }
          }
        }
      }
    }
  }
}
