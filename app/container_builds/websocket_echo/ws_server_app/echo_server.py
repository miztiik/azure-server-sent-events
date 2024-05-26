import asyncio
import websockets
import socket
import datetime


async def msg_handler(websocket):

    if websocket.path == "/" or websocket.path == "/echo":
        client_ip = websocket.remote_address[0]
        print(f"Client connected from: {client_ip}")
        async for message in websocket:
            __resp = f"Data recieved:  {message} from {client_ip}, processed at {str(datetime.datetime.now())}!"
            print(f"{__resp}\n---\n")
            await websocket.send(__resp)
    elif websocket.path == "/time":
        while True:
            __resp = f"Miztiik say the time🕒 is {str(datetime.datetime.now())} at {socket.gethostname()}"
            await websocket.send(__resp)
            await asyncio.sleep(1)
    else:
        print("\nClient must connect to ws://<yourIP>:<serverPort>.")
        await websocket.send("Unknown path")


async def main():
    async with websockets.serve(msg_handler, "0.0.0.0", 80):
        print("Server started successfully")
        # async with websockets.serve(msg_handler, "localhost", 80):
        await asyncio.Future()  # run forever


asyncio.run(main())
