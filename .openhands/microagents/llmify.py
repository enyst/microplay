#!/usr/bin/env python3
"""
Script to concatenate all files in the .openhands/microagents directory into a single markdown file.
Each file's content is separated by a clear delimiter and includes the relative path as a heading.
"""

import os
import sys
from pathlib import Path

def process_directory(base_dir, output_file):
    """
    Process all files in the directory and its subdirectories, writing their contents to the output file.
    
    Args:
        base_dir (Path): The base directory to process
        output_file: The file object to write to
    """
    # Get all files in the directory and its subdirectories
    all_files = []
    for root, _, files in os.walk(base_dir):
        for file in files:
            # Skip the script itself and the output file
            if file.startswith('llmify') or file.endswith('.md.llm'):
                continue
                
            file_path = Path(root) / file
            # Skip directories and non-text files
            if file_path.is_dir() or not is_text_file(file_path):
                continue
                
            all_files.append(file_path)
    
    # Sort files for consistent output
    all_files.sort()
    
    # Process each file
    for file_path in all_files:
        try:
            # Get relative path from base_dir
            rel_path = file_path.relative_to(base_dir)
            
            # Write separator and heading with the exact requested format
            output_file.write(f"\n\n---\n\n# {rel_path}\n\n")
            
            # Write file contents
            with open(file_path, 'r', encoding='utf-8', errors='replace') as f:
                content = f.read()
                output_file.write(content)
                
            print(f"Processed: {rel_path}")
        except Exception as e:
            print(f"Error processing {file_path}: {e}", file=sys.stderr)

def is_text_file(file_path):
    """
    Check if a file is likely a text file by reading the first few bytes.
    
    Args:
        file_path (Path): Path to the file
        
    Returns:
        bool: True if the file is likely a text file, False otherwise
    """
    try:
        # Try to open and read the first few bytes
        with open(file_path, 'rb') as f:
            chunk = f.read(1024)
            return b'\0' not in chunk  # Binary files typically contain null bytes
    except Exception:
        return False

def main():
    # Get the base directory (where the script is located)
    script_dir = Path(__file__).parent
    
    # Create output file path
    output_path = script_dir / "microagents.md.llm"
    
    print(f"Starting to process files in {script_dir}")
    print(f"Output will be written to {output_path}")
    
    # Process all files and write to output
    with open(output_path, 'w', encoding='utf-8') as output_file:
        output_file.write("# OpenHands Microagents Documentation\n\n")
        output_file.write("This file contains the concatenated contents of all files in the .openhands/microagents directory.\n")
        process_directory(script_dir, output_file)
    
    print(f"Done! Output written to {output_path}")

if __name__ == "__main__":
    main()