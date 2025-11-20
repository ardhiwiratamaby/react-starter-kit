# Stage 5: AI Service Gateway

## Stage Overview

This stage implements the AI Service Gateway that provides a unified interface for multiple AI providers (OpenAI, Google Cloud, AWS, etc.) with provider abstraction, failover capabilities, and cost optimization. The gateway handles Text-to-Speech (TTS), Speech-to-Text (STT), and Language Model (LLM) operations.

## Observable Outcomes

- ✅ FastAPI-based AI Gateway service running in Docker
- ✅ Provider abstraction layer supporting multiple AI services
- ✅ Configuration management for AI providers
- ✅ Health checks and monitoring endpoints
- ✅ Rate limiting and quota management
- ✅ Cost tracking and usage analytics
- ✅ Fallback and error handling mechanisms

## Technical Requirements

### AI Provider Support

- **Text-to-Speech (TTS)**: OpenAI, Google Cloud TTS, Amazon Polly
- **Speech-to-Text (STT)**: OpenAI Whisper, Google Cloud Speech, Deepgram
- **Language Models (LLM)**: OpenAI GPT, Google Gemini, Anthropic Claude

### Gateway Features

- Provider abstraction and routing
- Automatic failover between providers
- Cost optimization based on pricing models
- Rate limiting and quota enforcement
- Request/response caching where appropriate
- Comprehensive logging and monitoring

### Performance Requirements

- Sub-200ms response time for text operations
- Sub-2s response time for audio operations
- 99.9% availability target
- Horizontal scaling capability

## Implementation Details

### Step 1: FastAPI Gateway Structure

#### 1.1 Main Application Setup

```python
# apps/ai-gateway/main.py
from fastapi import FastAPI, HTTPException, Request, Depends
from fastapi.middleware.cors import CORSMiddleware
from fastapi.middleware.gzip import GZipMiddleware
from contextlib import asynccontextmanager
import uvicorn
import logging
from datetime import datetime

from routers import tts, stt, llm, health, admin
from services.config import Settings
from services.monitoring import MonitoringService
from services.rate_limiter import RateLimiter

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s"
)
logger = logging.getLogger(__name__)

settings = Settings()
monitoring = MonitoringService()
rate_limiter = RateLimiter()

@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup
    logger.info("AI Gateway starting up...")
    await monitoring.initialize()
    logger.info("AI Gateway ready")
    yield
    # Shutdown
    logger.info("AI Gateway shutting down...")

# Create FastAPI app
app = FastAPI(
    title="AI Service Gateway",
    description="Unified interface for AI service providers",
    version="1.0.0",
    lifespan=lifespan
)

# Add middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.ALLOWED_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)
app.add_middleware(GZipMiddleware, minimum_size=1000)

# Include routers
app.include_router(health.router, prefix="/health", tags=["health"])
app.include_router(tts.router, prefix="/tts", tags=["tts"])
app.include_router(stt.router, prefix="/stt", tags=["stt"])
app.include_router(llm.router, prefix="/llm", tags=["llm"])
app.include_router(admin.router, prefix="/admin", tags=["admin"])

# Rate limiting middleware
@app.middleware("http")
async def rate_limit_middleware(request: Request, call_next):
    client_ip = request.client.host
    path = request.url.path

    # Skip health checks
    if path.startswith("/health"):
        return await call_next(request)

    # Check rate limit
    if not await rate_limiter.is_allowed(client_ip, path):
        raise HTTPException(
            status_code=429,
            detail="Rate limit exceeded"
        )

    response = await call_next(request)
    return response

@app.get("/")
async def root():
    return {
        "service": "AI Service Gateway",
        "status": "running",
        "timestamp": datetime.utcnow().isoformat(),
        "version": "1.0.0"
    }

if __name__ == "__main__":
    uvicorn.run(
        "main:app",
        host="0.0.0.0",
        port=8001,
        reload=settings.DEBUG,
        log_level="info"
    )
```

