data "google_compute_network" "default" {
  name = "default"

}

resource "google_service_account" "dbuser_trillian" {
  project    = var.PROJECT_ID
  account_id = "dbuser-trillian"
}

resource "google_project_iam_member" "db_admin_member_trillian" {
  project    = var.PROJECT_ID
  role       = "roles/cloudsql.admin"
  member     = "serviceAccount:${google_service_account.dbuser_trillian.email}"
  depends_on = [google_service_account.dbuser_trillian]
}

resource "google_project_iam_member" "gcs_member_trillian" {
  project    = var.PROJECT_ID
  role       = "roles/storage.objectViewer"
  member     = "serviceAccount:${google_service_account.dbuser_trillian.email}"
  depends_on = [google_service_account.dbuser_trillian]
}

resource "google_service_account_iam_member" "gke_sa_iam_member_trillian" {
  service_account_id = google_service_account.dbuser_trillian.name
  role               = "roles/iam.workloadIdentityUser"
  count              = length(var.trillian_sa_names)
  member             = "serviceAccount:${var.PROJECT_ID}.svc.id.goog[trillian-system/${var.trillian_sa_names[count.index]}]"
  depends_on         = [google_service_account.dbuser_trillian]
}


resource "google_sql_database_instance" "trillian" {
  project          = var.PROJECT_ID
  database_version = "MYSQL_8_0"
  region           = var.DEFAULT_LOCATION

  settings {
    tier = "db-g1-small"

    database_flags {
      name  = "cloudsql_iam_authentication"
      value = "on"
    }

    user_labels = {
      "chainguard-dbtype" : "trillian",
    }

    ip_configuration {
      ipv4_enabled = true
    }
  }

  // Without this `terraform destroy` won't tear down the database.
  deletion_protection = false
}

// This is what the auth proxy uses to connect
resource "google_sql_user" "users_trillian" {
  project  = var.PROJECT_ID
  name     = google_service_account.dbuser_trillian.email
  instance = google_sql_database_instance.trillian.name
  type     = "CLOUD_IAM_SERVICE_ACCOUNT"
}

// This is what clients use, it's ok to use password here, because gatekeeper
// is the SQL auth proxy below.
resource "google_sql_user" "trillian" {
  project  = var.PROJECT_ID
  name     = "trillian"
  instance = google_sql_database_instance.trillian.name
  host     = "%"
  password = "trillian"
}

// Actual Trillian Database
resource "google_sql_database" "database_trillian" {
  project  = var.PROJECT_ID
  name     = "trillian"
  instance = google_sql_database_instance.trillian.name
}

output "database_connection_string" {
  value = google_sql_database_instance.trillian.connection_name
}