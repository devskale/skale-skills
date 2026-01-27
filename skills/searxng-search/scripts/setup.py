#!/usr/bin/env python3
import json
import os
import getpass

def setup():
    """
    Interactive setup script for SearXNG Search skill.
    Prompts user for credentials and saves them to config.json.
    """
    script_dir = os.path.dirname(os.path.abspath(__file__))
    config_path = os.path.join(script_dir, "..", "config.json")
    
    print("=== SearXNG Search Skill Setup ===")
    print(f"Configuration will be saved to: {config_path}")
    
    if os.path.exists(config_path):
        print("\nExisting configuration found.")
        overwrite = input("Do you want to overwrite it? (y/N): ").lower()
        if overwrite != 'y':
            print("Setup cancelled.")
            return

    print("\nPlease enter your SearXNG credentials:")
    username = input("Username: ").strip()
    password = getpass.getpass("Password: ").strip()
    
    config = {
        "username": username,
        "password": password
    }
    
    try:
        with open(config_path, "w") as f:
            json.dump(config, f, indent=2)
        print(f"\nSuccess! Configuration saved to {config_path}")
        print("You can now use the search skill.")
    except Exception as e:
        print(f"\nError saving configuration: {e}")

if __name__ == "__main__":
    setup()
