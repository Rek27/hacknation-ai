import chromadb
from chromadb.config import Settings
from sentence_transformers import SentenceTransformer
from typing import List, Dict, BinaryIO
import os
from pathlib import Path
from app.logger import get_logger
import PyPDF2
import tempfile

logger = get_logger(__name__)


class RAGPipeline:
    """RAG pipeline for document retrieval and embedding"""
    
    def __init__(self, collection_name: str = "documents"):
        logger.info("Initializing RAG pipeline...")
        
        # Initialize embedding model
        logger.info("Loading embedding model: all-MiniLM-L6-v2")
        self.embedding_model = SentenceTransformer('all-MiniLM-L6-v2')
        logger.info("Embedding model loaded successfully")
        
        # Initialize ChromaDB with persistent storage
        logger.info("Initializing ChromaDB client")
        db_path = "./chroma_db"
        Path(db_path).mkdir(exist_ok=True)
        
        self.client = chromadb.PersistentClient(path=db_path)
        
        # Create or get collection
        self.collection = self.client.get_or_create_collection(
            name=collection_name,
            metadata={"hnsw:space": "cosine"}
        )
        
        # Check existing documents
        existing_count = self.collection.count()
        logger.info(f"ChromaDB collection '{collection_name}' initialized with {existing_count} existing chunks")
        
    def extract_text_from_file(self, filepath: str) -> str:
        """Extract text from different file types"""
        file_ext = Path(filepath).suffix.lower()
        
        if file_ext == '.txt':
            with open(filepath, 'r', encoding='utf-8') as f:
                return f.read()
        
        elif file_ext == '.pdf':
            logger.info(f"Extracting text from PDF: {filepath}")
            with open(filepath, 'rb') as f:
                pdf_reader = PyPDF2.PdfReader(f)
                text = ""
                for page_num, page in enumerate(pdf_reader.pages):
                    text += page.extract_text() + "\n"
                logger.info(f"Extracted {len(text)} characters from {len(pdf_reader.pages)} pages")
                return text
        
        else:
            raise ValueError(f"Unsupported file type: {file_ext}")
    
    def chunk_text(self, text: str, chunk_size: int = 500, 
                   overlap: int = 50) -> List[str]:
        """Split text into overlapping chunks"""
        words = text.split()
        chunks = []
        
        for i in range(0, len(words), chunk_size - overlap):
            chunk = ' '.join(words[i:i + chunk_size])
            if chunk.strip():  # Only add non-empty chunks
                chunks.append(chunk)
        
        logger.debug(f"Text chunked into {len(chunks)} chunks")
        return chunks
    
    def ingest_document(self, filepath: str, metadata: Dict = None):
        """Ingest a document into the vector store"""
        logger.info(f"Ingesting document: {filepath}")
        
        # Extract text based on file type
        text = self.extract_text_from_file(filepath)
        logger.debug(f"Document loaded: {len(text)} characters")
        
        # Chunk the document
        chunks = self.chunk_text(text)
        
        if not chunks:
            logger.warning(f"No chunks generated from {filepath}")
            return 0
        
        logger.debug(f"Document split into {len(chunks)} chunks")
        
        # Generate embeddings
        logger.debug("Generating embeddings...")
        embeddings = self.embedding_model.encode(chunks).tolist()
        logger.debug(f"Generated {len(embeddings)} embeddings")
        
        # Prepare metadata
        if metadata is None:
            metadata = {}
        
        doc_name = Path(filepath).name
        
        # Add to collection with unique IDs based on timestamp
        import time
        timestamp = int(time.time() * 1000)
        ids = [f"{doc_name}_{timestamp}_{i}" for i in range(len(chunks))]
        metadatas = [{**metadata, "source": doc_name, "chunk_id": i} 
                     for i in range(len(chunks))]
        
        self.collection.add(
            embeddings=embeddings,
            documents=chunks,
            metadatas=metadatas,
            ids=ids
        )
        
        total_docs = self.collection.count()
        logger.info(f"Successfully ingested {len(chunks)} chunks from {doc_name}. Total chunks in DB: {total_docs}")
        return len(chunks)
    
    def ingest_from_bytes(self, file_content: bytes, filename: str, metadata: Dict = None) -> int:
        """Ingest a document from bytes (for file uploads)"""
        logger.info(f"Ingesting uploaded file: {filename}")
        
        # Save to temporary file
        with tempfile.NamedTemporaryFile(delete=False, suffix=Path(filename).suffix) as tmp_file:
            tmp_file.write(file_content)
            tmp_path = tmp_file.name
        
        try:
            # Process the temporary file
            chunks_added = self.ingest_document(tmp_path, metadata)
            return chunks_added
        finally:
            # Clean up temporary file
            if os.path.exists(tmp_path):
                os.remove(tmp_path)
    
    def ingest_directory(self, directory_path: str):
        """Ingest all text files from a directory"""
        logger.info(f"Ingesting directory: {directory_path}")
        directory = Path(directory_path)
        count = 0
        
        # Support multiple file types
        supported_extensions = ['*.txt', '*.pdf']
        files = []
        for ext in supported_extensions:
            files.extend(directory.glob(ext))
        
        logger.info(f"Found {len(files)} files to ingest")
        
        for filepath in files:
            try:
                chunks_added = self.ingest_document(str(filepath))
                count += chunks_added
                logger.info(f"✓ {filepath.name}: {chunks_added} chunks")
            except Exception as e:
                logger.error(f"Failed to ingest {filepath.name}: {e}", exc_info=True)
        
        logger.info(f"Directory ingestion complete: {count} total chunks")
        return count
    
    def search(self, query: str, n_results: int = 3) -> List[Dict]:
        """Search for relevant chunks"""
        logger.debug(f"Searching for: '{query}' (n_results={n_results})")
        
        # Check if collection has documents
        doc_count = self.collection.count()
        if doc_count == 0:
            logger.warning("No documents in collection")
            return []
        
        logger.debug(f"Collection has {doc_count} chunks")
        
        # Generate query embedding
        query_embedding = self.embedding_model.encode([query]).tolist()
        
        # Search in collection
        results = self.collection.query(
            query_embeddings=query_embedding,
            n_results=min(n_results, doc_count)  # Don't request more than available
        )
        
        # Format results
        formatted_results = []
        if results['documents'] and len(results['documents'][0]) > 0:
            for i in range(len(results['documents'][0])):
                formatted_results.append({
                    "content": results['documents'][0][i],
                    "metadata": results['metadatas'][0][i],
                    "score": 1 - results['distances'][0][i]
                })
        
        logger.info(f"Search returned {len(formatted_results)} results")
        logger.debug(f"Top result score: {formatted_results[0]['score']:.4f}" if formatted_results else "No results")
        
        return formatted_results
    
    def list_documents(self) -> List[Dict]:
        """List all documents in the collection"""
        results = self.collection.get()
        
        # Group by source
        sources = {}
        if results['metadatas']:
            for metadata in results['metadatas']:
                source = metadata.get('source', 'unknown')
                if source not in sources:
                    sources[source] = 0
                sources[source] += 1
        
        return [
            {"filename": source, "chunks": count}
            for source, count in sources.items()
        ]
    
    def delete_document(self, filename: str) -> int:
        """Delete all chunks from a specific document"""
        logger.info(f"Deleting document: {filename}")
        
        # Get all IDs for this document
        results = self.collection.get()
        ids_to_delete = []
        
        if results['metadatas']:
            for i, metadata in enumerate(results['metadatas']):
                if metadata.get('source') == filename:
                    ids_to_delete.append(results['ids'][i])
        
        if ids_to_delete:
            self.collection.delete(ids=ids_to_delete)
            logger.info(f"Deleted {len(ids_to_delete)} chunks from {filename}")
        
        return len(ids_to_delete)
    
    def clear_all(self):
        """Clear all documents from the collection"""
        logger.warning("Clearing all documents from collection")
        self.client.delete_collection(self.collection.name)
        self.collection = self.client.create_collection(
            name=self.collection.name,
            metadata={"hnsw:space": "cosine"}
        )
        logger.info("Collection cleared")