#### 1.2 Configuration Management

```python
# apps/ai-gateway/services/config.py
from pydantic import BaseSettings
from typing import List, Dict, Any
import os

class Settings(BaseSettings):
    # General settings
    DEBUG: bool = False
    ENVIRONMENT: str = "development"

    # Security
    SECRET_KEY: str
    API_KEYS: List[str] = []

    # CORS
    ALLOWED_ORIGINS: List[str] = ["http://localhost:3000", "http://localhost:4000"]

    # Rate limiting
    RATE_LIMIT_PER_MINUTE: int = 60
    RATE_LIMIT_PER_HOUR: int = 1000

    # OpenAI
    OPENAI_API_KEY: str = ""
    OPENAI_BASE_URL: str = "https://api.openai.com/v1"

    # Google Cloud
    GOOGLE_API_KEY: str = ""
    GOOGLE_PROJECT_ID: str = ""

    # AWS
    AWS_ACCESS_KEY_ID: str = ""
    AWS_SECRET_ACCESS_KEY: str = ""
    AWS_REGION: str = "us-east-1"

    # Deepgram
    DEEPGRAM_API_KEY: str = ""

    # Caching
    REDIS_URL: str = "redis://localhost:6379"
    CACHE_TTL_SECONDS: int = 300

    # Monitoring
    METRICS_ENABLED: bool = True
    LOG_LEVEL: str = "INFO"

    class Config:
        env_file = ".env"
        case_sensitive = True

class AIProviderConfig:
    def __init__(self):
        self.providers = self._load_providers()

    def _load_providers(self) -> Dict[str, Any]:
        return {
            "tts": {
                "primary": "openai",
                "fallback": ["google", "aws"],
                "providers": {
                    "openai": {
                        "enabled": bool(os.getenv("OPENAI_API_KEY")),
                        "model": "tts-1",
                        "voice": "alloy",
                        "pricing": 0.015,  # per 1K characters
                    },
                    "google": {
                        "enabled": bool(os.getenv("GOOGLE_API_KEY")),
                        "voice": "en-US-Standard-A",
                        "pricing": 0.004,  # per 1K characters
                    },
                    "aws": {
                        "enabled": bool(os.getenv("AWS_ACCESS_KEY_ID")),
                        "engine": "neural",
                        "voice": "Joanna",
                        "pricing": 0.004,  # per 1K characters
                    }
                }
            },
            "stt": {
                "primary": "openai",
                "fallback": ["deepgram", "google"],
                "providers": {
                    "openai": {
                        "enabled": bool(os.getenv("OPENAI_API_KEY")),
                        "model": "whisper-1",
                        "pricing": 0.006,  # per minute
                    },
                    "deepgram": {
                        "enabled": bool(os.getenv("DEEPGRAM_API_KEY")),
                        "model": "nova-2",
                        "pricing": 0.0059,  # per minute
                    },
                    "google": {
                        "enabled": bool(os.getenv("GOOGLE_API_KEY")),
                        "model": "speech-to-text",
                        "pricing": 0.006,  # per minute
                    }
                }
            },
            "llm": {
                "primary": "openai",
                "fallback": ["google"],
                "providers": {
                    "openai": {
                        "enabled": bool(os.getenv("OPENAI_API_KEY")),
                        "model": "gpt-4",
                        "pricing": 0.03,  # per 1K tokens
                        "max_tokens": 4096,
                    },
                    "google": {
                        "enabled": bool(os.getenv("GOOGLE_API_KEY")),
                        "model": "gemini-pro",
                        "pricing": 0.0025,  # per 1K tokens
                        "max_tokens": 2048,
                    }
                }
            }
        }
```

### Step 2: Provider Abstraction Layer

#### 2.1 Base Provider Interface

