import os
import requests
from fastapi import APIRouter

router = APIRouter(
    prefix="/api/stocks",
    tags=["Stocks API"]
)

API_KEY = os.getenv("FINNHUB_API_KEY")

SYMBOLS = [
    "AAPL",   # Apple
    "TSLA",   # Tesla
    "GOOGL",  # Google
    "AMZN",   # Amazon
    "MSFT",   # Microsoft
    "META",   # Facebook
    "NVDA",   # Nvidia
    "NFLX",   # Netflix
    "AMD",    # AMD
    "INTC"    # Intel
]

@router.get("/")
def get_stocks():
    stocks = []

    for symbol in SYMBOLS:
        url = f"https://finnhub.io/api/v1/quote?symbol={symbol}&token={API_KEY}"
        response = requests.get(url)
        data = response.json()

        stocks.append({
            "symbol": symbol,
            "price": data.get("c"),
            "change": data.get("d"),
            "percent": data.get("dp")
        })

    return stocks

@router.get("/history")
def get_stock_history(symbol: str, range: str = "1W"):
    url = f"https://finnhub.io/api/v1/quote?symbol={symbol}&token={API_KEY}"
    
    response = requests.get(url)
    data = response.json()

    price = data.get("c", 0)

    if range == "1D":
        prices = [price * 0.99, price * 1.01, price]
    elif range == "1M":
        prices = [price * 0.9, price * 0.95, price * 1.05, price]
    else:  # 1W
        prices = [price * 0.95, price * 0.97, price * 0.96, price * 0.98, price]

    return {"prices": prices}