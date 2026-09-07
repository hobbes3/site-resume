# PROVIDER CONFIGURATION & VARIABLES

terraform {
  required_version = "1.16.1"

  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "5.24.0"
    }
  }

  # S3-compatible backend for OpenTofu state storage
  backend "s3" {
    bucket                      = "site-resume-tfstate"
    key                         = "cloudflare/terraform.tfstate"
    region                      = "auto"
    profile                     = "site-resume"
    endpoints                   = { 
      s3 = "https://ecb38e99c15d28c64e8794aeca162eac.r2.cloudflarestorage.com"
    }
    skip_credentials_validation = true
    skip_region_validation      = true
    skip_requesting_account_id  = true
    skip_metadata_api_check     = true
    use_path_style              = true
    use_lockfile                = true
  }
}

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}

# --- Sensitive Credentials ---

variable "cloudflare_api_token" {
  type        = string
  description = "Cloudflare API Token with Zone and Access management permissions"
  sensitive   = true
}

variable "github_client_secret" {
  type        = string
  description = "Client Secret for GitHub OAuth Application used in Zero Trust SSO"
  sensitive   = true
}

# --- Infrastructure Variables ---

variable "dns_records" {
  type = map(object({
    name    = string
    content = string
  }))
  description = "Map of primary CNAME routing definitions for domain endpoints"
  default = {
    "root"   = { name = "@", content = "site-resume-618.pages.dev" }
    "resume" = { name = "resume", content = "hobbes3.com" }
    "fec"    = { name = "fec", content = "site-fec-2016.pages.dev" }
    "www"    = { name = "www", content = "site-resume-618.pages.dev" }
  }
}

# RESOURCE DEFINITIONS

# Cloudflare Pages Deployments

# Main resume project
resource "cloudflare_pages_project" "site" {
  account_id        = "ecb38e99c15d28c64e8794aeca162eac"
  name              = "site-resume"
  production_branch = "main"
}

# Legacy FEC 2016 archive project
resource "cloudflare_pages_project" "fec_2016" {
  account_id        = "ecb38e99c15d28c64e8794aeca162eac"
  name              = "site-fec-2016"
  production_branch = "master"

  lifecycle {
    ignore_changes = [source]
  }
}

# Traffic Routing & Redirects

# 301 Permanent Redirect for short resume link
resource "cloudflare_page_rule" "resume_redirect" {
  zone_id  = "f3528c90e0b1c9516a279b76be10da07"
  target   = "resume.hobbes3.com/*"
  status   = "active"
  priority = 1

  actions = {
    forwarding_url = {
      status_code = 301
      url         = "https://hobbes3.com/resumes/hobbes3_resume_latest.pdf"
    }
  }
}

# DNS Records (Zone: hobbes3.com)

# CNAME endpoints
resource "cloudflare_dns_record" "records" {
  for_each = var.dns_records
  zone_id  = "f3528c90e0b1c9516a279b76be10da07"
  name     = each.value.name
  type     = "CNAME"
  content  = each.value.content
  ttl      = 1
  proxied  = true
}

# MX Routing (Cloudflare Email Routing)
resource "cloudflare_dns_record" "mx1" {
  zone_id  = "f3528c90e0b1c9516a279b76be10da07"
  name     = "@"
  type     = "MX"
  content  = "route1.mx.cloudflare.net"
  priority = 40
  ttl      = 1
}

resource "cloudflare_dns_record" "mx2" {
  zone_id  = "f3528c90e0b1c9516a279b76be10da07"
  name     = "@"
  type     = "MX"
  content  = "route2.mx.cloudflare.net"
  priority = 82
  ttl      = 1
}

resource "cloudflare_dns_record" "mx3" {
  zone_id  = "f3528c90e0b1c9516a279b76be10da07"
  name     = "@"
  type     = "MX"
  content  = "route3.mx.cloudflare.net"
  priority = 89
  ttl      = 1
}

# Email Security & Authentication (SPF, DMARC, DKIM)
resource "cloudflare_dns_record" "spf" {
  zone_id = "f3528c90e0b1c9516a279b76be10da07"
  name    = "@"
  type    = "TXT"
  content = "v=spf1 include:_spf.mx.cloudflare.net ~all"
  ttl     = 1
}

resource "cloudflare_dns_record" "dmarc" {
  zone_id = "f3528c90e0b1c9516a279b76be10da07"
  name    = "_dmarc"
  type    = "TXT"
  content = "v=DMARC1; p=none; rua=mailto:0874192e7644485da391ab8d68d1c498@dmarc-reports.cloudflare.net"
  ttl     = 1
}

resource "cloudflare_dns_record" "dkim" {
  zone_id = "f3528c90e0b1c9516a279b76be10da07"
  name    = "cf2024-1._domainkey"
  type    = "TXT"
  content = "v=DKIM1; h=sha256; k=rsa; p=MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAiweykoi+o48IOGuP7GR3X0MOExCUDY/BCRHoWBnh3rChl7WhdyCxW3jgq1daEjPPqoi7sJvdg5hEQVsgVRQP4DcnQDVjGMbASQtrY4WmB1VebF+RPJB2ECPsEDTpeiI5ZyUAwJaVX7r6bznU67g7LvFq35yIo4sdlmtZGV+i0H4cpYH9+3JJ78km4KXwaf9xUJCWF6nxeD+qG6Fyruw1Qlbds2r85U9dkNDVAS3gioCvELryh1TxKGiVTkg4wqHTyHfWsp7KD3WQHYJn0RyfJJu6YEmL77zonn7p2SRMvTMP3ZEXibnC9gz3nnhR6wcYL8Q7zXypKTMD58bTixDSJwIDAQAB"
  ttl     = 1

  lifecycle {
    ignore_changes = [content]
  }
}

