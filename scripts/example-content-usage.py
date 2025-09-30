#!/usr/bin/env python3
"""
Example script showing how to use the content management system.
This demonstrates reading and using the structured content.
"""

import yaml
from pathlib import Path
from typing import Dict, List, Any


class ContentManager:
    """Simple content manager for reading structured content."""
    
    def __init__(self, content_dir: Path):
        self.content_dir = content_dir
    
    def load_services(self) -> List[Dict[str, Any]]:
        """Load all services."""
        with open(self.content_dir / 'services' / 'services.yaml') as f:
            data = yaml.safe_load(f)
        return data.get('services', [])
    
    def load_hosts(self) -> List[Dict[str, Any]]:
        """Load all hosts."""
        with open(self.content_dir / 'hosts' / 'hosts.yaml') as f:
            data = yaml.safe_load(f)
        return data.get('hosts', [])
    
    def load_tools(self) -> Dict[str, List[Dict[str, Any]]]:
        """Load all tools organized by category."""
        with open(self.content_dir / 'tools' / 'tools.yaml') as f:
            return yaml.safe_load(f)
    
    def get_enabled_services(self) -> List[Dict[str, Any]]:
        """Get only enabled services."""
        return [s for s in self.load_services() if s.get('enabled', True)]
    
    def get_services_by_category(self, category: str) -> List[Dict[str, Any]]:
        """Get services in a specific category."""
        return [s for s in self.load_services() if s.get('category') == category]
    
    def get_active_hosts(self) -> List[Dict[str, Any]]:
        """Get only active hosts."""
        return [h for h in self.load_hosts() if h.get('active', True)]


def main():
    # Initialize content manager
    content_dir = Path(__file__).parent.parent / 'content'
    cm = ContentManager(content_dir)
    
    # Example 1: List all enabled services
    print("🚀 Enabled Services")
    print("=" * 50)
    enabled = cm.get_enabled_services()
    for service in enabled:
        print(f"• {service['name']:20} - {service['description']}")
    print(f"\nTotal: {len(enabled)} services\n")
    
    # Example 2: List services by category
    print("📊 Media Services")
    print("=" * 50)
    media = cm.get_services_by_category('media')
    for service in media:
        status = "✓" if service.get('enabled', True) else "✗"
        print(f"[{status}] {service['name']:15} - {service['description']}")
    print()
    
    # Example 3: List active hosts
    print("💻 Active Hosts")
    print("=" * 50)
    hosts = cm.get_active_hosts()
    for host in hosts:
        print(f"• {host['hostname']:15} ({host['type']:10}) - {host['description']}")
    print()
    
    # Example 4: List tools by category
    print("🛠️  Graphical Tools")
    print("=" * 50)
    tools = cm.load_tools()
    for tool in tools.get('graphical', [])[:5]:  # Show first 5
        print(f"• {tool['name']:20} - {tool['description']}")
    print(f"... and {len(tools.get('graphical', [])) - 5} more\n")
    
    # Example 5: Generate a simple report
    print("📈 Content Summary")
    print("=" * 50)
    print(f"Services: {len(cm.load_services())} total, {len(cm.get_enabled_services())} enabled")
    print(f"Hosts:    {len(cm.load_hosts())} total, {len(cm.get_active_hosts())} active")
    
    all_tools = sum(len(tools) for tools in cm.load_tools().values())
    print(f"Tools:    {all_tools} total across all categories")


if __name__ == '__main__':
    main()
