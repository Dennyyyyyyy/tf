# terraform {
#   backend "gcs" {
#     bucket = "dennyyyyyyy-secret"
#     prefix = "terraform/state"
#   }
# }

module "github_repository" {
  #source       = "github.com/dennyyyyyyy/tf-github-repository"
  source             = "./modules/github_repository"
  github_owner       = var.GITHUB_OWNER
  github_token       = var.GITHUB_TOKEN
  repository_name    = var.FLUX_GITHUB_REPO
  public_key_openssh = module.tls_private_key.public_key_openssh
  # public_key_openssh_title = "flux"
  public_key_openssh_title = "flux-ssh-pub"
}

module "gke_cluster" {
  source         = "./modules/gke_cluster"
  GOOGLE_REGION  = var.GOOGLE_REGION
  GOOGLE_PROJECT = var.GOOGLE_PROJECT
  GKE_NUM_NODES  = 2

}
# module "kind_cluster" {
#   source = "github.com/den-vasyliev/tf-kind-cluster?ref=cert_auth"
# }

module "tls_private_key" {
  source    = "github.com/dennyyyyyyy/tf-hashicorp-tls-keys"
  algorithm = "RSA"
}

module "flux_bootstrap" {
  #source            = "github.com/dennyyyyyyy/tf-fluxcd-flux-bootstrap"
  source            = "./modules/flux_bootstrap/"
  github_repository = "${var.GITHUB_OWNER}/${var.FLUX_GITHUB_REPO}"
  private_key       = module.tls_private_key.private_key_pem
  config_host       = module.gke_cluster.config_host
  config_token      = module.gke_cluster.config_token
  config_ca         = module.gke_cluster.config_ca
  github_token      = var.GITHUB_TOKEN
  #config_path       = "./kind-cluster-config"
  # config_host       = module.kind_cluster.endpoint
  # config_client_key = module.kind_cluster.client_key
  # config_ca         = module.kind_cluster.ca
  # config_crt        = module.kind_cluster.crt
  # github_token      = var.GITHUB_TOKEN
}
# module "flux_bootstrap" {
#   source            = "github.com/dennyyyyyyy/tf-fluxcd-flux-bootstrap"
#   github_repository = "${var.GITHUB_OWNER}/${var.FLUX_GITHUB_REPO}"
#   private_key       = module.tls_private_key.private_key_pem
#   config_path       = "./kind-cluster-config"
#   github_token      = var.GITHUB_TOKEN
# }l
module "gke-workload-identity" {
  source              = "terraform-google-modules/kubernetes-engine/google//modules/workload-identity"
  use_existing_k8s_sa = true
  annotate_k8s_sa     = true
  name                = "kustomize-controller"
  namespace           = "flux-system"
  project_id          = var.GOOGLE_PROJECT
  location            = var.GOOGLE_REGION
  cluster_name        = "main"  
  roles               = ["roles/cloudkms.cryptoKeyEncrypterDecrypter"]

  # module_depends_on = [
  #   module.flux_bootstrap
  # ]
}
module "kms" {
  source             = "terraform-google-modules/kms/google"
  version            = "2.2.3"
  project_id         = var.GOOGLE_PROJECT
  keyring            = "sops-flux2"
  location           = "global"
  keys               = ["sops-key-flux"]
  prevent_destroy    = false
}