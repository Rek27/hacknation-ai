# 🛒 SmartCart

## 📑 Table of Contents

- [The Problem](#-the-problem)
- [Target Audience](#-target-audience)
- [Solution Overview](#-solution-overview)
- [Core Features](#-core-features)
- [Unique Selling Proposition](#-unique-selling-proposition)
- [Architecture & Tech Stack](#-architecture--tech-stack)
- [System Workflow](#-system-workflow)
- [Results & Impact](#-results--impact)
- [Future Improvements](#-future-improvements)

## 🚩 The Problem

Event organizers face a fragmented and time-consuming procurement process:

- Searching and comparing products across multiple retailers
- Estimating quantities for food, drinks, materials, and supplies
- Managing budgets and delivery deadlines
- Handling multiple checkouts
- Missing discounts or sponsorship opportunities

Procurement becomes slow, stressful, and error-prone — especially under tight deadlines.

## 🎯 Target Audience

SmartCart is designed for:
- Hackathon organizers
- Event coordinators
- Party planners
- Community managers
- University tech clubs
- Corporate innovation teams

Anyone who must purchase across categories, retailers, and constraints — quickly and efficiently.

## 💡 Solution Overview

SmartCart replaces manual procurement with agent-driven commerce.

Users express high-level intent:

``` “I’m organizing a 100-person hackathon next weekend. Budget is €2,000. We need snacks, drinks, and extension cables.” ```

SmartCart then:

1. Calculates quantities
2 Discovers products across multiple retailers
3. Ranks options transparently
4. Builds a unified cart
5. Simulates checkout orchestration
6. Negotiates sponsorships and discounts

All through a conversational interface (text or voice).


## ✨ Core Features

### 🗣 Natural Language & Voice Input
- Capture event size, budget, deadlines, and preferences
- Hands-free interaction with speech-to-text and TTS

### 📦 Automatic Quantity Calculation
- Smart estimation based on event type and attendance
- Reduces under- or over-purchasing

### 🔎 Multi-Retailer Semantic Search
- Cross-category product discovery
- RAG-powered semantic retrieval
- Metadata filtering

### 📊 Transparent Ranking Engine
Products ranked by:

- Price
- Delivery speed
- Ratings

Includes explainable reasoning and alternative suggestions (cheapest, fastest, best-rated).

### 🛍 Unified Multi-Retailer Cart
- Aggregates items from different stores
- Allows substitutions and alternatives
- Fully itemized with cost breakdown

### 🤖 Autonomous Checkout Simulation
- Simulated multi-store checkout orchestration
- Deterministic sponsorship and discount negotiation

### 📺 Real-Time Guided UI
- Step-by-step streaming updates via SSE
- Clear, low cognitive load interface

## 🚀 Unique Selling Proposition
SmartCart is not a recommendation engine — it’s an agentic execution system.

✅ End-to-end workflow automation (intent → checkout)

✅ Multi-retailer by design

✅ High-level goal delegation instead of SKU selection

✅ Explainable product ranking

✅ Automated sponsorship & discount negotiation

✅ Voice-first interaction

✅ Modern, efficient UI optimized for speed

## 🏗 Architecture & Tech Stack

### Backend
- FastAPI (Python)
- Server-Sent Events (SSE) for real-time streaming

### AI Orchestration
- Multi-agent architecture
- OpenAI GPT-4.1 with strict function calling
  - Recommendation Agent
  - Form Agent
  - ShoppingList Agent
  - Purchase Agent
  - Voice Agent
  
### Search & Retrieval
- RAG pipeline
- ChromaDB vector database
- sentence-transformers (all-MiniLM-L6-v2, 384-dim embeddings)
- Semantic search with metadata filtering

### Ranking Engine
- Multi-criteria scoring:
  - Cost
  - Delivery speed
  - Ratings
- Explainable ranking outputs

### Frontend
- Flutter (Dart)
- Cross-platform: Web, iOS, Android, macOS
- MVC architecture
- SSE consumption for live updates

### Voice Interaction
- Whisper-1 (speech-to-text)
- TTS-1 (text-to-speech)
  
### Data & Simulation
- Mock retailers and products
- Deterministic sponsorship & checkout simulation

## 🔄 System Workflow
1. User expresses event intent (text or voice)
2. Agents extract constraints and requirements
3. Quantity estimation engine computes needs
4. Semantic search retrieves multi-retailer products
5. Ranking engine scores and explains options
6. Unified cart is built with alternatives
7. Checkout and sponsorship simulation runs
8. User receives real-time, guided updates

## 📈 Results & Impact
SmartCart successfully demonstrates:

- Fully working end-to-end agentic commerce system
- Natural language + voice-driven procurement
- Multi-retailer semantic discovery
- Transparent, explainable ranking
- Unified cross-store cart aggregation
- Simulated autonomous checkout
- Automated sponsorship negotiation

### Outcome
SmartCart significantly reduces:
- Time spent on procurement
- Cognitive load
- Manual comparison effort
- Decision fatigue

While improving:
- Budget control
- Delivery reliability
- Purchasing efficiency

## 🔮 Future Improvements
- Live retailer API integrations
- Real payment processing
- Dynamic sponsorship negotiation with real partners
- Improved logistics coordination
- Advanced demand prediction models
- Team collaboration features
