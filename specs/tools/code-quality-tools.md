# Code Quality Enhancement Tools

This document outlines the code quality tools integrated into the HeyHo Sync backend project to improve development productivity, code consistency, and security.

## 1. RuboCop - Code Linting and Formatting

### Overview
RuboCop is a Ruby static code analyzer and formatter that enforces the Ruby Style Guide and helps maintain consistent code across the project.

### Purpose
- **Consistency**: Ensures uniform code style across the entire codebase
- **Error Prevention**: Catches potential bugs and syntax errors before runtime
- **Best Practices**: Enforces Ruby community standards and conventions
- **Learning Tool**: Helps developers learn idiomatic Ruby patterns

### Configuration
The tool is configured via `.rubocop.yml` file in the project root with Rails-specific defaults.

### Usage
```bash
# Run linter to check for issues
make lint

# Automatically fix correctable issues
make lint:fix

# Check specific files or directories
bundle exec rubocop app/controllers

# Generate a TODO file for existing violations
bundle exec rubocop --auto-gen-config
```

### Common Rules Enforced
- Line length limits (typically 120 characters)
- Proper indentation (2 spaces for Ruby)
- Method complexity and length limits
- Consistent string literal style
- Proper naming conventions (snake_case for methods, CamelCase for classes)

## 2. Brakeman - Security Scanning

### Overview
Brakeman is a static analysis security vulnerability scanner specifically designed for Ruby on Rails applications.

### Purpose
- **Vulnerability Detection**: Identifies common security issues without running the application
- **OWASP Coverage**: Checks for OWASP Top 10 vulnerabilities
- **False Positive Management**: Provides mechanisms to ignore false positives
- **Continuous Security**: Enables security checks as part of CI/CD pipeline

### Security Issues Detected
- SQL Injection vulnerabilities
- Cross-Site Scripting (XSS)
- Mass Assignment problems
- Open Redirects
- Unsafe Deserialization
- Command Injection
- File Access vulnerabilities
- Weak Authentication
- Information Disclosure
- Cross-Site Request Forgery (CSRF)

### Usage
```bash
# Run security scan
make security-check

# Generate detailed HTML report
bundle exec brakeman -o brakeman-report.html

# Run with specific confidence level
bundle exec brakeman -w 3  # Only high confidence warnings

# Interactive mode for reviewing issues
bundle exec brakeman -I
```

### Ignoring False Positives
Create a `config/brakeman.ignore` file to suppress false positives after careful review.

## 3. Lefthook - Git Hooks Management

### Overview
Lefthook is a fast and powerful Git hooks manager that automates code quality checks before commits and pushes.

### Purpose
- **Automated Quality Gates**: Runs checks automatically before code enters the repository
- **Fail-Fast Approach**: Catches issues at the earliest possible stage
- **Developer Experience**: Provides fast feedback without manual intervention
- **Team Consistency**: Ensures all team members run the same checks

### Configuration
Configured via `lefthook.yml` in the project root.

### Hooks Configuration
```yaml
pre-commit:
  parallel: true
  commands:
    rubocop:
      glob: "*.rb"
      run: bundle exec rubocop {staged_files}
    rspec:
      glob: "spec/**/*.rb"
      run: bundle exec rspec {staged_files}

pre-push:
  commands:
    security:
      run: bundle exec brakeman -q
```

### Usage
```bash
# Install hooks
lefthook install

# Run hooks manually
lefthook run pre-commit

# Skip hooks temporarily
git commit --no-verify -m "Emergency fix"

# Uninstall hooks
lefthook uninstall
```

## 4. YARD - Documentation Generation

### Overview
YARD (Yet Another Ruby Documentation tool) is a documentation generation framework for Ruby that produces readable API documentation.

### Purpose
- **API Documentation**: Generates comprehensive API documentation from code comments
- **Type Information**: Documents parameter types and return values
- **Examples**: Includes usage examples directly in documentation
- **Browsable Output**: Creates HTML documentation that can be hosted