```python
# apps/ai-gateway/services/base_provider.py
from abc import ABC, abstractmethod
from typing import Dict, Any, Optional, List
from pydantic import BaseModel
import asyncio

class ProviderResponse(BaseModel):
    success: bool
    data: Optional[Dict[str, Any]] = None
    error: Optional[str] = None
    provider: str
    response_time_ms: int
    cost_usd: float
    metadata: Dict[str, Any] = {}

class BaseProvider(ABC):
    def __init__(self, name: str, config: Dict[str, Any]):
        self.name = name
        self.config = config
        self.enabled = config.get("enabled", False)

    @abstractmethod
    async def text_to_speech(self, text: str, **kwargs) -> ProviderResponse:
        """Convert text to speech"""
        pass

    @abstractmethod
    async def speech_to_text(self, audio_data: bytes, **kwargs) -> ProviderResponse:
        """Convert speech to text"""
        pass

    @abstractmethod
    async def generate_text(self, prompt: str, **kwargs) -> ProviderResponse:
        """Generate text using language model"""
        pass

    async def health_check(self) -> bool:
        """Check if provider is healthy"""
        return self.enabled

    def calculate_cost(self, operation: str, usage: Dict[str, Any]) -> float:
        """Calculate cost for operation"""
        pricing = self.config.get("pricing", 0)

        if operation == "tts":
            # Cost per 1K characters
            characters = usage.get("character_count", 0)
            return (characters / 1000) * pricing
        elif operation == "stt":
            # Cost per minute
            duration_minutes = usage.get("duration_seconds", 0) / 60
            return duration_minutes * pricing
        elif operation == "llm":
            # Cost per 1K tokens
            tokens = usage.get("token_count", 0)
            return (tokens / 1000) * pricing

        return 0.0
```

#### 2.2 OpenAI Provider Implementation