# Zero Trust Access Control (Pages Preview Deployment Protection)

# GitHub Identity Provider Integration for Zero Trust SSO
resource "cloudflare_zero_trust_access_identity_provider" "github_sso" {
  account_id = "ecb38e99c15d28c64e8794aeca162eac"
  name       = "GitHub SSO"
  type       = "github"

  config = {
    client_id     = "Ov23liVrM7tRDqiP4rNQ"
    client_secret = var.github_client_secret
  }
}

# Standalone Policy: StackHawk Service Auth
resource "cloudflare_zero_trust_access_policy" "stackhawk_service_auth" {
  account_id       = "ecb38e99c15d28c64e8794aeca162eac"
  name             = "Service Token - StackHawk Scanner"
  decision         = "non_identity"
  session_duration = "15m"

  include = [
    {
      service_token = {
        token_id = "3e4a836a-79f3-41b3-85fc-ba5deac0b273" # betterleaks:allow
      }
    }
  ]
}

# Standalone Policy: Restricted Owners SSO
resource "cloudflare_zero_trust_access_policy" "allow_owners" {
  account_id       = "ecb38e99c15d28c64e8794aeca162eac"
  name             = "Allow Owners SSO and PIN"
  decision         = "allow"
  session_duration = "15m"

  include = [
    {
      login_method = {
        id = cloudflare_zero_trust_access_identity_provider.github_sso.id
      }
    },
    {
      login_method = {
        id = "337223b3-6f42-4502-9b4b-2339d55f60ef"
      }
    }
  ]
  require = [
    {
      email = {
        email = "hobbes3@gmail.com"
      }
    }
  ]
}

# Base Application referencing Reusable Policy IDs
resource "cloudflare_zero_trust_access_application" "site_resume_preview" {
  account_id                = "ecb38e99c15d28c64e8794aeca162eac"
  name                      = "site-resume - Cloudflare Pages"
  domain                    = "*.site-resume-618.pages.dev"
  type                      = "self_hosted"
  session_duration          = "15m"
  auto_redirect_to_identity = false

  policies = [
    {
      id         = cloudflare_zero_trust_access_policy.stackhawk_service_auth.id
      precedence = 1
    },
    {
      id         = cloudflare_zero_trust_access_policy.allow_owners.id
      precedence = 2
    }
  ]
}

# HTTP Response Header Transformation Rules
resource "cloudflare_ruleset" "response_header_transforms" {
  zone_id     = "f3528c90e0b1c9516a279b76be10da07"
  name        = "Security Response Headers"
  description = "Enforce HSTS, CSP, and security headers zone-wide"
  kind        = "zone"
  phase       = "http_response_headers_transform"

  rules = [
    # Global HTTP Security Policies (Excludes /reports/* and fec.hobbes3.com)
    {
      action      = "rewrite"
      description = "Apply standard zone-wide security response headers"
      expression  = "(http.request.uri.path ne \"/reports/*\" and http.host ne \"fec.hobbes3.com\")"

      action_parameters = {
        headers = {
          "Content-Security-Policy"   = { operation = "set", value = "default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'; img-src 'self' data:; font-src 'self';" }
          "X-Frame-Options"           = { operation = "set", value = "DENY" }
          "X-Content-Type-Options"    = { operation = "set", value = "nosniff" }
          "Referrer-Policy"           = { operation = "set", value = "strict-origin-when-cross-origin" }
          "Permissions-Policy"        = { operation = "set", value = "camera=(), microphone=(), geolocation=(), payment=()" }
          "Strict-Transport-Security" = { operation = "set", value = "max-age=31536000; includeSubDomains; preload" }
        }
      }
    },
    # Relaxed Policies for /reports/* Subpaths
    {
      action      = "rewrite"
      description = "Apply relaxed security headers and CORS policy for report assets"
      expression  = "starts_with(http.request.uri.path, \"/reports/\")"

      action_parameters = {
        headers = {
          "Content-Security-Policy"   = { operation = "set", value = "default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline'; img-src 'self' data:; font-src 'self';" }
          "Access-Control-Allow-Origin"  = { operation = "set", value = "*" }
          "Access-Control-Allow-Methods" = { operation = "set", value = "GET, HEAD, OPTIONS" }
          "X-Frame-Options"           = { operation = "set", value = "DENY" }
          "X-Content-Type-Options"    = { operation = "set", value = "nosniff" }
          "Referrer-Policy"           = { operation = "set", value = "strict-origin-when-cross-origin" }
          "Permissions-Policy"        = { operation = "set", value = "camera=(), microphone=(), geolocation=(), payment=()" }
          "Strict-Transport-Security" = { operation = "set", value = "max-age=31536000; includeSubDomains; preload" }
        }
      }
    }
  ]
}
