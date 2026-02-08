#!/usr/bin/env python3
"""
Ingest a CSV file into the vector database (ChromaDB).
Each row is formatted as "Field: value, ..." for all columns and added as one document.
Run from backend directory: python ingest_items_csv.py <path/to/file.csv>
"""

import argparse
import csv
import sys
from pathlib import Path

# Ensure backend is on path when run as script
BACKEND_DIR = Path(__file__).resolve().parent
if str(BACKEND_DIR) not in sys.path:
    sys.path.insert(0, str(BACKEND_DIR))

from app.rag_pipeline import RAGPipeline
from app.logger import get_logger

logger = get_logger(__name__)


def header_to_label(header: str) -> str:
    """Turn CSV header into a readable label (e.g. delivery_estimate -> Delivery Estimate)."""
    # Special case: image_id -> Image
    if header == "image_id":
        return "Image"
    return header.replace("_", " ").strip().title()


def row_to_text(row: dict, headers: list) -> str:
    """Format a CSV row as 'Label: value, ...' for each column."""
    parts = []
    for h in headers:
        value = row.get(h, '')
        # Special case: delivery_estimate is numeric, append "days"
        if h == "delivery_estimate" and value:
            value = f"{value} days"
        parts.append(f"{header_to_label(h)}: {value}")
    return ", ".join(parts)


def main():
    parser = argparse.ArgumentParser(
        description="Ingest a CSV file into the vector database. Each row becomes one searchable document."
    )
    parser.add_argument(
        "csv_file",
        type=Path,
        help="Path to the CSV file to ingest",
    )
    parser.add_argument(
        "-n",
        "--collection-name",
        default="documents",
        help="ChromaDB collection name (default: documents)",
    )
    args = parser.parse_args()

    csv_path = args.csv_file.resolve()
    if not csv_path.exists():
        logger.error("CSV not found: %s", csv_path)
        sys.exit(1)
    if csv_path.suffix.lower() != ".csv":
        logger.warning("File does not have .csv extension: %s", csv_path)

    logger.info("Loading RAG pipeline (embedding model + ChromaDB)...")
    rag = RAGPipeline(collection_name=args.collection_name)

    with open(csv_path, newline="", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        headers = reader.fieldnames or []
        rows = list(reader)

    if not headers:
        logger.error("CSV has no headers: %s", csv_path)
        sys.exit(1)

    source_name = csv_path.name
    logger.info("Ingesting %d rows from %s", len(rows), csv_path)

    ingested = 0
    for i, row in enumerate(rows):
        text = row_to_text(row, headers)
        doc_id = f"item_{i}"
        
        # Build metadata with filterable fields
        metadata = {
            "source": source_name,
            "row": i
        }
        
        # Add delivery_estimate as filterable metadata (convert to int)
        if "delivery_estimate" in row and row["delivery_estimate"]:
            try:
                metadata["delivery_estimate"] = int(row["delivery_estimate"])
            except (ValueError, TypeError):
                logger.warning(f"Row {i}: Invalid delivery_estimate value: {row['delivery_estimate']}")
        
        # Add price as filterable metadata (convert to float)
        if "price" in row and row["price"]:
            try:
                metadata["price"] = float(row["price"])
            except (ValueError, TypeError):
                logger.warning(f"Row {i}: Invalid price value: {row['price']}")
        
        rag.ingest_text(
            text,
            doc_id=doc_id,
            metadata=metadata,
        )
        ingested += 1
        if (i + 1) % 10 == 0:
            logger.info("  %d / %d rows ingested", i + 1, len(rows))

    logger.info("Done. Ingested %d items into the vector database.", ingested)
    return 0


if __name__ == "__main__":
    sys.exit(main())