```python
# apps/ai-gateway/providers/openai_provider.py
import openai
import asyncio
import time
from typing import Dict, Any, Optional
from services.base_provider import BaseProvider, ProviderResponse
import io
import wave

class OpenAIProvider(BaseProvider):
    def __init__(self, config: Dict[str, Any]):
        super().__init__("openai", config)
        self.client = openai.AsyncOpenAI(
            api_key=config.get("api_key"),
            base_url=config.get("base_url", "https://api.openai.com/v1")
        )

    async def text_to_speech(self, text: str, **kwargs) -> ProviderResponse:
        start_time = time.time()

        try:
            voice = kwargs.get("voice", self.config.get("voice", "alloy"))
            model = kwargs.get("model", self.config.get("model", "tts-1"))

            response = await self.client.audio.speech.create(
                model=model,
                voice=voice,
                input=text
            )

            # Convert to bytes
            audio_bytes = response.content

            response_time_ms = int((time.time() - start_time) * 1000)
            cost = self.calculate_cost("tts", {"character_count": len(text)})

            return ProviderResponse(
                success=True,
                data={
                    "audio_data": audio_bytes,
                    "format": "mp3",
                    "voice": voice,
                    "model": model
                },
                provider=self.name,
                response_time_ms=response_time_ms,
                cost_usd=cost,
                metadata={
                    "character_count": len(text),
                    "model": model,
                    "voice": voice
                }
            )

        except Exception as e:
            response_time_ms = int((time.time() - start_time) * 1000)
            return ProviderResponse(
                success=False,
                error=str(e),
                provider=self.name,
                response_time_ms=response_time_ms,
                cost_usd=0.0
            )

    async def speech_to_text(self, audio_data: bytes, **kwargs) -> ProviderResponse:
        start_time = time.time()

        try:
            # Create audio file-like object
            audio_file = io.BytesIO(audio_data)

            model = kwargs.get("model", self.config.get("model", "whisper-1"))

            transcription = await self.client.audio.transcriptions.create(
                model=model,
                file=("audio.mp3", audio_file, "audio/mpeg")
            )

            response_time_ms = int((time.time() - start_time) * 1000)

            # Estimate duration (this is approximate)
            duration_seconds = len(audio_data) / (16000 * 2)  # Assuming 16kHz mono
            cost = self.calculate_cost("stt", {"duration_seconds": duration_seconds})

            return ProviderResponse(
                success=True,
                data={
                    "text": transcription.text,
                    "model": model,
                    "language": transcription.language
                },
                provider=self.name,
                response_time_ms=response_time_ms,
                cost_usd=cost,
                metadata={
                    "duration_seconds": duration_seconds,
                    "model": model
                }
            )

        except Exception as e:
            response_time_ms = int((time.time() - start_time) * 1000)
            return ProviderResponse(
                success=False,
                error=str(e),
                provider=self.name,
                response_time_ms=response_time_ms,
                cost_usd=0.0
            )

    async def generate_text(self, prompt: str, **kwargs) -> ProviderResponse:
        start_time = time.time()

        try:
            model = kwargs.get("model", self.config.get("model", "gpt-4"))
            max_tokens = kwargs.get("max_tokens", self.config.get("max_tokens", 4096))
            temperature = kwargs.get("temperature", 0.7)

            response = await self.client.chat.completions.create(
                model=model,
                messages=[{"role": "user", "content": prompt}],
                max_tokens=max_tokens,
                temperature=temperature
            )

            text = response.choices[0].message.content
            usage = response.usage

            response_time_ms = int((time.time() - start_time) * 1000)
            cost = self.calculate_cost("llm", {"token_count": usage.total_tokens})

            return ProviderResponse(
                success=True,
                data={
                    "text": text,
                    "model": model,
                    "usage": {
                        "prompt_tokens": usage.prompt_tokens,
                        "completion_tokens": usage.completion_tokens,
                        "total_tokens": usage.total_tokens
                    }
                },
                provider=self.name,
                response_time_ms=response_time_ms,
                cost_usd=cost,
                metadata={
                    "model": model,
                    "temperature": temperature,
                    "max_tokens": max_tokens
                }
            )

        except Exception as e:
            response_time_ms = int((time.time() - start_time) * 1000)
            return ProviderResponse(
                success=False,
                error=str(e),
                provider=self.name,
                response_time_ms=response_time_ms,
                cost_usd=0.0
            )
```

#### 2.3 Provider Manager

