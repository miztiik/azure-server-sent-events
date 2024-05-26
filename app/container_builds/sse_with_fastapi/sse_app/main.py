import socket
import datetime
import asyncio
import uvicorn
import json
from asyncio import sleep
from fastapi import FastAPI, Request, Response, BackgroundTasks
from fastapi.responses import JSONResponse
from sse_starlette.sse import EventSourceResponse
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import StreamingResponse
import random


MESSAGE_STREAM_DELAY = 1  # second
MESSAGE_STREAM_RETRY_TIMEOUT = 15000  # milisecond
app = FastAPI()

# add CORS so our web page can connect to our api
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

COUNTER = 0


def get_message():
    global COUNTER
    COUNTER += 1
    return COUNTER, COUNTER < 21


app = FastAPI()

# https://devdojo.com/bobbyiliev/how-to-use-server-sent-events-sse-with-fastapi

# uvicorn main:app --reload
custom_headers = {
    "Cache-Control": "no-cache, no-store, must-revalidate",
    "X-Response-Time": f"{socket.gethostname()} at {datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S')}",
    "X-Miztiik-Automation": "True",
    "X-Brand-Tag": "Let's create a society without inequality",
    # "X-Brand-Tag": "ஏற்றத்தாழ்வற்ற சமுதாயம் உருவாக்குவோம்"
}


@app.get("/")
async def root(req: Request, resp: Response):
    __msg = "Hello World"
    __resp = {
        "message": f"{__msg} from {req.client.host}, processed at {str(datetime.datetime.now())}!"
    }
    return JSONResponse(content=__resp, headers=custom_headers)


STREAM_DELAY = 10  # second
RETRY_TIMEOUT = 15000  # milisecond


async def get_msgs():
    global COUNTER
    COUNTER += 1

    # Replace this with your actual logic to fetch new messages
    # This could involve database queries, external API calls, etc.
    print("Simulating fetching messages from external source...")
    await asyncio.sleep(2)  # Simulate external interaction delay
    return [
        {
            "id": COUNTER,
            "message": f"message {COUNTER}",
            "timestamp": str(datetime.datetime.now()),
        },
    ]


async def waypoints_generator():
    for number in range(1, 1001):
        data = json.dumps(
            {
                "loc": {
                    "lat": round(random.uniform(-90, 90), 4),
                    "lng": round(random.uniform(-180, 180), 4),
                },
                "time_generated": str(datetime.datetime.now()),
            }
        )
        await sleep(10)
        yield f"event: locationUpdate\ndata: {data}\n\n"


@app.get("/get-waypoints")
async def root():
    return StreamingResponse(waypoints_generator(), media_type="text/event-stream")


@app.get("/stream")
async def message_stream(request: Request):

    async def event_generator():
        while True:
            # If client closes connection, stop sending events
            if await request.is_disconnected():
                print("-----DISCONNECT TRIGGERED------")
                break

            # Fetch new messages using the external function
            new_msgs = await get_msgs()

            # Send new messages if available
            if new_msgs:
                for m in new_msgs:
                    yield {
                        "event": "new_message",
                        "id": m.get("id"),
                        "retry": RETRY_TIMEOUT,
                        "data": m["message"],
                    }

            await asyncio.sleep(STREAM_DELAY)

    return EventSourceResponse(event_generator())


if __name__ == "__main__":
    # uvicorn.run("main:app", host="127.0.0.1", port=8000, log_level="debug", reload=True)
    uvicorn.run("main:app", host="0.0.0.0", port=80, reload=True)
