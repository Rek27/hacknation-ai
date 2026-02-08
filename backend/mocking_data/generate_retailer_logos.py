#!/usr/bin/env python3
"""
Script to generate retailer logos from items.csv using DALL-E.
Extracts unique retailers and creates a logo for each based on the products they sell.
"""

import csv
import os
from collections import defaultdict
from pathlib import Path
import requests
from openai import OpenAI
from dotenv import load_dotenv

# Load environment variables from .env file
SCRIPT_DIR = Path(__file__).parent
load_dotenv(SCRIPT_DIR.parent / ".env")

# Initialize OpenAI client
client = OpenAI(api_key=os.getenv("OPENAI_API_KEY"))

# Paths
CSV_PATH = SCRIPT_DIR / "items.csv"
OUTPUT_DIR = SCRIPT_DIR / "images" / "retailers"

# Create output directory if it doesn't exist
OUTPUT_DIR.mkdir(parents=True, exist_ok=True)


def parse_csv_and_get_retailers():
    """
    Parse the CSV file and extract unique retailers with their products.
    Returns a dict of {retailer_name: [list of products]}
    """
    retailer_products = defaultdict(list)
    
    with open(CSV_PATH, 'r', encoding='utf-8') as f:
        reader = csv.DictReader(f)
        for row in reader:
            retailer = row['retailer']
            article = row['article']
            # Only add up to 5 products per retailer for the prompt
            if len(retailer_products[retailer]) < 5:
                retailer_products[retailer].append(article)
    
    return dict(retailer_products)


def generate_logo(retailer_name, products):
    """
    Generate a logo for a retailer using DALL-E 3.
    
    Args:
        retailer_name: Name of the retailer
        products: List of products they sell (not used in prompt)
    
    Returns:
        Path to the saved image file
    """
    # Create the prompt - simple and generic
    prompt = f"Create a logo for retailer {retailer_name}, use normal brands style"
    
    print(f"Generating logo for {retailer_name}...")
    print(f"  Prompt: {prompt}")
    
    try:
        # Call DALL-E 3 API (cheapest option: 1024x1024 standard quality)
        response = client.images.generate(
            model="dall-e-3",
            prompt=prompt,
            size="1024x1024",
            quality="standard",
            n=1
        )
        
        # Get the image URL
        image_url = response.data[0].url
        
        # Download the image
        image_response = requests.get(image_url)
        image_response.raise_for_status()
        
        # Save the image
        # Sanitize the retailer name for filename
        safe_name = retailer_name.replace(" ", "_").replace("/", "_")
        output_path = OUTPUT_DIR / f"{safe_name}.png"
        
        with open(output_path, 'wb') as f:
            f.write(image_response.content)
        
        print(f"  ✓ Saved to {output_path}")
        return output_path
        
    except Exception as e:
        print(f"  ✗ Error generating logo for {retailer_name}: {e}")
        return None


def main():
    """Main function to generate all retailer logos."""
    print("=" * 60)
    print("Retailer Logo Generator")
    print("=" * 60)
    print()
    
    # Check for API key
    if not os.getenv("OPENAI_API_KEY"):
        print("ERROR: OPENAI_API_KEY environment variable not set!")
        print("Please set it with: export OPENAI_API_KEY='your-api-key'")
        return
    
    # Parse CSV and get retailers
    print("Parsing CSV file...")
    retailer_products = parse_csv_and_get_retailers()
    
    print(f"Found {len(retailer_products)} unique retailers:")
    for retailer in retailer_products.keys():
        print(f"  - {retailer}")
    print()
    
    # Generate logo for each retailer
    print("Generating logos...")
    print()
    
    success_count = 0
    for retailer, products in retailer_products.items():
        result = generate_logo(retailer, products)
        if result:
            success_count += 1
        print()
    
    # Summary
    print("=" * 60)
    print(f"Complete! Generated {success_count}/{len(retailer_products)} logos")
    print(f"Images saved to: {OUTPUT_DIR}")
    print("=" * 60)


if __name__ == "__main__":
    main()
