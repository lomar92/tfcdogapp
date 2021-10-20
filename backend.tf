terraform {
  backend "remote" {
    organization = "amarlojo-training"

    workspaces {
      name = "learn_TFC_dogAWS"
    }
  }
}