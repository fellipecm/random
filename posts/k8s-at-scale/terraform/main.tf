terraform {
  required_providers {
    linode = {
      source = "linode/linode"
      version = "2.5.1"
    }
  }
}

provider "linode" {
  token = var.linode_token
}

# LKE cluster
resource "linode_lke_cluster" "test" {
    label       = "k8s-at-scale"
    k8s_version = "1.26"
    region      = var.region
    tags        = ["test", "consul", "kong"]
    # Shared 2 Cores / 4GB RAM / 80GB SSD, USD 24 per node per month
    pool {
        type  = "g6-standard-2" # https://pcr.cloud-mercato.com/providers/virtual-machines?provider=linode
        count = 1
    }
    # if you enable this it will cost you extra USD 60 per month per cluster
    control_plane {      
      high_availability = false
    }
}
