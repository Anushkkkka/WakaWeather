# api_server.py
from fastapi import FastAPI, Query
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from datetime import datetime
from weather_confidence import (
    fetch_all, weighted_confidence, confidence_label, summarize,
    detect_severe, adaptive_recommendation, satellite_link, city, country
)
import os
import openai

# -----------------------------------
# FASTAPI APP SETUP
# -----------------------------------

app = FastAPI(title="WakaWeather Confidence API")

# Allow iOS / Android devices and simulator access
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # for local testing
    allow_methods=["*"],
    allow_headers=["*"],
)

# -----------------------------------
# DATA MODELS
# -----------------------------------

class SourceOut(BaseModel):
    name: str
    temp: float
    rain: float
    wind: float
    condition: str

class RangePair(BaseModel):
    min: float
    max: float

class Payload(BaseModel):
    city: str
    country: str
    confidence: float
    label: str
    temp_range: RangePair
    rain_range: RangePair
    conditions: list[str]
    wind_max: float
    severe: bool
    alert: str | None
    recommendation: str
    satellite_url: str
    sources: list[SourceOut]
    generated_at: str

# -----------------------------------
# WEATHER CONFIDENCE ENDPOINT
# -----------------------------------

@app.get("/confidence", response_model=Payload)
def confidence(lat: float = Query(...), lon: float = Query(...), q: str = Query("Suva")):
    forecasts = fetch_all(q, lat, lon)
    if len(forecasts) < 2:
        # Return a minimal payload if not enough data
        return Payload(
            city=q, country=country, confidence=0.0, label="Low",
            temp_range=RangePair(min=0, max=0),
            rain_range=RangePair(min=0, max=0),
            conditions=[],
            wind_max=0.0, severe=False, alert=None,
            recommendation="Forecast uncertain. Try again shortly.",
            satellite_url=satellite_link(lat, lon),
            sources=[],
            generated_at=datetime.utcnow().isoformat()
        )

    f1, f2 = forecasts[0], forecasts[1]
    conf = weighted_confidence(f1, f2)
    label = confidence_label(conf)
    summary = summarize(forecasts)
    severe, alert = detect_severe(f1["condition"], f1["rain"], f1["wind"])
    rec = adaptive_recommendation(f1["condition"], label)

    sources = [
        SourceOut(
            name=f["source"],
            temp=float(f["temp"]),
            rain=float(f["rain"]),
            wind=float(f["wind"]),
            condition=f["condition"]
        )
        for f in forecasts
    ]

    return Payload(
        city=q,
        country=country,
        confidence=float(conf),
        label=label,
        temp_range=RangePair(
            min=float(summary["temp_range"][0]),
            max=float(summary["temp_range"][1])
        ),
        rain_range=RangePair(
            min=float(summary["rain_range"][0]),
            max=float(summary["rain_range"][1])
        ),
        conditions=summary["conditions"],
        wind_max=max(s.wind for s in sources) if sources else 0.0,
        severe=severe,
        alert=alert,
        recommendation=rec,
        satellite_url=satellite_link(lat, lon),
        sources=sources,
        generated_at=datetime.utcnow().isoformat()
    )

# -----------------------------------
# AI CHAT ENDPOINT
# -----------------------------------

# Load OpenAI key (make sure to set it before running)
openai.api_key = os.getenv("OPENAI_API_KEY", "YOUR_OPENAI_KEY_HERE")

class ChatRequest(BaseModel):
    message: str

class ChatResponse(BaseModel):
    reply: str

@app.post("/chat", response_model=ChatResponse)
def chat_with_ai(req: ChatRequest):
    """
    Handle chat messages and return AI-generated responses.
    """
    user_message = req.message.strip()

    # Combine user message with weather-aware context
    prompt = f"""
    You are WakaWeather AI Assistant, helping Pacific island users with friendly weather-related advice.
    Be concise, kind, and weather-aware. If the question isn't about weather, still answer politely.
    User: {user_message}
    """

    try:
        completion = openai.ChatCompletion.create(
            model="gpt-3.5-turbo",
            messages=[
                {"role": "system", "content": "You are a helpful weather assistant."},
                {"role": "user", "content": prompt}
            ],
            temperature=0.7,
            max_tokens=300
        )
        reply = completion.choices[0].message["content"].strip()
        return {"reply": reply}

    except Exception as e:
        print("AI Chat error:", e)
        return {"reply": "Sorry, I’m having trouble answering that right now."}