```python
# apps/ai-gateway/services/provider_manager.py
from typing import List, Dict, Any, Optional
import asyncio
from providers.openai_provider import OpenAIProvider
from providers.google_provider import GoogleProvider
from providers.aws_provider import AWSProvider
from providers.deepgram_provider import DeepgramProvider
from services.config import AIProviderConfig
from services.base_provider import BaseProvider, ProviderResponse
import logging

logger = logging.getLogger(__name__)

class ProviderManager:
    def __init__(self):
        self.config = AIProviderConfig()
        self.providers = self._initialize_providers()

    def _initialize_providers(self) -> Dict[str, Dict[str, BaseProvider]]:
        providers = {}

        # Initialize TTS providers
        providers["tts"] = {}
        for provider_name, config in self.config.providers["tts"]["providers"].items():
            if config["enabled"]:
                providers["tts"][provider_name] = self._create_provider(provider_name, config)

        # Initialize STT providers
        providers["stt"] = {}
        for provider_name, config in self.config.providers["stt"]["providers"].items():
            if config["enabled"]:
                providers["stt"][provider_name] = self._create_provider(provider_name, config)

        # Initialize LLM providers
        providers["llm"] = {}
        for provider_name, config in self.config.providers["llm"]["providers"].items():
            if config["enabled"]:
                providers["llm"][provider_name] = self._create_provider(provider_name, config)

        return providers

    def _create_provider(self, provider_name: str, config: Dict[str, Any]) -> BaseProvider:
        if provider_name == "openai":
            return OpenAIProvider(config)
        elif provider_name == "google":
            return GoogleProvider(config)
        elif provider_name == "aws":
            return AWSProvider(config)
        elif provider_name == "deepgram":
            return DeepgramProvider(config)
        else:
            raise ValueError(f"Unknown provider: {provider_name}")

    async def execute_with_fallback(
        self,
        service_type: str,
        operation: str,
        *args,
        **kwargs
    ) -> ProviderResponse:
        """
        Execute operation with fallback mechanism
        """
        config = self.config.providers[service_type]
        primary_provider_name = config["primary"]
        fallback_providers = config["fallback"]

        # Try primary provider first
        primary_provider = self.providers[service_type].get(primary_provider_name)
        if primary_provider:
            try:
                response = await self._execute_operation(
                    primary_provider, operation, *args, **kwargs
                )
                if response.success:
                    logger.info(f"Success with primary provider {primary_provider_name}")
                    return response
                else:
                    logger.warning(f"Primary provider {primary_provider_name} failed: {response.error}")
            except Exception as e:
                logger.error(f"Primary provider {primary_provider_name} error: {e}")

        # Try fallback providers
        for fallback_name in fallback_providers:
            fallback_provider = self.providers[service_type].get(fallback_name)
            if fallback_provider:
                try:
                    response = await self._execute_operation(
                        fallback_provider, operation, *args, **kwargs
                    )
                    if response.success:
                        logger.info(f"Success with fallback provider {fallback_name}")
                        return response
                    else:
                        logger.warning(f"Fallback provider {fallback_name} failed: {response.error}")
                except Exception as e:
                    logger.error(f"Fallback provider {fallback_name} error: {e}")

        # All providers failed
        return ProviderResponse(
            success=False,
            error="All AI providers failed",
            provider="none",
            response_time_ms=0,
            cost_usd=0.0
        )

    async def _execute_operation(
        self,
        provider: BaseProvider,
        operation: str,
        *args,
        **kwargs
    ) -> ProviderResponse:
        if operation == "text_to_speech":
            return await provider.text_to_speech(*args, **kwargs)
        elif operation == "speech_to_text":
            return await provider.speech_to_text(*args, **kwargs)
        elif operation == "generate_text":
            return await provider.generate_text(*args, **kwargs)
        else:
            raise ValueError(f"Unknown operation: {operation}")

    async def health_check(self) -> Dict[str, Any]:
        """Check health of all providers"""
        health_status = {}

        for service_type, providers in self.providers.items():
            health_status[service_type] = {}
            for provider_name, provider in providers.items():
                try:
                    is_healthy = await provider.health_check()
                    health_status[service_type][provider_name] = {
                        "healthy": is_healthy,
                        "enabled": provider.enabled
                    }
                except Exception as e:
                    health_status[service_type][provider_name] = {
                        "healthy": False,
                        "error": str(e),
                        "enabled": provider.enabled
                    }

        return health_status

    def get_provider_stats(self) -> Dict[str, Any]:
        """Get statistics about providers"""
        stats = {}

        for service_type, providers in self.providers.items():
            stats[service_type] = {
                "total": len(providers),
                "enabled": sum(1 for p in providers.values() if p.enabled),
                "primary": self.config.providers[service_type]["primary"],
                "fallback": self.config.providers[service_type]["fallback"],
                "providers": list(providers.keys())
            }

        return stats
```

### Step 3: API Routers

#### 3.1 TTS Router

