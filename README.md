# [hobbes3.com](https://hobbes3.com)

[![CI/CD Pipeline](https://img.shields.io/github/actions/workflow/status/hobbes3/site-resume/ci-cd.yaml?branch=main&label=CI%2FCD&logo=githubactions&logoColor=white)](https://github.com/hobbes3/site-resume/actions/workflows/ci-cd.yaml)
[![Renovate](https://img.shields.io/badge/renovate-enabled-brightgreen?logo=renovate&logoColor=white)](https://github.com/hobbes3/site-resume/issues/6)
[![CodeQL](https://img.shields.io/badge/CodeQL-enabled-blue?logo=github&logoColor=white)](https://github.com/hobbes3/site-resume/security/code-scanning/tools/CodeQL/status)
[![Grype](https://img.shields.io/badge/Grype-vulnerability_scan-blue?logo=anchore&logoColor=white)](https://github.com/hobbes3/site-resume/security/code-scanning/tools/Grype/status)
[![StackHawk](https://img.shields.io/badge/StackHawk-HawkScan-00C4B3?logo=stackhawk&logoColor=white)](https://github.com/hobbes3/site-resume/security/code-scanning/tools/HawkScan/status)
[![Betterleaks](https://img.shields.io/badge/betterleaks-secret_scan-red?logo=1password&logoColor=white)](https://github.com/hobbes3/site-resume/security/code-scanning/tools/betterleaks/status)
[![Lighthouse Report](https://img.shields.io/badge/Lighthouse-Report-informational?logo=lighthouse&logoColor=white)](https://hobbes3.com/reports/lhr-latest.html)

My personal portfolio and resume website built with lightweight semantic HTML5, TypeScript, and SASS, bundled with Vite.

## OpenTofu

For local infrastructure commands, use the `site-resume` profile from `~/.aws/credentials`:

```sh
export AWS_PROFILE=site-resume
cd opentofu
tofu init -reconfigure
tofu plan
```
