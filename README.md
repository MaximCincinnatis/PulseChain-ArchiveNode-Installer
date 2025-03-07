# PulseChain Archive Node Installer

A comprehensive toolkit for installing, configuring, monitoring, and maintaining PulseChain Archive Nodes.

![PulseChain Logo](https://pulsechain.com/img/logo.png)

## 📋 Overview

This project provides a suite of shell scripts that simplify the process of running a PulseChain Archive Node. Whether you're a blockchain developer, validator, or enthusiast, these scripts help you set up and maintain a reliable node with minimal technical effort.

**⚠️ ALPHA RELEASE**: This software is currently in alpha stage. Expect potential bugs, incomplete features, and changes in future versions. Use in production environments at your own risk.

An Archive Node stores the complete history of the blockchain, allowing you to query any historical state. This is particularly valuable for developers, data analysts, and services that need to access historical blockchain data.

## ✨ Features

- **Simple Installation**: One-command setup process with both interactive and automatic options
- **Network Options**: Support for both PulseChain Mainnet and Testnet v4
- **Container-Based**: Uses Docker containers for clean, isolated deployment
- **Monitoring Tools**: Real-time status checks and multi-window dashboard
- **Auto Recovery**: Automatic detection and resolution of common node issues
- **Performance Tuning**: Configurable parameters to optimize for your hardware
- **Easy Management**: Simple commands for starting, stopping, and restarting your node
- **Desktop Integration**: Optional desktop shortcuts for common operations

## 🖥️ System Requirements

- **Operating System**: Ubuntu Linux (18.04 LTS or newer)
- **CPU**: 4+ cores recommended
- **RAM**: 16GB+ recommended
- **Storage**: 1TB+ SSD or NVMe recommended (Archive nodes store the complete state history)
- **Network**: Stable internet connection with open ports

## 🚀 Quick Installation

For a rapid setup, run:

```bash
curl -sSL https://raw.githubusercontent.com/MaximCincinnatis/PulseChain-ArchiveNode-Installer/main/install-quick.sh | bash
```

This will download and run the installer with default settings.

## 📦 Manual Installation

For more control over the installation process:

1. Clone the repository:
   ```bash
   git clone https://github.com/MaximCincinnatis/PulseChain-ArchiveNode-Installer.git
   cd PulseChain-ArchiveNode-Installer
   ```

2. Make the install script executable:
   ```bash
   chmod +x install.sh
   ```

3. Run the installer:
   ```bash
   ./install.sh
   ```

4. Follow the interactive prompts to configure your node

## 📊 Node Management

After installation, you'll have access to the following commands:

| Script | Description |
|--------|-------------|
| `./monitor-node.sh` | Display detailed node status including sync progress, peer count, and resource usage |
| `./restart.sh` | Start or restart the node containers |
| `./shutdown.sh` | Gracefully stop the node containers |
| `./edit-parameters.sh` | Modify node configuration parameters |
| `./check-node.sh` | Quick status check of your node |
| `./monitor-dashboard.sh` | Launch a multi-window monitoring dashboard |
| `./upgrade.sh` | Update the installer scripts to the latest version |

## 🔧 Configuration Options

The node can be configured during installation or later using the `edit-parameters.sh` script. Key configuration options include:

- **Network**: PulseChain Mainnet or Testnet v4
- **Data Directory**: Location to store blockchain data
- **Max Peers**: Maximum number of network peers (affects bandwidth)
- **Cache Size**: Memory allocation for database caching (affects performance)

For a complete list of configuration options, see the [node-options.md](node-options.md) file.

## 🔄 Auto Recovery

The installer can set up an automatic recovery system that:

- Monitors node health at regular intervals
- Detects when containers stop running
- Identifies stuck synchronization
- Restarts services when issues are detected
- Alerts on low disk space

To enable auto-recovery:

```bash
# During installation, select "Yes" when prompted to enable auto-recovery
# Or manually add to crontab:
crontab -e
# Add this line to run every 10 minutes:
*/10 * * * * /path/to/auto-recovery.sh >> /path/to/logs/recovery.log 2>&1
```

## 📝 Logging

- Container logs can be viewed with:
  ```bash
  docker logs -f go-pulse    # Execution client logs
  docker logs -f lighthouse  # Consensus client logs
  ```

- Recovery logs (if auto-recovery is enabled) are stored in the logs directory

## ❓ Troubleshooting

Common issues and solutions:

- **Node not syncing**: Check your internet connection and run `./restart.sh`
- **Low peer count**: Ensure ports 30303 and 9000 are open in your firewall
- **Containers won't start**: Check Docker status with `systemctl status docker`
- **High disk usage**: Archive nodes require significant storage; consider upgrading or using a non-archive node if space is limited

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

### Contribution Guidelines

When contributing to this project, please follow these best practices:

- **Security First**: Never commit sensitive information (API keys, passwords, private keys)
- **Code Style**: Follow the existing code style and shell scripting best practices
- **Documentation**: Update documentation for any new features or changes
- **Testing**: Test your changes thoroughly before submitting a PR
- **Environment Variables**: Use the .env.example file as a template for any new configuration options
- **Backwards Compatibility**: Ensure changes don't break existing installations

### Development Setup

For development, we recommend:

1. Setting up a test environment with a small test blockchain
2. Using shellcheck for bash script validation
3. Testing on both mainnet and testnet configurations

## 📜 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Credits

- PulseChain team for developing the underlying node software (go-pulse and lighthouse)

## 🔒 Security Considerations

Running a blockchain node requires attention to security. Please consider the following:

- **Network Exposure**: Some configuration options (like `--http.addr=0.0.0.0`) expose your node's API to the network. Only use these if you have proper firewall rules in place.
- **Permissions**: All configuration files and JWT tokens should have restrictive permissions (this installer sets them up correctly).
- **Regular Updates**: Keep your node software updated to patch security vulnerabilities.
- **Resource Monitoring**: Monitor system resources to prevent denial-of-service situations.
- **Backup Security**: If you back up node data, ensure the backups are stored securely.
- **No Sensitive Data**: Never store private keys or wallet credentials on your node server.

For additional security, consider:
- Using a dedicated user account for running the node
- Implementing IP-based access control for your node's API endpoints
- Setting up fail2ban to prevent brute force attempts
- Regular security audits of your server

## ⚠️ Disclaimer

This is unofficial software created by community members and is currently in **ALPHA** stage. Always verify the authenticity of blockchain tools before running them on your system. Running a node involves certain risks including bandwidth usage, system resource consumption, and potential exposure to network-based attacks. The software may contain bugs or issues as development continues. 