```python
# apps/ai-gateway/routers/tts.py
from fastapi import APIRouter, HTTPException, UploadFile, File
from pydantic import BaseModel
from typing import Optional
from services.provider_manager import ProviderManager
from services.rate_limiter import RateLimiter
from services.monitoring import MonitoringService

router = APIRouter()
provider_manager = ProviderManager()
rate_limiter = RateLimiter()
monitoring = MonitoringService()

class TTSRequest(BaseModel):
    text: str
    voice: Optional[str] = None
    model: Optional[str] = None
    provider: Optional[str] = None

@router.post("/speak")
async def text_to_speech(request: TTSRequest):
    """Convert text to speech"""
    try:
        # Rate limiting check
        if not await rate_limiter.is_allowed("tts"):
            raise HTTPException(status_code=429, detail="Rate limit exceeded")

        # Execute with fallback
        response = await provider_manager.execute_with_fallback(
            "tts", "text_to_speech", request.text,
            voice=request.voice,
            model=request.model
        )

        if not response.success:
            raise HTTPException(status_code=500, detail=response.error)

        # Record metrics
        await monitoring.record_request(
            service="tts",
            provider=response.provider,
            success=True,
            response_time_ms=response.response_time_ms,
            cost_usd=response.cost_usd
        )

        return {
            "success": True,
            "audio_data": response.data["audio_data"].hex(),
            "format": response.data["format"],
            "provider": response.provider,
            "response_time_ms": response.response_time_ms,
            "cost_usd": response.cost_usd,
            "metadata": response.metadata
        }

    except Exception as e:
        await monitoring.record_request(
            service="tts",
            provider="unknown",
            success=False,
            response_time_ms=0,
            cost_usd=0.0,
            error=str(e)
        )
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/voices")
async def get_available_voices():
    """Get available voices for TTS"""
    return {
        "openai": ["alloy", "echo", "fable", "onyx", "nova", "shimmer"],
        "google": ["en-US-Standard-A", "en-US-Standard-B", "en-US-Standard-C"],
        "aws": ["Joanna", "Matthew", "Ivy", "Justin", "Kendra", "Kimberly"]
    }
```

#### 3.2 LLM Router

