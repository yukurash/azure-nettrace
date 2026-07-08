## What

<!-- What does this PR add/change? -->

## Sanitization checklist (public repo — mandatory)

- [ ] No real subscription / tenant / object GUIDs (only zeroed placeholders like `00000000-0000-0000-0000-000000000000`)
- [ ] No real resource names, host names or IP addresses from live environments (use `contoso-*`)
- [ ] No e-mail addresses or `*.onmicrosoft.com` tenant domains
- [ ] No connection strings, keys, SAS tokens or passwords (masked as `***MASKED***`)
- [ ] Any example output went through `scripts/sanitize.ps1` **and** a manual review
