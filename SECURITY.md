# Security Policy

## Reporting a Vulnerability

We take the security of the PulseChain Archive Node Installer seriously. If you believe you've found a security vulnerability, please follow these steps:

1. **Do NOT disclose the vulnerability publicly** (no GitHub issues for security vulnerabilities)
2. Email the maintainer directly at [your-email@example.com] (replace with your actual email)
3. Include detailed information about the vulnerability:
   - Description of the issue
   - Steps to reproduce
   - Potential impact
   - Suggested fix (if available)

We will acknowledge receipt of your report within 48 hours and provide an estimated timeline for a fix.

## Security Best Practices for Node Operators

When running a PulseChain node using this software, consider the following security practices:

### System Security
- Keep your operating system and all software up to date
- Use a firewall to restrict access to only necessary ports
- Install and configure fail2ban to prevent brute force attacks
- Regularly audit your system for unauthorized access

### Node Configuration Security
- Never expose your node's RPC interface directly to the internet without proper authentication
- If you must expose RPC endpoints, use:
  - Strong authentication methods
  - HTTPS with valid certificates
  - IP address whitelisting
- Run the node under a dedicated user account with limited privileges
- Configure file permissions properly (the installer handles this, but verify)

### Resource Protection
- Monitor system resources to prevent denial-of-service situations
- Set up alerts for abnormal resource usage
- Implement rate limiting for API endpoints if exposed

### Data Protection
- Backup your node data regularly
- Store backups securely with encryption
- Never store private keys or wallet credentials on your node server

## Security Updates

We will publish security updates as they become available. To stay informed:

1. Watch this repository for updates
2. Regularly run the `./upgrade.sh` script to get the latest security patches
3. Check the releases page for security-related announcements

## Verification

All official releases are signed. We encourage you to verify signatures before installing or upgrading. 