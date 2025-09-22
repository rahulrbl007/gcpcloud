terraform {
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
  zone    = var.zone
}

resource "google_compute_network" "vpc_network" {
  name                    = "terraform-network"
  auto_create_subnetworks = true
  project                 = var.project_id
}

resource "google_compute_instance" "vm_instance" {
  name         = "terraform-instance"
  machine_type = "e2-medium"
  zone         = var.zone
  project      = var.project_id

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11"
      size  = 10
      type  = "pd-standard"
    }
  }

  network_interface {
    network = google_compute_network.vpc_network.name
access_config {
  
}
  }
 tags = ["web", "dev", "private", "mynewwork"]
}

resource "google_compute_instance" "vm_instance_2" {
  name         = "terraform-instance-2"
  machine_type = "e2-medium"
  zone         = var.zone
  project      = var.project_id

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11"
      size  = 10
      type  = "pd-standard"
    }
  }

  network_interface {
    network = google_compute_network.vpc_network.name
  }
}

resource "google_compute_firewall" "allow_http" {
  name    = "allow-http"
  network = google_compute_network.vpc_network.name
  project = var.project_id

  allow {
    protocol = "tcp"
    ports    = ["80", "443"]
  }

  source_ranges = ["0.0.0.0/0"]
  direction     = "INGRESS"
  priority      = 1000  

}

resource "google_compute_firewall" "allow_ssh" {
  name    = "allow-ssh"
  network = google_compute_network.vpc_network.name
  project = var.project_id

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["0.0.0.0/0"]
  direction     = "INGRESS"
  priority      = 1000
}

resource "google_compute_firewall" "allow_icmp" {
  name    = "allow-icmp"
  network = google_compute_network.vpc_network.name
  project = var.project_id

  allow {
    protocol = "icmp"
  }

  source_ranges = ["0.0.0.0/0"]
  direction     = "INGRESS"
  priority      = 1000 
}

resource "google_compute_firewall" "allow_rdp" {
  name    = "allow-rdp"
  network = google_compute_network.vpc_network.name
  project = var.project_id

  allow {
    protocol = "tcp"
    ports    = ["3389"]
  }

  source_ranges = ["0.0.0.0/0"]
  direction     = "INGRESS"
  priority      = 1000
}

resource "google_compute_firewall" "allow_internal" { 
  name    = "allow-internal"
  network = google_compute_network.vpc_network.name
  project = var.project_id

  allow {
    protocol = "all"
  }

  source_ranges = ["0.0.0.0/0"]
  direction     = "INGRESS"
  priority      = 1000
}

resource "google_compute_instance_group" "instance_group" {
  name        = "terraform-instance-group"
  zone        = var.zone
  project     = var.project_id
  instances   = [google_compute_instance.vm_instance.id, google_compute_instance.vm_instance_2.id]
  named_port {
    name = "http"
    port = 80
  }
  named_port {
    name = "https"
    port = 443
  } 
}

resource "google_compute_instance_template" "instance_template" {
  name         = "terraform-instance-template"
  machine_type = "e2-medium"
  project      = var.project_id

  disk {
    source_image = "debian-cloud/debian-11"
    auto_delete  = true
    boot         = true
    disk_size_gb = 10
    disk_type    = "pd-standard"
  }

  network_interface {
    network = google_compute_network.vpc_network.name
    access_config {
      
    }
  }

  metadata = {
    startup-script = <<-EOT
      #!/bin/bash
      apt-get update
      apt-get install -y apache2
      systemctl start apache2
      systemctl enable apache2
      echo "Hello, World from $(hostname)" > /var/www/html/index.html
    EOT
  }

  tags = ["web", "dev", "private", "mynewwork"]
}

resource "google_compute_instance_group_manager" "instance_group_manager" {
  name               = "terraform-instance-group-manager"
  base_instance_name = "mig-instance"
  zone               = var.zone
  project            = var.project_id
  version {
    instance_template = google_compute_instance_template.instance_template.id
  }
  target_size        = 2

  named_port {
    name = "http"
    port = 80
  }


}

resource "google_compute_autoscaler" "autoscaler" {
  name        = "terraform-autoscaler"
  target      = google_compute_instance_group_manager.instance_group_manager.id
  project     = var.project_id
  zone        = var.zone

  autoscaling_policy {
    max_replicas    = 5
    min_replicas    = 3
    cooldown_period = 60

    cpu_utilization {
      target = 0.6
    }
  }

  
}

// adding a load balancer
resource "google_compute_health_check" "health_check" {
  name               = "terraform-health-check"
  project            = var.project_id
  check_interval_sec = 5
  timeout_sec        = 5
  healthy_threshold  = 2
  unhealthy_threshold = 2

  http_health_check {
    port = 80
    request_path = "/"
  }
}

resource "google_compute_backend_service" "backend_service" {
  name                  = "terraform-backend-service"
  project               = var.project_id
  protocol              = "HTTP"
  port_name             = "http"
  timeout_sec           = 10
  health_checks        = [google_compute_health_check.health_check.id]
  backend {
    group = google_compute_instance_group_manager.instance_group_manager.instance_group
  }
}

resource "google_compute_url_map" "url_map" {
  name        = "terraform-url-map"
  project     = var.project_id
  default_service = google_compute_backend_service.backend_service.id
}

resource "google_compute_target_http_proxy" "http_proxy" {
  name    = "terraform-http-proxy"
  project = var.project_id
  url_map = google_compute_url_map.url_map.id
}

resource "google_compute_global_forwarding_rule" "http_forwarding_rule" {
  name       = "terraform-http-forwarding-rule"
  project    = var.project_id
  ip_protocol = "TCP"
  port_range  = "80"
  target      = google_compute_target_http_proxy.http_proxy.id
}