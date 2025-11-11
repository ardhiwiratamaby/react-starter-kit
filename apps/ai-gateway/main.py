from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
import os
from dotenv import load_dotenv

load_dotenv()

app = FastAPI(
    title="AI Gateway Service",
    description="AI service gateway for pronunciation assistant",
    version="1.0.0"
)

# Enable CORS for development
app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:3000", "http://localhost:4000"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.get("/health")
async def health_check():
    """Health check endpoint"""
    return {
        "status": "ok",
        "timestamp": "2024-01-01T00:00:00Z",
        "service": "ai-gateway",
        "version": "1.0.0"
    }

@app.get("/")
async def root():
    """Root endpoint"""
    return {"message": "AI Gateway Service is running"}

@app.get("/test-hot-reload")
async def test_hot_reload():
    """Test endpoint to verify hot reload functionality"""
    return {"message": "Hot reload is working!", "timestamp": "2024-01-01T00:00:00Z"}

# TODO: Add AI service endpoints in Stage 5
# @app.post("/tts")
# async def text_to_speech():
#     pass

# @app.post("/stt")
# async def speech_to_text():
#     pass

# @app.post("/llm")
# async def language_model():
#     pass

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8001)