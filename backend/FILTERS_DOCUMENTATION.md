# Search Database Filters Documentation

## Overview

The `search_database` function now supports **expandable filtering** using structured `Filters` objects that apply filters to the vector database BEFORE querying, reducing the search space and improving performance.

Multiple filters are combined using **AND logic** - all filter conditions must be satisfied.

## Quick Start

```python
from app.tools.implementations import search_database, Filters, FilterRange
from app.rag_pipeline import RAGPipeline

rag = RAGPipeline()

# Search with same-day delivery filter
results = search_database(
    query="Banana Smoothie",
    filters=Filters(delivery_time=0),
    rag_pipeline=rag
)

# Search with max 1-day delivery
results = search_database(
    query="Water",
    filters=Filters(delivery_time=FilterRange(max=1)),
    rag_pipeline=rag
)

# Search with multiple filters (AND relationship)
results = search_database(
    query="Coffee",
    filters=Filters(
        delivery_time=FilterRange(max=1),
        price=FilterRange(max=3.0)
    ),
    rag_pipeline=rag
)
```

## Filters Class

The `Filters` class is a dataclass that provides type-safe filter definitions.

```python
@dataclass
class Filters:
    delivery_time: Optional[Union[int, FilterRange]] = None
    price: Optional[Union[float, FilterRange]] = None
```

### FilterRange Class

The `FilterRange` class defines min/max bounds for numeric filters.

```python
@dataclass
class FilterRange:
    min: Optional[Union[int, float]] = None
    max: Optional[Union[int, float]] = None
```

## Supported Filters

### 1. Delivery Time Filter

Filter by delivery estimate (in days).

**Field:** `delivery_time` (int or FilterRange)
**Metadata field:** `delivery_estimate` (integer: 0, 1, or 2)

#### Examples:

```python
# Exact match - same-day delivery only
filters = Filters(delivery_time=0)

# Max delivery time - up to 1 day
filters = Filters(delivery_time=FilterRange(max=1))

# Min delivery time - at least 1 day
filters = Filters(delivery_time=FilterRange(min=1))

# Range - 1-2 days delivery
filters = Filters(delivery_time=FilterRange(min=1, max=2))
```

### 2. Price Filter

Filter by item price.

**Field:** `price` (float or FilterRange)
**Metadata field:** `price` (float)

#### Examples:

```python
# Exact price
filters = Filters(price=1.50)

# Max price - up to $2.00
filters = Filters(price=FilterRange(max=2.0))

# Min price - at least $1.00
filters = Filters(price=FilterRange(min=1.0))

# Price range - $1.00 to $3.00
filters = Filters(price=FilterRange(min=1.0, max=3.0))
```

### 3. Combined Filters (AND Logic)

Multiple filters are automatically combined with AND logic.

```python
# Same-day delivery AND max price $2.00
filters = Filters(
    delivery_time=0,
    price=FilterRange(max=2.0)
)

# 1-2 day delivery AND price range $1-3
filters = Filters(
    delivery_time=FilterRange(min=1, max=2),
    price=FilterRange(min=1.0, max=3.0)
)
```

## How It Works

### 1. Filter Building

The `Filters` object is converted to a dict, then the `_build_where_clause()` helper function translates it into ChromaDB where clauses:

```python
# User filter
Filters(delivery_time=FilterRange(max=1))

# Converts to dict
{"delivery_time": {"max": 1}}

# Becomes ChromaDB where clause
{"delivery_estimate": {"$lte": 1}}

# Multiple filters
Filters(delivery_time=0, price=FilterRange(max=2.0))

# Converts to dict
{"delivery_time": 0, "price": {"max": 2.0}}

# Becomes ChromaDB where clause
{"$and": [
    {"delivery_estimate": {"$eq": 0}},
    {"price": {"$lte": 2.0}}
]}
```

### 2. Filter Application

Filters are applied at the vector database level BEFORE semantic search:

