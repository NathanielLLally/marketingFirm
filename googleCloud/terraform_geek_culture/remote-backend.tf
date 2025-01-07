terraform {
  backend "gcs" {
    bucket      = "10gb_per_dollar"
    prefix      = "terraform/state1"
    credentials = "Credentials.json"  #mention here the name and add service account key inside same folder
  }
}
