# WEATHER CONFIDENCE METER – GPT-5 FAST EDITION (Fiji Default + Progress Bar)
# Multithreaded fetch with live progress feedback using tqdm

import csv, json, os, random, sys
import requests
from datetime import datetime, timedelta, timezone
from statistics import pstdev
from concurrent.futures import ThreadPoolExecutor, as_completed
from tqdm import tqdm  # <-- progress bar

try:
    from zoneinfo import ZoneInfo
except Exception:
    ZoneInfo = None

# ==== CONFIG ====
OPENWEATHER_API_KEY = "b80379ef419a2419869dc803295a52fb"
WEATHERAPI_KEY = "5c3ac9730dee40c892c60248250608"
WEATHERSTACK_API_KEY = "0684b523bc9c0adf739f43ec513bafc1"
AI_CHATBOT_URL = "https://www.chatbase.co/chatbot/fXOeYmYGnYPvNLJ7cevzC"

TIMEOUT_S = 4
city, country, lat, lon, tz = "Suva", "Fiji", -18.1248, 178.4501, "Pacific/Fiji"

PACIFIC_EMERGENCY = {
    "Fiji": {
        "NDMO": "https://ndmo.gov.fj/",
        "Met": "https://www.met.gov.fj/",
        "Hotline": "+679 331 9250"
    }
}

# ==== RECOMMENDATIONS ====
RECOMMENDATIONS_SUNNY = [
    "Visit the beaches of Pacific Harbour", "Take a trip to Colo-i-Suva Forest Park",
    "Catch the sunset from Tamavua Hills", "Go reef diving near Beqa Lagoon"
]
RECOMMENDATIONS_RAINY = [
    "Visit TappooCity or MHCC for indoor shopping",
    "Relax at a resort with covered lounges",
    "Go to the cinema or enjoy indoor entertainment",
    "Try local dishes in an indoor food court"
]

# ==== UTILS ====
def retry_get(url):
    try:
        return requests.get(url, timeout=TIMEOUT_S)
    except:
        return None

def local_now(tz_str):
    try:
        if tz_str and ZoneInfo:
            return datetime.now(ZoneInfo(tz_str))
    except Exception:
        pass
    return datetime.now(timezone.utc)

def confidence_label(s): return "High" if s >= 85 else "Moderate" if s >= 60 else "Low"
def satellite_link(lat, lon): return f"https://zoom.earth/#view={lat},{lon},7z/date=now"
def uncertainty_bounds(v): return pstdev(v) if len(v) > 1 else 0.0

# ==== FORECAST APIS ====
def get_openweather(city):
    try:
        r = retry_get(f"https://api.openweathermap.org/data/2.5/forecast?q={city}&appid={OPENWEATHER_API_KEY}&units=metric")
        if not r: return None
        data = r.json()
        target = (datetime.now(timezone.utc) + timedelta(days=1)).strftime("%Y-%m-%d")
        for e in data.get("list", []):
            if e["dt_txt"].startswith(target) and "12:00:00" in e["dt_txt"]:
                return {"source": "OpenWeatherMap", "temp": e["main"]["temp"],
                        "rain": e.get("rain", {}).get("3h", 0),
                        "condition": e["weather"][0]["description"],
                        "wind": e["wind"]["speed"]}
    except: return None

def get_weatherapi(city):
    try:
        r = retry_get(f"http://api.weatherapi.com/v1/forecast.json?key={WEATHERAPI_KEY}&q={city}&days=2")
        if not r: return None
        day = r.json()["forecast"]["forecastday"][1]["day"]
        return {"source": "WeatherAPI", "temp": day["avgtemp_c"], "rain": day["totalprecip_mm"],
                "condition": day["condition"]["text"], "wind": day["maxwind_mph"] * 0.44704}
    except: return None

def get_weatherstack(city):
    try:
        r = retry_get(f"http://api.weatherstack.com/current?access_key={WEATHERSTACK_API_KEY}&query={city}")
        if not r: return None
        cur = r.json()["current"]
        return {"source": "Weatherstack", "temp": cur["temperature"], "rain": cur["precip"],
                "condition": cur["weather_descriptions"][0], "wind": cur["wind_speed"] * 0.277778}
    except: return None

def get_openmeteo(lat, lon):
    try:
        r = retry_get(
            f"https://api.open-meteo.com/v1/forecast?latitude={lat}&longitude={lon}"
            "&hourly=temperature_2m,precipitation,weathercode,windspeed_10m&timezone=auto"
        )
        if not r: return None
        data = r.json()
        t = (datetime.now(timezone.utc) + timedelta(days=1)).strftime("%Y-%m-%dT12:00")
        if t in data["hourly"]["time"]:
            i = data["hourly"]["time"].index(t)
            code = data["hourly"]["weathercode"][i]
            cond = "Storm" if code in [95, 96, 99] else "Clear or Cloudy"
            return {"source": "Open-Meteo", "temp": data["hourly"]["temperature_2m"][i],
                    "rain": data["hourly"]["precipitation"][i], "condition": cond,
                    "wind": data["hourly"]["windspeed_10m"][i]}
    except: return None