1. User provides filters
2. `_build_where_clause()` converts to ChromaDB format
3. ChromaDB filters the collection before searching
4. Semantic search runs only on filtered items
5. Results are returned

This approach is more efficient than filtering after search.

## Adding New Filters

The system is designed to be expandable. To add a new filter:

### Step 1: Update Ingestion

Ensure the filterable field is stored as metadata when ingesting data.

**File:** `backend/ingest_items_csv.py`

```python
# Add new filterable metadata
metadata["your_field_name"] = value
```

### Step 2: Add Filter Logic

Add the filter handling in `_build_where_clause()`.

**File:** `backend/app/tools/implementations.py`

```python
def _build_where_clause(filters: dict) -> dict:
    # ... existing code ...
    
    # Handle your new filter
    if "your_filter_name" in filters:
        filter_value = filters["your_filter_name"]
        
        if isinstance(filter_value, (int, float, str)):
            # Exact match
            conditions.append({"your_metadata_field": {"$eq": filter_value}})
        elif isinstance(filter_value, dict):
            # Range filter
            if "max" in filter_value:
                conditions.append({"your_metadata_field": {"$lte": filter_value["max"]}})
            if "min" in filter_value:
                conditions.append({"your_metadata_field": {"$gte": filter_value["min"]}})
```

### Step 3: Update Documentation

Update this file and the function docstring with the new filter.

## ChromaDB Operators

Available operators for filter conditions:

- `$eq` - Equal to
- `$ne` - Not equal to
- `$gt` - Greater than
- `$gte` - Greater than or equal to
- `$lt` - Less than
- `$lte` - Less than or equal to
- `$in` - In array
- `$nin` - Not in array
- `$and` - Logical AND
- `$or` - Logical OR

## Testing

Run the filter tests:

```bash
# From backend directory
uv run python test/test_price_range.py --filters
```

Test file location: `backend/test/test_price_range.py`

The test suite includes:
- Baseline search (no filters)
- Exact match filters
- Max/min filters
- Range filters
- Multiple queries with filters
- Combined filters (AND logic)

## Examples

### Example 1: Find Cheap Same-Day Items

```python
from app.tools.implementations import search_database, Filters, FilterRange

results = search_database(
    query="Smoothie",
    filters=Filters(
        delivery_time=0,
        price=FilterRange(max=1.50)
    ),
    top_results=5,
    rag_pipeline=rag
)
```

### Example 2: Find Premium Items with Fast Delivery

```python
results = search_database(
    query="Meal",
    filters=Filters(
        delivery_time=FilterRange(max=1),
        price=FilterRange(min=3.0)
    ),
    rag_pipeline=rag
)
```

### Example 3: Multiple Queries with Filters

```python
results = search_database(
    query=["Coffee", "Water", "Milk"],
    filters=Filters(delivery_time=0),
    top_results=3,
    rag_pipeline=rag
)

# Returns up to 3 same-day results for each item
for item_result in results:
    print(f"{item_result['query']}: {len(item_result['results'])} results")
```

### Example 4: Using FilterRange for Complex Queries

```python
# Find mid-priced items with 1-2 day delivery
results = search_database(
    query="Coffee",
    filters=Filters(
        delivery_time=FilterRange(min=1, max=2),
        price=FilterRange(min=2.0, max=4.0)
    ),
    rag_pipeline=rag
)
```

## Architecture

```
User Request
    ↓
search_database(query, filters=...)
    ↓
_build_where_clause(filters)
    ↓
ChromaDB where clause
    ↓
rag_pipeline.search(query, where=...)
    ↓
ChromaDB filters collection
    ↓
Semantic search on filtered items
    ↓
Results
```

## Benefits

1. **Performance**: Filters applied before search, reducing search space
2. **Flexibility**: Easy to add new filters
3. **Composable**: Multiple filters combine with AND logic
4. **Type-safe**: Clear separation between user filters and DB queries
5. **Testable**: Comprehensive test suite ensures correctness
