terraform {
  required_version = ">= 1.0.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

variable "project_id" {
  type        = string
  description = "GCP project ID"
}

variable "region" {
  type        = string
  description = "GCP region"
  default     = "asia-south1"
}

# ---------------------------------------------------------------------------
# INSECURE EXAMPLE – SHOULD BE FLAGGED BY IaC SCAN
# ---------------------------------------------------------------------------

resource "google_compute_ssl_policy" "insecure_policy" {
  name            = "lb-ssl-policy-insecure"
  min_tls_version = "TLS_1_0"
  profile         = "COMPATIBLE"

  custom_features = [
    "TLS_RSA_WITH_AES_128_GCM_SHA256",
    "TLS_RSA_WITH_AES_256_GCM_SHA384",
    "TLS_RSA_WITH_AES_128_CBC_SHA",
    "TLS_RSA_WITH_AES_256_CBC_SHA",
    "TLS_RSA_WITH_3DES_EDE_CBC_SHA",
  ]
}

# ---------------------------------------------------------------------------
# SECURE EXAMPLE – SHOULD PASS IaC SCAN
# ---------------------------------------------------------------------------

resource "google_compute_ssl_policy" "secure_policy" {
  name            = "lb-ssl-policy-secure"
  min_tls_version = "TLS_1_2"
  profile         = "MODERN" # or "RESTRICTED"
}

provider "google" {
  project = var.project_id
  region  = var.region
}


variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "GCP region"
  type        = string
  default     = "us-central1"
}

############################################################
# 1) Public GCS bucket (likely flagged as publicly readable)
############################################################

resource "google_storage_bucket" "public_bucket" {
  name     = "${var.project_id}-public-demo-bucket"
  location = var.region

  # Disable uniform bucket-level access (bad practice)
  uniform_bucket_level_access = false

  # Explicitly allow public access (bad)
  public_access_prevention = "unspecified"
}

# Grant allUsers read access to objects in the bucket (bad)
resource "google_storage_bucket_iam_member" "public_read" {
  bucket = google_storage_bucket.public_bucket.name
  role   = "roles/storage.objectViewer"
  member = "allUsers"
}

############################################################
# 2) Overly permissive firewall rule (0.0.0.0/0, all TCP ports)
############################################################

resource "google_compute_network" "demo_vpc" {
  name                    = "demo-vpc"
  auto_create_subnetworks = true
}

resource "google_compute_firewall" "allow_all_ingress" {
  name    = "allow-all-ingress"
  network = google_compute_network.demo_vpc.name

  direction = "INGRESS"
  priority  = 1000

  # Allow *any* source (0.0.0.0/0) – bad
  source_ranges = ["0.0.0.0/0"]

  # Allow all TCP ports – bad
  allow {
    protocol = "tcp"
    ports    = ["0-65535"]
  }

  # Tag not required; rule applies broadly
}