```python
# apps/ai-gateway/routers/llm.py
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from typing import Optional, List
from services.provider_manager import ProviderManager
from services.rate_limiter import RateLimiter
from services.monitoring import MonitoringService

router = APIRouter()
provider_manager = ProviderManager()
rate_limiter = RateLimiter()
monitoring = MonitoringService()

class LLMRequest(BaseModel):
    prompt: str
    model: Optional[str] = None
    temperature: Optional[float] = 0.7
    max_tokens: Optional[int] = None
    provider: Optional[str] = None

class ScriptGenerationRequest(BaseModel):
    document_content: str
    topic: Optional[str] = None
    difficulty_level: Optional[str] = "intermediate"
    target_duration_minutes: Optional[int] = 10
    language: Optional[str] = "en"

@router.post("/generate")
async def generate_text(request: LLMRequest):
    """Generate text using language model"""
    try:
        if not await rate_limiter.is_allowed("llm"):
            raise HTTPException(status_code=429, detail="Rate limit exceeded")

        response = await provider_manager.execute_with_fallback(
            "llm", "generate_text", request.prompt,
            model=request.model,
            temperature=request.temperature,
            max_tokens=request.max_tokens
        )

        if not response.success:
            raise HTTPException(status_code=500, detail=response.error)

        await monitoring.record_request(
            service="llm",
            provider=response.provider,
            success=True,
            response_time_ms=response.response_time_ms,
            cost_usd=response.cost_usd
        )

        return {
            "success": True,
            "text": response.data["text"],
            "provider": response.provider,
            "usage": response.data["usage"],
            "response_time_ms": response.response_time_ms,
            "cost_usd": response.cost_usd,
            "metadata": response.metadata
        }

    except Exception as e:
        await monitoring.record_request(
            service="llm",
            provider="unknown",
            success=False,
            response_time_ms=0,
            cost_usd=0.0,
            error=str(e)
        )
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/generate-script")
async def generate_conversation_script(request: ScriptGenerationRequest):
    """Generate conversation script from document or topic"""
    try:
        # Build prompt for script generation
        if request.topic:
            prompt = f"""
            Generate a conversation script for English pronunciation practice.

            Topic: {request.topic}
            Difficulty level: {request.difficulty_level}
            Target duration: {request.target_duration_minutes} minutes
            Language: {request.language}

            The script should:
            1. Be a natural conversation between two people (Person A and Person B)
            2. Include 10-15 turns total
            3. Use vocabulary appropriate for {request.difficulty_level} level
            4. Be engaging and educational
            5. Include pronunciation challenges relevant to the topic

            Format the response as JSON with the following structure:
            {{
                "title": "Conversation title",
                "description": "Brief description",
                "estimated_duration_minutes": 10,
                "dialogue": [
                    {{"speaker": "Person A", "text": "Hello!", "pronunciation_notes": "Focus on the 'o' sound in hello"}},
                    {{"speaker": "Person B", "text": "Hi there!", "pronunciation_notes": "Make sure to pronounce the 'th' sound clearly"}}
                ]
            }}
            """
        else:
            prompt = f"""
            Generate a conversation script for English pronunciation practice based on this document:

            Document content: {request.document_content[:2000]}...

            Difficulty level: {request.difficulty_level}
            Target duration: {request.target_duration_minutes} minutes
            Language: {request.language}

            Create a conversation that:
            1. Incorporates key vocabulary and concepts from the document
            2. Provides practice for challenging pronunciation from the content
            3. Is engaging and relevant to the document topic
            4. Includes 10-15 turns between Person A and Person B

            Format the response as JSON with dialogue array including pronunciation notes.
            """

        response = await provider_manager.execute_with_fallback(
            "llm", "generate_text", prompt,
            temperature=0.8,
            max_tokens=2000
        )

        if not response.success:
            raise HTTPException(status_code=500, detail=response.error)

        # Parse the JSON response
        import json
        try:
            script_data = json.loads(response.data["text"])
        except json.JSONDecodeError:
            # Fallback if JSON parsing fails
            script_data = {
                "title": "Generated Conversation",
                "dialogue": response.data["text"],
                "raw_response": response.data["text"]
            }

        await monitoring.record_request(
            service="llm",
            provider=response.provider,
            success=True,
            response_time_ms=response.response_time_ms,
            cost_usd=response.cost_usd
        )

        return {
            "success": True,
            "script": script_data,
            "provider": response.provider,
            "response_time_ms": response.response_time_ms,
            "cost_usd": response.cost_usd
        }

    except Exception as e:
        await monitoring.record_request(
            service="llm",
            provider="unknown",
            success=False,
            response_time_ms=0,
            cost_usd=0.0,
            error=str(e)
        )
        raise HTTPException(status_code=500, detail=str(e))
```

### Step 4: Monitoring and Health Checks

#### 4.1 Health Check Router

```python
# apps/ai-gateway/routers/health.py
from fastapi import APIRouter, HTTPException
from services.provider_manager import ProviderManager
from services.monitoring import MonitoringService
import asyncio

router = APIRouter()
provider_manager = ProviderManager()
monitoring = MonitoringService()

@router.get("/")
async def health_check():
    """Overall health check"""
    try:
        # Check all providers
        provider_health = await provider_manager.health_check()

        # Determine overall status
        all_healthy = all(
            all(provider.get("healthy", False) for provider in service_providers.values())
            for service_providers in provider_health.values()
        )

        return {
            "status": "healthy" if all_healthy else "degraded",
            "timestamp": "2024-01-01T00:00:00Z",  # Use actual timestamp
            "providers": provider_health,
            "stats": provider_manager.get_provider_stats()
        }

    except Exception as e:
        raise HTTPException(status_code=503, detail=str(e))

@router.get("/detailed")
async def detailed_health_check():
    """Detailed health check with timing"""
    try:
        start_time = asyncio.get_event_loop().time()

        provider_health = await provider_manager.health_check()

        end_time = asyncio.get_event_loop().time()
        response_time_ms = int((end_time - start_time) * 1000)

        # Get system metrics
        system_metrics = await monitoring.get_system_metrics()

        return {
            "status": "healthy",
            "response_time_ms": response_time_ms,
            "timestamp": "2024-01-01T00:00:00Z",
            "providers": provider_health,
            "system": system_metrics,
            "stats": provider_manager.get_provider_stats()
        }

    except Exception as e:
        raise HTTPException(status_code=503, detail=str(e))
```

