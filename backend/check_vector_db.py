#!/usr/bin/env python3
"""
Quick check of what's in the vector DB: total count and optional search.
Usage:
  uv run python check_vector_db.py                    # show count + sample
  uv run python check_vector_db.py "banana smoothie"  # search and print results
"""

import sys
from pathlib import Path

BACKEND_DIR = Path(__file__).resolve().parent
if str(BACKEND_DIR) not in sys.path:
    sys.path.insert(0, str(BACKEND_DIR))

from app.rag_pipeline import RAGPipeline


def main():
    rag = RAGPipeline(collection_name="documents")
    total = rag.collection.count()

    print(f"Total documents in vector DB: {total}")

    if total == 0:
        print("No documents stored yet. Run: uv run python ingest_items_csv.py <your.csv>")
        return 0

    if len(sys.argv) > 1:
        query = " ".join(sys.argv[1:])
        print(f"\nSearch results for: {query!r}\n")
        results = rag.search(query, n_results=5)
        for i, r in enumerate(results, 1):
            print(f"--- Result {i} (score: {r['score']:.3f}) ---")
            print(r["content"][:300] + ("..." if len(r["content"]) > 300 else ""))
            print()
    else:
        # Show a few stored docs as sample
        got = rag.collection.get(limit=3, include=["documents", "metadatas"])
        if got["documents"]:
            print("\nSample stored documents (first 3):\n")
            for i, (doc, meta) in enumerate(zip(got["documents"], got["metadatas"] or []), 1):
                print(f"--- {i} (id: {meta.get('source', '?')}, row: {meta.get('row', '?')}) ---")
                print(doc[:250] + ("..." if len(doc) > 250 else ""))
                print()

    return 0


if __name__ == "__main__":
    sys.exit(main())