### Documentation Syntax
```ruby
# Processes a synchronization request for the given resource
#
# @param resource_type [String] the type of resource to sync
# @param options [Hash] synchronization options
# @option options [Boolean] :force (false) force synchronization even if up-to-date
# @option options [Integer] :batch_size (100) number of records to process at once
#
# @return [SyncResult] the result of the synchronization operation
#
# @raise [InvalidResourceError] if the resource type is not supported
# @raise [SyncTimeoutError] if the operation exceeds the timeout threshold
#
# @example Basic usage
#   sync_service.process('users', force: true)
#
# @example With custom batch size
#   sync_service.process('orders', batch_size: 50)
#
# @see SyncResult
# @see #validate_resource
#
# @since 1.0.0
def process(resource_type, options = {})
  # implementation
end
```

### Usage
```bash
# Generate documentation
make docs

# Generate and serve documentation locally
yard server --reload

# Generate documentation with specific options
yard doc --output-dir ./public/docs --plugin rails

# Check documentation coverage
yard stats --list-undoc
```

### Documentation Best Practices
1. Document all public methods
2. Include parameter types and descriptions
3. Provide usage examples for complex methods
4. Document exceptions that can be raised
5. Link related methods and classes
6. Keep documentation up-to-date with code changes

## Integration with Development Workflow

### Recommended Development Flow
1. **Write Code**: Implement your feature or fix
2. **Document**: Add YARD documentation for new/modified methods
3. **Lint**: Run `make lint:fix` to auto-correct style issues
4. **Test**: Ensure all tests pass with `make test`
5. **Security Check**: Run `make security-check` for vulnerability scanning
6. **Commit**: Lefthook automatically runs pre-commit checks
7. **Generate Docs**: Run `make docs` to update documentation

### Makefile Integration
All tools are integrated into the Makefile for consistency:
```makefile
lint:
	bundle exec rubocop

lint:fix:
	bundle exec rubocop -A

security-check:
	bundle exec brakeman -q

docs:
	bundle exec yard doc

quality-check: lint security-check test
	@echo "All quality checks passed!"
```

### Continuous Integration
These tools should be integrated into your CI/CD pipeline:
```yaml
# Example GitHub Actions workflow
- name: Run RuboCop
  run: bundle exec rubocop

- name: Run Brakeman
  run: bundle exec brakeman -q --no-pager

- name: Check Documentation Coverage
  run: yard stats --list-undoc --fail-on-warning
```

## Benefits Summary

### For Individual Developers
- Learn best practices through automated feedback
- Catch bugs early in development cycle
- Maintain consistent personal coding style
- Build better documentation habits

### For Teams
- Unified code style across all contributors
- Reduced code review friction
- Automated security awareness
- Self-documenting codebase
- Lower onboarding time for new developers

### For the Project
- Higher code quality and maintainability
- Reduced technical debt
- Better security posture
- Professional documentation
- Easier debugging and troubleshooting

## Troubleshooting

### RuboCop Issues
- **Too many offenses**: Use `--auto-gen-config` to create a TODO file
- **Disagreement with rules**: Customize `.rubocop.yml` configuration
- **Performance issues**: Use `--cache` flag or configure cache directory

### Brakeman False Positives
- Review each warning carefully
- Use `--interactive` mode to create ignore file
- Document why warnings are ignored in comments

### Lefthook Not Running
- Ensure hooks are installed: `lefthook install`
- Check Git hooks directory: `ls .git/hooks/`
- Verify Lefthook configuration: `lefthook validate`

### YARD Documentation Issues
- **Missing documentation**: Use `yard stats` to identify undocumented code
- **Incorrect formatting**: Validate syntax with `yard parse --fail-on-warning`
- **Large codebase**: Use `.yardopts` file for consistent options

## Resources

- [RuboCop Documentation](https://docs.rubocop.org/)
- [Brakeman Guide](https://brakemanscanner.org/docs/)
- [Lefthook Documentation](https://github.com/evilmartians/lefthook/wiki)
- [YARD Getting Started](https://yardoc.org/guides/index.html)
- [Ruby Style Guide](https://rubystyle.guide/)
- [Rails Security Guide](https://guides.rubyonrails.org/security.html)