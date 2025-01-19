variable "api_url" {
  description = "The base URL of the Proxmox API"
  type        = string
}

variable "method" {
  description = "HTTP method to use (GET, POST, PUT, DELETE)"
  type        = string
}

variable "endpoint" {
  description = "The API endpoint to call (relative to the base URL)"
  type        = string
}

variable "headers" {
  description = "Optional HTTP headers to include in the request"
  type        = map(string)
  default     = {}
}

variable "body" {
  description = "Optional JSON body for POST/PUT requests"
  type        = string
  default     = "{}"
}

variable "query_params" {
  description = "Optional query parameters for the API request"
  type        = map(string)
  default     = {}
}

variable "auth_token" {
  description = "Proxmox API token for authentication"
  type        = string
  sensitive   = true
}

resource "null_resource" "proxmox_api_call" {
  provisioner "local-exec" {
    command = <<EOT
      set -x

      # Construct the query string if any query params exist
      query_string=""
      if [ ! -z "${jsonencode(var.query_params)}" ]; then
        for key in $(echo ${jsonencode(var.query_params)} | jq -r 'keys[]'); do
          value=$(echo ${jsonencode(var.query_params)} | jq -r ".[$key]")
          query_string="${query_string}${key}=${value}&"
        done
        query_string="?${query_string}"
      fi

      # Make the API request
      response=$(curl -s -w "%%{http_code}" --request "${var.method}" \
        --header "Authorization: PVEAPIToken=${var.auth_token}" \
        $(for key in $(echo '${jsonencode(var.headers)}' | jq -r 'keys[]'); do
          value=$(echo '${jsonencode(var.headers)}' | jq -r ".[$key]")
          echo --header "${key}: ${value}"
        done) \
        --header "Content-Type: application/json" \
        --data '${var.body}' \
        "${var.api_url}${var.endpoint}${query_string}")

      # Split the response and HTTP code
      http_code=$(echo "$response" | tail -c 4)
      body=$(echo "$response" | sed -e '$ d')

      # Handle response
      echo "HTTP Code: $http_code"
      if [ "$http_code" -ge 200 ] && [ "$http_code" -lt 300 ]; then
        echo "API call succeeded: $body"
      else
        echo "API call failed with HTTP code $http_code. Response: $body"
        exit 1
      fi
    EOT
  }
}

output "response" {
  description = "The body of the API response"
  value       = null_resource.proxmox_api_call.id
}