# ==== SUMMARY ====
def weighted_confidence(f1, f2):
    td = abs(f1["temp"] - f2["temp"])
    rd = abs(f1["rain"] - f2["rain"])
    return max(0, min(100 - (td * 4 + rd * 5), 100))

def detect_severe(cond, rain, wind):
    if cond and ("storm" in cond.lower() or "cyclone" in cond.lower()):
        return True, "⚠️ Storm or cyclone risk"
    if rain > 10: return True, "⚠️ Heavy rainfall expected"
    if wind > 10: return True, f"⚠️ Strong winds expected ({wind:.1f} m/s)"
    return False, None

def summarize(forecasts):
    temps = [f["temp"] for f in forecasts]; rains = [f["rain"] for f in forecasts]
    conds = sorted({f["condition"] for f in forecasts})
    return {"temp_range": (min(temps), max(temps)), "rain_range": (min(rains), max(rains)),
            "conditions": conds, "temp_unc": uncertainty_bounds(temps), "rain_unc": uncertainty_bounds(rains)}

def adaptive_recommendation(cond, label):
    if label == "Low": return "Forecast uncertain. Prepare for all conditions."
    if "rain" in cond.lower() or "storm" in cond.lower():
        return ", ".join(random.sample(RECOMMENDATIONS_RAINY, 2))
    return ", ".join(random.sample(RECOMMENDATIONS_SUNNY, 2))

# ==== PARALLEL FETCH WITH PROGRESS BAR ====
def fetch_all(city, lat, lon):
    funcs = {
        "OpenWeatherMap": lambda: get_openweather(city),
        "WeatherAPI": lambda: get_weatherapi(city),
        "Open-Meteo": lambda: get_openmeteo(lat, lon),
        "Weatherstack": lambda: get_weatherstack(city)
    }

    results = []
    with ThreadPoolExecutor(max_workers=4) as ex, tqdm(total=4, desc="🌤️ Fetching Data", ncols=70) as bar:
        future_map = {ex.submit(func): name for name, func in funcs.items()}
        for future in as_completed(future_map):
            src = future_map[future]
            try:
                res = future.result()
                if res:
                    results.append(res)
            except:
                pass
            bar.update(1)
            bar.set_postfix_str(f"{src}")
    return results

# ==== MAIN ====
def main():
    show_alerts = "--alerts" in sys.argv
    now_local = local_now(tz)

    forecasts = fetch_all(city, lat, lon)
    if len(forecasts) < 2:
        print("\n❌ Not enough data to generate forecast. Check connection.")
        return

    f1, f2 = forecasts[0], forecasts[1]
    conf = weighted_confidence(f1, f2)
    label = confidence_label(conf)
    summary = summarize(forecasts)
    severe, alert = detect_severe(f1["condition"], f1["rain"], f1["wind"])
    rec = adaptive_recommendation(f1["condition"], label)

    print("\n✅ Data received! Processing results...\n")
    print(f"📍 {city} ({country}) — Tomorrow @ 12:00 (local: {tz})")
    print("\n📡 Forecast Sources:")
    for f in forecasts:
        print(f"- {f['source']}: {round(f['temp'],1)}°C, {round(f['rain'],1)} mm, {f['condition']}, {round(f['wind'],1)} m/s")

    tr, rr = summary["temp_range"], summary["rain_range"]
    print(f"\n🌡️ Temp: {round(tr[0],1)}–{round(tr[1],1)}°C (±{round(summary['temp_unc'],2)}°C)")
    print(f"🌧️ Rain: {round(rr[0],1)}–{round(rr[1],1)} mm (±{round(summary['rain_unc'],2)} mm)")
    print(f"🌥️ Conditions: {', '.join(summary['conditions'])}")
    print(f"📊 Confidence: {round(conf,1)}% ({label})")

    if severe:
        print(f"\n🚨 SEVERE WEATHER: {alert}")

    if show_alerts:
        alerts = gdacs_alerts_pacific()
        if alerts:
            print("\n🌪️ Disaster Alerts (GDACS):")
            for a in alerts:
                print(f"- {a['type']} near {a['country']} (severity: {a['severity']}) {('— '+a['name']) if a.get('name') else ''}")

    print(f"\n✅ Recommendation: {rec}")
    print(f"🛰️ Satellite View: {satellite_link(lat, lon)}")
    print(f"🤖 AI Chatbot: {AI_CHATBOT_URL}")

    if severe and country in PACIFIC_EMERGENCY:
        print("\n📞 Emergency / Official Info:")
        for k, v in PACIFIC_EMERGENCY[country].items():
            print(f"- {k}: {v}")

if __name__ == "__main__":
    main()
