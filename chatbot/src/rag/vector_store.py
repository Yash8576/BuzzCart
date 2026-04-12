from __future__ import annotations

import json
import logging
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path
from typing import Any, Dict, List, Optional

import faiss
import numpy as np
from sentence_transformers import CrossEncoder, SentenceTransformer
from transformers import AutoTokenizer

from ..core.config import settings

logger = logging.getLogger(__name__)


@dataclass
class SearchMatch:
    text: str
    metadata: Dict[str, Any]
    score: float


class VectorStoreManager:
    """Stores one FAISS cosine-similarity index per product."""

    def __init__(self) -> None:
        self.vector_store_dir = Path(settings.VECTOR_STORE_DIR)
        self.model_cache_dir = Path(settings.MODEL_CACHE_DIR)
        self.embedding_model: Optional[SentenceTransformer] = None
        self.reranker: Optional[CrossEncoder] = None
        self.tokenizer = None

    async def initialize(self) -> None:
        self.vector_store_dir.mkdir(parents=True, exist_ok=True)
        self.model_cache_dir.mkdir(parents=True, exist_ok=True)

        logger.info("Loading embedding model: %s", settings.EMBEDDING_MODEL_NAME)
        self.embedding_model = SentenceTransformer(
            settings.EMBEDDING_MODEL_NAME,
            cache_folder=str(self.model_cache_dir),
        )

        logger.info("Loading tokenizer: %s", settings.EMBEDDING_MODEL_NAME)
        self.tokenizer = AutoTokenizer.from_pretrained(
            settings.EMBEDDING_MODEL_NAME,
            cache_dir=str(self.model_cache_dir),
        )

        logger.info("Loading reranker model: %s", settings.RERANKER_MODEL_NAME)
        self.reranker = CrossEncoder(
            settings.RERANKER_MODEL_NAME,
            max_length=512,
        )

    def chunk_text_by_tokens(self, text: str) -> List[str]:
        if not self.tokenizer:
            raise RuntimeError("Tokenizer not initialized")

        normalized = " ".join(text.split())
        if not normalized:
            return []

        encoded = self.tokenizer(
            normalized,
            add_special_tokens=False,
            return_offsets_mapping=True,
            truncation=False,
        )
        input_ids = encoded["input_ids"]
        offsets = encoded["offset_mapping"]

        if not input_ids:
            return []

        chunks: List[str] = []
        start = 0
        step = max(
            settings.CHUNK_SIZE_TOKENS - settings.CHUNK_OVERLAP_TOKENS,
            1,
        )

        while start < len(input_ids):
            end = min(start + settings.CHUNK_SIZE_TOKENS, len(input_ids))
            char_start = offsets[start][0]
            char_end = offsets[end - 1][1]
            chunk = normalized[char_start:char_end].strip()
            if chunk:
                chunks.append(chunk)
            if end >= len(input_ids):
                break
            start += step

        return chunks

    def build_product_index(
        self,
        product_id: str,
        chunks: List[Dict[str, Any]],
        manifest: Dict[str, Any],
    ) -> None:
        if not self.embedding_model:
            raise RuntimeError("Embedding model not initialized")

        if not chunks:
            raise ValueError("No chunks available to index")

        texts = [chunk["text"] for chunk in chunks]
        embeddings = self.embedding_model.encode(
            texts,
            normalize_embeddings=True,
            show_progress_bar=False,
            convert_to_numpy=True,
        ).astype("float32")

        dimension = embeddings.shape[1]
        index = faiss.IndexFlatIP(dimension)
        index.add(embeddings)

        product_dir = self._product_dir(product_id)
        product_dir.mkdir(parents=True, exist_ok=True)

        faiss.write_index(index, str(product_dir / "index.faiss"))
        (product_dir / "chunks.json").write_text(
            json.dumps(chunks, ensure_ascii=True, indent=2),
            encoding="utf-8",
        )

        manifest_payload = {
            **manifest,
            "product_id": product_id,
            "chunks_created": len(chunks),
            "updated_at": datetime.utcnow().isoformat(),
        }
        (product_dir / "manifest.json").write_text(
            json.dumps(manifest_payload, ensure_ascii=True, indent=2),
            encoding="utf-8",
        )
        logger.info(
            "Indexed %s chunks for product %s",
            len(chunks),
            product_id,
        )

    def similarity_search(
        self,
        product_id: str,
        query: str,
        k: Optional[int] = None,
    ) -> List[SearchMatch]:
        if not self.embedding_model:
            raise RuntimeError("Embedding model not initialized")

        product_dir = self._product_dir(product_id)
        index_path = product_dir / "index.faiss"
        chunks_path = product_dir / "chunks.json"
        if not index_path.exists() or not chunks_path.exists():
            return []

        index = faiss.read_index(str(index_path))
        chunks = json.loads(chunks_path.read_text(encoding="utf-8"))
        if not chunks:
            return []

        query_vector = self.embedding_model.encode(
            [query],
            normalize_embeddings=True,
            show_progress_bar=False,
            convert_to_numpy=True,
        ).astype("float32")

        limit = min(k or settings.TOP_K_RESULTS, len(chunks))
        scores, indices = index.search(query_vector, limit)
        matches: List[SearchMatch] = []

        for row_index, score in zip(indices[0], scores[0]):
            if row_index < 0 or row_index >= len(chunks):
                continue
            chunk = chunks[row_index]
            if chunk.get("metadata", {}).get("product_id") != product_id:
                continue
            matches.append(
                SearchMatch(
                    text=chunk["text"],
                    metadata=chunk["metadata"],
                    score=float(score),
                )
            )

        return matches

    def load_product_chunks(self, product_id: str) -> List[SearchMatch]:
        chunks_path = self._product_dir(product_id) / "chunks.json"
        if not chunks_path.exists():
            return []

        chunks = json.loads(chunks_path.read_text(encoding="utf-8"))
        matches: List[SearchMatch] = []
        for chunk in chunks:
            metadata = chunk.get("metadata", {})
            if metadata.get("product_id") != product_id:
                continue
            matches.append(
                SearchMatch(
                    text=str(chunk.get("text", "")),
                    metadata=metadata,
                    score=0.0,
                )
            )
        return matches

    def rerank_chunks(self, query: str, matches: List[SearchMatch]) -> List[SearchMatch]:
        if not self.reranker or not matches:
            return matches[: settings.RERANK_TOP_K]

        pairs = [(query, match.text) for match in matches]
        scores = self.reranker.predict(pairs)
        reranked = [
            SearchMatch(text=match.text, metadata=match.metadata, score=float(score))
            for match, score in zip(matches, scores)
        ]
        reranked.sort(key=lambda item: item.score, reverse=True)
        return reranked[: settings.RERANK_TOP_K]

    def rerank_sentences(
        self,
        query: str,
        candidates: List[Dict[str, Any]],
    ) -> List[Dict[str, Any]]:
        if not self.reranker or not candidates:
            return candidates[: settings.SENTENCE_TOP_K]

        pairs = [(query, candidate["text"]) for candidate in candidates]
        scores = self.reranker.predict(pairs)
        ranked = []
        for candidate, score in zip(candidates, scores):
            enriched = dict(candidate)
            enriched["score"] = float(score)
            ranked.append(enriched)

        ranked.sort(key=lambda item: item["score"], reverse=True)
        return ranked[: settings.SENTENCE_TOP_K]

    def get_product_status(self, product_id: str) -> Dict[str, Any]:
        manifest_path = self._product_dir(product_id) / "manifest.json"
        if not manifest_path.exists():
            return {
                "product_id": product_id,
                "indexed": False,
                "chunks_created": 0,
                "pages_processed": 0,
                "source_name": None,
                "document_url": None,
                "updated_at": None,
            }

        payload = json.loads(manifest_path.read_text(encoding="utf-8"))
        return {
            "product_id": product_id,
            "indexed": True,
            "chunks_created": int(payload.get("chunks_created", 0)),
            "pages_processed": int(payload.get("pages_processed", 0)),
            "source_name": payload.get("source_name"),
            "document_url": payload.get("document_url"),
            "updated_at": payload.get("updated_at"),
        }

    def should_reindex(self, product_id: str, document_url: Optional[str]) -> bool:
        status = self.get_product_status(product_id)
        if not status["indexed"]:
            return True
        if not document_url:
            return False
        return status.get("document_url") != document_url

    def delete_product_index(self, product_id: str) -> None:
        product_dir = self._product_dir(product_id)
        if not product_dir.exists():
            return

        for path in product_dir.iterdir():
            path.unlink(missing_ok=True)
        product_dir.rmdir()
        logger.info("Deleted vector index for product %s", product_id)

    def _product_dir(self, product_id: str) -> Path:
        safe_product_id = "".join(
            char for char in product_id if char.isalnum() or char in {"-", "_"}
        )
        if not safe_product_id:
            raise ValueError("Invalid product_id")
        return self.vector_store_dir / safe_product_id
