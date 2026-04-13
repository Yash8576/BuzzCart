from __future__ import annotations

import json
import logging
import math
import re
from typing import Any, Dict, List, Optional

import requests

from ..api.schemas import AnswerSource, ProductChatResponse
from ..core.config import settings
from .document_processor import DocumentProcessor
from .vector_store import SearchMatch, VectorStoreManager

logger = logging.getLogger(__name__)

FALLBACK_ANSWER = "I cannot find this information in the document."
STOPWORDS = {
    "a",
    "an",
    "and",
    "are",
    "be",
    "can",
    "do",
    "does",
    "for",
    "from",
    "has",
    "have",
    "how",
    "i",
    "in",
    "is",
    "it",
    "me",
    "many",
    "much",
    "number",
    "of",
    "on",
    "or",
    "please",
    "product",
    "tell",
    "that",
    "the",
    "this",
    "to",
    "what",
    "when",
    "where",
    "which",
    "with",
    "you",
}


class ChatEngine:
    """Grounded product-document QA engine with hybrid retrieval and evidence-first synthesis."""

    def __init__(
        self,
        vector_store: VectorStoreManager,
        document_processor: DocumentProcessor,
    ) -> None:
        self.vector_store = vector_store
        self.document_processor = document_processor

    async def generate_response(
        self,
        product_id: str,
        query: str,
        document_url: Optional[str] = None,
        force_document_sync: bool = False,
        user_id: Optional[str] = None,
    ) -> ProductChatResponse:
        _ = user_id

        cleaned_query = " ".join(query.split())
        if not cleaned_query:
            return self._fallback()

        if force_document_sync and document_url:
            await self.document_processor.sync_product_document(
                product_id=product_id,
                document_url=document_url,
                force=True,
            )
        else:
            await self.document_processor.ensure_index_current(
                product_id=product_id,
                document_url=document_url,
            )

        retrieved = self.vector_store.similarity_search(
            product_id=product_id,
            query=cleaned_query,
            k=settings.RETRIEVAL_CANDIDATE_POOL,
        )
        if not retrieved:
            return self._fallback()

        expanded = self.vector_store.expand_matches_with_neighbors(
            product_id=product_id,
            matches=retrieved,
        )
        reranked_chunks = self.vector_store.rerank_chunks(cleaned_query, expanded)
        if not reranked_chunks:
            return self._fallback()

        evidence_candidates = self._collect_evidence_candidates(cleaned_query, reranked_chunks)
        if not evidence_candidates:
            return self._fallback()

        ranked_evidence = self.vector_store.rerank_sentences(cleaned_query, evidence_candidates)
        if not ranked_evidence:
            return self._fallback()

        selected_evidence = self._select_supporting_evidence(cleaned_query, ranked_evidence)
        if not selected_evidence:
            return self._fallback()

        answer = self._render_grounded_answer(cleaned_query, selected_evidence)
        if answer == FALLBACK_ANSWER:
            return self._fallback()

        primary = selected_evidence[0]
        return ProductChatResponse(
            answer=answer,
            source=AnswerSource(
                page=int(primary["page"]),
                chunk_id=int(primary["chunk_id"]),
            ),
            confidence=self._confidence_label(selected_evidence),
        )

    def _collect_evidence_candidates(
        self,
        query: str,
        matches: List[SearchMatch],
    ) -> List[Dict[str, Any]]:
        candidates: List[Dict[str, Any]] = []
        seen = set()
        expects_numeric = self._expects_numeric_answer(query)

        for match in matches:
            for text in self._extract_candidate_spans(query, match.text):
                normalized = self._normalize_candidate_text(text)
                if len(normalized) < 6:
                    continue
                key = normalized.lower()
                if key in seen:
                    continue
                seen.add(key)

                support = self._support_ratio(query, normalized)
                numeric_bonus = 0.12 if expects_numeric and self._contains_numeric_value(normalized) else 0.0
                section_title = match.metadata.get("section_title")
                if section_title and self._support_ratio(query, str(section_title)) >= 0.35:
                    numeric_bonus += 0.05
                noise_penalty = self._noise_penalty(normalized, match.text)
                direct_answer_bonus = self._direct_answer_bonus(query, normalized)

                candidates.append(
                    {
                        "text": normalized,
                        "page": int(match.metadata["page"]),
                        "chunk_id": int(match.metadata["chunk_id"]),
                        "context_text": match.text,
                        "section_title": section_title,
                        "support": support,
                        "base_score": float(match.score),
                        "dense_score": float(match.dense_score),
                        "lexical_score": float(match.lexical_score),
                        "numeric_bonus": numeric_bonus,
                        "noise_penalty": noise_penalty,
                        "direct_answer_bonus": direct_answer_bonus,
                    }
                )

        candidates.sort(
            key=lambda item: (
                item["support"] + item["numeric_bonus"],
                item["base_score"],
                -len(item["text"]),
            ),
            reverse=True,
        )
        return candidates[: max(settings.SENTENCE_TOP_K * 3, 12)]

    def _extract_candidate_spans(self, query: str, text: str) -> List[str]:
        lines = self._split_lines(text)
        sentences = self._split_sentences(text)
        spans = [*lines, *sentences, *self._build_sentence_windows(sentences), *self._extract_query_windows(query, text)]

        compact = self._normalize_candidate_text(text)
        if compact and len(compact) <= 420:
            spans.append(compact)
        return spans

    def _split_lines(self, text: str) -> List[str]:
        return [
            line
            for raw_line in re.split(r"[\r\n]+", text)
            if (line := self._normalize_candidate_text(raw_line)) and len(line) >= 4
        ]

    def _split_sentences(self, text: str) -> List[str]:
        return [
            sentence
            for part in re.split(r"(?:[\r\n]+|(?<=[.!?])\s+)", text)
            if (sentence := self._normalize_candidate_text(part))
            and len(sentence) >= 12
            and re.search(r"[A-Za-z0-9]", sentence)
        ]

    def _build_sentence_windows(self, sentences: List[str]) -> List[str]:
        windows: List[str] = []
        for index, sentence in enumerate(sentences):
            windows.append(sentence)
            if index + 1 < len(sentences):
                windows.append(self._normalize_candidate_text(f"{sentence} {sentences[index + 1]}"))
        return [window for window in windows if window]

    def _extract_query_windows(self, query: str, text: str) -> List[str]:
        spans: List[str] = []
        lowered_text = text.lower()

        for term in self._meaningful_terms(query):
            start_index = 0
            while True:
                hit = lowered_text.find(term, start_index)
                if hit == -1:
                    break
                window_start = max(0, hit - 90)
                window_end = min(len(text), hit + 210)
                snippet = self._normalize_candidate_text(text[window_start:window_end])
                if len(snippet) >= 12:
                    spans.append(snippet)
                start_index = hit + len(term)

        return spans

    def _select_supporting_evidence(
        self,
        query: str,
        ranked_candidates: List[Dict[str, Any]],
    ) -> List[Dict[str, Any]]:
        if not ranked_candidates:
            return []

        enriched: List[Dict[str, Any]] = []
        for candidate in ranked_candidates:
            item = dict(candidate)
            rerank_probability = self._sigmoid(float(item.get("score", 0.0)))
            support = max(float(item.get("support", 0.0)), self._support_ratio(query, item["text"]))
            item["support"] = support
            item["rerank_probability"] = rerank_probability
            item["selection_score"] = (
                rerank_probability * 0.55
                + support * 0.28
                + float(item.get("base_score", 0.0)) * 0.12
                + float(item.get("numeric_bonus", 0.0))
                + float(item.get("direct_answer_bonus", 0.0))
                + float(item.get("lexical_score", 0.0)) * 0.08
                - float(item.get("noise_penalty", 0.0))
            )
            enriched.append(item)

        enriched.sort(key=lambda item: item["selection_score"], reverse=True)
        primary = enriched[0]
        min_required = 0.48
        if self._expects_numeric_answer(query) and self._contains_numeric_value(primary["text"]):
            min_required = 0.42
        if primary["selection_score"] < min_required:
            return []

        selected = [primary]
        for candidate in enriched[1:]:
            if len(selected) >= settings.MAX_EVIDENCE_BLOCKS:
                break
            if self._is_duplicate_evidence(selected, candidate):
                continue
            if candidate["selection_score"] < primary["selection_score"] * 0.65:
                continue
            if candidate["support"] < 0.2 and candidate["rerank_probability"] < 0.62:
                continue
            selected.append(candidate)

        return selected

    def _render_grounded_answer(
        self,
        query: str,
        evidence_blocks: List[Dict[str, Any]],
    ) -> str:
        if not evidence_blocks:
            return FALLBACK_ANSWER

        rewritten = self._rewrite_with_ollama(query, evidence_blocks)
        if rewritten:
            return rewritten
        return self._deterministic_rewrite(query, evidence_blocks)

    def _rewrite_with_ollama(
        self,
        query: str,
        evidence_blocks: List[Dict[str, Any]],
    ) -> Optional[str]:
        prompt_lines = [
            "You answer product-document questions using only the evidence blocks.",
            "Rules:",
            "- Use only facts stated in the evidence blocks.",
            "- Keep numbers, units, capacities, and limits exactly as written.",
            "- If the evidence is insufficient, return exactly the fallback answer.",
            "- If the evidence shows configuration-dependent options, say that clearly.",
            "- Return JSON only.",
            "",
            f"Question: {query}",
            f"Fallback answer: {FALLBACK_ANSWER}",
            "Evidence blocks:",
        ]

        for index, evidence in enumerate(evidence_blocks, start=1):
            prompt_lines.append(
                f"[{index}] page={evidence['page']} chunk={evidence['chunk_id']} text={evidence['text']}"
            )

        prompt_lines.extend(
            [
                "",
                'Return JSON with this exact shape: {"answer": "...", "primary_evidence_id": 1}',
            ]
        )

        try:
            response = requests.post(
                f"{settings.OLLAMA_BASE_URL}/api/generate",
                json={
                    "model": settings.OLLAMA_MODEL,
                    "prompt": "\n".join(prompt_lines),
                    "stream": False,
                    "format": "json",
                    "options": {"temperature": 0},
                },
                timeout=settings.OLLAMA_TIMEOUT_SECONDS,
            )
            response.raise_for_status()
            payload = response.json()
            parsed = json.loads(payload.get("response", "{}"))
            answer = " ".join(str(parsed.get("answer", "")).split())
            if not answer:
                return None
            if answer == FALLBACK_ANSWER:
                return answer
            evidence_text = " ".join(block["text"] for block in evidence_blocks)
            if not self._is_answer_grounded(answer, evidence_text):
                return None
            return answer
        except Exception as exc:
            logger.warning("Ollama rewrite failed, using deterministic fallback: %s", exc)
            return None

    def _deterministic_rewrite(
        self,
        query: str,
        evidence_blocks: List[Dict[str, Any]],
    ) -> str:
        primary_text = self._focus_evidence_for_query(query, evidence_blocks[0]["text"])
        if not primary_text:
            return FALLBACK_ANSWER
        concise_fact = self._rewrite_fact_line(query, primary_text)
        if concise_fact:
            return concise_fact
        if self._expects_yes_no_answer(query):
            return f"Yes. {self._ensure_terminal_period(primary_text)}"
        return self._ensure_terminal_period(primary_text)

    def _focus_evidence_for_query(self, query: str, evidence: str) -> str:
        return self._best_matching_line(query, evidence) or self._normalize_candidate_text(evidence)

    def _support_ratio(self, query: str, sentence: str) -> float:
        query_terms = self._meaningful_terms(query)
        if not query_terms:
            return 1.0
        sentence_terms = set(self._meaningful_terms(sentence))
        overlap = len(set(query_terms) & sentence_terms)
        return overlap / max(len(set(query_terms)), 1)

    def _meaningful_terms(self, text: str) -> List[str]:
        return [
            token
            for token in re.findall(r"[a-z0-9]+", text.lower())
            if len(token) > 2 and token not in STOPWORDS
        ]

    def _normalize_candidate_text(self, text: str) -> str:
        return re.sub(r"\s+", " ", text).strip(" ,;:|-")

    def _best_matching_line(self, query: str, text: str) -> Optional[str]:
        best_line: Optional[str] = None
        best_score = -1.0
        for raw_line in re.split(r"[\r\n]+", text):
            line = self._normalize_candidate_text(raw_line)
            if len(line) < 4:
                continue
            score = self._support_ratio(query, line)
            if self._contains_numeric_value(line) and self._expects_numeric_answer(query):
                score += 0.15
            if score > best_score or (
                abs(score - best_score) < 1e-9
                and best_line is not None
                and len(line) < len(best_line)
            ):
                best_line = line
                best_score = score
        if best_score < 0.2:
            return None
        return best_line

    def _expects_numeric_answer(self, query: str) -> bool:
        lowered_query = query.lower()
        return any(
            phrase in lowered_query
            for phrase in (
                "how many",
                "number of",
                "count of",
                "how much",
                "how long",
                "how heavy",
                "how fast",
            )
        )

    def _expects_yes_no_answer(self, query: str) -> bool:
        lowered_query = query.lower().strip()
        return lowered_query.startswith(
            ("is ", "are ", "does ", "do ", "can ", "supports ", "has ", "have ")
        )

    def _contains_numeric_value(self, text: str) -> bool:
        return bool(re.search(r"\b\d+(?:\.\d+)?\b", text, flags=re.IGNORECASE))

    def _noise_penalty(self, text: str, context: str) -> float:
        lowered = f"{text} {context}".lower()
        penalty = 0.0
        for phrase, value in (
            ("configuration tested", 0.28),
            ("learn more", 0.12),
            ("support.apple.com", 0.12),
            ("helpful? yes no", 0.12),
            ("privacy policy", 0.12),
            ("terms of use", 0.12),
            ("actual viewable area is less", 0.10),
        ):
            if phrase in lowered:
                penalty += value
        if re.search(r"\b\d+/\d+\b", lowered):
            penalty += 0.05
        if re.match(r"^\d+\.", text):
            penalty += 0.05
        return penalty

    def _direct_answer_bonus(self, query: str, text: str) -> float:
        lowered_query = query.lower()
        lowered_text = text.lower()
        bonus = 0.0
        if len(text) <= 120:
            bonus += 0.08
        if self._support_ratio(query, text) >= 0.45:
            bonus += 0.08
        if self._expects_numeric_answer(query) and self._contains_numeric_value(text):
            bonus += 0.12
        for keyword in ("processor", "chip", "memory", "storage", "battery", "display", "weight", "camera", "ports"):
            if keyword in lowered_query and keyword in lowered_text:
                bonus += 0.08
        if "configurable to" in lowered_text:
            bonus -= 0.08
        return bonus

    def _rewrite_fact_line(self, query: str, evidence: str) -> Optional[str]:
        lowered_query = query.lower()

        if "memory" in lowered_query:
            match = re.search(r"(\d+\s*(?:GB|TB)\s+unified\s+memory)", evidence, flags=re.IGNORECASE)
            if match:
                return f"It has {match.group(1)}."

        if "processor" in lowered_query or "chip" in lowered_query:
            match = re.search(
                r"equipped with (?:the )?(?:well-known )?(.+?(?:processor|chip))",
                evidence,
                flags=re.IGNORECASE,
            )
            if match:
                return f"It uses {self._normalize_candidate_text(match.group(1))}."
            match = re.search(
                r"\b([A-Z][A-Za-z0-9 .+\-]{1,60}\b(?:processor|chip))",
                evidence,
                flags=re.IGNORECASE,
            )
            if match:
                return f"It uses the {self._normalize_candidate_text(match.group(1))}."

        if "storage" in lowered_query:
            match = re.search(r"(\d+\s*(?:GB|TB)\s+SSD)", evidence, flags=re.IGNORECASE)
            if match:
                return f"It has {match.group(1)} storage."

        if "battery" in lowered_query:
            match = re.search(r"(Up to\s+\d+\s+hours\s+(?:video streaming|wireless web))", evidence, flags=re.IGNORECASE)
            if match:
                return self._ensure_terminal_period(match.group(1))

        if "weight" in lowered_query:
            match = re.search(r"(\d+(?:\.\d+)?\s+pounds\s+\(\d+(?:\.\d+)?\s+kg\))", evidence, flags=re.IGNORECASE)
            if match:
                return f"It weighs {match.group(1)}."

        return None

    def _is_duplicate_evidence(
        self,
        selected: List[Dict[str, Any]],
        candidate: Dict[str, Any],
    ) -> bool:
        normalized_candidate = candidate["text"].lower()
        for item in selected:
            normalized_selected = item["text"].lower()
            if normalized_candidate == normalized_selected:
                return True
            if normalized_candidate in normalized_selected or normalized_selected in normalized_candidate:
                return True
        return False

    def _is_answer_grounded(self, answer: str, evidence_text: str) -> bool:
        answer_terms = set(self._meaningful_terms(answer))
        if not answer_terms:
            return False

        evidence_terms = set(self._meaningful_terms(evidence_text))
        lexical_overlap = len(answer_terms & evidence_terms) / max(len(answer_terms), 1)
        answer_numbers = set(re.findall(r"\d+(?:\.\d+)?", answer))
        evidence_numbers = set(re.findall(r"\d+(?:\.\d+)?", evidence_text))
        if answer_numbers and not answer_numbers.issubset(evidence_numbers):
            return False
        return lexical_overlap >= 0.5

    def _confidence_label(self, evidence_blocks: List[Dict[str, Any]]) -> str:
        if not evidence_blocks:
            return "low"
        primary = evidence_blocks[0]
        probability = float(primary.get("rerank_probability", self._sigmoid(float(primary.get("score", 0.0)))))
        support = float(primary.get("support", 0.0))
        corroboration = 1 if len(evidence_blocks) > 1 else 0
        if probability >= 0.86 and support >= 0.35 and corroboration:
            return "high"
        if probability >= 0.72 and support >= 0.25:
            return "medium"
        return "low"

    def _ensure_terminal_period(self, text: str) -> str:
        cleaned = text.strip()
        if not cleaned:
            return FALLBACK_ANSWER
        if cleaned.endswith((".", "!", "?")):
            return cleaned
        return f"{cleaned}."

    def _sigmoid(self, value: float) -> float:
        return 1.0 / (1.0 + math.exp(-value))

    def _fallback(self) -> ProductChatResponse:
        return ProductChatResponse(
            answer=FALLBACK_ANSWER,
            source=None,
            confidence="low",
        )
