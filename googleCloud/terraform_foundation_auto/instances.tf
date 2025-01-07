resource "google_compute_instance" "web" {
  name         = "webserver"
  machine_type = "f1-micro"
  zone = "us-west3-b"

  /*
   *   gcloud compute zones list
   *  
   *   
   */
  tags = ["http-server"]

  boot_disk {
    initialize_params {
      image = "fedora-coreos-41"
    }
  }

  metadata_startup_script = file("./dpkg_deps.sh")

  scheduling {
    preemptible       = true
    automatic_restart = false
  }

  network_interface {
    network = "default"
    access_config {

    }

  }
}
