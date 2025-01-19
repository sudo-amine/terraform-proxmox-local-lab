variable "control_plane" {
  type = object({
    count          = number
    first_id       = string
    names_prefix   = string
    ip_range_start = number
    disk_size      = string
    cores          = number
    memory         = number
  })
}

variable "workers" {
  type = object({
    count          = number
    first_id       = string
    names_prefix   = string
    ip_range_start = number
    disk_size      = string
    cores          = number
    memory         = number
  })
}


variable "network" {
  type = object({
    bridge         = string
    gateway        = string
    subnet         = string
    gateway_subnet = string
  })
}

variable "storage" {
  type = object({
    local = string
    main  = string
  })
}

variable "vm_template" {
  type = object({
    id        = string
    name      = string
    ip        = string
    image_url = string
    disk_size = string
  })
}
