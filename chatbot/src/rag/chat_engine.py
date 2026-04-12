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
    "how",
    "i",
    "in",
    "is",
    "it",
    "me",
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
    """Strict extractive product-document QA engine."""

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

        if document_url and (
            force_document_sync
            or self.vector_store.should_reindex(product_id, document_url)
        ):
            await self.document_processor.sync_product_document(
                product_id=product_id,
                document_url=document_url,
                force=True,
            )

        direct_fact = self._find_document_wide_direct_fact(
            product_id=product_id,
            query=cleaned_query,
        )
        if direct_fact:
            return ProductChatResponse(
                answer=self._render_grounded_answer(cleaned_query, direct_fact["text"]),
                source=AnswerSource(
                    page=int(direct_fact["page"]),
                    chunk_id=int(direct_fact["chunk_id"]),
                ),
                confidence=self._confidence_label(
                    score=float(direct_fact.get("score", 0.0)),
                    support=float(direct_fact.get("support", 0.0)),
                    deterministic=bool(direct_fact.get("deterministic_match")),
                    exact_pattern_match=bool(direct_fact.get("exact_pattern_match")),
                ),
            )

        retrieved = self.vector_store.similarity_search(
            product_id=product_id,
            query=cleaned_query,
            k=settings.TOP_K_RESULTS,
        )
        if not retrieved:
            return self._fallback()

        reranked_chunks = self.vector_store.rerank_chunks(cleaned_query, retrieved)
        if not reranked_chunks:
            return self._fallback()

        sentence_candidates = self._collect_sentence_candidates(
            cleaned_query,
            reranked_chunks,
        )
        if not sentence_candidates:
            return self._fallback()

        ranked_sentences = self.vector_store.rerank_sentences(
            cleaned_query,
            sentence_candidates,
        )
        if not ranked_sentences:
            return self._fallback()

        selected = self._select_sentence_with_guardrails(
            query=cleaned_query,
            ranked_sentences=ranked_sentences,
        )
        if not selected:
            return self._fallback()

        answer_text = self._render_grounded_answer(
            cleaned_query,
            selected["text"],
        )

        return ProductChatResponse(
            answer=answer_text,
            source=AnswerSource(
                page=int(selected["page"]),
                chunk_id=int(selected["chunk_id"]),
            ),
            confidence=self._confidence_label(
                score=float(selected["score"]),
                support=float(selected["support"]),
                deterministic=bool(selected.get("deterministic_match")),
                exact_pattern_match=bool(selected.get("exact_pattern_match")),
            ),
        )

    def _find_document_wide_direct_fact(
        self,
        product_id: str,
        query: str,
    ) -> Optional[Dict[str, Any]]:
        if not self._focused_patterns_for_query(query):
            return None

        chunks = self.vector_store.load_product_chunks(product_id)
        if not chunks:
            return None

        candidates = self._collect_sentence_candidates(query, chunks)
        if not candidates:
            return None

        enriched_candidates = []
        for candidate in candidates:
            enriched = dict(candidate)
            enriched["score"] = float(candidate.get("score", 0.0))
            enriched["support"] = self._support_ratio(query, candidate["text"])
            enriched_candidates.append(enriched)

        chosen = self._choose_deterministic_direct_fact(query, enriched_candidates)
        if not chosen or not chosen.get("exact_pattern_match"):
            return None

        return chosen

    def _collect_sentence_candidates(
        self,
        query: str,
        matches: List[SearchMatch],
    ) -> List[Dict[str, Any]]:
        candidates: List[Dict[str, Any]] = []
        seen = set()

        for match in matches:
            candidate_texts = [
                *self._split_sentences(match.text),
                *self._extract_targeted_spans(query, match.text),
            ]
            for sentence in candidate_texts:
                normalized = " ".join(sentence.lower().split())
                if normalized in seen:
                    continue
                seen.add(normalized)
                candidates.append(
                    {
                        "text": sentence,
                        "page": match.metadata["page"],
                        "chunk_id": match.metadata["chunk_id"],
                        "context_text": match.text,
                    }
                )

        return candidates

    def _split_sentences(self, text: str) -> List[str]:
        parts = re.split(r"(?<=[.!?])\s+", text)
        sentences = []
        for part in parts:
            sentence = part.strip()
            if len(sentence) < 12:
                continue
            if re.search(r"[A-Za-z0-9]", sentence):
                sentences.append(sentence)
        return sentences

    def _extract_targeted_spans(self, query: str, text: str) -> List[str]:
        spans: List[str] = []

        for term in self._meaningful_terms(query):
            lowered = text.lower()
            start_index = 0
            while True:
                hit = lowered.find(term, start_index)
                if hit == -1:
                    break

                window_start = max(0, hit - 40)
                window_end = min(len(text), hit + 140)
                snippet = text[window_start:window_end].strip(" ,;:")
                if len(snippet) >= 8:
                    spans.append(snippet)

                start_index = hit + len(term)

        for pattern in (
            r"\bApple\s+[A-Za-z0-9\-+ ]{0,40}\s+chip\b",
            r"\b[A-Z][A-Za-z0-9\-+ ]{0,30}\s+chip\b",
        ):
            for match in re.finditer(pattern, text, flags=re.IGNORECASE):
                spans.append(match.group(0).strip())

        for pattern in self._focused_patterns_for_query(query):
            for match in re.finditer(pattern, text, flags=re.IGNORECASE):
                spans.append(match.group(0).strip())

        return spans

    def _select_sentence_with_guardrails(
        self,
        query: str,
        ranked_sentences: List[Dict[str, Any]],
    ) -> Optional[Dict[str, Any]]:
        enriched_candidates = []
        for candidate in ranked_sentences:
            enriched = dict(candidate)
            enriched["support"] = self._support_ratio(query, candidate["text"])
            enriched_candidates.append(enriched)

        direct_match = self._choose_deterministic_direct_fact(
            query,
            enriched_candidates,
        )
        if direct_match is not None:
            return direct_match

        llm_choice = self._choose_with_ollama(query, enriched_candidates)
        if llm_choice is not None:
            chosen = enriched_candidates[llm_choice]
            if self._is_supported_answer(chosen):
                return chosen

        strongest = enriched_candidates[0]
        if self._is_supported_answer(strongest):
            return strongest

        return None

    def _choose_deterministic_direct_fact(
        self,
        query: str,
        candidates: List[Dict[str, Any]],
    ) -> Optional[Dict[str, Any]]:
        query_terms = set(self._meaningful_terms(query))
        if not query_terms:
            return None

        keyword_patterns = self._focused_patterns_for_query(query)

        for pattern in keyword_patterns:
            pattern_matches = []
            for candidate in candidates:
                if re.search(pattern, candidate["text"], flags=re.IGNORECASE):
                    pattern_matches.append(candidate)
            if pattern_matches:
                pattern_matches.sort(
                    key=self._candidate_sort_key,
                )
                chosen = dict(pattern_matches[0])
                chosen["deterministic_match"] = True
                chosen["exact_pattern_match"] = True
                return chosen

        strong_candidates = [
            candidate
            for candidate in candidates
            if float(candidate.get("support", 0.0)) >= 0.4
        ]
        if not strong_candidates:
            return None

        compact_candidates = [
            candidate for candidate in strong_candidates if len(candidate["text"]) <= 80
        ]
        if compact_candidates:
            compact_candidates.sort(key=self._candidate_sort_key)
            chosen = dict(compact_candidates[0])
            chosen["deterministic_match"] = True
            return chosen

        return None

    def _focused_patterns_for_query(self, query: str) -> List[str]:
        lowered_query = query.lower()
        patterns: List[str] = []

        if "chip" in lowered_query:
            patterns.extend(
                [
                    r"\bApple\s+[A-Za-z0-9\-+ ]{0,40}\s+chip\b",
                    r"\b[A-Z][A-Za-z0-9\-+ ]{0,30}\s+chip\b",
                ]
            )
        if "performance core" in lowered_query:
            patterns.append(r"\b\d+\s+performance\s+cores?\b")
        if "efficiency core" in lowered_query:
            patterns.append(r"\b\d+\s+efficiency\s+cores?\b")
        if "gpu" in lowered_query:
            patterns.extend(
                [
                    r"\b\d+\s*-\s*core\s+GPU,\s*\d+\s*-\s*core\s+GPU\b",
                    r"\b\d+\s*-\s*core\s+GPU\b",
                ]
            )
        if "cpu" in lowered_query:
            patterns.append(r"\b\d+\s*-\s*core\s+CPU\b")
        if "memory bandwidth" in lowered_query or "bandwidth" in lowered_query:
            patterns.append(r"\b\d+\s*GB/s\s+memory\s+bandwidth\b")
        if "unified memory" in lowered_query or "ram" in lowered_query or "memory" in lowered_query:
            patterns.append(r"\b\d+\s*GB\s+unified\s+memory\b")
        if "storage" in lowered_query:
            patterns.append(r"\b\d+\s*(?:GB|TB)\s+SSD\b")
        if "video streaming" in lowered_query:
            patterns.append(r"Up to \d+\s+hours\s+video\s+streaming")
        if "wireless web" in lowered_query:
            patterns.append(r"Up to \d+\s+hours\s+wireless\s+web")
        if "battery life" in lowered_query and "video streaming" not in lowered_query and "wireless web" not in lowered_query:
            patterns.extend(
                [
                    r"Up to \d+\s+hours\s+video\s+streaming",
                    r"Up to \d+\s+hours\s+wireless\s+web",
                ]
            )
        if "watt-hour" in lowered_query or "battery rating" in lowered_query or "battery capacity" in lowered_query:
            patterns.append(r"(?:Built-in\s+)?\d+(?:\.\d+)?-watt-hour(?:\s+[A-Za-z-]+)*\s+battery")
        if "bright" in lowered_query or "brightness" in lowered_query or "nits" in lowered_query:
            patterns.append(r"\b\d+\s+nits\s+brightness\b")
        if "screen size" in lowered_query or ("screen" in lowered_query and "size" in lowered_query):
            patterns.extend(
                [
                    r"\b\d+(?:\.\d+)?-inch\s+\([^)]+\)\s+(?:LED-backlit|Liquid Retina)\s+display\b",
                    r"\b\d+(?:\.\d+)?\s+inches?\s+diagonally\b",
                    r"\b\d+(?:\.\d+)?-inch\b",
                ]
            )
        if "weight" in lowered_query:
            patterns.append(r"\b\d+(?:\.\d+)?\s+pounds\s+\(\d+(?:\.\d+)?\s+kg\)\b")
        if "external display" in lowered_query:
            patterns.extend(
                [
                    r"\bsupport(?:s)?\s+for\s+up\s+to\s+(?:one|two|\d+)\s+external\s+displays?\b",
                    r"\bup\s+to\s+(?:one|two|\d+)\s+external\s+displays?\b",
                ]
            )
        if "camera" in lowered_query:
            patterns.append(r"\b\d+\s*MP\s+Center Stage camera\b")
        if "wireless" in lowered_query or "wifi" in lowered_query or "wi-fi" in lowered_query:
            patterns.append(r"\bWi-?Fi\s+\d+(?:E)?\s+\(802\.11[a-z]+\)\b")
        if "thunderbolt" in lowered_query or "usb-c" in lowered_query or re.search(r"\bports?\b", lowered_query):
            patterns.append(r"\b(?:Two|\d+)\s+Thunderbolt\s+\d+\s+\(USB-C\)\s+ports?\b")
        if "ray tracing" in lowered_query:
            patterns.append(r"\bHardware-accelerated\s+ray\s+tracing\b")

        return patterns

    def _candidate_sort_key(self, item: Dict[str, Any]):
        text = item["text"].lower()
        context_text = str(item.get("context_text", item["text"])).lower()
        penalty = 0
        for noisy_phrase in (
            "configuration tested",
            "testing conducted",
            "supported formats",
            "learn more about",
        ):
            if noisy_phrase in context_text:
                penalty += 1

        if "configurable to" in context_text and len(text) > 40:
            penalty += 1

        return (
            penalty,
            int(item.get("page", 999)),
            len(item["text"]),
            -float(item["score"]),
        )

    def _choose_with_ollama(
        self,
        query: str,
        candidates: List[Dict[str, Any]],
    ) -> Optional[int]:
        prompt_lines = [
            "You select one exact sentence from a product manual.",
            "Rules:",
            "- Reply with JSON only.",
            "- Return {\"sentence_id\": null} if no sentence directly answers the question.",
            "- Never rewrite or combine sentences.",
            "",
            f"Question: {query}",
            "Candidate sentences:",
        ]

        for index, candidate in enumerate(candidates, start=1):
            prompt_lines.append(f"{index}. {candidate['text']}")

        prompt_lines.append("")
        prompt_lines.append("Return JSON with this exact shape: {\"sentence_id\": number|null}")

        try:
            response = requests.post(
                f"{settings.OLLAMA_BASE_URL}/api/generate",
                json={
                    "model": settings.OLLAMA_MODEL,
                    "prompt": "\n".join(prompt_lines),
                    "stream": False,
                    "format": "json",
                    "options": {
                        "temperature": 0,
                    },
                },
                timeout=settings.OLLAMA_TIMEOUT_SECONDS,
            )
            response.raise_for_status()
            payload = response.json()
            raw = payload.get("response", "{}")
            parsed = json.loads(raw)
            sentence_id = parsed.get("sentence_id")
            if sentence_id is None:
                return None
            if isinstance(sentence_id, int) and 1 <= sentence_id <= len(candidates):
                return sentence_id - 1
        except Exception as exc:
            logger.warning("Ollama selection failed, using deterministic fallback: %s", exc)

        return None

    def _render_grounded_answer(self, query: str, evidence: str) -> str:
        cleaned_evidence = " ".join(evidence.split())
        if not cleaned_evidence:
            return FALLBACK_ANSWER

        focused_evidence = self._focus_evidence_for_query(query, cleaned_evidence)

        rewritten = self._rewrite_with_ollama(query, focused_evidence)
        if rewritten:
            return rewritten

        return self._deterministic_rewrite(query, focused_evidence)

    def _focus_evidence_for_query(self, query: str, evidence: str) -> str:
        lowered_query = query.lower()

        for pattern in self._focused_patterns_for_query(query):
            match = re.search(pattern, evidence, flags=re.IGNORECASE)
            if match:
                return match.group(0).strip()

        return evidence

    def _rewrite_with_ollama(self, query: str, evidence: str) -> Optional[str]:
        prompt = "\n".join(
            [
                "You answer product-document questions using only the supplied evidence.",
                "Rules:",
                "- Use only facts that appear in the evidence.",
                "- Write one short, clear sentence in natural English.",
                "- Do not add any facts, explanations, or assumptions.",
                f"- If the evidence is insufficient, return exactly: {FALLBACK_ANSWER}",
                "",
                f"Question: {query}",
                f"Evidence: {evidence}",
                "",
                "Return JSON with this exact shape: {\"answer\": \"...\"}",
            ]
        )

        try:
            response = requests.post(
                f"{settings.OLLAMA_BASE_URL}/api/generate",
                json={
                    "model": settings.OLLAMA_MODEL,
                    "prompt": prompt,
                    "stream": False,
                    "format": "json",
                    "options": {"temperature": 0},
                },
                timeout=settings.OLLAMA_TIMEOUT_SECONDS,
            )
            response.raise_for_status()
            payload = response.json()
            raw = payload.get("response", "{}")
            parsed = json.loads(raw)
            answer = " ".join(str(parsed.get("answer", "")).split())
            if not answer:
                return None
            if answer == FALLBACK_ANSWER:
                return answer
            return answer
        except Exception as exc:
            logger.warning("Ollama rewrite failed, using deterministic fallback: %s", exc)
            return None

    def _deterministic_rewrite(self, query: str, evidence: str) -> str:
        lowered_query = query.lower()

        if "chip" in lowered_query and "chip" in evidence.lower():
            return f"It uses the {self._ensure_terminal_period(evidence)}".replace("..", ".")

        performance_only_match = re.search(
            r"(\d+)\s+performance\s+cores?",
            evidence,
            flags=re.IGNORECASE,
        )
        if "performance core" in lowered_query and performance_only_match:
            return f"It has {performance_only_match.group(1)} performance cores."

        efficiency_only_match = re.search(
            r"(\d+)\s+efficiency\s+cores?",
            evidence,
            flags=re.IGNORECASE,
        )
        if "efficiency core" in lowered_query and efficiency_only_match:
            return f"It has {efficiency_only_match.group(1)} efficiency cores."

        memory_match = re.search(
            r"(\d+\s*GB)\s+unified\s+memory",
            evidence,
            flags=re.IGNORECASE,
        )
        if ("unified memory" in lowered_query or "ram" in lowered_query or "memory" in lowered_query) and memory_match:
            return f"It has {memory_match.group(1)} unified memory."

        gpu_match = re.search(
            r"(\d+)\s*-\s*core\s+GPU",
            evidence,
            flags=re.IGNORECASE,
        )
        gpu_options_match = re.search(
            r"(\d+)\s*-\s*core\s+GPU,\s*(\d+)\s*-\s*core\s+GPU",
            evidence,
            flags=re.IGNORECASE,
        )
        if "gpu" in lowered_query and gpu_options_match:
            return (
                f"The document lists a {gpu_options_match.group(1)}-core GPU "
                f"or {gpu_options_match.group(2)}-core GPU, depending on configuration."
            )
        if "gpu" in lowered_query and gpu_match:
            return f"It has a {gpu_match.group(1)}-core GPU."

        bandwidth_match = re.search(
            r"(\d+\s*GB/s)\s+memory\s+bandwidth",
            evidence,
            flags=re.IGNORECASE,
        )
        if "bandwidth" in lowered_query and bandwidth_match:
            return f"It has {bandwidth_match.group(1)} memory bandwidth."

        brightness_match = re.search(
            r"(\d+)\s+nits\s+brightness",
            evidence,
            flags=re.IGNORECASE,
        )
        if ("bright" in lowered_query or "brightness" in lowered_query or "nits" in lowered_query) and brightness_match:
            return f"The display is {brightness_match.group(1)} nits bright."

        storage_match = re.search(
            r"(\d+\s*(?:GB|TB))\s+SSD",
            evidence,
            flags=re.IGNORECASE,
        )
        if "storage" in lowered_query and storage_match:
            return f"It comes with {storage_match.group(1)} SSD storage."

        battery_match = re.search(
            r"Up to\s+(\d+)\s+hours\s+video\s+streaming",
            evidence,
            flags=re.IGNORECASE,
        )
        if "video streaming" in lowered_query and battery_match:
            return f"It offers up to {battery_match.group(1)} hours of video streaming."

        wireless_web_match = re.search(
            r"Up to\s+(\d+)\s+hours\s+wireless\s+web",
            evidence,
            flags=re.IGNORECASE,
        )
        if "wireless web" in lowered_query and wireless_web_match:
            return f"It offers up to {wireless_web_match.group(1)} hours of wireless web use."

        if "battery life" in lowered_query and battery_match:
            return f"It offers up to {battery_match.group(1)} hours of video streaming."

        watt_hour_match = re.search(
            r"(?:Built-in\s+)?(\d+(?:\.\d+)?)\-watt-hour(?:\s+[A-Za-z-]+)*\s+battery",
            evidence,
            flags=re.IGNORECASE,
        )
        if ("watt-hour" in lowered_query or "battery rating" in lowered_query or "battery capacity" in lowered_query) and watt_hour_match:
            return f"It has a {watt_hour_match.group(1)}-watt-hour battery."

        performance_match = re.search(
            r"(\d+)\s+performance\s+cores?\s+and\s+(\d+)\s+efficiency\s+cores?",
            evidence,
            flags=re.IGNORECASE,
        )
        if performance_match:
            return (
                f"It has {performance_match.group(1)} performance cores and "
                f"{performance_match.group(2)} efficiency cores."
            )

        cpu_match = re.search(
            r"(\d+)\s*-\s*core\s+CPU",
            evidence,
            flags=re.IGNORECASE,
        )
        if "cpu" in lowered_query and cpu_match:
            return f"It has a {cpu_match.group(1)}-core CPU."

        screen_size_match = re.search(
            r"(\d+(?:\.\d+)?)\-inch",
            evidence,
            flags=re.IGNORECASE,
        )
        screen_size_inches_match = re.search(
            r"(\d+(?:\.\d+)?)\s+inches?\s+diagonally",
            evidence,
            flags=re.IGNORECASE,
        )
        if ("screen size" in lowered_query or ("screen" in lowered_query and "size" in lowered_query)) and screen_size_match:
            return f"It has a {screen_size_match.group(1)}-inch display."
        if ("screen size" in lowered_query or ("screen" in lowered_query and "size" in lowered_query)) and screen_size_inches_match:
            return f"It has a {screen_size_inches_match.group(1)}-inch display."

        weight_match = re.search(
            r"(\d+(?:\.\d+)?)\s+pounds\s+\((\d+(?:\.\d+)?)\s+kg\)",
            evidence,
            flags=re.IGNORECASE,
        )
        if "weight" in lowered_query and weight_match:
            return f"It weighs {weight_match.group(1)} pounds ({weight_match.group(2)} kg)."

        external_display_match = re.search(
            r"(?:support(?:s)?\s+for\s+)?up\s+to\s+((?:one|two|\d+)\s+external\s+displays?)",
            evidence,
            flags=re.IGNORECASE,
        )
        if "external display" in lowered_query and external_display_match:
            return f"It supports up to {external_display_match.group(1)}."

        camera_match = re.search(
            r"(\d+\s*MP\s+Center Stage camera)",
            evidence,
            flags=re.IGNORECASE,
        )
        if "camera" in lowered_query and camera_match:
            return f"It has a {camera_match.group(1)}."

        wifi_match = re.search(
            r"(Wi-?Fi\s+\d+(?:E)?\s+\(802\.11[a-z]+\))",
            evidence,
            flags=re.IGNORECASE,
        )
        if ("wireless" in lowered_query or "wifi" in lowered_query or "wi-fi" in lowered_query) and wifi_match:
            return f"It supports {wifi_match.group(1)}."

        thunderbolt_match = re.search(
            r"((?:Two|\d+)\s+Thunderbolt\s+\d+\s+\(USB-C\)\s+ports?)",
            evidence,
            flags=re.IGNORECASE,
        )
        if ("thunderbolt" in lowered_query or "usb-c" in lowered_query or re.search(r"\bports?\b", lowered_query)) and thunderbolt_match:
            return f"It has {thunderbolt_match.group(1)}."

        if "ray tracing" in lowered_query and re.search(
            r"Hardware-accelerated\s+ray\s+tracing",
            evidence,
            flags=re.IGNORECASE,
        ):
            return "Yes, it supports hardware-accelerated ray tracing."

        return self._ensure_terminal_period(evidence)

    def _ensure_terminal_period(self, text: str) -> str:
        cleaned = text.strip()
        if not cleaned:
            return FALLBACK_ANSWER
        if cleaned.endswith((".", "!", "?")):
            return cleaned
        return f"{cleaned}."

    def _is_supported_answer(self, candidate: Dict[str, Any]) -> bool:
        probability = self._sigmoid(float(candidate["score"]))
        support = float(candidate["support"])

        if probability >= 0.84:
            return True
        if probability >= 0.72 and support >= 0.25:
            return True
        if probability >= 0.58 and support >= 0.5:
            return True
        return False

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

    def _confidence_label(
        self,
        score: float,
        support: float,
        deterministic: bool = False,
        exact_pattern_match: bool = False,
    ) -> str:
        if exact_pattern_match:
            return "high"
        if deterministic and support >= 0.5:
            return "high"
        probability = self._sigmoid(score)
        if probability >= 0.84 and support >= 0.35:
            return "high"
        if probability >= 0.7 and support >= 0.2:
            return "medium"
        return "low"

    def _sigmoid(self, value: float) -> float:
        return 1.0 / (1.0 + math.exp(-value))

    def _fallback(self) -> ProductChatResponse:
        return ProductChatResponse(
            answer=FALLBACK_ANSWER,
            source=None,
            confidence="low",
        )
