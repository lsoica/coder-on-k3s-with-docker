terraform {
  required_providers {
    coder = {
      source  = "coder/coder"
      version = "0.6.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.12.1"
    }
    openstack = {
      source  = "terraform-provider-openstack/openstack"
      version = "~> 1.48.0"
    }
  }
}

variable "use_kubeconfig" {
  type        = bool
  sensitive   = true
  description = <<-EOF
  Use host kubeconfig? (true/false)

  Set this to false if the Coder host is itself running as a Pod on the same
  Kubernetes cluster as you are deploying workspaces to.

  Set this to true if the Coder host is running outside the Kubernetes cluster
  for workspaces.  A valid "~/.kube/config" must be present on the Coder host.
  EOF
}

variable "namespace" {
  type        = string
  sensitive   = true
  description = "The namespace to create workspaces in (must exist prior to creating workspaces)"
}

variable "repository" {
  type        = string
  description = "Name of the repository to clone"
  default = ""
}

variable "branch" {
  type        = string
  description = "Branch of the repository to clone"
  default = ""
}

variable "home_disk_size" {
  type        = number
  description = "How large would you like your home volume to be (in GB)?"
  default     = 10
  validation {
    condition     = var.home_disk_size >= 1
    error_message = "Value must be greater than or equal to 1."
  }
}

provider "kubernetes" {
  # Authenticate via ~/.kube/config or a Coder-specific ServiceAccount, depending on admin preferences
  config_path = var.use_kubeconfig == true ? "~/.kube/config" : null
}

data "coder_workspace" "me" {}

data "template_file" "startup_script" {
  template = "${file("./startup.sh")}"
  vars = {
    repository = "${var.repository}"
    branch = "${var.branch}"
    private_key = "${openstack_compute_keypair_v2.node-1.private_key}"
    node_1_ip = "${openstack_compute_instance_v2.node-1.access_ip_v4}"
  }
}
resource "coder_agent" "main" {
  os             = "linux"
  arch           = "amd64"
  startup_script = "${data.template_file.startup_script.rendered}"
}

# code-server
resource "coder_app" "code-server" {
  agent_id     = coder_agent.main.id
  slug         = "code-server"
  display_name = "code-server"
  icon         = "/icon/code.svg"
  url          = "http://localhost:13337?folder=/home/coder"
  subdomain    = false
  share        = "owner"

  healthcheck {
    url       = "http://localhost:13337/healthz"
    interval  = 3
    threshold = 10
  }
}

resource "coder_app" "pycharm1" {
  agent_id = coder_agent.main.id
  slug          = "pycharm1"  
  display_name  = "PyCharm"  
  icon          = "/icon/pycharm.svg"
  url           = "http://localhost:9001"
  subdomain     = false
  share         = "owner"

  healthcheck {
    url         = "http://localhost:9001/healthz"
    interval    = 6
    threshold   = 20
  }    
}

resource "kubernetes_persistent_volume_claim" "home" {
  metadata {
    name      = "coder-${lower(data.coder_workspace.me.owner)}-${lower(data.coder_workspace.me.name)}-home"
    namespace = var.namespace
  }
  wait_until_bound = false
  spec {
    access_modes = ["ReadWriteOnce"]
    resources {
      requests = {
        storage = "${var.home_disk_size}Gi"
      }
    }
  }
}

resource "kubernetes_pod" "main" {
  count = data.coder_workspace.me.start_count
  metadata {
    name      = "coder-${lower(data.coder_workspace.me.owner)}-${lower(data.coder_workspace.me.name)}"
    namespace = var.namespace
  }
  spec {
    service_account_name = "coder"
    security_context {
      run_as_user = "1000"
      fs_group    = "1000"
    }    
    container {
      name    = "dev"
      image   = "laurentiusoica/coder:0.0.6"
      command = ["sh", "-c", coder_agent.main.init_script]
      security_context {
        run_as_user = "1000"
      }      
      env {
        name  = "CODER_AGENT_TOKEN"
        value = coder_agent.main.token
      }
      volume_mount {
        mount_path = "/home/coder"
        name       = "home"
        read_only  = false
      }
      volume_mount {
        mount_path = "/var/run"
        name       = "docker-sock"
      }
    }

    volume {
      name = "home"
      persistent_volume_claim {
        claim_name = kubernetes_persistent_volume_claim.home.metadata.0.name
        read_only  = false
      }
    }
    volume {
      name = "docker-sock"
      host_path {
        path = "/var/run"
      }
    }
  }
}

provider "openstack" {
  user_name   = "laurentiu.soica"
  tenant_name = "nci-ui"
  password    = "parola"
  auth_url    = "http://10.40.143.254:5000"
  region      = "RegionOne"
}

resource "openstack_compute_keypair_v2" "node-1" {
  name = "${lower(data.coder_workspace.me.name)}"
}

resource "openstack_compute_instance_v2" "node-1" {
  name            = "node-1"
  image_name      = "rhel8.4-fromiso"
  flavor_name     = "m1.small"
  key_pair        = "${lower(data.coder_workspace.me.name)}"
  security_groups = ["default"]
  availability_zone = "nci-ui"

  network {
    name = "ui-private-network"
  }
}