## Docker Configuration

#### 5.1 AI Gateway Dockerfile

```dockerfile
# apps/ai-gateway/Dockerfile
FROM python:3.11-slim

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    gcc \
    g++ \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements and install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY . .

# Create non-root user
RUN useradd -m -u 1000 aiuser && chown -R aiuser:aiuser /app
USER aiuser

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8001/health/ || exit 1

EXPOSE 8001

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8001"]
```

#### 5.2 Requirements File

```txt
# apps/ai-gateway/requirements.txt
fastapi==0.104.1
uvicorn[standard]==0.24.0
pydantic==2.5.0
pydantic-settings==2.1.0
openai==1.3.5
google-cloud-texttospeech==2.14.1
google-cloud-speech==2.24.2
google-generativeai==0.3.2
boto3==1.34.0
deepgram-sdk==2.12.0
redis==5.0.1
httpx==0.25.2
python-multipart==0.0.6
aiofiles==23.2.1
structlog==23.2.0
prometheus-client==0.19.0
psutil==5.9.6
```

## Testing Strategy

### Unit Tests

```python
# apps/ai-gateway/tests/test_provider_manager.py
import pytest
import asyncio
from unittest.mock import Mock, AsyncMock
from services.provider_manager import ProviderManager

@pytest.fixture
def provider_manager():
    return ProviderManager()

@pytest.mark.asyncio
async def test_tts_fallback(provider_manager):
    """Test TTS fallback mechanism"""
    # Mock provider responses
    mock_response = Mock()
    mock_response.success = True
    mock_response.data = {"audio_data": b"fake_audio"}

    # Test fallback execution
    response = await provider_manager.execute_with_fallback(
        "tts", "text_to_speech", "Hello world"
    )

    assert response.provider in ["openai", "google", "aws"]
    assert response.success is True

@pytest.mark.asyncio
async def test_health_check(provider_manager):
    """Test provider health checks"""
    health_status = await provider_manager.health_check()

    assert "tts" in health_status
    assert "stt" in health_status
    assert "llm" in health_status
```

### Integration Tests

```bash
# Test API endpoints
curl -X POST http://localhost:8001/tts/speak \
  -H "Content-Type: application/json" \
  -d '{"text": "Hello world"}'

curl -X POST http://localhost:8001/llm/generate \
  -H "Content-Type: application/json" \
  -d '{"prompt": "Say hello"}'

curl -X GET http://localhost:8001/health/detailed
```

## Estimated Timeline: 1 Week

### Day 1-2: Provider Infrastructure

- Create provider abstraction layer
- Implement OpenAI provider
- Set up provider manager with fallback

### Day 3-4: Additional Providers and API

- Implement Google and AWS providers
- Create API routers for TTS, STT, and LLM
- Add rate limiting and monitoring

### Day 5: Testing and Optimization

- Add comprehensive testing
- Implement health checks
- Optimize performance and error handling

## Success Criteria

- [ ] AI Gateway service running in Docker
- [ ] OpenAI provider integration working
- [ ] Provider fallback mechanism functional
- [ ] TTS endpoint returning audio
- [ ] STT endpoint transcribing audio
- [ ] LLM endpoint generating text
- [ ] Script generation from documents working
- [ ] Health check endpoints operational
- [ ] Rate limiting enforced
- [ ] Cost tracking functional
- [ ] Monitoring metrics collected
- [ ] Error handling comprehensive

This AI Gateway provides a robust, scalable foundation for all AI operations in the pronunciation assistant with provider flexibility and built-in reliability features.
