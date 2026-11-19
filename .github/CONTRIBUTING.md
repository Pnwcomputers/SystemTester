# Contributing to SystemTester

Thank you for your interest in contributing to SystemTester! This document provides guidelines and information for contributors.

## 📚 Table of Contents
- [🎯 Ways to Contribute](#-ways-to-contribute)
- [🔄 Development Process](#-development-process)
- [📋 Code Review Process](#-code-review-process)
- [🏷 Commit Message Format](#-commit-message-format)
- [🔒 Security Issues](#-security-issues)
- [📞 Getting Help](#-getting-help)
- [🙏 Recognition](#-recognition)

## 🎯 Ways to Contribute

### 🐛 Bug Reports
- Use the bug report template
- Include system information and logs
- Provide clear reproduction steps

### 💡 Feature Requests
- Use the feature request template
- Explain the use case and business value
- Consider implementation complexity

### 🔧 Code Contributions
- Fork the repository
- Create a feature branch
- Follow PowerShell best practices
- Add tests for new functionality
- Update documentation

### 📖 Documentation
- Improve README clarity
- Add configuration examples
- Create troubleshooting guides
- Fix typos and formatting

## 🔄 Development Process

### Setting Up Development Environment
1. Fork the repository
2. Clone your fork locally
3. Create a feature branch: `git checkout -b feature/your-feature-name`
4. Make your changes
5. Test thoroughly on multiple Windows versions
6. Commit with clear messages
7. Push to your fork
8. Create a pull request

### PowerShell Style Guidelines
- Use approved verbs for function names
- Follow PascalCase for functions and variables
- Use meaningful variable names
- Include comment-based help for functions
- Handle errors gracefully
- Use Write-Log for consistent logging

### Testing Requirements
- Test on Windows 10 and 11
- Test both domain and workgroup environments
- Verify offline functionality
- Check with different hardware configurations
- Use virtual machines or sandbox environments when possible
- Validate behavior with and without admin rights
- Test with missing or partial Sysinternals tools to confirm graceful degradation

## ✅ Pull Request Checklist
- [ ] Code follows PowerShell style guidelines
- [ ] New functionality includes tests
- [ ] Documentation is updated
- [ ] Changes tested on Windows 10 and 11
- [ ] No sensitive data included

## 📋 Code Review Process

1. **Automated Checks**: PR must pass all automated tests
2. **Manual Review**: Maintainer reviews code and functionality
3. **Testing**: Changes tested in real deployment scenarios
4. **Documentation**: Ensure documentation is updated
5. **Approval**: Maintainer approves and merges PR

## 🏷 Commit Message Format

Use conventional commits format:

Examples:
- `feat(installer): add support for custom MSI packages`
- `fix(logging): resolve log file permission issues`
- `docs(readme): update installation instructions`
- `test(core): add unit tests for bloatware removal`

## 🔒 Security Issues

For security-related issues:
1. **DO NOT** open a public issue
2. Email security@pnwcomputers.com
3. Include proof of concept (if safe)
4. Allow reasonable time for response

## 📞 Getting Help

- Check existing issues and documentation
- Join discussions in GitHub Discussions
- Email support@pnwcomputers.com for questions

## 🙏 Recognition

Contributors will be recognized in:
- CHANGELOG.md for significant contributions
- README.md for major features
- GitHub contributors page

We’re excited to collaborate with you! Whether it’s a typo fix or a new feature, your contribution makes a difference.
