#!/usr/bin/env python3
"""
Simple YAML validator for the content management system.
This script checks that YAML files are valid and warns about common issues.
"""

import sys
import yaml
from pathlib import Path


def validate_yaml_file(file_path: Path) -> tuple[bool, str]:
    """
    Validate a YAML file.
    Returns (is_valid, message)
    """
    try:
        with open(file_path, 'r') as f:
            data = yaml.safe_load(f)
        
        if data is None:
            return False, "File is empty or contains only comments"
        
        return True, "Valid YAML"
    except yaml.YAMLError as e:
        return False, f"YAML syntax error: {e}"
    except Exception as e:
        return False, f"Error reading file: {e}"


def validate_service(service: dict, index: int) -> list[str]:
    """Validate a service entry."""
    warnings = []
    required_fields = ['name', 'description', 'category']
    
    for field in required_fields:
        if field not in service:
            warnings.append(f"Service {index}: Missing required field '{field}'")
    
    if 'category' in service:
        valid_categories = [
            'budgeting', 'rss', 'git-forge', 'monitoring', 'remote-access',
            'homepage', 'gtd', 'media', 'notebook', 'sharing', 'irc',
            'calendar', 'reddit-client', 'youtube-client', 'self-management',
            'sync', 'password-manager', 'search-engine', 'library', 'torrent',
            'authentication', 'ai', 'automation', 'other'
        ]
        if service['category'] not in valid_categories:
            warnings.append(
                f"Service {index} ({service.get('name', '?')}): "
                f"Invalid category '{service['category']}'"
            )
    
    return warnings


def validate_services_file(file_path: Path) -> list[str]:
    """Validate the services YAML file."""
    warnings = []
    
    with open(file_path, 'r') as f:
        data = yaml.safe_load(f)
    
    if 'services' not in data:
        warnings.append("Missing 'services' key at top level")
        return warnings
    
    services = data['services']
    if not isinstance(services, list):
        warnings.append("'services' should be a list")
        return warnings
    
    for i, service in enumerate(services, 1):
        warnings.extend(validate_service(service, i))
    
    return warnings


def main():
    content_dir = Path(__file__).parent.parent / 'content'
    
    if not content_dir.exists():
        print("❌ Content directory not found!")
        return 1
    
    # Find all YAML files in content directory
    yaml_files = list(content_dir.rglob('*.yaml')) + list(content_dir.rglob('*.yml'))
    
    if not yaml_files:
        print("❌ No YAML files found in content directory")
        return 1
    
    print(f"🔍 Validating {len(yaml_files)} YAML file(s)...\n")
    
    all_valid = True
    total_warnings = 0
    
    for yaml_file in sorted(yaml_files):
        rel_path = yaml_file.relative_to(content_dir.parent)
        is_valid, message = validate_yaml_file(yaml_file)
        
        if is_valid:
            print(f"✅ {rel_path}: {message}")
            
            # Additional validation for services file
            if yaml_file.name == 'services.yaml':
                warnings = validate_services_file(yaml_file)
                if warnings:
                    print(f"⚠️  Warnings for {rel_path}:")
                    for warning in warnings:
                        print(f"   - {warning}")
                    total_warnings += len(warnings)
        else:
            print(f"❌ {rel_path}: {message}")
            all_valid = False
    
    print()
    if all_valid:
        if total_warnings > 0:
            print(f"⚠️  All files are valid YAML, but there are {total_warnings} warning(s)")
            print("   Review the warnings above to ensure content follows the schema")
            return 0
        else:
            print("🎉 All files are valid!")
            return 0
    else:
        print("💢 Some files have errors. Please fix them before committing.")
        return 1


if __name__ == '__main__':
    sys.exit(main())
