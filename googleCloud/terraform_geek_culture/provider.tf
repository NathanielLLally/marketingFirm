provider "google" {

  credentials = file("./Credentials.json")
  project = "x"
  region  = "us-central1"
  zone    = "us-central1-c"
}

